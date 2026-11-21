/*
 * 这个文件：测试网关路由：按路径能不能正确转发到对应服务。
 */

package com.smartfridge.gateway;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.cloud.gateway.config.GatewayProperties;
import org.springframework.test.context.ActiveProfiles;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 默认 profile 下网关不使用固定地址，而是按服务名经注册中心转发。
 *
 * <p>这里只断言路由定义，不真正发请求：测试环境没有 Nacos，`lb://` 无法解析实例。
 */
@SpringBootTest(
    properties = {
        "spring.cloud.nacos.discovery.enabled=false",
        "spring.cloud.nacos.config.enabled=false"
    }
)
@ActiveProfiles("cloud")
class GatewayDiscoveryRouteTest {

    @Autowired
    private GatewayProperties routes;

    @Test
    void cloudProfileRoutesByServiceName() {
        assertThat(routes.getRoutes()).hasSize(5)
            .allSatisfy(route -> {
                assertThat(route.getUri().getScheme()).isEqualTo("lb");
                assertThat(route.getUri().getHost()).endsWith("-service");
                assertThat(route.getPredicates()).isNotEmpty();
            });

        assertThat(routes.getRoutes())
            .extracting(route -> route.getUri().getHost())
            .containsExactlyInAnyOrder(
                "auth-family-service",
                "fridge-service",
                "recipe-service",
                "stock-service",
                "order-service"
            );
    }
}
