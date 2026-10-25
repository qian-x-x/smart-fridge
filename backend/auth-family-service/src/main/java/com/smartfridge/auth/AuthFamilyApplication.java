package com.smartfridge.auth;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication(scanBasePackages = "com.smartfridge")
@ConfigurationPropertiesScan
public class AuthFamilyApplication {

    public static void main(String[] args) {
        SpringApplication.run(AuthFamilyApplication.class, args);
    }
}
