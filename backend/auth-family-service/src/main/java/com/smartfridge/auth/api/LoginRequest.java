package com.smartfridge.auth.api;

import jakarta.validation.constraints.NotBlank;

public record LoginRequest(
    @NotBlank(message = "用户名或手机号不能为空")
    String identifier,

    @NotBlank(message = "密码不能为空")
    String password
) {
}
