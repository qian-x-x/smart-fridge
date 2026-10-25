package com.smartfridge.auth.security;

import java.time.Instant;

public record IssuedTokenPair(
    String accessToken,
    String refreshToken,
    String refreshTokenId,
    Instant refreshExpiresAt,
    long expiresInSeconds
) {
}
