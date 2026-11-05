package com.smartfridge.gateway;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.http.HttpHeaders;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cloud.gateway.config.GatewayProperties;
import org.springframework.test.web.reactive.server.WebTestClient;

@SpringBootTest(
    webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
    properties = {
        "spring.cloud.nacos.discovery.enabled=false",
        "spring.cloud.nacos.config.enabled=false"
    }
)
class GatewayCorsTest {

    @LocalServerPort
    private int port;

    @Autowired
    private GatewayProperties routes;

    @Test
    void localProfileRoutesAllServicesWithoutNacos() {
        org.assertj.core.api.Assertions.assertThat(routes.getRoutes()).hasSize(6)
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
