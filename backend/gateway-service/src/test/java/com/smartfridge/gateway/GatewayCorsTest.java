/*
 * 这个文件：测试网关的跨域配置：前端从浏览器调接口时不会被 CORS 挡掉。
 */

package com.smartfridge.gateway;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.http.HttpHeaders;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cloud.gateway.config.GatewayProperties;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.reactive.server.WebTestClient;

@SpringBootTest(
    webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
    properties = {
        "spring.cloud.nacos.discovery.enabled=false",
        "spring.cloud.nacos.config.enabled=false"
    }
)
@ActiveProfiles("local")
class GatewayCorsTest {

    @LocalServerPort
    private int port;

    @Autowired
    private GatewayProperties routes;

    /**
     * local 是降级 profile：没有注册中心时，网关仍应按固定地址把请求转发到 5 个业务服务。
     * 默认 profile（cloud）走 lb://，由 {@link GatewayDiscoveryRouteTest} 覆盖。
     */
    @Test
    void localProfileRoutesAllServicesWithoutNacos() {
        org.assertj.core.api.Assertions.assertThat(routes.getRoutes()).hasSize(5)
            .allSatisfy(route -> {
                org.assertj.core.api.Assertions.assertThat(route.getUri().getScheme()).isEqualTo("http");
                org.assertj.core.api.Assertions.assertThat(route.getUri().getHost()).isEqualTo("127.0.0.1");
                org.assertj.core.api.Assertions.assertThat(route.getPredicates()).isNotEmpty();
            });
    }

    @Test
    void permitsFlutterWebWhenServedFromLoopbackIp() {
        String origin = "http://127.0.0.1:3000";
        WebTestClient.bindToServer()
            .baseUrl("http://127.0.0.1:" + port)
            .build()
            .options()
            .uri("/api/v1/auth/login")
            .header(HttpHeaders.ORIGIN, origin)
            .header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, "POST")
            .header(HttpHeaders.ACCESS_CONTROL_REQUEST_HEADERS, "content-type")
            .exchange()
            .expectStatus().isOk()
            .expectHeader().valueEquals(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, origin);
    }
}
