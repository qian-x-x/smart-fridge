package com.smartfridge.fridge.food;

import java.math.BigDecimal;
import java.time.Instant;

record FoodOperationRecord(
    long id,
    long fridgeId,
    long foodItemId,
    long actorUserId,
    String action,
    Long oldZoneId,
    Long oldContainerId,
    BigDecimal oldQuantity,
    Long newZoneId,
    Long newContainerId,
    BigDecimal newQuantity,
    String note,
    Long originalOperationId,
    Long revertedByOperationId,
    Instant createdAt
) {
}
