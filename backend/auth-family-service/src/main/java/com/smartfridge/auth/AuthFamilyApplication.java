/*
 * 这个文件：账号与家庭服务的启动类。它负责两件大事：登录注册，以及家庭/成员管理。
 */

package com.smartfridge.auth;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.cloud.openfeign.EnableFeignClients;

@SpringBootApplication(scanBasePackages = "com.smartfridge")
@ConfigurationPropertiesScan
@EnableFeignClients
public class AuthFamilyApplication {

    public static void main(String[] args) {
        SpringApplication.run(AuthFamilyApplication.class, args);
    }
}
