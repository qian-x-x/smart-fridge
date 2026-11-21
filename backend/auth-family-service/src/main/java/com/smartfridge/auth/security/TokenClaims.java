/*
 * 这个文件：解析出来后的 token 内容：用户 id、用户名、角色、令牌编号、类型、过期时间。
 */

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
