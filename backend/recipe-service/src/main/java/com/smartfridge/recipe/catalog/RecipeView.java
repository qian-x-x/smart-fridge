/*
 * 这个文件：返回给前端的菜谱：名称、图片、原料清单、制作步骤。
 */

package com.smartfridge.recipe.catalog;

import java.util.List;

public record RecipeView(
    long id,
    String name,
    String summary,
    String category,
    int durationMinutes,
    int calories,
    String difficulty,
    int servings,
    String coverEmoji,
    List<String> steps,
    List<RecipeIngredientView> ingredients,
    boolean featured
) {
}
