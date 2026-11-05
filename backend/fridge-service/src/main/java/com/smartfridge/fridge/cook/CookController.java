package com.smartfridge.fridge.cook;

import com.smartfridge.common.api.ApiResponse;
import com.smartfridge.fridge.security.CurrentUser;
import com.smartfridge.fridge.security.GatewayUserInterceptor;
import jakarta.validation.Valid;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.net.URI;
import java.util.List;

@RestController
public class CookController {

    private final CookService cookService;

    public CookController(CookService cookService) {
        this.cookService = cookService;
    }

    @PostMapping("/api/v1/fridges/{fridgeId}/cook-records")
    public ResponseEntity<ApiResponse<CookRecordView>> cook(
        @PathVariable long fridgeId,
        @RequestAttribute(GatewayUserInterceptor.CURRENT_USER_ATTRIBUTE) CurrentUser user,
        @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization,
        @Valid @RequestBody CookRequest request
    ) {
        CookResult result = cookService.cook(fridgeId, user, authorization, request);
        if (!result.created()) {
            return ResponseEntity.ok(ApiResponse.success(result.record()));
        }
        return ResponseEntity.created(
                URI.create("/api/v1/fridges/" + fridgeId + "/cook-records/" + result.record().id())
            )
            .body(ApiResponse.success(result.record()));
    }

    @GetMapping("/api/v1/fridges/{fridgeId}/cook-records")
    public ApiResponse<List<CookRecordView>> history(
        @PathVariable long fridgeId,
        @RequestParam(required = false) Integer limit,
        @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization
    ) {
        return ApiResponse.success(cookService.history(fridgeId, limit, authorization));
    }
}
