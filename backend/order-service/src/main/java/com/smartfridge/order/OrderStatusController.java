/*
 * 这个文件：健康检查接口。
 */

package com.smartfridge.order;

import com.smartfridge.common.api.ApiResponse;
import com.smartfridge.common.api.ServiceInfo;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/orders")
public class OrderStatusController {

    @GetMapping("/ping")
    public ApiResponse<ServiceInfo> ping() {
        return ApiResponse.success(new ServiceInfo("order-service", "UP", "S1"));
    }
}
