/*
 * 这个文件：库存调用的唯一出口，也是熔断的落点。
 * 库存不足是业务结果，正常往上抛；熔断打开就不再发真实请求；超时等技术故障则降级成可读提示。
 */

package com.smartfridge.order;

import com.alibaba.csp.sentinel.annotation.SentinelResource;
import com.alibaba.csp.sentinel.slots.block.BlockException;
import com.smartfridge.common.api.ApiResponse;
import com.smartfridge.common.error.BusinessException;
import feign.FeignException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.net.ConnectException;
import java.net.SocketTimeoutException;

/**
 * 库存调用的唯一出口，也是熔断的落点。
 *
 * <p>资源名 {@code stock-deduct} 由一个 Sentinel 熔断规则保护（慢调用比例）。
 * 三种失败在这里被区分开：
 * <ul>
 *   <li>库存不足（HTTP 409）：业务结果，原样向上抛，不计入降级；</li>
 *   <li>熔断打开：{@code onBlocked} 直接返回，不再发起真实调用；</li>
 *   <li>超时或其他技术异常：{@code onFailure} 兜底，返回可读原因。</li>
 * </ul>
 */
@Component
public class StockGateway {

    private static final Logger log = LoggerFactory.getLogger(StockGateway.class);

    private final StockClient stockClient;

    public StockGateway(StockClient stockClient) {
        this.stockClient = stockClient;
    }

    @SentinelResource(
        value = "stock-deduct",
        blockHandler = "onBlocked",
        fallback = "onFailure",
        exceptionsToIgnore = BusinessException.class
    )
    public StockResult deduct(String sku, int quantity, Long delayMs) {
        try {
            ApiResponse<ProductStock> response = stockClient.deduct(
                sku, new DeductStockRequest(quantity), delayMs
            );
            if (response == null || response.data() == null) {
                return StockResult.failure("库存服务返回为空");
            }
            return StockResult.ok(response.data().stock());
        } catch (FeignException error) {
            if (error.status() == 409) {
                // 库存不足是正常业务结果，不应触发熔断计数。
                throw BusinessException.conflict("库存不足，请调整数量后重试");
            }
            throw error;
        }
    }

    /** 熔断打开时不发起真实调用。 */
    public StockResult onBlocked(String sku, int quantity, Long delayMs, BlockException error) {
        log.warn("stock call blocked by circuit breaker: sku={} rule={}", sku, error.getRule());
        return StockResult.failure("库存服务已熔断，本次未发起调用");
    }

    /** 超时、连接失败等异常统一降级，给出调用端能看懂的原因。 */
    public StockResult onFailure(String sku, int quantity, Long delayMs, Throwable error) {
        log.warn("stock call degraded: sku={} cause={}", sku, error.toString());
        return StockResult.failure("库存服务调用失败：" + describe(error));
    }

    /**
     * Feign 会把底层网络异常包在 RetryableException 里，这里剥到根因再分类，
     * 避免把 “RetryableException” 这种实现细节暴露给调用方。
     */
    private String describe(Throwable error) {
        Throwable root = error;
        while (root.getCause() != null && root.getCause() != root) {
            root = root.getCause();
        }
        if (root instanceof SocketTimeoutException) {
            return "响应超时（超过 1500ms 未返回）";
        }
        if (root instanceof ConnectException) {
            return "无法连接库存服务";
        }
        return error.getClass().getSimpleName();
    }
}
