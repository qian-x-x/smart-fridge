package com.smartfridge.fridge.cook;

import java.time.Instant;
import java.util.List;

public record CookRecordView(
    long id,
    long fridgeId,
    long recipeId,
    String recipeName,
    long actorUserId,
    int servings,
    String note,
    Instant createdAt,
    List<CookItemView> items
) {
}
