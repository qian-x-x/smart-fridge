/*
 * 这个文件：创建家庭的总调度：先查这个 requestId 是不是已经处理过（幂等重放），
 * 没处理过就开全局事务去建；失败或并发重复时再根据状态决定是重试、等待还是报错。
 */

package com.smartfridge.auth.workspace;

import com.alibaba.csp.sentinel.annotation.SentinelResource;
import com.alibaba.csp.sentinel.slots.block.BlockException;
import com.smartfridge.auth.family.FamilyService;
import com.smartfridge.common.api.ErrorCode;
import com.smartfridge.common.error.BusinessException;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

@Service
public class WorkspaceService {
    private final WorkspaceRepository repository;
    private final WorkspaceTransaction transaction;
    private final WorkspaceTransactionStatus status;
    private final FamilyService families;
    private final FamilyWorkspaceVisibility visibility;

    public WorkspaceService(WorkspaceRepository repository, WorkspaceTransaction transaction,
                            WorkspaceTransactionStatus status, FamilyService families,
                            FamilyWorkspaceVisibility visibility) {
        this.repository = repository;
        this.transaction = transaction;
        this.status = status;
        this.families = families;
        this.visibility = visibility;
    }

    @SentinelResource(value = "family-workspace-create", blockHandler = "blocked",
        exceptionsToIgnore = BusinessException.class)
    public Result create(long userId, String authorization, CreateWorkspaceRequest request) {
        var previous = repository.find(userId, request.requestId());
        if (previous.isPresent()) return replay(userId, request);
        try {
            var workspace = transaction.create(userId, authorization, request);
            visibility.confirmCommitted(workspace.family().id());
            return new Result(workspace, true);
        } catch (DuplicateKeyException exception) {
            // Resolve after the losing global transaction has finished rolling back.
            return replay(userId, request);
        }
    }

    private Result replay(long userId, CreateWorkspaceRequest request) {
        var saved = repository.find(userId, request.requestId())
            .orElseThrow(() -> BusinessException.conflict("创建请求状态已变化，请使用原请求重试"));
        if (!saved.familyName().equals(request.normalizedName())) {
            throw BusinessException.conflict("同一请求标识不能用于不同的家庭名称");
        }
        if (saved.fridgeId() == null || (!saved.completed() && !status.committed(saved.xid()))) {
            throw BusinessException.conflict("家庭正在初始化，请稍后使用原请求重试");
        }
        // AT phase-one rows can be visible before the global decision. Never
        // return them as a successful replay while their global tx is active.
        var confirmed = repository.find(userId, request.requestId())
            .filter(row -> row.fridgeId() != null && row.familyId() == saved.familyId())
            .orElseThrow(() -> BusinessException.conflict("家庭初始化已回滚，请使用原请求重试"));
        var family = families.requireMember(userId, confirmed.familyId());
        visibility.confirmCommitted(family.id());
        return new Result(new WorkspaceView(family, confirmed.fridgeId()), false);
    }

    public Result blocked(long userId, String authorization, CreateWorkspaceRequest request,
                          BlockException exception) {
        throw new BusinessException(ErrorCode.TOO_MANY_REQUESTS, HttpStatus.TOO_MANY_REQUESTS,
            "创建家庭过于频繁，请稍后重试");
    }

    public record Result(WorkspaceView workspace, boolean created) {}
}
