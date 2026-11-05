package com.smartfridge.fridge.cook;

import java.math.BigDecimal;

public record CookItemView(
    long foodItemId,
    String foodName,
    BigDecimal quantity,
    String unit
) {
}
