/*
 * 这个文件：菜谱的一种原料：名称、数量、单位。
 */

package com.smartfridge.recipe.catalog;

import java.math.BigDecimal;

public record RecipeIngredientView(
    String name,
    BigDecimal quantity,
    String unit,
    boolean optional
) {
}
