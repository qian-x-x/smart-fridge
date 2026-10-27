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
