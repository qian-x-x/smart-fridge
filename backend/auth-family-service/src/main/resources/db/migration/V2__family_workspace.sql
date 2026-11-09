CREATE TABLE family_workspace_request (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    actor_user_id BIGINT NOT NULL,
    request_id VARCHAR(64) NOT NULL,
    family_name VARCHAR(60) NOT NULL,
    family_id BIGINT,
    fridge_id BIGINT,
    xid VARCHAR(128),
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_workspace_request UNIQUE (actor_user_id, request_id)
);

-- Seata AT branch undo data for auth_db. No historical migration is changed.
CREATE TABLE IF NOT EXISTS undo_log (
    branch_id BIGINT NOT NULL,
    xid VARCHAR(128) NOT NULL,
    context VARCHAR(128) NOT NULL,
    rollback_info LONGBLOB NOT NULL,
    log_status INT NOT NULL,
    log_created DATETIME(6) NOT NULL,
    log_modified DATETIME(6) NOT NULL,
    CONSTRAINT ux_auth_undo UNIQUE (xid, branch_id)
);
