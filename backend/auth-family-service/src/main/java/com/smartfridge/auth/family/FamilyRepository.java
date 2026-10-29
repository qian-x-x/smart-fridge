package com.smartfridge.auth.family;

import java.sql.Timestamp;
import java.util.List;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

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
    private static final RowMapper<FamilyRecord> FAMILY_RECORD_MAPPER =
        (resultSet, rowNum) -> new FamilyRecord(
            resultSet.getLong("id"),
            resultSet.getString("name"),
            resultSet.getString("invite_code"),
            resultSet.getLong("owner_user_id"),
            resultSet.getTimestamp("created_at").toInstant()
        );

    public Optional<FamilyRecord> findById(long familyId) {
        return jdbcTemplate.query(
            """
                SELECT id, name, invite_code, owner_user_id, created_at
                FROM family
                WHERE id = ?
                """,
            FAMILY_RECORD_MAPPER,
            familyId
        ).stream().findFirst();
    }

    public Optional<FamilyRecord> findByInviteCode(String inviteCode) {
        return jdbcTemplate.query(
            """
                SELECT id, name, invite_code, owner_user_id, created_at
                FROM family
                WHERE invite_code = ?
                """,
            FAMILY_RECORD_MAPPER,
            inviteCode
        ).stream().findFirst();
    }

    private static final RowMapper<FamilyMemberView> MEMBER_MAPPER =
        (resultSet, rowNum) -> new FamilyMemberView(
            resultSet.getLong("user_id"),
            resultSet.getString("username"),
            resultSet.getString("display_name"),
            resultSet.getString("role"),
            resultSet.getTimestamp("joined_at").toInstant(),
            resultSet.getBoolean("is_current_member")
        );

    public List<FamilyMemberView> findMembers(long familyId, long currentUserId) {
        return jdbcTemplate.query(
            """
                SELECT fm.user_id, u.username, u.display_name, fm.role, fm.joined_at,
                       CASE WHEN fm.user_id = ? THEN TRUE ELSE FALSE END AS is_current_member
                FROM family_member fm
                JOIN app_user u ON u.id = fm.user_id
                WHERE fm.family_id = ?
                ORDER BY CASE fm.role
                             WHEN 'OWNER' THEN 0
                             WHEN 'EDITOR' THEN 1
                             ELSE 2
                         END,
                         fm.joined_at,
                         fm.id
                """,
            MEMBER_MAPPER,
            currentUserId,
            familyId
        );
    }

    public java.util.Optional<FamilyMemberView> findMember(
        long familyId,
        long userId,
        long currentUserId
    ) {
        return jdbcTemplate.query(
            """
                SELECT fm.user_id, u.username, u.display_name, fm.role, fm.joined_at,
                       CASE WHEN fm.user_id = ? THEN TRUE ELSE FALSE END AS is_current_member
                FROM family_member fm
                JOIN app_user u ON u.id = fm.user_id
                WHERE fm.family_id = ? AND fm.user_id = ?
                """,
            MEMBER_MAPPER,
            currentUserId,
            familyId,
            userId
        ).stream().findFirst();
    }

    public java.util.Optional<FamilyRecord> lockById(long familyId) {
        return jdbcTemplate.query(
            """
                SELECT id, name, invite_code, owner_user_id, created_at
                FROM family
                WHERE id = ?
                FOR UPDATE
                """,
            FAMILY_RECORD_MAPPER,
            familyId
        ).stream().findFirst();
    }

    public void updateMemberRole(long familyId, long userId, String role) {
        jdbcTemplate.update(
            """
                UPDATE family_member
                SET role = ?
                WHERE family_id = ? AND user_id = ?
                """,
            role,
            familyId,
            userId
        );
    }

    public void removeMember(long familyId, long userId) {
        jdbcTemplate.update(
            "DELETE FROM family_member WHERE family_id = ? AND user_id = ?",
            familyId,
            userId
        );
    }

    public void transferOwner(long familyId, long currentOwnerId, long newOwnerId) {
        jdbcTemplate.update(
            """
                UPDATE family
                SET owner_user_id = ?, updated_at = CURRENT_TIMESTAMP
                WHERE id = ? AND owner_user_id = ?
                """,
            newOwnerId,
            familyId,
            currentOwnerId
        );
        jdbcTemplate.update(
            "UPDATE family_member SET role = 'OWNER' WHERE family_id = ? AND user_id = ?",
            familyId,
            newOwnerId
        );
        jdbcTemplate.update(
            "UPDATE family_member SET role = 'EDITOR' WHERE family_id = ? AND user_id = ?",
            familyId,
            currentOwnerId
        );
    }

}
