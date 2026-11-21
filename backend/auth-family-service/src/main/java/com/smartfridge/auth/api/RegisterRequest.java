/*
 * 这个文件：注册请求体：用户名、手机号、显示名称、密码。
 * 除了长度和格式校验，还额外检查密码编码后不超过 72 字节（BCrypt 的硬性上限）。
 */

package com.smartfridge.auth.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import jakarta.validation.constraints.AssertTrue;

public record RegisterRequest(
    @Size(min = 3, max = 40, message = "用户名长度应为 3 至 40 个字符")
    @Pattern(regexp = "^[a-zA-Z0-9_]*$", message = "用户名只能包含字母、数字和下划线")
    String username,

    @Pattern(regexp = "^$|^1[3-9]\\d{9}$", message = "手机号格式不正确")
    String phone,

    @NotBlank(message = "显示名称不能为空")
    @Size(max = 40, message = "显示名称不能超过 40 个字符")
    String displayName,

    @NotBlank(message = "密码不能为空")
    @Size(min = 8, max = 72, message = "密码长度应为 8 至 72 个字符")
    String password
) {
    @AssertTrue(message = "密码编码后不能超过 72 字节")
    public boolean isPasswordWithinStorageLimit() {
        return password == null || password.getBytes(java.nio.charset.StandardCharsets.UTF_8).length <= 72;
    }
}
