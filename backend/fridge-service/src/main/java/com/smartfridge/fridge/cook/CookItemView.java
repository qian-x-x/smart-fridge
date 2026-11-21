/*
 * 这个文件：做饭记录里的一项明细：食材名、扣减数量、单位。
 */

package com.smartfridge.fridge.cook;

import java.math.BigDecimal;

public record CookItemView(
    long foodItemId,
    String foodName,
    BigDecimal quantity,
    String unit
) {
}
