package com.smartfridge.auth.security;

import java.time.Instant;

public record TokenClaims(
    long userId,
    String username,
    String platformRole,
    String tokenId,
    TokenType tokenType,
    Instant expiresAt
) {
}
