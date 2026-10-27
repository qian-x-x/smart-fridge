package com.smartfridge.fridge.food;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Positive;

public record MoveFoodRequest(
    @Positive(message = "目标区域 ID 必须为正数")
    long zoneId,

    Long containerId,

    @Min(value = 0, message = "食材版本不能小于 0")
    int version
) {
}
