/*
 * 这个文件：网关的统一鉴权闸门。
 * 登录、注册这类公开接口直接放行；其余 /api/ 请求必须带 Bearer token。
 * 校验内容：签名是否有效、是不是 access 类型、有没有被用户登出拉黑。
 * 校验通过后，删掉客户端自己伪造的身份头，由网关注入真实的 X-User-Id / X-User-Name / X-User-Role，
 * 后面的服务只信任这三个头，不再自己解析 token。
 */

package com.smartfridge.gateway.filter;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import com.smartfridge.gateway.security.TokenIntrospectionClient;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.core.Ordered;
import org.springframework.core.io.buffer.DataBuffer;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

import java.nio.charset.StandardCharsets;
import java.time.Instant;

@Component
public class JwtGatewayFilter implements GlobalFilter, Ordered {

    private final byte[] jwtSecret;
    private final TokenIntrospectionClient introspection;

    public JwtGatewayFilter(@Value("${smart-fridge.jwt.secret}") String jwtSecret,
                            TokenIntrospectionClient introspection) {
        this.jwtSecret = jwtSecret.getBytes(StandardCharsets.UTF_8);
        this.introspection = introspection;
    }

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        String path = exchange.getRequest().getURI().getPath();
        if (!path.startsWith("/api/") ||
            path.startsWith("/api/v1/auth/") ||
            path.startsWith("/actuator/")) {
            return chain.filter(exchange);
        }

        if ("OPTIONS".equalsIgnoreCase(exchange.getRequest().getMethod().name())) {
            return chain.filter(exchange);
        }

        String authorization = exchange.getRequest().getHeaders().getFirst(HttpHeaders.AUTHORIZATION);
        if (authorization == null || !authorization.startsWith("Bearer ")) {
            return reject(exchange, "缺少访问令牌");
        }

        try {
            Claims claims = Jwts.parser()
                .verifyWith(Keys.hmacShaKeyFor(jwtSecret))
                .build()
                .parseSignedClaims(authorization.substring(7))
                .getPayload();

            if (!"access".equals(claims.get("type", String.class))) {
                return reject(exchange, "令牌类型无效");
            }

            // 先删掉客户端可能自己伪造的身份头，再由网关注入真实身份：
            // 后面的业务服务只认这三个头，所以这一步决定了「你是谁」。
            ServerHttpRequest request = exchange.getRequest().mutate()
                .headers(headers -> {
                    headers.remove("X-User-Id");
                    headers.remove("X-User-Name");
                    headers.remove("X-User-Role");
                    // Only backend coordinators may create/propagate Seata XIDs.
                    headers.remove("TX_XID");
                    headers.set("X-User-Id", claims.getSubject());
                    headers.set("X-User-Name", claims.get("username", String.class));
                    headers.set("X-User-Role", claims.get("role", String.class));
                })
                .build();
            return introspection.isActive(authorization)
                .onErrorResume(error -> reject(exchange, HttpStatus.SERVICE_UNAVAILABLE,
                    "INTERNAL_ERROR", "认证服务暂时不可用").then(Mono.empty()))
                .flatMap(active -> active
                    ? chain.filter(exchange.mutate().request(request).build())
                    : reject(exchange, "访问令牌已撤销或失效"));
        } catch (JwtException | IllegalArgumentException exception) {
            return reject(exchange, "访问令牌无效或已过期");
        }
    }

    private Mono<Void> reject(ServerWebExchange exchange, String message) {
        return reject(exchange, HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", message);
    }

    private Mono<Void> reject(ServerWebExchange exchange, HttpStatus status, String code, String message) {
        String traceId = exchange.getResponse().getHeaders().getFirst(GatewayTraceFilter.TRACE_HEADER);
        String body = """
            {"code":"%s","message":"%s","data":null,"traceId":"%s"}
            """.formatted(code, message, traceId == null ? "" : traceId).trim();
        exchange.getResponse().setStatusCode(status);
        exchange.getResponse().getHeaders().setContentType(MediaType.APPLICATION_JSON);
        DataBuffer buffer = exchange.getResponse().bufferFactory()
            .wrap(body.getBytes(StandardCharsets.UTF_8));
        return exchange.getResponse().writeWith(Mono.just(buffer));
    }

    @Override
    public int getOrder() {
        return Ordered.HIGHEST_PRECEDENCE + 10;
    }
}
