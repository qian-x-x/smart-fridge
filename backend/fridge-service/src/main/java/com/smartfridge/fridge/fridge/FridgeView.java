package com.smartfridge.fridge.fridge;

import java.time.Instant;
import java.util.List;

public record FridgeView(
    long id,
    long familyId,
    String name,
    String timezone,
    List<FridgeZoneView> zones,
    Instant createdAt,
    Instant updatedAt
) {
}
