package com.smartfridge.fridge.fridge;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

public record CreateFridgeRequest(
    @Positive(message = "家庭 ID 必须为正数")
    long familyId,

    @NotBlank(message = "冰箱名称不能为空")
    @Size(max = 80, message = "冰箱名称不能超过 80 个字符")
    String name
) {
}
