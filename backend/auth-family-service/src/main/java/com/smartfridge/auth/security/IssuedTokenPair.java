/*
 * 这个文件：内部用的「一对新令牌」结果：access、refresh、refresh 的编号和过期时间。
 */

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
