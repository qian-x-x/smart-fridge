CREATE TABLE IF NOT EXISTS fridge (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    family_id BIGINT NOT NULL,
    name VARCHAR(80) NOT NULL,
    timezone VARCHAR(40) NOT NULL DEFAULT 'Asia/Shanghai',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_fridge_family UNIQUE (family_id)
);

CREATE TABLE IF NOT EXISTS fridge_zone (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    fridge_id BIGINT NOT NULL,
    code VARCHAR(20) NOT NULL,
    name VARCHAR(40) NOT NULL,
    temperature_c DECIMAL(4, 1),
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_fridge_zone_code UNIQUE (fridge_id, code),
    CONSTRAINT fk_fridge_zone_fridge FOREIGN KEY (fridge_id) REFERENCES fridge (id)
);

CREATE INDEX idx_fridge_zone_fridge ON fridge_zone (fridge_id, sort_order);

CREATE TABLE IF NOT EXISTS fridge_container (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    zone_id BIGINT NOT NULL,
    name VARCHAR(40) NOT NULL,
    container_type VARCHAR(20) NOT NULL,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_fridge_container_order UNIQUE (zone_id, sort_order),
    CONSTRAINT fk_fridge_container_zone FOREIGN KEY (zone_id) REFERENCES fridge_zone (id)
);

CREATE INDEX idx_fridge_container_zone ON fridge_container (zone_id, sort_order);
