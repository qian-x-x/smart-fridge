package com.smartfridge.auth.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

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
}
