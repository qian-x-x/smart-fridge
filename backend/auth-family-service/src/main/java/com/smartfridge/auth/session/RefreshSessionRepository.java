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
}
