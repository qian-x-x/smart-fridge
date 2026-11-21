/*
 * 这个文件：健康检查接口，运维用来确认服务活着。
 */

package com.smartfridge.fridge;

import com.smartfridge.common.api.ApiResponse;
import com.smartfridge.common.api.ServiceInfo;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/fridges")
public class FridgeStatusController {

    @GetMapping("/ping")
    public ApiResponse<ServiceInfo> ping() {
        return ApiResponse.success(new ServiceInfo("fridge-service", "UP", "S1"));
    }
}
