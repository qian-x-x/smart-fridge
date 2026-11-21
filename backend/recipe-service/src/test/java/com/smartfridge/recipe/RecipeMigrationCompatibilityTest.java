/*
 * 这个文件：测试菜谱数据的数据库迁移兼容性：升级后旧数据还能正常读取。
 */

package com.smartfridge.recipe;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

import static org.junit.jupiter.api.Assertions.assertEquals;

class RecipeMigrationCompatibilityTest {
    @Test
    void upgradesExistingSixRecipeDatabaseWithoutLosingIdsIngredientsOrCustomRows() {
        var dataSource = new DriverManagerDataSource(
            "jdbc:h2:mem:recipe_upgrade;MODE=MySQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1",
            "sa", "");
        Flyway.configure().dataSource(dataSource).locations("classpath:db/migration")
            .target("1").load().migrate();
        var jdbc = new JdbcTemplate(dataSource);
        assertEquals(6, jdbc.queryForObject("SELECT COUNT(*) FROM recipe", Integer.class));
        var originalIds = jdbc.queryForList("SELECT id, name FROM recipe ORDER BY id");
        var originalIngredients = jdbc.queryForList("SELECT * FROM recipe_ingredient ORDER BY id");
        jdbc.update("""
            INSERT INTO recipe
            (id, name, summary, category, duration_minutes, calories, difficulty, servings, cover_emoji, steps, featured)
            SELECT 900, '保留的自定义菜谱', summary, category, duration_minutes, calories,
                   difficulty, servings, cover_emoji, steps, FALSE FROM recipe WHERE id = 1
            """);
        jdbc.update("INSERT INTO recipe_ingredient (recipe_id, name, quantity, unit) VALUES (900, '保留原料', 1, '份')");
        var upgraded = Flyway.configure().dataSource(dataSource)
            .locations("classpath:db/migration").load();
        assertEquals(1, upgraded.migrate().migrationsExecuted);
        assertEquals(19, jdbc.queryForObject("SELECT COUNT(*) FROM recipe", Integer.class));
        assertEquals(originalIds, jdbc.queryForList("SELECT id, name FROM recipe WHERE id <= 6 ORDER BY id"));
        assertEquals(originalIngredients, jdbc.queryForList("SELECT * FROM recipe_ingredient WHERE recipe_id <= 6 ORDER BY id"));
        assertEquals("保留原料", jdbc.queryForObject(
            "SELECT name FROM recipe_ingredient WHERE recipe_id = 900", String.class));
        assertEquals(0, upgraded.migrate().migrationsExecuted);
        assertEquals(19, jdbc.queryForObject("SELECT COUNT(*) FROM recipe", Integer.class));
    }
}
