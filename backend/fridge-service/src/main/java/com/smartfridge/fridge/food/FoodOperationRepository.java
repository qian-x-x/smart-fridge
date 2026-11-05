package com.smartfridge.fridge.food;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.sql.PreparedStatement;
import java.util.List;
import java.util.Optional;
import java.util.Set;

@Repository
public class FoodOperationRepository {

    static final Set<String> UNDOABLE_ACTIONS = Set.of("MOVE", "CONSUME", "COOK", "DISCARD");

    private static final RowMapper<FoodOperationRecord> ROW_MAPPER = (resultSet, rowNum) ->
        new FoodOperationRecord(
            resultSet.getLong("id"),
            resultSet.getLong("fridge_id"),
            resultSet.getLong("food_item_id"),
            resultSet.getLong("actor_user_id"),
            resultSet.getString("action"),
            resultSet.getObject("old_zone_id", Long.class),
            resultSet.getObject("old_container_id", Long.class),
            resultSet.getBigDecimal("old_quantity"),
            resultSet.getObject("new_zone_id", Long.class),
            resultSet.getObject("new_container_id", Long.class),
            resultSet.getBigDecimal("new_quantity"),
            resultSet.getString("note"),
            resultSet.getObject("original_operation_id", Long.class),
            resultSet.getObject("reverted_by_operation_id", Long.class),
            resultSet.getTimestamp("created_at").toInstant()
        );

    private final JdbcTemplate jdbcTemplate;

    public FoodOperationRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<FoodOperationView> timeline(long fridgeId, Long foodItemId, int limit) {
        String sql = """
            SELECT o.id, o.fridge_id, o.food_item_id, f.name AS food_name,
                   o.actor_user_id, o.action,
                   o.old_zone_id, o.old_container_id, o.old_quantity,
                   o.new_zone_id, o.new_container_id, o.new_quantity,
                   o.note, o.original_operation_id, o.reverted_by_operation_id,
                   o.created_at
            FROM food_operation o
            JOIN food_item f ON f.id = o.food_item_id
            WHERE o.fridge_id = ?
            """ + (foodItemId == null ? "" : " AND o.food_item_id = ? ") + """
            ORDER BY o.created_at DESC, o.id DESC
            LIMIT ?
            """;
        Object[] args = foodItemId == null
            ? new Object[]{fridgeId, limit}
            : new Object[]{fridgeId, foodItemId, limit};
        return jdbcTemplate.query(sql, (resultSet, rowNum) -> toView(
            resultSet.getLong("id"),
            resultSet.getLong("fridge_id"),
            resultSet.getLong("food_item_id"),
            resultSet.getString("food_name"),
            resultSet.getLong("actor_user_id"),
            resultSet.getString("action"),
            resultSet.getObject("old_zone_id", Long.class),
            resultSet.getObject("old_container_id", Long.class),
            resultSet.getBigDecimal("old_quantity"),
            resultSet.getObject("new_zone_id", Long.class),
            resultSet.getObject("new_container_id", Long.class),
            resultSet.getBigDecimal("new_quantity"),
            resultSet.getString("note"),
            resultSet.getObject("original_operation_id", Long.class),
            resultSet.getObject("reverted_by_operation_id", Long.class),
            resultSet.getTimestamp("created_at").toInstant()
        ), args);
    }

    public Optional<FoodOperationRecord> findOperation(long operationId, long fridgeId) {
        return jdbcTemplate.query(
            """
                SELECT id, fridge_id, food_item_id, actor_user_id, action,
                       old_zone_id, old_container_id, old_quantity,
                       new_zone_id, new_container_id, new_quantity,
                       note, original_operation_id, reverted_by_operation_id,
                       created_at
                FROM food_operation
                WHERE id = ? AND fridge_id = ?
                """,
            ROW_MAPPER,
            operationId,
            fridgeId
        ).stream().findFirst();
    }

    public Optional<FoodOperationRecord> findById(long operationId) {
        return jdbcTemplate.query(
            """
                SELECT id, fridge_id, food_item_id, actor_user_id, action,
                       old_zone_id, old_container_id, old_quantity,
                       new_zone_id, new_container_id, new_quantity,
                       note, original_operation_id, reverted_by_operation_id,
                       created_at
                FROM food_operation
                WHERE id = ?
                """,
            ROW_MAPPER,
            operationId
        ).stream().findFirst();
    }

    public long insertOperation(
        long fridgeId,
        long foodItemId,
        long actorUserId,
        String action,
        Long oldZoneId,
        Long oldContainerId,
        BigDecimal oldQuantity,
        Long newZoneId,
        Long newContainerId,
        BigDecimal newQuantity,
        String note,
        Long originalOperationId
    ) {
        KeyHolder keys = new GeneratedKeyHolder();
        jdbcTemplate.update(connection -> {
            PreparedStatement statement = connection.prepareStatement(
                """
                    INSERT INTO food_operation (
                        fridge_id, food_item_id, actor_user_id, action,
                        old_zone_id, old_container_id, old_quantity,
                        new_zone_id, new_container_id, new_quantity,
                        note, original_operation_id
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                new String[]{"id"}
            );
            statement.setLong(1, fridgeId);
            statement.setLong(2, foodItemId);
            statement.setLong(3, actorUserId);
            statement.setString(4, action);
            statement.setObject(5, oldZoneId);
            statement.setObject(6, oldContainerId);
            statement.setObject(7, oldQuantity);
            statement.setObject(8, newZoneId);
            statement.setObject(9, newContainerId);
            statement.setObject(10, newQuantity);
            statement.setString(11, note);
            statement.setObject(12, originalOperationId);
            return statement;
        }, keys);
        Number key = keys.getKey();
        if (key == null) {
            throw new IllegalStateException("Database did not return a generated key");
        }
        return key.longValue();
    }

    public boolean markUndone(long operationId, long undoOperationId) {
        return jdbcTemplate.update(
            """
                UPDATE food_operation
                SET reverted_by_operation_id = ?
                WHERE id = ?
                  AND reverted_by_operation_id IS NULL
                """,
            undoOperationId,
            operationId
        ) == 1;
    }

    public boolean clearReversion(long operationId, long expectedUndoOperationId) {
        return jdbcTemplate.update(
            """
                UPDATE food_operation
                SET reverted_by_operation_id = NULL
                WHERE id = ?
                  AND reverted_by_operation_id = ?
                """,
            operationId,
            expectedUndoOperationId
        ) == 1;
    }

    private FoodOperationView toView(
        long id,
        long fridgeId,
        long foodItemId,
        String foodName,
        long actorUserId,
        String action,
        Long oldZoneId,
        Long oldContainerId,
        BigDecimal oldQuantity,
        Long newZoneId,
        Long newContainerId,
        BigDecimal newQuantity,
        String note,
        Long originalOperationId,
        Long revertedByOperationId,
        java.time.Instant createdAt
    ) {
        boolean undone = revertedByOperationId != null;
        boolean undoable = !undone
            && UNDOABLE_ACTIONS.contains(action)
            && originalOperationId == null;
        return new FoodOperationView(
            id,
            fridgeId,
            foodItemId,
            foodName,
            actorUserId,
            action,
            oldZoneId,
            oldContainerId,
            oldQuantity,
            newZoneId,
            newContainerId,
            newQuantity,
            note,
            originalOperationId,
            revertedByOperationId,
            undone,
            undoable,
            createdAt
        );
    }
}
