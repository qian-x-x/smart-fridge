/*
 * 这个文件：操作流水相关接口：查看流水、撤销某次操作、恢复已撤销的操作。
 */

package com.smartfridge.fridge.food;

import com.smartfridge.common.api.ApiResponse;
import com.smartfridge.fridge.security.CurrentUser;
import com.smartfridge.fridge.security.GatewayUserInterceptor;
import org.springframework.http.HttpHeaders;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
public class FoodOperationController {

    private final FoodOperationService operationService;

    public FoodOperationController(FoodOperationService operationService) {
        this.operationService = operationService;
    }

    @GetMapping("/api/v1/fridges/{fridgeId}/operations")
    public ApiResponse<List<FoodOperationView>> timeline(
        @PathVariable long fridgeId,
        @RequestParam(required = false) Long foodId,
        @RequestParam(required = false) Integer limit,
        @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization
    ) {
        return ApiResponse.success(operationService.timeline(fridgeId, foodId, limit, authorization));
    }

    @PostMapping("/api/v1/foods/{foodId}/operations/{operationId}/undo")
    public ApiResponse<FoodView> undo(
        @PathVariable long foodId,
        @PathVariable long operationId,
        @RequestParam(required = false) Integer version,
        @RequestAttribute(GatewayUserInterceptor.CURRENT_USER_ATTRIBUTE) CurrentUser user,
        @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization
    ) {
        return ApiResponse.success(operationService.undo(foodId, operationId, version, user, authorization));
    }

    @PostMapping("/api/v1/foods/{foodId}/operations/{operationId}/restore")
    public ApiResponse<FoodView> restore(
        @PathVariable long foodId,
        @PathVariable long operationId,
        @RequestParam(required = false) Integer version,
        @RequestAttribute(GatewayUserInterceptor.CURRENT_USER_ATTRIBUTE) CurrentUser user,
        @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization
    ) {
        return ApiResponse.success(operationService.restore(foodId, operationId, version, user, authorization));
    }
}
