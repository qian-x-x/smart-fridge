/*
 * 这个文件：一次做饭的完整记录：菜谱、份数、谁做的、扣了哪些食材、备注。
 */

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
