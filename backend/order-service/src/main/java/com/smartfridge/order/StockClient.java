package com.smartfridge.order;

import com.smartfridge.common.api.ApiResponse;
import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;

/**
 * 按服务名调用库存服务：地址来自注册中心，不写死 IP。
 *
 * <p>{@code delayMs} 只用于演示“调用变慢 / 超时”，正常下单不会传。
 */
@FeignClient(name = "stock-service")
public interface StockClient {

    @PostMapping("/api/v1/products/{sku}/deduct")
    ApiResponse<ProductStock> deduct(
        @PathVariable("sku") String sku,
        @RequestBody DeductStockRequest request,
        @RequestParam(value = "delayMs", required = false) Long delayMs
    );
}
