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
