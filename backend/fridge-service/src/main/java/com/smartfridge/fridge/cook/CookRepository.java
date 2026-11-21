/*
 * 这个文件：做饭记录表和明细表的 SQL 操作。
 */

package com.smartfridge.fridge.cook;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.sql.PreparedStatement;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

@Repository
public class CookRepository {

    private static final RowMapper<CookHeader> HEADER_MAPPER = (resultSet, rowNum) -> new CookHeader(
        resultSet.getLong("id"),
        resultSet.getLong("fridge_id"),
        resultSet.getLong("recipe_id"),
        resultSet.getString("recipe_name"),
        resultSet.getLong("actor_user_id"),
        resultSet.getInt("servings"),
        resultSet.getString("note"),
        resultSet.getTimestamp("created_at").toInstant()
    );

    private final JdbcTemplate jdbcTemplate;

    public CookRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public Optional<CookRecordView> findByRequestId(long fridgeId, String requestId) {
        return jdbcTemplate.query(
            """
                SELECT id, fridge_id, recipe_id, recipe_name, actor_user_id,
                       servings, note, created_at
                FROM cook_record
                WHERE fridge_id = ? AND request_id = ?
                """,
            HEADER_MAPPER,
            fridgeId,
            requestId
        ).stream().findFirst().map(this::withItems);
    }

    public Optional<CookRecordView> findById(long cookRecordId, long fridgeId) {
        return jdbcTemplate.query(
            """
                SELECT id, fridge_id, recipe_id, recipe_name, actor_user_id,
                       servings, note, created_at
                FROM cook_record
                WHERE id = ? AND fridge_id = ?
                """,
            HEADER_MAPPER,
            cookRecordId,
            fridgeId
        ).stream().findFirst().map(this::withItems);
    }

    public List<CookRecordView> list(long fridgeId, int limit) {
        return jdbcTemplate.query(
            """
                SELECT id, fridge_id, recipe_id, recipe_name, actor_user_id,
                       servings, note, created_at
                FROM cook_record
                WHERE fridge_id = ?
                ORDER BY created_at DESC, id DESC
                LIMIT ?
                """,
            HEADER_MAPPER,
            fridgeId,
            limit
        ).stream().map(this::withItems).toList();
    }

    public long insert(
        long fridgeId,
        long recipeId,
        String recipeName,
        long actorUserId,
        int servings,
        String requestId,
        String note
    ) {
        KeyHolder keys = new GeneratedKeyHolder();
        jdbcTemplate.update(connection -> {
            PreparedStatement statement = connection.prepareStatement(
                """
                    INSERT INTO cook_record (
                        fridge_id, recipe_id, recipe_name, actor_user_id,
                        servings, request_id, note
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                new String[]{"id"}
            );
            statement.setLong(1, fridgeId);
            statement.setLong(2, recipeId);
            statement.setString(3, recipeName);
            statement.setLong(4, actorUserId);
            statement.setInt(5, servings);
            statement.setString(6, requestId);
            statement.setString(7, note);
            return statement;
        }, keys);
        Number key = keys.getKey();
        if (key == null) {
            throw new IllegalStateException("Database did not return a generated key");
        }
        return key.longValue();
    }

    public void insertItem(
        long cookRecordId,
        long foodItemId,
        String foodName,
        BigDecimal quantity,
        String unit
    ) {
        jdbcTemplate.update(
            """
                INSERT INTO cook_record_item (
                    cook_record_id, food_item_id, food_name, quantity, unit
                )
                VALUES (?, ?, ?, ?, ?)
                """,
            cookRecordId,
            foodItemId,
            foodName,
            quantity,
            unit
        );
    }

    private CookRecordView withItems(CookHeader header) {
        List<CookItemView> items = jdbcTemplate.query(
            """
                SELECT food_item_id, food_name, quantity, unit
                FROM cook_record_item
                WHERE cook_record_id = ?
                ORDER BY id ASC
                """,
            (resultSet, rowNum) -> new CookItemView(
                resultSet.getLong("food_item_id"),
                resultSet.getString("food_name"),
                resultSet.getBigDecimal("quantity"),
                resultSet.getString("unit")
            ),
            header.id()
        );
        return new CookRecordView(
            header.id(),
            header.fridgeId(),
            header.recipeId(),
            header.recipeName(),
            header.actorUserId(),
            header.servings(),
            header.note(),
            header.createdAt(),
            items
        );
    }

    private record CookHeader(
        long id,
        long fridgeId,
        long recipeId,
        String recipeName,
        long actorUserId,
        int servings,
        String note,
        Instant createdAt
    ) {
    }
}
