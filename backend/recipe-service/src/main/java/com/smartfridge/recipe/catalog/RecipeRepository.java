package com.smartfridge.recipe.catalog;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.Arrays;
import java.util.List;
import java.util.Optional;

@Repository
public class RecipeRepository {

    private final JdbcTemplate jdbcTemplate;

    public RecipeRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<RecipeView> findAll() {
        return jdbcTemplate.query(
            """
                SELECT id, name, summary, category, duration_minutes, calories,
                       difficulty, servings, cover_emoji, steps, featured
                FROM recipe
                ORDER BY featured DESC, id
                """,
            (resultSet, rowNum) -> toView(
                resultSet.getLong("id"),
                resultSet.getString("name"),
                resultSet.getString("summary"),
                resultSet.getString("category"),
                resultSet.getInt("duration_minutes"),
                resultSet.getInt("calories"),
                resultSet.getString("difficulty"),
                resultSet.getInt("servings"),
                resultSet.getString("cover_emoji"),
                resultSet.getString("steps"),
                resultSet.getBoolean("featured")
            )
        );
    }

    public Optional<RecipeView> findById(long recipeId) {
        return jdbcTemplate.query(
            """
                SELECT id, name, summary, category, duration_minutes, calories,
                       difficulty, servings, cover_emoji, steps, featured
                FROM recipe
                WHERE id = ?
                """,
            (resultSet, rowNum) -> toView(
                resultSet.getLong("id"),
                resultSet.getString("name"),
                resultSet.getString("summary"),
                resultSet.getString("category"),
                resultSet.getInt("duration_minutes"),
                resultSet.getInt("calories"),
                resultSet.getString("difficulty"),
                resultSet.getInt("servings"),
                resultSet.getString("cover_emoji"),
                resultSet.getString("steps"),
                resultSet.getBoolean("featured")
            ),
            recipeId
        ).stream().findFirst();
    }

    private RecipeView toView(
        long id,
        String name,
        String summary,
        String category,
        int durationMinutes,
        int calories,
        String difficulty,
        int servings,
        String coverEmoji,
        String steps,
        boolean featured
    ) {
        return new RecipeView(
            id,
            name,
            summary,
            category,
            durationMinutes,
            calories,
            difficulty,
            servings,
            coverEmoji,
            Arrays.stream(steps.split("\\|")).toList(),
            ingredients(id),
            featured
        );
    }

    private List<RecipeIngredientView> ingredients(long recipeId) {
        return jdbcTemplate.query(
            """
                SELECT name, quantity, unit, optional
                FROM recipe_ingredient
                WHERE recipe_id = ?
                ORDER BY sort_order, id
                """,
            (resultSet, rowNum) -> new RecipeIngredientView(
                resultSet.getString("name"),
                resultSet.getBigDecimal("quantity"),
                resultSet.getString("unit"),
                resultSet.getBoolean("optional")
            ),
            recipeId
        );
    }
}
