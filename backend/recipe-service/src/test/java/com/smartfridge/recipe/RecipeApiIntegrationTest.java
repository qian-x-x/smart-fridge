package com.smartfridge.recipe;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

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
            .andExpect(jsonPath("$.data.length()").value(6))
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
}
