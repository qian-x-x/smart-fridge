package com.smartfridge.recipe.config;

import com.smartfridge.recipe.security.GatewayUserInterceptor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    private final GatewayUserInterceptor gatewayUserInterceptor;

    public WebConfig(GatewayUserInterceptor gatewayUserInterceptor) {
        this.gatewayUserInterceptor = gatewayUserInterceptor;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(gatewayUserInterceptor)
            .addPathPatterns("/api/v1/**")
            .excludePathPatterns("/api/v1/recipes/ping");
    }
}
