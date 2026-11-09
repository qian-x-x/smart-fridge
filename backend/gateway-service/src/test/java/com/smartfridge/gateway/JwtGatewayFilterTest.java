package com.smartfridge.gateway;

import com.smartfridge.gateway.filter.JwtGatewayFilter;
import com.smartfridge.gateway.filter.GatewayTraceFilter;
import com.smartfridge.gateway.security.TokenIntrospectionClient;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.mock.http.server.reactive.MockServerHttpRequest;
import org.springframework.mock.web.server.MockServerWebExchange;
import reactor.core.publisher.Mono;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

class JwtGatewayFilterTest {
    private static final String SECRET = "dev-only-smart-fridge-secret-change-before-release-2026";

    @Test
    void revokedTokenCannotReadRecipes() {
        var client = mock(TokenIntrospectionClient.class);
        var token = token();
        when(client.isActive("Bearer " + token)).thenReturn(Mono.just(false));
        var exchange = exchange(token);
        new JwtGatewayFilter(SECRET, client).filter(exchange, ignored -> {
            throw new AssertionError("Revoked token was forwarded");
        }).block();
        assertThat(exchange.getResponse().getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(exchange.getResponse().getBodyAsString().block()).contains("UNAUTHORIZED");
    }

    @Test
    void authenticationOutageIsServiceUnavailableAndDoesNotClearTheSession() {
        var client = mock(TokenIntrospectionClient.class);
        var token = token();
        when(client.isActive("Bearer " + token)).thenReturn(Mono.error(new IllegalStateException("offline")));
        var exchange = exchange(token);
        new JwtGatewayFilter(SECRET, client).filter(exchange, ignored -> {
            throw new AssertionError("Unauthenticated request was forwarded");
        }).block();
        assertThat(exchange.getResponse().getStatusCode()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
        assertThat(exchange.getResponse().getBodyAsString().block()).contains("INTERNAL_ERROR");
    }

    @Test
    void activeTokenReplacesForgedIdentityHeaders() {
        var client = mock(TokenIntrospectionClient.class);
        var token = token();
        when(client.isActive("Bearer " + token)).thenReturn(Mono.just(true));
        var exchange = exchange(token);
        var forwarded = new AtomicReference<String>();
        new JwtGatewayFilter(SECRET, client).filter(exchange, next -> {
            forwarded.set(next.getRequest().getHeaders().getFirst("X-User-Id"));
            assertThat(next.getRequest().getHeaders().getFirst("X-User-Role")).isEqualTo("USER");
            assertThat(next.getRequest().getHeaders().getFirst("TX_XID")).isNull();
            return Mono.empty();
        }).block();
        assertThat(forwarded.get()).isEqualTo("7");
    }

    @Test
    void publicRoutesCannotForwardAnExternalTransactionContext() {
        var exchange = MockServerWebExchange.from(MockServerHttpRequest.post("/api/v1/auth/register")
            .header("TX_XID", "forged-xid"));
        new GatewayTraceFilter().filter(exchange, next -> {
            assertThat(next.getRequest().getHeaders().getFirst("TX_XID")).isNull();
            return Mono.empty();
        }).block();
    }

    @Test
    void invalidTokenIsRejectedWithoutCallingTheAuthenticationService() {
        var client = mock(TokenIntrospectionClient.class);
        var exchange = exchange("invalid");
        new JwtGatewayFilter(SECRET, client).filter(exchange, ignored -> Mono.empty()).block();
        assertThat(exchange.getResponse().getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        verifyNoInteractions(client);
    }

    @Test
    void traceHeaderCannotBreakJsonErrors() {
        var exchange = MockServerWebExchange.from(MockServerHttpRequest.get("/api/v1/recipes")
            .header("X-Request-Id", "bad\"trace"));
        var client = mock(TokenIntrospectionClient.class);
        var auth = new JwtGatewayFilter(SECRET, client);
        new GatewayTraceFilter().filter(exchange, next -> auth.filter(next, ignored -> Mono.empty())).block();
        assertThat(exchange.getResponse().getHeaders().getFirst("X-Request-Id"))
            .matches("[A-Za-z0-9._-]{1,128}");
        assertThat(exchange.getResponse().getBodyAsString().block()).doesNotContain("bad\"trace");
    }

    private MockServerWebExchange exchange(String token) {
        return MockServerWebExchange.from(MockServerHttpRequest.get("/api/v1/recipes")
            .header("Authorization", "Bearer " + token)
            .header("X-User-Id", "999").header("X-User-Role", "ADMIN")
            .header("TX_XID", "forged-global-transaction"));
    }

    private String token() {
        return Jwts.builder().subject("7").claim("type", "access").claim("role", "USER")
            .claim("username", "owner").expiration(Date.from(Instant.now().plusSeconds(300)))
            .signWith(Keys.hmacShaKeyFor(SECRET.getBytes(StandardCharsets.UTF_8))).compact();
    }
}
