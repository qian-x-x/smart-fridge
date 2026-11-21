/*
 * 这个文件：refreshToken 的会话表：保存、判断是否有效、撤销、消费。
 * 「消费」保证同一个 refreshToken 只能换一次新令牌，防止被盗后反复使用。
 */

package com.smartfridge.auth.session;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.Timestamp;
import java.time.Instant;

@Repository
public class RefreshSessionRepository {

    private final JdbcTemplate jdbcTemplate;

    public RefreshSessionRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public void save(String tokenId, long userId, Instant expiresAt) {
        jdbcTemplate.update(
            """
                INSERT INTO refresh_session (token_jti, user_id, expires_at, revoked)
                VALUES (?, ?, ?, FALSE)
                """,
            tokenId,
            userId,
            Timestamp.from(expiresAt)
        );
    }

    public boolean existsActive(String tokenId) {
        Integer count = jdbcTemplate.queryForObject(
            """
                SELECT COUNT(*)
                FROM refresh_session
                WHERE token_jti = ? AND revoked = FALSE AND expires_at > CURRENT_TIMESTAMP
                """,
            Integer.class,
            tokenId
        );
        return count != null && count > 0;
    }

    public void revoke(String tokenId) {
        jdbcTemplate.update(
            "UPDATE refresh_session SET revoked = TRUE WHERE token_jti = ?",
            tokenId
        );
    }

    public boolean consumeActive(String tokenId) {
        return jdbcTemplate.update(
            "UPDATE refresh_session SET revoked = TRUE " +
                "WHERE token_jti = ? AND revoked = FALSE AND expires_at > CURRENT_TIMESTAMP",
            tokenId
        ) == 1;
    }
}
