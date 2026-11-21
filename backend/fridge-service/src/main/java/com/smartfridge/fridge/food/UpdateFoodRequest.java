/*
 * 这个文件：编辑食材信息的请求体（名称、数量、日期、标签等）。
 */

package com.smartfridge.fridge.food;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Pattern;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record UpdateFoodRequest(
    @Positive(message = "区域 ID 必须为正数")
    long zoneId,

    Long containerId,

    @NotBlank(message = "食材名称不能为空")
    @Size(max = 80, message = "食材名称不能超过 80 个字符")
    String name,

    @NotBlank(message = "食材分类不能为空")
    @Size(max = 40, message = "食材分类不能超过 40 个字符")
    String category,

    @NotNull(message = "食材数量不能为空")
    @DecimalMin(value = "0.001", message = "食材数量必须大于 0")
    @Digits(integer = 9, fraction = 3, message = "食材数量最多 9 位整数和 3 位小数")
    BigDecimal quantity,

    @NotBlank(message = "食材单位不能为空")
    @Size(max = 20, message = "食材单位不能超过 20 个字符")
    String unit,

    @NotNull(message = "生产日期不能为空")
    LocalDate productionDate,

    @NotNull(message = "到期日期不能为空")
    LocalDate expiresOn,

    @Size(max = 20, message = "食材标签不能超过 20 个")
    List<@NotBlank(message = "标签不能为空")
        @Pattern(regexp = "^[^,]*$", message = "单个标签不能包含逗号")
        @Size(max = 30, message = "单个标签不能超过 30 个字符") String> tags,

    @Size(max = 80, message = "食材模型标识不能超过 80 个字符")
    String modelKey,

    @Size(max = 500, message = "食材照片地址不能超过 500 个字符")
    String photoUrl,

    @Min(value = 0, message = "食材版本不能小于 0")
    int version
) {
}
