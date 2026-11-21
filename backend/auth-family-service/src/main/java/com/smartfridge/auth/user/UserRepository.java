/*
 * 这个文件：用户表的 SQL：判断用户名/手机号是否已存在、新增、按账号或 id 查询。
 */

package com.smartfridge.auth.user;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public class UserRepository {

    private static final RowMapper<UserAccount> ROW_MAPPER = (resultSet, rowNum) -> new UserAccount(
        resultSet.getLong("id"),
        resultSet.getString("username"),
        resultSet.getString("phone"),
        resultSet.getString("password_hash"),
        resultSet.getString("display_name"),
        resultSet.getString("platform_role"),
        resultSet.getString("status")
    );

    private final JdbcTemplate jdbcTemplate;

    public UserRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public boolean existsByUsername(String username) {
        Integer count = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM app_user WHERE username = ?",
            Integer.class,
            username
        );
        return count != null && count > 0;
    }

    public boolean existsByPhone(String phone) {
        Integer count = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM app_user WHERE phone = ?",
            Integer.class,
            phone
        );
        return count != null && count > 0;
    }

    public UserAccount insert(
        String username,
        String phone,
        String passwordHash,
        String displayName
    ) {
        jdbcTemplate.update(
            """
                INSERT INTO app_user (username, phone, password_hash, display_name, platform_role, status)
                VALUES (?, ?, ?, ?, 'USER', 'ACTIVE')
                """,
            username,
            phone,
            passwordHash,
            displayName
        );
        return findByIdentifier(username != null ? username : phone)
            .orElseThrow(() -> new IllegalStateException("Newly created user was not found"));
    }

    public Optional<UserAccount> findByIdentifier(String identifier) {
        List<UserAccount> users = jdbcTemplate.query(
            """
                SELECT id, username, phone, password_hash, display_name, platform_role, status
                FROM app_user
                WHERE username = ? OR phone = ?
                LIMIT 1
                """,
            ROW_MAPPER,
            identifier,
            identifier
        );
        return users.stream().findFirst();
    }

    public Optional<UserAccount> findById(long userId) {
        List<UserAccount> users = jdbcTemplate.query(
            """
                SELECT id, username, phone, password_hash, display_name, platform_role, status
                FROM app_user
                WHERE id = ?
                """,
            ROW_MAPPER,
            userId
        );
        return users.stream().findFirst();
    }
}
