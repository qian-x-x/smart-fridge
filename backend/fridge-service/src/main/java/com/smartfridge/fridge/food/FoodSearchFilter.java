/*
 * 这个文件：食材搜索条件：关键字、分区、状态、日期范围等。
 */

package com.smartfridge.fridge.food;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.util.List;
import org.springframework.format.annotation.DateTimeFormat;

public record FoodSearchFilter(
    @Size(max = 80) String query,
    @Size(max = 40) String category,
    @Size(max = 20) List<@NotBlank @Size(max = 40) @Pattern(regexp = "[^,]*") String> tags,
    @Positive Long zoneId,
    ExpiryState expiryState,
    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate expiresFrom,
    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate expiresTo,
    Sort sort
) {
    public enum ExpiryState { ALL, EXPIRED, EXPIRING, FRESH }
    public enum Sort { EXPIRES_ASC, EXPIRES_DESC, NAME_ASC, CREATED_DESC }

    @AssertTrue(message = "到期日期下限不能晚于上限")
    public boolean isDateRangeValid() {
        return expiresFrom == null || expiresTo == null || !expiresFrom.isAfter(expiresTo);
    }
}
