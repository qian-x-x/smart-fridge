/*
 * 这个文件：冰箱服务的启动类。食材、冰箱结构、做饭扣减都在这个服务里。
 */

package com.smartfridge.fridge;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.openfeign.EnableFeignClients;

@SpringBootApplication(scanBasePackages = "com.smartfridge")
@EnableFeignClients(basePackages = "com.smartfridge.fridge.family")
public class FridgeApplication {

    public static void main(String[] args) {
        SpringApplication.run(FridgeApplication.class, args);
    }
}
