/*
 * 这个文件：Feign 接口声明：向认证服务查询「这个用户在这个家庭里是什么角色」。
 */

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
