package com.smartfridge.auth.workspace;

import com.smartfridge.common.api.ErrorCode;
import com.smartfridge.common.error.BusinessException;
import io.seata.core.context.RootContext;
import io.seata.core.model.GlobalStatus;
import io.seata.tm.api.GlobalTransactionContext;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

@Component
public class WorkspaceTransactionStatus {
    private final boolean enabled;

    public WorkspaceTransactionStatus(@Value("${seata.enabled:true}") boolean enabled) {
        this.enabled = enabled;
    }

    String currentXid() {
        String xid = RootContext.getXID();
        if (!enabled || xid == null) throw unavailable();
        return xid;
    }

    boolean committed(String xid) {
        if (!enabled || xid == null) throw unavailable();
        try {
            GlobalStatus status = GlobalTransactionContext.reload(xid).getStatus();
            return hasCommitDecision(status);
        } catch (Exception exception) {
            throw unavailable();
        }
    }

    static boolean hasCommitDecision(GlobalStatus status) {
        // AT returns Committed before TC finishes asynchronous undo-log cleanup.
        // AsyncCommitting already has an irrevocable commit decision.
        return status == GlobalStatus.Committed || status == GlobalStatus.AsyncCommitting
            || status == GlobalStatus.Finished;
    }

    private BusinessException unavailable() {
        return new BusinessException(ErrorCode.INTERNAL_ERROR, HttpStatus.SERVICE_UNAVAILABLE,
            "家庭初始化事务服务暂时不可用，请使用原请求重试");
    }
}
