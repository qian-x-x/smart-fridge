package com.smartfridge.auth.workspace;

import com.smartfridge.common.error.BusinessException;
import io.seata.core.context.RootContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Hide phase-one families from ordinary users until the global decision. */
@Service
public class FamilyWorkspaceVisibility {
    private static final Logger log = LoggerFactory.getLogger(FamilyWorkspaceVisibility.class);
    private final WorkspaceRepository repository;
    private final WorkspaceTransactionStatus status;

    public FamilyWorkspaceVisibility(WorkspaceRepository repository, WorkspaceTransactionStatus status) {
        this.repository = repository;
        this.status = status;
    }

    public boolean visible(long familyId) {
        var pending = repository.fence(familyId);
        if (pending.isEmpty()) return false;
        var row = pending.get();
        if (!row.pending() || row.completed()) return true;
        String callerXid = RootContext.getXID();
        if (callerXid != null && callerXid.equals(row.xid())) return true;
        return row.fridgeId() != null && status.committed(row.xid())
            && repository.fence(familyId).isPresent();
    }

    @Transactional
    public void confirmCommitted(long familyId) {
        var row = repository.findFamily(familyId).orElseThrow(() ->
            BusinessException.conflict("家庭初始化已回滚，请使用原请求重试"));
        if (!row.completed() && !status.committed(row.xid())) {
            throw BusinessException.conflict("家庭正在初始化，请稍后使用原请求重试");
        }
        try {
            // This method is called after the coordinator's global interceptor
            // has committed and unbound its XID, never inside phase one.
            repository.confirm(familyId);
        } catch (DataAccessException exception) {
            log.warn("Could not cache committed workspace confirmation for family {}", familyId);
        }
    }
}
