package com.smartfridge.gateway.filter;

import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.core.Ordered;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

import java.util.UUID;

@Component
public class GatewayTraceFilter implements GlobalFilter, Ordered {

    public static final String TRACE_HEADER = "X-Request-Id";

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        String requestedTraceId = exchange.getRequest().getHeaders().getFirst(TRACE_HEADER);
        final String traceId = requestedTraceId == null || requestedTraceId.isBlank()
            ? UUID.randomUUID().toString()
            : requestedTraceId;

        ServerHttpRequest request = exchange.getRequest().mutate()
            .headers(headers -> headers.set(TRACE_HEADER, traceId))
            .build();
        exchange.getResponse().getHeaders().set(TRACE_HEADER, traceId);
        return chain.filter(exchange.mutate().request(request).build());
    }

    @Override
    public int getOrder() {
        return Ordered.HIGHEST_PRECEDENCE;
    }
}
