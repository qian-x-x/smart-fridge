CREATE TABLE food_catalog_batch (
    fridge_id BIGINT NOT NULL,
    actor_user_id BIGINT NOT NULL,
    request_id VARCHAR(64) NOT NULL,
    payload_hash CHAR(64) NOT NULL,
    item_count INT NOT NULL,
    PRIMARY KEY (fridge_id, actor_user_id, request_id),
    CONSTRAINT fk_catalog_batch_fridge FOREIGN KEY (fridge_id) REFERENCES fridge (id)
);
