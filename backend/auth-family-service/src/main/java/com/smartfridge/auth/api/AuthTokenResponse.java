/*
 * 这个文件：登录或注册成功后返回给前端的内容：两种 token、有效期、用户资料。
 */

package com.smartfridge.auth.api;

public record AuthTokenResponse(
    String accessToken,
    String refreshToken,
    String tokenType,
    long expiresIn,
    UserView user
) {
}
