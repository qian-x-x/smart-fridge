/*
 * 这个文件：批量导入食材的请求体（一次提交多条）。
 */

package com.smartfridge.fridge.food;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.util.List;

public record CatalogFoodBatchRequest(
    @Positive(message = "冰箱 ID 必须为正数")
    long fridgeId,
    @NotBlank @Size(min = 8, max = 64) @Pattern(regexp = "[A-Za-z0-9_-]+")
    String requestId,
    @NotEmpty @Size(max = 200, message = "每批最多添加 200 种食材")
    List<@NotNull @Valid Item> items
) {
    public record Item(
        @Positive long zoneId,
        @NotBlank @Size(max = 72) String name,
        @NotBlank @Size(max = 40) String category,
        @NotNull @Positive @Digits(integer = 9, fraction = 0, message = "份量须为正整数") BigDecimal portions
    ) {}
}
