package com.smartfridge.fridge.food;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Repository;

import java.sql.Date;
import java.sql.PreparedStatement;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;

@Repository
public class FoodRepository {

    private static final RowMapper<FoodRecord> ROW_MAPPER = (resultSet, rowNum) -> new FoodRecord(
        resultSet.getLong("id"),
        resultSet.getLong("fridge_id"),
        resultSet.getLong("zone_id"),
        resultSet.getObject("container_id", Long.class),
        resultSet.getString("name"),
        resultSet.getString("category"),
        resultSet.getBigDecimal("quantity"),
        resultSet.getString("unit"),
        resultSet.getDate("production_date").toLocalDate(),
        resultSet.getDate("expires_on").toLocalDate(),
        resultSet.getString("tags"),
        resultSet.getString("model_key"),
        resultSet.getString("photo_url"),
        resultSet.getString("status"),
        resultSet.getInt("version"),
        resultSet.getLong("created_by"),
        resultSet.getLong("updated_by"),
        resultSet.getTimestamp("created_at").toInstant(),
        resultSet.getTimestamp("updated_at").toInstant()
    );

    private final JdbcTemplate jdbcTemplate;

    public FoodRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    Optional<CatalogBatch> findCatalogBatch(long fridgeId, long userId, String requestId) {
        return jdbcTemplate.query(
            """
                SELECT payload_hash, item_count FROM food_catalog_batch
                WHERE fridge_id = ? AND actor_user_id = ? AND request_id = ?
                """,
            (rs, rowNum) -> new CatalogBatch(rs.getString("payload_hash"), rs.getInt("item_count")),
            fridgeId, userId, requestId
        ).stream().findFirst();
    }

    void insertCatalogBatch(long fridgeId, long userId, String requestId, String hash, int itemCount) {
        jdbcTemplate.update(
            """
                INSERT INTO food_catalog_batch (fridge_id, actor_user_id, request_id, payload_hash, item_count)
                VALUES (?, ?, ?, ?, ?)
                """,
            fridgeId, userId, requestId, hash, itemCount
        );
    }

    record CatalogBatch(String payloadHash, int itemCount) {}

    public FoodView create(CreateFoodRequest request, long userId) {
        KeyHolder keys = new GeneratedKeyHolder();
        jdbcTemplate.update(connection -> {
            PreparedStatement statement = connection.prepareStatement(
                """
                    INSERT INTO food_item (
                        fridge_id, zone_id, container_id, name, category, quantity,
                        unit, production_date, expires_on, tags, model_key, photo_url,
                        status, version, created_by, updated_by
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'ACTIVE', 0, ?, ?)
                    """,
                new String[]{"id"}
            );
            statement.setLong(1, request.fridgeId());
            statement.setLong(2, request.zoneId());
            if (request.containerId() == null) {
                statement.setObject(3, null);
            } else {
                statement.setLong(3, request.containerId());
            }
            statement.setString(4, request.name().trim());
            statement.setString(5, request.category().trim());
            statement.setBigDecimal(6, request.quantity());
            statement.setString(7, request.unit().trim());
            statement.setDate(8, Date.valueOf(request.productionDate()));
            statement.setDate(9, Date.valueOf(request.expiresOn()));
            statement.setString(10, tags(request.tags()));
            statement.setString(11, trimToNull(request.modelKey()));
            statement.setString(12, trimToNull(request.photoUrl()));
            statement.setLong(13, userId);
            statement.setLong(14, userId);
            return statement;
        }, keys);
        long foodId = requiredId(keys);
        recordOperation(
            request.fridgeId(),
            foodId,
            userId,
            "ADD",
            null,
            null,
            null,
            request.zoneId(),
            request.containerId(),
            request.quantity(),
            null
        );
        return requireById(foodId);
    }

    public boolean zoneBelongsToFridge(long zoneId, long fridgeId) {
        Integer count = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM fridge_zone WHERE id = ? AND fridge_id = ?",
            Integer.class,
            zoneId,
            fridgeId
        );
        return count != null && count == 1;
    }

    public boolean containerBelongsToZone(Long containerId, long zoneId) {
        if (containerId == null) {
            return true;
        }
        Integer count = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM fridge_container WHERE id = ? AND zone_id = ?",
            Integer.class,
            containerId,
            zoneId
        );
        return count != null && count == 1;
    }

    public FoodView requireById(long foodId) {
        return findById(foodId)
            .orElseThrow(() -> new IllegalStateException("Food item was not found"));
    }

    public Optional<FoodView> findById(long foodId) {
        return jdbcTemplate.query(
            """
                SELECT id, fridge_id, zone_id, container_id, name, category,
                       quantity, unit, production_date, expires_on, tags,
                       model_key, photo_url, status, version, created_by,
                       updated_by, created_at, updated_at
                FROM food_item
                WHERE id = ? AND status = 'ACTIVE'
                """,
            ROW_MAPPER,
            foodId
        ).stream().findFirst()
            .map(this::view);
    }

    public Optional<FoodRecord> findRecordById(long foodId) {
        return jdbcTemplate.query(
            """
                SELECT id, fridge_id, zone_id, container_id, name, category,
                       quantity, unit, production_date, expires_on, tags,
                       model_key, photo_url, status, version, created_by,
                       updated_by, created_at, updated_at
                FROM food_item
                WHERE id = ? AND status = 'ACTIVE'
                """,
            ROW_MAPPER,
            foodId
        ).stream().findFirst();
    }

    /**
     * Locks the food row regardless of status so undo and restore can also act on
     * items that were discarded. Callers must run inside a transaction.
     */
    public Optional<FoodRecord> lockRecordById(long foodId) {
        return jdbcTemplate.query(
            """
                SELECT id, fridge_id, zone_id, container_id, name, category,
                       quantity, unit, production_date, expires_on, tags,
                       model_key, photo_url, status, version, created_by,
                       updated_by, created_at, updated_at
                FROM food_item
                WHERE id = ?
                FOR UPDATE
                """,
            ROW_MAPPER,
            foodId
        ).stream().findFirst();
    }

    /**
     * Applies a full state snapshot with the version read while holding the row
     * lock. Used by operation undo and restore; returns false when the version
     * moved on and the caller must ask the client to refresh.
     */
    public boolean applyState(
        FoodRecord food,
        String status,
        java.math.BigDecimal quantity,
        long zoneId,
        Long containerId,
        long userId
    ) {
        return jdbcTemplate.update(
            """
                UPDATE food_item
                SET status = ?,
                    quantity = ?,
                    zone_id = ?,
                    container_id = ?,
                    version = version + 1,
                    updated_by = ?,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = ?
                  AND version = ?
                """,
            status,
            quantity,
            zoneId,
            containerId,
            userId,
            food.id(),
            food.version()
        ) == 1;
    }

    public boolean move(
        FoodRecord food,
        long zoneId,
        Long containerId,
        int expectedVersion,
        long userId
    ) {
        int updated = jdbcTemplate.update(
            """
                UPDATE food_item
                SET zone_id = ?,
                    container_id = ?,
                    version = version + 1,
                    updated_by = ?,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = ?
                  AND version = ?
                  AND status = 'ACTIVE'
                """,
            zoneId,
            containerId,
            userId,
            food.id(),
            expectedVersion
        );
        if (updated == 0) {
            return false;
        }
        recordOperation(
            food.fridgeId(),
            food.id(),
            userId,
            "MOVE",
            food.zoneId(),
            food.containerId(),
            food.quantity(),
            zoneId,
            containerId,
            food.quantity(),
            null
        );
        return true;
    }

    public boolean consume(
        FoodRecord food,
        java.math.BigDecimal quantity,
        int expectedVersion,
        long userId
    ) {
        java.math.BigDecimal newQuantity = food.quantity().subtract(quantity);
        int updated = jdbcTemplate.update(
            """
                UPDATE food_item
                SET quantity = ?,
                    version = version + 1,
                    updated_by = ?,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = ?
                  AND version = ?
                  AND status = 'ACTIVE'
                """,
            newQuantity,
            userId,
            food.id(),
            expectedVersion
        );
        if (updated == 0) {
            return false;
        }
        recordOperation(
            food.fridgeId(),
            food.id(),
            userId,
            "CONSUME",
            food.zoneId(),
            food.containerId(),
            food.quantity(),
            food.zoneId(),
            food.containerId(),
            newQuantity,
            null
        );
        return true;
    }

    /**
     * Deducts the amount used by a cooking confirmation. The update and the
     * COOK operation row stay in one statement pair inside the caller's
     * transaction, and the quantity guard also protects against stale versions.
     */
    public boolean consumeForCook(
        FoodRecord food,
        java.math.BigDecimal quantity,
        int expectedVersion,
        long userId,
        String note
    ) {
        java.math.BigDecimal newQuantity = food.quantity().subtract(quantity);
        int updated = jdbcTemplate.update(
            """
                UPDATE food_item
                SET quantity = ?,
                    version = version + 1,
                    updated_by = ?,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = ?
                  AND version = ?
                  AND status = 'ACTIVE'
                  AND quantity >= ?
                """,
            newQuantity,
            userId,
            food.id(),
            expectedVersion,
            quantity
        );
        if (updated == 0) {
            return false;
        }
        recordOperation(
            food.fridgeId(),
            food.id(),
            userId,
            "COOK",
            food.zoneId(),
            food.containerId(),
            food.quantity(),
            food.zoneId(),
            food.containerId(),
            newQuantity,
            note
        );
        return true;
    }

    public boolean update(
        FoodRecord food,
        UpdateFoodRequest request,
        long userId
    ) {        int updated = jdbcTemplate.update(
            """
                UPDATE food_item
                SET zone_id = ?,
                    container_id = ?,
                    name = ?,
                    category = ?,
                    quantity = ?,
                    unit = ?,
                    production_date = ?,
                    expires_on = ?,
                    tags = ?,
                    model_key = ?,
                    photo_url = ?,
                    version = version + 1,
                    updated_by = ?,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = ?
                  AND version = ?
                  AND status = 'ACTIVE'
                """,
            request.zoneId(),
            request.containerId(),
            request.name().trim(),
            request.category().trim(),
            request.quantity(),
            request.unit().trim(),
            Date.valueOf(request.productionDate()),
            Date.valueOf(request.expiresOn()),
            tags(request.tags()),
            trimToNull(request.modelKey()),
            trimToNull(request.photoUrl()),
            userId,
            food.id(),
            request.version()
        );
        if (updated == 0) {
            return false;
        }
        recordOperation(
            food.fridgeId(),
            food.id(),
            userId,
            "UPDATE",
            food.zoneId(),
            food.containerId(),
            food.quantity(),
            request.zoneId(),
            request.containerId(),
            request.quantity(),
            null
        );
        return true;
    }

    /**
     * Rows already past their expiry date, oldest first. Used by the bulk
     * cleanup endpoint so the server, not the client clock, decides what counts
     * as expired.
     */
    public List<FoodRecord> findExpired(long fridgeId, LocalDate today) {
        return jdbcTemplate.query(
            """
                SELECT id, fridge_id, zone_id, container_id, name, category,
                       quantity, unit, production_date, expires_on, tags,
                       model_key, photo_url, status, version, created_by,
                       updated_by, created_at, updated_at
                FROM food_item
                WHERE fridge_id = ?
                  AND status = 'ACTIVE'
                  AND expires_on < ?
                ORDER BY expires_on, id
                """,
            ROW_MAPPER,
            fridgeId,
            Date.valueOf(today)
        );
    }

    public boolean discard(FoodRecord food, int expectedVersion, long userId, String note) {
        int updated = jdbcTemplate.update(
            """
                UPDATE food_item
                SET status = 'DISCARDED',
                    quantity = 0,
                    version = version + 1,
                    updated_by = ?,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = ?
                  AND version = ?
                  AND status = 'ACTIVE'
                """,
            userId,
            food.id(),
            expectedVersion
        );
        if (updated == 0) {
            return false;
        }
        recordOperation(
            food.fridgeId(),
            food.id(),
            userId,
            "DISCARD",
            food.zoneId(),
            food.containerId(),
            food.quantity(),
            food.zoneId(),
            food.containerId(),
            java.math.BigDecimal.ZERO,
            note
        );
        return true;
    }

    public List<FoodView> search(long fridgeId, FoodSearchFilter filter, LocalDate today) {
        StringBuilder sql = new StringBuilder("""
                SELECT id, fridge_id, zone_id, container_id, name, category,
                       quantity, unit, production_date, expires_on, tags,
                       model_key, photo_url, status, version, created_by,
                       updated_by, created_at, updated_at
                FROM food_item
                WHERE fridge_id = ?
                  AND status = 'ACTIVE'
                """);
        java.util.ArrayList<Object> args = new java.util.ArrayList<>();
        args.add(fridgeId);
        if (filter.query() != null && !filter.query().isBlank()) {
            sql.append(" AND LOWER(name) LIKE LOWER(?) ESCAPE '!'");
            args.add("%" + escapeLike(filter.query().trim()) + "%");
        }
        if (filter.category() != null && !filter.category().isBlank()) {
            sql.append(" AND category = ?");
            args.add(filter.category().trim());
        }
        if (filter.zoneId() != null) {
            sql.append(" AND zone_id = ?");
            args.add(filter.zoneId());
        }
        if (filter.tags() != null) {
            for (String tag : filter.tags().stream().map(String::trim).distinct().toList()) {
                sql.append(" AND CONCAT(',', tags, ',') LIKE ? ESCAPE '!'");
                args.add("%," + escapeLike(tag) + ",%");
            }
        }
        if (filter.expiresFrom() != null) {
            sql.append(" AND expires_on >= ?");
            args.add(Date.valueOf(filter.expiresFrom()));
        }
        if (filter.expiresTo() != null) {
            sql.append(" AND expires_on <= ?");
            args.add(Date.valueOf(filter.expiresTo()));
        }
        FoodSearchFilter.ExpiryState expiry = filter.expiryState() == null
            ? FoodSearchFilter.ExpiryState.ALL : filter.expiryState();
        switch (expiry) {
            case EXPIRED -> { sql.append(" AND expires_on < ?"); args.add(Date.valueOf(today)); }
            case EXPIRING -> {
                sql.append(" AND expires_on >= ? AND expires_on <= ?");
                args.add(Date.valueOf(today));
                args.add(Date.valueOf(today.plusDays(3)));
            }
            case FRESH -> { sql.append(" AND expires_on > ?"); args.add(Date.valueOf(today.plusDays(3))); }
            case ALL -> { }
        }
        FoodSearchFilter.Sort sort = filter.sort() == null ? FoodSearchFilter.Sort.EXPIRES_ASC : filter.sort();
        sql.append(switch (sort) {
            case EXPIRES_ASC -> " ORDER BY expires_on ASC, id ASC";
            case EXPIRES_DESC -> " ORDER BY expires_on DESC, id ASC";
            case NAME_ASC -> " ORDER BY name ASC, id ASC";
            case CREATED_DESC -> " ORDER BY created_at DESC, id ASC";
        });
        return jdbcTemplate.query(sql.toString(), ROW_MAPPER, args.toArray()).stream().map(this::view).toList();
    }

    private String escapeLike(String value) {
        return value.replace("!", "!!").replace("%", "!%").replace("_", "!_");
    }

    private void recordOperation(
        long fridgeId,
        long foodId,
        long actorUserId,
        String action,
        Long oldZoneId,
        Long oldContainerId,
        java.math.BigDecimal oldQuantity,
        long newZoneId,
        Long newContainerId,
        java.math.BigDecimal newQuantity,
        String note
    ) {
        jdbcTemplate.update(
            """
                INSERT INTO food_operation (
                    fridge_id, food_item_id, actor_user_id, action,
                    old_zone_id, old_container_id, old_quantity,
                    new_zone_id, new_container_id, new_quantity, note
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
            fridgeId,
            foodId,
            actorUserId,
            action,
            oldZoneId,
            oldContainerId,
            oldQuantity,
            newZoneId,
            newContainerId,
            newQuantity,
            note
        );
    }

    /** Maps a stored row without filtering on status, so discarded rows stay readable. */
    public FoodView viewOf(FoodRecord record) {
        return view(record);
    }

    private FoodView view(FoodRecord record) {
        long remainingDays = java.time.temporal.ChronoUnit.DAYS.between(
            LocalDate.now(),
            record.expiresOn()
        );
        return new FoodView(
            record.id(),
            record.fridgeId(),
            record.zoneId(),
            record.containerId(),
            record.name(),
            record.category(),
            record.quantity(),
            record.unit(),
            record.productionDate(),
            record.expiresOn(),
            remainingDays,
            remainingDays <= 3,
            tags(record.tags()),
            record.modelKey(),
            record.photoUrl(),
            record.createdBy(),
            record.updatedBy(),
            record.version(),
            record.createdAt(),
            record.updatedAt()
        );
    }

    private List<String> tags(String value) {
        if (value == null || value.isBlank()) {
            return List.of();
        }
        return Arrays.stream(value.split(","))
            .map(String::trim)
            .filter(tag -> !tag.isEmpty())
            .toList();
    }

    private String tags(List<String> values) {
        if (values == null) {
            return "";
        }
        return values.stream()
            .filter(value -> value != null && !value.isBlank())
            .map(String::trim)
            .distinct()
            .collect(java.util.stream.Collectors.joining(","));
    }

    private long requiredId(KeyHolder keys) {
        Number key = keys.getKey();
        if (key == null) {
            throw new IllegalStateException("Database did not return a generated key");
        }
        return key.longValue();
    }

    private String trimToNull(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return value.trim();
    }
}
