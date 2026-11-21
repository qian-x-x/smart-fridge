/*
 * 这个文件：测试菜谱接口：列表和详情返回的数据结构是否正确。
 */

package com.smartfridge.recipe;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class RecipeApiIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void rejectsCatalogRequestsWithoutGatewayUserIdentity() throws Exception {
        mockMvc.perform(get("/api/v1/recipes"))
            .andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    void listsSeededRecipesForAuthenticatedFamilyMember() throws Exception {
        mockMvc.perform(get("/api/v1/recipes")
                .header("X-User-Id", "7"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.length()").value(18))
            .andExpect(jsonPath("$.data[0].name").value("番茄滑蛋"))
            .andExpect(jsonPath("$.data[0].ingredients.length()").value(4));
    }

    @Test
    void returnsRecipeDetailWithIngredientsAndSteps() throws Exception {
        mockMvc.perform(get("/api/v1/recipes/1")
                .header("X-User-Id", "7"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.name").value("番茄滑蛋"))
            .andExpect(jsonPath("$.data.steps.length()").value(4))
            .andExpect(jsonPath("$.data.ingredients[0].name").value("西红柿"));
    }

    @Test
    void newHomeRecipeHasCompleteIngredientsAndSteps() throws Exception {
        mockMvc.perform(get("/api/v1/recipes/10").header("X-User-Id", "7"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.name").value("麻婆豆腐"))
            .andExpect(jsonPath("$.data.servings").value(2))
            .andExpect(jsonPath("$.data.ingredients[0].name").value("嫩豆腐"))
            .andExpect(jsonPath("$.data.ingredients[0].quantity").value(350))
            .andExpect(jsonPath("$.data.steps.length()").value(5));
    }

    @Test
    void realCatalogMatchesTheBundledDemoCatalog() throws Exception {
        Path root = Path.of("").toAbsolutePath();
        while (root != null && !Files.exists(root.resolve("apps/fridge-app/pubspec.yaml"))) {
            root = root.getParent();
        }
        assertNotNull(root, "Repository root must contain the Flutter catalog");
        ObjectMapper mapper = new ObjectMapper();
        JsonNode expected = mapper.readTree(root.resolve(
            "apps/fridge-app/assets/data/home-recipes-v2.json").toFile());
        JsonNode actual = mapper.readTree(mockMvc.perform(get("/api/v1/recipes")
            .header("X-User-Id", "7")).andReturn().getResponse().getContentAsByteArray()).get("data");
        assertEquals(expected.size(), actual.size());
        for (JsonNode recipe : expected) {
            JsonNode persisted = null;
            for (JsonNode candidate : actual) {
                if (candidate.get("id").asLong() == recipe.get("id").asLong()) persisted = candidate;
            }
            assertNotNull(persisted, recipe.get("name").asText());
            for (String field : new String[]{"name", "summary", "category", "durationMinutes",
                    "calories", "difficulty", "servings", "coverEmoji", "featured", "steps"}) {
                assertEquals(recipe.get(field), persisted.get(field), recipe.get("name") + ": " + field);
            }
            JsonNode expectedIngredients = recipe.get("ingredients");
            JsonNode actualIngredients = persisted.get("ingredients");
            assertEquals(expectedIngredients.size(), actualIngredients.size());
            assertTrue(actualIngredients.size() > 0);
            for (int i = 0; i < expectedIngredients.size(); i++) {
                JsonNode left = expectedIngredients.get(i), right = actualIngredients.get(i);
                for (String field : new String[]{"name", "unit", "optional"}) {
                    assertEquals(left.get(field), right.get(field));
                }
                assertEquals(0, left.get("quantity").decimalValue()
                    .compareTo(right.get("quantity").decimalValue()));
            }
        }
    }
}
