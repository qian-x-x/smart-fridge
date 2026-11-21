/*
 * 这个文件：返回给前端的食材信息，比数据库多了「还剩几天过期」和「是否临期」。
 */

package com.smartfridge.fridge.food;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

public record FoodView(
    long id,
    long fridgeId,
    long zoneId,
    Long containerId,
    String name,
    String category,
    BigDecimal quantity,
    String unit,
    LocalDate productionDate,
    LocalDate expiresOn,
    long remainingDays,
    boolean expiring,
    List<String> tags,
    String modelKey,
    String photoUrl,
    long createdBy,
    long updatedBy,
    int version,
    Instant createdAt,
    Instant updatedAt
) {
}
