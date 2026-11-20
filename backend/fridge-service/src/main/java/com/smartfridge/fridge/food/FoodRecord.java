package com.smartfridge.fridge.food;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

public record FoodRecord(
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
    String tags,
    String modelKey,
    String photoUrl,
    String status,
    int version,
    long createdBy,
    long updatedBy,
    Instant createdAt,
    Instant updatedAt
) {
    public static boolean isStickerModel(String modelKey) {
        return modelKey != null && modelKey.trim().startsWith("sticker:");
    }
}
