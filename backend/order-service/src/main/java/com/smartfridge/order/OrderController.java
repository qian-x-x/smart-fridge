/*
 * 这个文件：演示接口：下单、按 id 查订单、查最近订单。
 */

package com.smartfridge.order;

import com.smartfridge.common.api.ApiResponse;
import com.smartfridge.common.api.ErrorCode;
import com.smartfridge.common.error.BusinessException;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 下单接口。
 *
 * <p>三种正常结果对应三个状态码，便于现场演示时一眼区分：
 * 201 正常下单、429 被流控拦截、503 库存服务不可用或被熔断。
 * 库存不足与演示回滚由全局异常处理器返回 409 / 500。
 */
@RestController
@RequestMapping("/api/v1/orders")
public class OrderController {

    private final OrderService orderService;
    private final OrderRepository orderRepository;

    public OrderController(OrderService orderService, OrderRepository orderRepository) {
        this.orderService = orderService;
        this.orderRepository = orderRepository;
    }

    @PostMapping
    public ResponseEntity<ApiResponse<OrderView>> create(
        @Valid @RequestBody CreateOrderRequest request
    ) {
        OrderResult result = orderService.create(request);
        return switch (result.status()) {
            case CREATED -> ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(result.order()));
            case RATE_LIMITED -> ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                .body(ApiResponse.error(ErrorCode.TOO_MANY_REQUESTS, result.message()));
            case STOCK_UNAVAILABLE -> ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(ApiResponse.error(ErrorCode.INTERNAL_ERROR, result.message()));
        };
    }

    /** 查单条。回滚演示里用它确认“回滚后订单一律查不到”。 */
    @GetMapping("/{orderId}")
    public ApiResponse<OrderRow> byId(@PathVariable String orderId) {
        return ApiResponse.success(orderRepository.findById(orderId)
            .orElseThrow(() -> BusinessException.notFound("订单不存在")));
    }

    /** 最近订单，用于对比一次成功与一次回滚之后库里的差异。 */
    @GetMapping
    public ApiResponse<List<OrderRow>> recent(
        @RequestParam(defaultValue = "20") int limit
    ) {
        int bounded = Math.max(1, Math.min(limit, 100));
        return ApiResponse.success(orderRepository.recent(bounded));
    }
}
