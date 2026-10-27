package com.smartfridge.recipe.catalog;

import java.math.BigDecimal;

public record RecipeIngredientView(
    String name,
    BigDecimal quantity,
    String unit,
    boolean optional
) {
}
