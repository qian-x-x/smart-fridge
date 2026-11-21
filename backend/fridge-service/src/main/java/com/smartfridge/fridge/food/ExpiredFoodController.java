/*
 * 这个文件：一键清理过期食材的接口。
 */

package com.smartfridge.fridge.food;

import com.smartfridge.common.api.ApiResponse;
import com.smartfridge.fridge.security.CurrentUser;
import com.smartfridge.fridge.security.GatewayUserInterceptor;
import org.springframework.http.HttpHeaders;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/fridges")
public class ExpiredFoodController {

    private final FoodService foodService;

    public ExpiredFoodController(FoodService foodService) {
        this.foodService = foodService;
    }

    /**
     * Discards every already-expired item in the fridge in one call.
     *
     * @return how many items were discarded plus the affected rows, so the
     *         client can tell the user exactly what left the fridge
     */
    @PostMapping("/{fridgeId}/discard-expired")
    public ApiResponse<ExpiredCleanupView> discardExpired(
        @PathVariable long fridgeId,
        @RequestAttribute(GatewayUserInterceptor.CURRENT_USER_ATTRIBUTE) CurrentUser user,
        @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization
    ) {
        return ApiResponse.success(foodService.discardExpired(fridgeId, user, authorization));
    }
}
