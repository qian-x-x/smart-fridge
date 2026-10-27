package com.smartfridge.fridge.config;

import com.smartfridge.fridge.security.GatewayUserInterceptor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.time.Clock;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    private final GatewayUserInterceptor gatewayUserInterceptor;

    public WebConfig(GatewayUserInterceptor gatewayUserInterceptor) {
        this.gatewayUserInterceptor = gatewayUserInterceptor;
    }

    @Bean
    Clock clock() {
        return Clock.systemUTC();
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(gatewayUserInterceptor)
            .addPathPatterns("/api/v1/**")
            .excludePathPatterns("/api/v1/fridges/ping");
    }
}
