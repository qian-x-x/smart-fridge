package com.smartfridge.auth.api;

import jakarta.validation.constraints.NotBlank;

public record LoginRequest(
    @NotBlank(message = "用户名或手机号不能为空")
    String identifier,

    @NotBlank(message = "密码不能为空")
    String password
) {
    @jakarta.validation.constraints.AssertTrue(message = "密码编码后不能超过 72 字节")
    public boolean isPasswordWithinStorageLimit() {
        return password == null || password.getBytes(java.nio.charset.StandardCharsets.UTF_8).length <= 72;
    }
}
