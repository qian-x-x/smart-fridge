/*
 * 这个文件：测试「令牌是否已被吊销」的远程查询客户端及它的异常处理。
 */

package com.smartfridge.gateway;

import com.smartfridge.gateway.security.TokenIntrospectionClient;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.web.reactive.function.client.ClientResponse;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import static org.assertj.core.api.Assertions.*;

class TokenIntrospectionClientTest {
    @Test
    void acceptsValidEnvelopeAndRejectsRevokedToken() {
        assertThat(client(HttpStatus.OK, "{\"code\":\"OK\",\"data\":{\"userId\":7}}")
            .isActive("Bearer test").block()).isTrue();
        assertThat(client(HttpStatus.UNAUTHORIZED, "{\"code\":\"UNAUTHORIZED\"}")
            .isActive("Bearer test").block()).isFalse();
    }

    @Test
    void invalidAndEmptyResponsesAreServiceFailures() {
        assertThatThrownBy(() -> client(HttpStatus.OK, "{\"code\":\"OK\",\"data\":null}")
            .isActive("Bearer test").block()).isInstanceOf(IllegalStateException.class);
        assertThatThrownBy(() -> client(HttpStatus.OK, "")
            .isActive("Bearer test").block()).isInstanceOf(RuntimeException.class);
        assertThatThrownBy(() -> client(HttpStatus.INTERNAL_SERVER_ERROR, "{}")
            .isActive("Bearer test").block()).isInstanceOf(Exception.class);
    }

    private TokenIntrospectionClient client(HttpStatus status, String body) {
        var builder = WebClient.builder().exchangeFunction(request -> Mono.just(
            ClientResponse.create(status).header("Content-Type", "application/json").body(body).build()));
        return new TokenIntrospectionClient(builder, "");
    }
}
