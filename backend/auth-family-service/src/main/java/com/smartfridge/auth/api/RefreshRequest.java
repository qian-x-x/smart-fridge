/*
 * 这个文件：用 refreshToken 换新 token 的请求体。
 */

package com.smartfridge.auth.api;

import jakarta.validation.constraints.NotBlank;

public record RefreshRequest(
    @NotBlank(message = "刷新令牌不能为空")
    String refreshToken
) {
}
