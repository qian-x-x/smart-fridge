/*
 * 这个文件：冰箱接口：创建冰箱、按家庭查冰箱、按 id 查冰箱。
 */

package com.smartfridge.fridge.fridge;

import com.smartfridge.common.api.ApiResponse;
import com.smartfridge.fridge.security.CurrentUser;
import com.smartfridge.fridge.security.GatewayUserInterceptor;
import jakarta.validation.Valid;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.net.URI;

@RestController
@RequestMapping("/api/v1/fridges")
public class FridgeController {

    private final FridgeService fridgeService;

    public FridgeController(FridgeService fridgeService) {
        this.fridgeService = fridgeService;
    }

    @PostMapping
    public ResponseEntity<ApiResponse<FridgeView>> create(
        @RequestAttribute(GatewayUserInterceptor.CURRENT_USER_ATTRIBUTE) CurrentUser user,
        @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization,
        @Valid @RequestBody CreateFridgeRequest request
    ) {
        FridgeView fridge = fridgeService.create(user, authorization, request);
        return ResponseEntity.created(URI.create("/api/v1/fridges/" + fridge.id()))
            .body(ApiResponse.success(fridge));
    }

    @GetMapping
    public ApiResponse<FridgeView> getByFamily(
        @RequestParam long familyId,
        @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization
    ) {
        return ApiResponse.success(fridgeService.getByFamily(familyId, authorization));
    }

    @GetMapping("/{fridgeId}")
    public ApiResponse<FridgeView> get(
        @PathVariable long fridgeId,
        @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization
    ) {
        return ApiResponse.success(fridgeService.get(fridgeId, authorization));
    }
}
