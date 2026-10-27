package com.smartfridge.recipe.catalog;

import com.smartfridge.common.api.ApiResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/recipes")
public class RecipeController {

    private final RecipeService recipeService;

    public RecipeController(RecipeService recipeService) {
        this.recipeService = recipeService;
    }

    @GetMapping
    public ApiResponse<List<RecipeView>> list() {
        return ApiResponse.success(recipeService.list());
    }

    @GetMapping("/{recipeId}")
    public ApiResponse<RecipeView> get(@PathVariable long recipeId) {
        return ApiResponse.success(recipeService.get(recipeId));
    }
}
