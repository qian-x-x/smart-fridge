/*
 * 这个文件：Seata 全局事务的范围：建家庭 → 建冰箱 → 收尾，任何一步失败，整体回滚。
 */

package com.smartfridge.auth.workspace;

import io.seata.spring.annotation.GlobalTransactional;
import org.springframework.stereotype.Service;

@Service
public class WorkspaceTransaction {
    private final WorkspaceDraftService drafts;
    private final WorkspaceFridgeGateway fridges;

    public WorkspaceTransaction(WorkspaceDraftService drafts, WorkspaceFridgeGateway fridges) {
        this.drafts = drafts;
        this.fridges = fridges;
    }

    @GlobalTransactional(name = "family-workspace-create", rollbackFor = Exception.class, timeoutMills = 20000)
    public WorkspaceView create(long userId, String authorization, CreateWorkspaceRequest request) {
        var family = drafts.prepare(userId, request);
        long fridgeId = fridges.initialize(family.id(), userId, authorization);
        drafts.finish(userId, request.requestId(), fridgeId);
        return new WorkspaceView(family, fridgeId);
    }
}
