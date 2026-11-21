/*
 * 这个文件：冰箱、分区、容器三张表的 SQL。新建冰箱时会自动写入默认的三个温区
 * （冷藏、变温、冷冻）和五个容器，用户不需要手动配置。
 */

package com.smartfridge.fridge.fridge;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.sql.PreparedStatement;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@Repository
public class FridgeRepository {

    private static final List<ZoneSeed> DEFAULT_ZONES = List.of(
        new ZoneSeed("FRESH", "冷藏", new BigDecimal("4.0"), 10,
            List.of(new ContainerSeed("上层隔层", "SHELF"), new ContainerSeed("下层隔层", "SHELF"))),
        new ZoneSeed("VARIABLE", "变温", new BigDecimal("0.0"), 20,
            List.of(new ContainerSeed("变温上层", "SHELF"), new ContainerSeed("变温抽屉", "DRAWER"))),
        new ZoneSeed("FREEZER", "冷冻", new BigDecimal("-18.0"), 30,
            List.of(new ContainerSeed("冷冻抽屉", "DRAWER")))
    );

    private final JdbcTemplate jdbcTemplate;

    public FridgeRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public Optional<FridgeView> findOwnedFridgeForFamily(long familyId) {
        FridgeRecord fridge = findRecord(
            """
                SELECT id, family_id, name, timezone, created_at, updated_at
                FROM fridge
                WHERE family_id = ?
                """,
            familyId
        );
        return fridge == null ? Optional.empty() : Optional.of(load(fridge));
    }

    public Optional<FridgeView> findById(long fridgeId) {
        FridgeRecord fridge = findRecord(
            """
                SELECT id, family_id, name, timezone, created_at, updated_at
                FROM fridge
                WHERE id = ?
                """,
            fridgeId
        );
        return fridge == null ? Optional.empty() : Optional.of(load(fridge));
    }

    public FridgeView create(long familyId, String name) {
        long fridgeId = insertFridge(familyId, name);
        for (ZoneSeed zone : DEFAULT_ZONES) {
            long zoneId = insertZone(fridgeId, zone);
            for (int index = 0; index < zone.containers().size(); index++) {
                insertContainer(zoneId, zone.containers().get(index), (index + 1) * 10);
            }
        }
        return jdbcTemplate.query(
            """
                SELECT id, family_id, name, timezone, created_at, updated_at
                FROM fridge
                WHERE id = ?
                """,
            (resultSet, rowNum) -> new FridgeRecord(
                resultSet.getLong("id"),
                resultSet.getLong("family_id"),
                resultSet.getString("name"),
                resultSet.getString("timezone"),
                resultSet.getTimestamp("created_at").toInstant(),
                resultSet.getTimestamp("updated_at").toInstant()
            ),
            fridgeId
        ).stream().map(this::load).findFirst()
            .orElseThrow(() -> new IllegalStateException("Newly created fridge was not found"));
    }

    private long insertFridge(long familyId, String name) {
        KeyHolder keys = new GeneratedKeyHolder();
        jdbcTemplate.update(connection -> {
            PreparedStatement statement = connection.prepareStatement(
                "INSERT INTO fridge (family_id, name, timezone) VALUES (?, ?, ?)",
                new String[]{"id"}
            );
            statement.setLong(1, familyId);
            statement.setString(2, name);
            statement.setString(3, "Asia/Shanghai");
            return statement;
        }, keys);
        return requiredId(keys);
    }

    private long insertZone(long fridgeId, ZoneSeed zone) {
        KeyHolder keys = new GeneratedKeyHolder();
        jdbcTemplate.update(connection -> {
            PreparedStatement statement = connection.prepareStatement(
                """
                    INSERT INTO fridge_zone
                        (fridge_id, code, name, temperature_c, sort_order)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                new String[]{"id"}
            );
            statement.setLong(1, fridgeId);
            statement.setString(2, zone.code());
            statement.setString(3, zone.name());
            if (zone.temperatureC() == null) {
                statement.setObject(4, null);
            } else {
                statement.setBigDecimal(4, zone.temperatureC());
            }
            statement.setInt(5, zone.sortOrder());
            return statement;
        }, keys);
        return requiredId(keys);
    }

    private void insertContainer(long zoneId, ContainerSeed container, int sortOrder) {
        jdbcTemplate.update(
            """
                INSERT INTO fridge_container
                    (zone_id, name, container_type, sort_order)
                VALUES (?, ?, ?, ?)
                """,
            zoneId,
            container.name(),
            container.type(),
            sortOrder
        );
    }

    private FridgeView load(FridgeRecord fridge) {
        List<FridgeZoneView> zones = jdbcTemplate.query(
            """
                SELECT id, code, name, temperature_c, sort_order
                FROM fridge_zone
                WHERE fridge_id = ?
                ORDER BY sort_order, id
                """,
            (resultSet, rowNum) -> new ZoneRecord(
                resultSet.getLong("id"),
                resultSet.getString("code"),
                resultSet.getString("name"),
                resultSet.getBigDecimal("temperature_c"),
                resultSet.getInt("sort_order")
            ),
            fridge.id()
        ).stream().map(zone -> new FridgeZoneView(
            zone.id(),
            zone.code(),
            zone.name(),
            zone.temperatureC(),
            zone.sortOrder(),
            containers(zone.id())
        )).toList();
        return new FridgeView(
            fridge.id(),
            fridge.familyId(),
            fridge.name(),
            fridge.timezone(),
            zones,
            fridge.createdAt(),
            fridge.updatedAt()
        );
    }

    private FridgeRecord findRecord(String sql, long parameter) {
        return jdbcTemplate.query(
            sql,
            (resultSet, rowNum) -> new FridgeRecord(
                resultSet.getLong("id"),
                resultSet.getLong("family_id"),
                resultSet.getString("name"),
                resultSet.getString("timezone"),
                resultSet.getTimestamp("created_at").toInstant(),
                resultSet.getTimestamp("updated_at").toInstant()
            ),
            parameter
        ).stream().findFirst().orElse(null);
    }

    private List<FridgeContainerView> containers(long zoneId) {
        return new ArrayList<>(jdbcTemplate.query(
            """
                SELECT id, name, container_type, sort_order
                FROM fridge_container
                WHERE zone_id = ?
                ORDER BY sort_order, id
                """,
            (resultSet, rowNum) -> new FridgeContainerView(
                resultSet.getLong("id"),
                resultSet.getString("name"),
                resultSet.getString("container_type"),
                resultSet.getInt("sort_order")
            ),
            zoneId
        ));
    }

    private long requiredId(KeyHolder keys) {
        Number key = keys.getKey();
        if (key == null) {
            throw new IllegalStateException("Database did not return a generated key");
        }
        return key.longValue();
    }

    private record FridgeRecord(
        long id,
        long familyId,
        String name,
        String timezone,
        Instant createdAt,
        Instant updatedAt
    ) {
    }

    private record ZoneRecord(
        long id,
        String code,
        String name,
        BigDecimal temperatureC,
        int sortOrder
    ) {
    }

    private record ZoneSeed(
        String code,
        String name,
        BigDecimal temperatureC,
        int sortOrder,
        List<ContainerSeed> containers
    ) {
    }

    private record ContainerSeed(String name, String type) {
    }
}
