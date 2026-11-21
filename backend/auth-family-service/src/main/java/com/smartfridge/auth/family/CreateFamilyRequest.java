/*
 * 这个文件：创建家庭的请求体：只需要一个家庭名称。
 */

package com.smartfridge.auth.family;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateFamilyRequest(
    @NotBlank(message = "家庭名称不能为空")
    @Size(max = 60, message = "家庭名称不能超过 60 个字符")
    String name
) {
}
