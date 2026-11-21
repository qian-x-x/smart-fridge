/*
 * 这个文件：演示用的下单流程，专门用来验证两件事：
 * 1) Sentinel 限流真的能挡住超额请求；
 * 2) Seata 全局事务能让「订单落库」和「扣库存」要么一起成功、要么一起回滚。
 * 库存不足时故意抛异常而不是返回失败对象，因为全局事务只对异常回滚。
 */

package com.smartfridge.order;

import com.alibaba.csp.sentinel.annotation.SentinelResource;
import com.alibaba.csp.sentinel.slots.block.BlockException;
import com.smartfridge.common.api.ErrorCode;
import com.smartfridge.common.error.BusinessException;
import io.seata.spring.annotation.GlobalTransactional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.UUID;

/**
 * 下单流程。这里同时是两件事的落点：
 *
 * <ul>
 *   <li>资源名 {@code order-create} 由 QPS 流控规则保护（C2 流控证据）；</li>
 *   <li>{@code @GlobalTransactional} 开启全局事务，订单落库与库存扣减
 *       要么都成功、要么都回滚（D1 / F7 事务证据）。</li>
 * </ul>
 *
 * <p>关键顺序：先写订单（PENDING），再调用库存。库存不足时抛异常而不是返回失败值——
 * 全局事务只对异常回滚，返回一个“失败对象”会让已经写入的订单被提交。
 */
@Service
public class OrderService {

    private static final Logger log = LoggerFactory.getLogger(OrderService.class);
    private static final DateTimeFormatter DAY = DateTimeFormatter.BASIC_ISO_DATE;

    private final StockGateway stockGateway;
    private final OrderRepository orderRepository;

    public OrderService(StockGateway stockGateway, OrderRepository orderRepository) {
        this.stockGateway = stockGateway;
        this.orderRepository = orderRepository;
    }

    @GlobalTransactional(name = "order-create-tx", rollbackFor = Exception.class)
    @Transactional(rollbackFor = Exception.class)
    @SentinelResource(value = "order-create", blockHandler = "onRateLimited")
    public OrderResult create(CreateOrderRequest request) {
        String orderId = newOrderId();
        orderRepository.insertPending(orderId, request.sku(), request.quantity());

        StockResult stock = stockGateway.deduct(
            request.sku(), request.quantity(), request.stockDelayMs()
        );
        if (!stock.ok()) {
            // 熔断或超时：库存侧可能已经扣了，必须让全局事务回滚这笔订单。
            throw new BusinessException(
                ErrorCode.INTERNAL_ERROR, HttpStatus.SERVICE_UNAVAILABLE, stock.message()
            );
        }

        if (Boolean.TRUE.equals(request.failAfterDeduct())) {
            // 只用于演示：库存扣减已成功，订单侧紧接着失败。
            // 全局事务回滚后，库存应恢复、这条订单应消失。
            throw new BusinessException(
                ErrorCode.INTERNAL_ERROR,
                HttpStatus.INTERNAL_SERVER_ERROR,
                "演示用异常：库存已扣减，订单侧主动失败，全局事务应回滚"
            );
        }

        orderRepository.markCreated(orderId);
        log.info("order created id={} sku={} quantity={} remaining={}",
            orderId, request.sku(), request.quantity(), stock.remaining());
        return OrderResult.created(new OrderView(
            orderId, request.sku(), request.quantity(), stock.remaining(), "CREATED"
        ));
    }

    /** 触发流控时执行：这里不调用任何下游，确保限流真的挡住了流量。 */
    public OrderResult onRateLimited(CreateOrderRequest request, BlockException error) {
        log.warn("order rate limited for sku={} rule={}", request.sku(), error.getRule());
        return OrderResult.rateLimited("下单请求过于频繁（QPS 上限 2），请稍后重试");
    }

    /** 日期 + 随机短码，保证跨重启也不重复。 */
    private String newOrderId() {
        return "ORD-%s-%s".formatted(
            LocalDate.now().format(DAY),
            UUID.randomUUID().toString().substring(0, 8).toUpperCase()
        );
    }
}
