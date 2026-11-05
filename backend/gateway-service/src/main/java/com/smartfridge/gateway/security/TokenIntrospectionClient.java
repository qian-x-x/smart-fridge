package com.smartfridge.gateway.security;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;
import reactor.core.publisher.Mono;

import java.time.Duration;

@Component
public class TokenIntrospectionClient {
    private final WebClient client;

    public TokenIntrospectionClient(
        @Qualifier("authLoadBalancedClient") WebClient.Builder loadBalanced,
        @Value("${smart-fridge.auth-service-url:}") String authServiceUrl
    ) {
        client = authServiceUrl.isBlank()
            ? loadBalanced.baseUrl("http://auth-family-service").build()
            : WebClient.builder().baseUrl(authServiceUrl).build();
    }

    public Mono<Boolean> isActive(String authorization) {
        return client.post().uri("/api/v1/auth/introspect")
            .header("Authorization", authorization)
            .retrieve().bodyToMono(Envelope.class)
            .switchIfEmpty(Mono.error(new IllegalStateException("Empty authentication response")))
            .map(body -> {
                if (!"OK".equals(body.code()) || body.data() == null) {
                    throw new IllegalStateException("Invalid authentication response");
                }
                return true;
            })
            .onErrorResume(WebClientResponseException.Unauthorized.class, error -> Mono.just(false))
            .timeout(Duration.ofSeconds(3));
    }

    private record Envelope(String code, Object data) {}
}
