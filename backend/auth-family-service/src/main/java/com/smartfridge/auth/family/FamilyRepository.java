package com.smartfridge.auth.family;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.sql.Timestamp;
import java.util.List;

@Repository
public class FamilyRepository {

    private static final RowMapper<FamilyView> ROW_MAPPER = (resultSet, rowNum) -> new FamilyView(
        resultSet.getLong("id"),
        resultSet.getString("name"),
        resultSet.getString("invite_code"),
        resultSet.getLong("owner_user_id"),
        resultSet.getString("role"),
        resultSet.getTimestamp("created_at").toInstant()
    );

    private final JdbcTemplate jdbcTemplate;

    public FamilyRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public FamilyView create(String name, String inviteCode, long ownerUserId) {
        jdbcTemplate.update(
            """
                INSERT INTO family (name, invite_code, owner_user_id)
                VALUES (?, ?, ?)
                """,
            name,
            inviteCode,
            ownerUserId
        );
        return jdbcTemplate.query(
            """
                SELECT id, name, invite_code, owner_user_id, created_at, 'OWNER' AS role
                FROM family
                WHERE invite_code = ?
                """,
            ROW_MAPPER,
            inviteCode
        ).stream().findFirst()
            .orElseThrow(() -> new IllegalStateException("Newly created family was not found"));
    }

    public void addMember(long familyId, long userId, String role) {
        jdbcTemplate.update(
            """
                INSERT INTO family_member (family_id, user_id, role)
                VALUES (?, ?, ?)
                """,
            familyId,
            userId,
            role
        );
    }

    public List<FamilyView> findAllByUserId(long userId) {
        return jdbcTemplate.query(
            """
                SELECT f.id, f.name, f.invite_code, f.owner_user_id, f.created_at, fm.role
                FROM family f
                JOIN family_member fm ON fm.family_id = f.id
                WHERE fm.user_id = ?
                ORDER BY f.created_at DESC
                """,
            ROW_MAPPER,
            userId
        );
    }

    public String findRole(long familyId, long userId) {
        List<String> roles = jdbcTemplate.query(
            "SELECT role FROM family_member WHERE family_id = ? AND user_id = ?",
            (resultSet, rowNum) -> resultSet.getString("role"),
            familyId,
            userId
        );
        return roles.stream().findFirst().orElse(null);
    }
}
