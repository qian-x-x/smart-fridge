package com.smartfridge.auth.workspace;

import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Repository
public class WorkspaceRepository {
    private final JdbcTemplate jdbc;

    public WorkspaceRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    Optional<WorkspaceRecord> find(long userId, String requestId) {
        return jdbc.query("""
            SELECT actor_user_id, request_id, family_name, family_id, fridge_id, xid, completed
            FROM family_workspace_request WHERE actor_user_id = ? AND request_id = ?
            """, (rs, row) -> {
                long fridgeId = rs.getLong("fridge_id");
                Long nullableFridgeId = rs.wasNull() ? null : fridgeId;
                return new WorkspaceRecord(rs.getLong("actor_user_id"), rs.getString("request_id"),
                    rs.getString("family_name"), rs.getLong("family_id"), nullableFridgeId,
                    rs.getString("xid"), rs.getBoolean("completed"));
            }, userId, requestId).stream().findFirst();
    }

    Optional<WorkspaceRecord> findFamily(long familyId) {
        return jdbc.query("""
            SELECT actor_user_id, request_id FROM family_workspace_request WHERE family_id = ?
            """, (rs, row) -> new Object[]{rs.getLong(1), rs.getString(2)}, familyId)
            .stream().findFirst().flatMap(key -> find((Long) key[0], (String) key[1]));
    }

    // A caller may already hold a REPEATABLE_READ snapshot from before global
    // rollback. Probe current committed data on a separate read transaction.
    @Transactional(propagation = Propagation.REQUIRES_NEW,
        isolation = Isolation.READ_COMMITTED, readOnly = true)
    public Optional<FamilyFence> fence(long familyId) {
        return jdbc.query("""
            SELECT f.workspace_pending, w.xid, w.fridge_id, w.completed
            FROM family f LEFT JOIN family_workspace_request w ON w.family_id = f.id
            WHERE f.id = ?
            """, (rs, row) -> {
                long fridgeId = rs.getLong("fridge_id");
                Long nullableFridgeId = rs.wasNull() ? null : fridgeId;
                return new FamilyFence(rs.getBoolean("workspace_pending"), rs.getString("xid"),
                    nullableFridgeId, rs.getBoolean("completed"));
            }, familyId).stream().findFirst();
    }

    record FamilyFence(boolean pending, String xid, Long fridgeId, boolean completed) {}

    void confirm(long familyId) {
        jdbc.update("""
            UPDATE family_workspace_request SET completed = TRUE
            WHERE family_id = ? AND fridge_id IS NOT NULL AND completed = FALSE
            """, familyId);
        jdbc.update("UPDATE family SET workspace_pending = FALSE WHERE id = ?", familyId);
    }

    void claim(long userId, CreateWorkspaceRequest request, String xid) {
        jdbc.update("""
            INSERT INTO family_workspace_request(actor_user_id, request_id, family_name, xid)
            VALUES (?, ?, ?, ?)
            """, userId, request.requestId(), request.normalizedName(), xid);
    }

    void attachFamily(long userId, String requestId, long familyId) {
        jdbc.update("UPDATE family SET workspace_pending = TRUE WHERE id = ?", familyId);
        jdbc.update("""
            UPDATE family_workspace_request SET family_id = ?
            WHERE actor_user_id = ? AND request_id = ?
            """, familyId, userId, requestId);
    }

    void finish(long userId, String requestId, long fridgeId) {
        int changed = jdbc.update("""
            UPDATE family_workspace_request SET fridge_id = ?
            WHERE actor_user_id = ? AND request_id = ? AND fridge_id IS NULL
            """, fridgeId, userId, requestId);
        if (changed != 1) throw new IllegalStateException("家庭初始化请求状态已变化");
    }
}
