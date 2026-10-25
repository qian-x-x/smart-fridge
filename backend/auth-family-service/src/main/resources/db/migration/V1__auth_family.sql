CREATE TABLE IF NOT EXISTS app_user (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(40),
    phone VARCHAR(20),
    password_hash VARCHAR(100) NOT NULL,
    display_name VARCHAR(40) NOT NULL,
    platform_role VARCHAR(20) NOT NULL DEFAULT 'USER',
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_app_user_username UNIQUE (username),
    CONSTRAINT uk_app_user_phone UNIQUE (phone)
);

CREATE TABLE IF NOT EXISTS family (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(60) NOT NULL,
    invite_code VARCHAR(16) NOT NULL,
    owner_user_id BIGINT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_family_invite_code UNIQUE (invite_code),
    CONSTRAINT fk_family_owner FOREIGN KEY (owner_user_id) REFERENCES app_user (id)
);

CREATE TABLE IF NOT EXISTS family_member (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    family_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    role VARCHAR(20) NOT NULL,
    joined_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_family_member UNIQUE (family_id, user_id),
    CONSTRAINT fk_member_family FOREIGN KEY (family_id) REFERENCES family (id),
    CONSTRAINT fk_member_user FOREIGN KEY (user_id) REFERENCES app_user (id)
);

CREATE INDEX idx_family_member_user ON family_member (user_id);

CREATE TABLE IF NOT EXISTS refresh_session (
    token_jti VARCHAR(64) PRIMARY KEY,
    user_id BIGINT NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    revoked BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_refresh_user FOREIGN KEY (user_id) REFERENCES app_user (id)
);

CREATE INDEX idx_refresh_session_user ON refresh_session (user_id, revoked, expires_at);
