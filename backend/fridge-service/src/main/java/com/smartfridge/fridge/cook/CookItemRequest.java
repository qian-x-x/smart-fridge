package com.smartfridge.fridge.cook;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.math.BigDecimal;

public record CookItemRequest(
    @Positive(message = "食材 ID 必须为正数")
    long foodItemId,

    @NotNull(message = "扣减数量不能为空")
    @DecimalMin(value = "0.001", message = "扣减数量必须大于 0")
    @Digits(integer = 9, fraction = 3, message = "扣减数量最多 9 位整数和 3 位小数")
    BigDecimal quantity,

    @Min(value = 0, message = "食材版本不能小于 0")
    Integer version
) {
}
