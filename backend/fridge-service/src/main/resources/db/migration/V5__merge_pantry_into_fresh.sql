-- Keep each item and both ends of its timeline in the same fridge.
-- The retired containers have no equivalent in the default cold compartment.
UPDATE food_item
SET zone_id = (SELECT id FROM fridge_zone WHERE fridge_id = food_item.fridge_id AND code = 'FRESH'),
    container_id = NULL,
    version = version + 1
WHERE zone_id IN (SELECT id FROM fridge_zone WHERE code = 'PANTRY');

UPDATE food_operation
SET old_zone_id = (SELECT id FROM fridge_zone WHERE fridge_id = food_operation.fridge_id AND code = 'FRESH'),
    old_container_id = NULL
WHERE old_zone_id IN (SELECT id FROM fridge_zone WHERE code = 'PANTRY');

UPDATE food_operation
SET new_zone_id = (SELECT id FROM fridge_zone WHERE fridge_id = food_operation.fridge_id AND code = 'FRESH'),
    new_container_id = NULL
WHERE new_zone_id IN (SELECT id FROM fridge_zone WHERE code = 'PANTRY');

DELETE FROM fridge_container
WHERE zone_id IN (SELECT id FROM fridge_zone WHERE code = 'PANTRY');

DELETE FROM fridge_zone WHERE code = 'PANTRY';
