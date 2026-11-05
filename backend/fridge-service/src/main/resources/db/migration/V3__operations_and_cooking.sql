ALTER TABLE food_operation ADD COLUMN reverted_by_operation_id BIGINT;

ALTER TABLE food_operation ADD CONSTRAINT fk_operation_reverted_by
    FOREIGN KEY (reverted_by_operation_id) REFERENCES food_operation (id);

CREATE INDEX idx_food_operation_reverted ON food_operation (reverted_by_operation_id);

CREATE TABLE IF NOT EXISTS cook_record (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    fridge_id BIGINT NOT NULL,
    recipe_id BIGINT NOT NULL,
    recipe_name VARCHAR(80) NOT NULL,
    actor_user_id BIGINT NOT NULL,
    servings INT NOT NULL,
    request_id VARCHAR(64) NOT NULL,
    note VARCHAR(200),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_cook_record_request UNIQUE (fridge_id, request_id),
    CONSTRAINT ck_cook_record_servings CHECK (servings >= 1),
    CONSTRAINT fk_cook_record_fridge FOREIGN KEY (fridge_id) REFERENCES fridge (id)
);

CREATE INDEX idx_cook_record_fridge ON cook_record (fridge_id, created_at);

CREATE TABLE IF NOT EXISTS cook_record_item (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    cook_record_id BIGINT NOT NULL,
    food_item_id BIGINT NOT NULL,
    food_name VARCHAR(80) NOT NULL,
    quantity DECIMAL(12, 3) NOT NULL,
    unit VARCHAR(20) NOT NULL,
    CONSTRAINT ck_cook_item_quantity CHECK (quantity > 0),
    CONSTRAINT fk_cook_item_record FOREIGN KEY (cook_record_id) REFERENCES cook_record (id),
    CONSTRAINT fk_cook_item_food FOREIGN KEY (food_item_id) REFERENCES food_item (id)
);

CREATE INDEX idx_cook_item_record ON cook_record_item (cook_record_id);
