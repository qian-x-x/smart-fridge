/*
 * 这个文件：菜谱查询业务：列表和详情，查不到给「菜谱不存在」。
 */

package com.smartfridge.recipe.catalog;

import com.smartfridge.common.error.BusinessException;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class RecipeService {

    private final RecipeRepository repository;

    public RecipeService(RecipeRepository repository) {
        this.repository = repository;
    }

    public List<RecipeView> list() {
        return repository.findAll();
    }

    public RecipeView get(long recipeId) {
        return repository.findById(recipeId)
            .orElseThrow(() -> BusinessException.notFound("菜谱不存在"));
    }
}
