package com.smartfridge.fridge.food;

import com.smartfridge.common.api.ApiResponse;
import com.smartfridge.fridge.security.CurrentUser;
import com.smartfridge.fridge.security.GatewayUserInterceptor;
import jakarta.validation.Valid;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.net.URI;
import java.util.List;

@RestController
@RequestMapping("/api/v1/foods")
public class FoodController {

    private final FoodService foodService;

    public FoodController(FoodService foodService) {
        this.foodService = foodService;
    }

    @PostMapping
    public ResponseEntity<ApiResponse<FoodView>> create(
        @RequestAttribute(GatewayUserInterceptor.CURRENT_USER_ATTRIBUTE) CurrentUser user,
        @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization,
        @Valid @RequestBody CreateFoodRequest request
    ) {
        FoodView food = foodService.create(user, authorization, request);
        return ResponseEntity.created(URI.create("/api/v1/foods/" + food.id()))
            .body(ApiResponse.success(food));
    }

    @GetMapping
    public ApiResponse<List<FoodView>> search(
        @RequestParam long fridgeId,
        @Valid @ModelAttribute FoodSearchFilter filter,
        @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization
    ) {
        return ApiResponse.success(foodService.search(fridgeId, filter, authorization));
    }

    @PostMapping("/catalog-batch")
    public ResponseEntity<ApiResponse<CatalogBatchView>> createCatalogBatch(
        @RequestAttribute(GatewayUserInterceptor.CURRENT_USER_ATTRIBUTE) CurrentUser user,
        @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization,
        @Valid @RequestBody CatalogFoodBatchRequest request
    ) {
        var result = foodService.createCatalogBatch(user, authorization, request);
        var response = ApiResponse.success(new CatalogBatchView(result.added()));
        return result.created() ? ResponseEntity.status(201).body(response) : ResponseEntity.ok(response);
    }

    public record CatalogBatchView(int added) {}

    @GetMapping("/{foodId}")
    public ApiResponse<FoodView> get(
        @PathVariable long foodId,
        @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization
    ) {
        return ApiResponse.success(foodService.get(foodId, authorization));
    }

    @PostMapping("/{foodId}/move")
    public ApiResponse<FoodView> move(
        @PathVariable long foodId,
        @RequestAttribute(GatewayUserInterceptor.CURRENT_USER_ATTRIBUTE) CurrentUser user,
        @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization,
        @Valid @RequestBody MoveFoodRequest request
    ) {
        return ApiResponse.success(foodService.move(foodId, user, authorization, request));
    }

    @PostMapping("/{foodId}/consume")
    public ApiResponse<FoodView> consume(
        @PathVariable long foodId,
        @RequestAttribute(GatewayUserInterceptor.CURRENT_USER_ATTRIBUTE) CurrentUser user,
        @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization,
        @Valid @RequestBody ConsumeFoodRequest request
    ) {
        return ApiResponse.success(foodService.consume(foodId, user, authorization, request));
    }

    @PutMapping("/{foodId}")
    public ApiResponse<FoodView> update(
        @PathVariable long foodId,
        @RequestAttribute(GatewayUserInterceptor.CURRENT_USER_ATTRIBUTE) CurrentUser user,
        @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization,
        @Valid @RequestBody UpdateFoodRequest request
    ) {
        return ApiResponse.success(foodService.update(foodId, user, authorization, request));
    }

    @DeleteMapping("/{foodId}")
    public ResponseEntity<Void> discard(
        @PathVariable long foodId,
        @RequestParam int version,
        @RequestAttribute(GatewayUserInterceptor.CURRENT_USER_ATTRIBUTE) CurrentUser user,
        @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization
    ) {
        foodService.discard(foodId, user, authorization, version);
        return ResponseEntity.noContent().build();
    }
}
