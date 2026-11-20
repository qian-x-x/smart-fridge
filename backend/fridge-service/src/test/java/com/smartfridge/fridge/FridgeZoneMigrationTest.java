package com.smartfridge.fridge;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

class FridgeZoneMigrationTest {
    @Test
    void upgradesBothFridgesAndPreservesInventoryAndMoveHistory() {
        var dataSource = new DriverManagerDataSource(
            "jdbc:h2:mem:fridge_zone_upgrade;MODE=MySQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1",
            "sa", "");
        Flyway.configure().dataSource(dataSource).target("4").load().migrate();
        var jdbc = new JdbcTemplate(dataSource);
        jdbc.update("INSERT INTO fridge(id, family_id, name) VALUES (1, 101, 'A'), (2, 102, 'B')");
        jdbc.update("""
            INSERT INTO fridge_zone(id, fridge_id, code, name) VALUES
                (11, 1, 'FRESH', '冷藏'), (12, 1, 'VARIABLE', '变温'), (13, 1, 'FREEZER', '冷冻'),
                (14, 1, 'PANTRY', '常温'),
                (21, 2, 'FRESH', '冷藏'), (22, 2, 'VARIABLE', '变温'), (23, 2, 'FREEZER', '冷冻'),
                (24, 2, 'PANTRY', '常温')
            """);
        jdbc.update("""
            INSERT INTO fridge_container(id, zone_id, name, container_type) VALUES
                (101, 11, '冷藏上层', 'SHELF'), (102, 12, '变温抽屉', 'DRAWER'),
                (104, 14, '常温储物筐', 'BASKET')
            """);
        jdbc.update("""
            INSERT INTO food_item(id, fridge_id, zone_id, container_id, name, category, quantity, unit,
                                  production_date, expires_on, status, version, created_by, updated_by) VALUES
                (71, 1, 14, 104, '大米', '主食', 2.5, '盒', '2026-11-12', '2026-11-18', 'ACTIVE', 3, 5, 5),
                (72, 1, 11, 101, '鸡蛋', '蛋类', 3, '个', '2026-11-13', '2026-11-21', 'ACTIVE', 7, 5, 5),
                (73, 2, 24, NULL, '紫菜', '其他', 0, '份', '2026-11-10', '2026-11-12', 'DISCARDED', 5, 6, 6),
                (74, 1, 12, 102, '鲜虾', '水产', 1, '盒', '2026-11-12', '2026-11-18', 'ACTIVE', 8, 5, 5)
            """);
        jdbc.update("""
            INSERT INTO food_operation(id, fridge_id, food_item_id, actor_user_id, action,
                                       old_zone_id, old_container_id, new_zone_id, new_container_id) VALUES
                (81, 1, 71, 5, 'MOVE', 13, NULL, 14, 104),
                (82, 1, 72, 5, 'MOVE', 14, 104, 11, 101),
                (83, 2, 73, 6, 'ADD', NULL, NULL, 24, NULL),
                (84, 1, 74, 5, 'ADD', NULL, NULL, 12, 102)
            """);
        String inventory = "SELECT id, fridge_id, name, quantity, expires_on, status FROM food_item ORDER BY id";
        var preserved = jdbc.queryForList(inventory);

        var upgrade = Flyway.configure().dataSource(dataSource).target("5").load();
        assertEquals(1, upgrade.migrate().migrationsExecuted);
        assertEquals(preserved, jdbc.queryForList(inventory));
        assertEquals(List.of(11L, 11L, 21L, 12L),
            jdbc.queryForList("SELECT zone_id FROM food_item ORDER BY id", Long.class));
        assertEquals(List.of(4, 7, 6, 8),
            jdbc.queryForList("SELECT version FROM food_item ORDER BY id", Integer.class));
        assertEquals(List.of(101L, 102L), jdbc.queryForList(
            "SELECT container_id FROM food_item WHERE container_id IS NOT NULL ORDER BY id", Long.class));
        assertEquals(List.of(13L, 11L), jdbc.queryForList(
            "SELECT old_zone_id FROM food_operation WHERE action = 'MOVE' ORDER BY id", Long.class));
        assertEquals(List.of(11L, 11L, 21L, 12L),
            jdbc.queryForList("SELECT new_zone_id FROM food_operation ORDER BY id", Long.class));
        assertEquals(List.of(101L, 102L), jdbc.queryForList("""
            SELECT new_container_id FROM food_operation WHERE new_container_id IS NOT NULL ORDER BY id
            """, Long.class));
        assertEquals(0, jdbc.queryForObject(
            "SELECT COUNT(*) FROM food_operation WHERE old_container_id IS NOT NULL", Integer.class));
        assertEquals(List.of(11L, 12L, 13L, 21L, 22L, 23L),
            jdbc.queryForList("SELECT id FROM fridge_zone ORDER BY id", Long.class));
        assertEquals(List.of(101L, 102L),
            jdbc.queryForList("SELECT id FROM fridge_container ORDER BY id", Long.class));
        assertEquals(0, upgrade.migrate().migrationsExecuted);
    }
}
