/*
 * 这个文件：移动食材的请求体：从哪个分区挪到哪个分区/容器。
 */

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
