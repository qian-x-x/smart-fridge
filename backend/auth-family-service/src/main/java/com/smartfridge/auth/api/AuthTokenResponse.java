package com.smartfridge.auth.api;

public record AuthTokenResponse(
    String accessToken,
    String refreshToken,
    String tokenType,
    long expiresIn,
    UserView user
) {
}
