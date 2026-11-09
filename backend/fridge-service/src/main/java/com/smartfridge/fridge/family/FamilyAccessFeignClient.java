package com.smartfridge.fridge.family;

import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.http.HttpHeaders;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestHeader;

@FeignClient(
    name = "auth-family-service",
    url = "${smart-fridge.auth-service-url:}"
)
public interface FamilyAccessFeignClient {

    @GetMapping("/api/v1/families/{familyId}")
    FamilyAccessEnvelope getFamily(
        @PathVariable("familyId") long familyId,
        @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization
    );
}
