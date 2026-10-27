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
