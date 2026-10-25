package com.smartfridge.notification;

import com.smartfridge.common.api.ApiResponse;
import com.smartfridge.common.api.ServiceInfo;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/notifications")
public class NotificationStatusController {

    @GetMapping("/ping")
    public ApiResponse<ServiceInfo> ping() {
        return ApiResponse.success(new ServiceInfo("notification-service", "UP", "S1"));
    }
}
