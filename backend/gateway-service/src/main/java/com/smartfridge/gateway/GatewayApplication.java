/*
 * 这个文件：网关服务的启动类。所有外部请求先到这里，再按路径转发给后面的业务服务。
 */

package com.smartfridge.gateway;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class GatewayApplication {

    public static void main(String[] args) {
        SpringApplication.run(GatewayApplication.class, args);
    }
}
