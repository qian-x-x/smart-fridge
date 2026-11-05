package com.smartfridge.fridge.food;

import java.math.BigDecimal;
import java.time.Instant;

public record FoodOperationView(
    long id,
    long fridgeId,
    long foodItemId,
    String foodName,
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
    boolean undone,
    boolean undoable,
    Instant createdAt
) {
}
