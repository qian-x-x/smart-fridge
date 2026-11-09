package com.smartfridge.auth.workspace;

import com.smartfridge.common.error.BusinessException;
import io.seata.core.context.RootContext;
import io.seata.core.model.GlobalStatus;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class WorkspaceTransactionStatusTest {
    @Test void atCommitRemainsSuccessfulWhileUndoLogsAreCleanedAsynchronously() {
        assertThat(WorkspaceTransactionStatus.hasCommitDecision(GlobalStatus.AsyncCommitting)).isTrue();
        assertThat(WorkspaceTransactionStatus.hasCommitDecision(GlobalStatus.Committed)).isTrue();
        assertThat(WorkspaceTransactionStatus.hasCommitDecision(GlobalStatus.Begin)).isFalse();
        assertThat(WorkspaceTransactionStatus.hasCommitDecision(GlobalStatus.Committing)).isFalse();
        assertThat(WorkspaceTransactionStatus.hasCommitDecision(GlobalStatus.Rollbacking)).isFalse();
        assertThat(WorkspaceTransactionStatus.hasCommitDecision(GlobalStatus.Rollbacked)).isFalse();
        assertThat(WorkspaceTransactionStatus.hasCommitDecision(GlobalStatus.CommitFailed)).isFalse();
    }

    @Test void disabledSeataCannotSilentlyCreateAPartialWorkspace() {
        assertThatThrownBy(() -> new WorkspaceTransactionStatus(false).currentXid())
            .isInstanceOf(BusinessException.class);
    }

    @Test void enabledSeataStillRequiresAnActiveGlobalTransaction() {
        RootContext.unbind();
        assertThatThrownBy(() -> new WorkspaceTransactionStatus(true).currentXid())
            .isInstanceOf(BusinessException.class);
    }
}
