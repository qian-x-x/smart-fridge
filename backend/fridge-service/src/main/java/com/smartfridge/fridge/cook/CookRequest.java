package com.smartfridge.fridge.cook;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.util.List;

public record CookRequest(
    @Positive(message = "菜谱 ID 必须为正数")
    long recipeId,

    @NotBlank(message = "菜谱名称不能为空")
    @Size(max = 80, message = "菜谱名称不能超过 80 个字符")
    String recipeName,

    @NotNull(message = "份数不能为空")
    @Min(value = 1, message = "份数不能小于 1")
    @Max(value = 20, message = "份数不能大于 20")
    Integer servings,

    @NotBlank(message = "请求标识不能为空")
    @Size(min = 8, max = 64, message = "请求标识长度需在 8 到 64 之间")
    @Pattern(regexp = "^[A-Za-z0-9_-]+$", message = "请求标识只能包含字母、数字、下划线和连字符")
    String requestId,

    @Size(max = 200, message = "做饭备注不能超过 200 个字符")
    String note,

    @NotEmpty(message = "扣减清单不能为空")
    @Size(max = 20, message = "单次做饭最多扣减 20 种食材")
    List<@Valid CookItemRequest> items
) {
}
