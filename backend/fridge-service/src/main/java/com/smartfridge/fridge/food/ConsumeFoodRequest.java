package com.smartfridge.fridge.food;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

public record ConsumeFoodRequest(
    @NotNull(message = "使用数量不能为空")
    @DecimalMin(value = "0.001", message = "使用数量必须大于 0")
    BigDecimal quantity,

    @Min(value = 0, message = "食材版本不能小于 0")
    int version
) {
}
