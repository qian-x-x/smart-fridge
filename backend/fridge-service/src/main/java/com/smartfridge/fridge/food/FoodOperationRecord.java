/*
 * 这个文件：流水表的一行：谁在什么时候对哪个食材做了什么，前后状态各是什么。
 */

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
