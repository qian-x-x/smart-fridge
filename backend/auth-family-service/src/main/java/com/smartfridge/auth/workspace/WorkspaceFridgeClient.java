package com.smartfridge.auth.workspace;

import com.smartfridge.common.api.ApiResponse;
import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.http.HttpHeaders;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;

@FeignClient(name = "fridge-service", url = "${smart-fridge.fridge-service-url:}")
public interface WorkspaceFridgeClient {
    @PostMapping("/api/v1/fridges")
    ApiResponse<CreatedFridge> create(
        @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization,
        @RequestHeader("X-User-Id") String userId,
        @RequestBody NewFridge request
    );

    record NewFridge(long familyId, String name) {}
    record CreatedFridge(long id, long familyId) {}
}
