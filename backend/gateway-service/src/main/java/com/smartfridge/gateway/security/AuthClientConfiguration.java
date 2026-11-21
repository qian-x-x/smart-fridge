/*
 * 这个文件：声明调用认证服务的 Feign 客户端（带负载均衡）。
 */

package com.smartfridge.gateway.security;

import org.springframework.cloud.client.loadbalancer.LoadBalanced;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.function.client.WebClient;

@Configuration
public class AuthClientConfiguration {
    @Bean
    @LoadBalanced
    public WebClient.Builder authLoadBalancedClient() {
        return WebClient.builder();
    }
}
