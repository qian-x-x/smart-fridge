/*
 * 这个文件：返回给前端的流水条目：动作、操作人、时间、数量变化、能否撤销。
 */

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
