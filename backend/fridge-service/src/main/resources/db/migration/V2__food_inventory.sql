CREATE TABLE IF NOT EXISTS food_item (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    fridge_id BIGINT NOT NULL,
    zone_id BIGINT NOT NULL,
    container_id BIGINT,
    name VARCHAR(80) NOT NULL,
    category VARCHAR(40) NOT NULL,
    quantity DECIMAL(12, 3) NOT NULL,
    unit VARCHAR(20) NOT NULL,
    production_date DATE NOT NULL,
    expires_on DATE NOT NULL,
    tags VARCHAR(500) NOT NULL DEFAULT '',
    model_key VARCHAR(80),
    photo_url VARCHAR(500),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    version INT NOT NULL DEFAULT 0,
    created_by BIGINT NOT NULL,
    updated_by BIGINT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_food_quantity CHECK (quantity >= 0),
    CONSTRAINT fk_food_fridge FOREIGN KEY (fridge_id) REFERENCES fridge (id),
    CONSTRAINT fk_food_zone FOREIGN KEY (zone_id) REFERENCES fridge_zone (id),
    CONSTRAINT fk_food_container FOREIGN KEY (container_id) REFERENCES fridge_container (id)
);

CREATE INDEX idx_food_fridge_status ON food_item (fridge_id, status, expires_on);
CREATE INDEX idx_food_zone ON food_item (zone_id, status);
CREATE INDEX idx_food_name ON food_item (fridge_id, name);

CREATE TABLE IF NOT EXISTS food_operation (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    fridge_id BIGINT NOT NULL,
    food_item_id BIGINT NOT NULL,
    actor_user_id BIGINT NOT NULL,
    action VARCHAR(20) NOT NULL,
    old_zone_id BIGINT,
    old_container_id BIGINT,
    old_quantity DECIMAL(12, 3),
    new_zone_id BIGINT,
    new_container_id BIGINT,
    new_quantity DECIMAL(12, 3),
    note VARCHAR(200),
    original_operation_id BIGINT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_operation_fridge FOREIGN KEY (fridge_id) REFERENCES fridge (id),
    CONSTRAINT fk_operation_food FOREIGN KEY (food_item_id) REFERENCES food_item (id),
    CONSTRAINT fk_operation_original FOREIGN KEY (original_operation_id) REFERENCES food_operation (id)
);

CREATE INDEX idx_food_operation_item ON food_operation (food_item_id, created_at);
CREATE INDEX idx_food_operation_fridge ON food_operation (fridge_id, created_at);
