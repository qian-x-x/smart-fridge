/*
 * 这个文件：库存接口：查库存、扣库存、以及一个模拟慢响应的接口（给熔断演示用）。
 */

package com.smartfridge.stock;

import com.smartfridge.common.api.ApiResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 商品库存接口。除了正常的查询与扣减，还提供 {@code delayMs} 用于演示
 * “调用变慢 → 熔断”与“调用超时 → 错误传播”，这是 C3 与 C2 的现场素材。
 */
@RestController
@RequestMapping("/api/v1/products")
public class ProductController {

    private final StockService stockService;

    public ProductController(StockService stockService) {
        this.stockService = stockService;
    }

    @GetMapping("/{sku}")
    public ApiResponse<ProductStockView> stockOf(
        @PathVariable String sku,
        @RequestParam(required = false) Long delayMs
    ) {
        delay(delayMs);
        return ApiResponse.success(stockService.stockOf(sku));
    }

    @PostMapping("/{sku}/deduct")
    public ApiResponse<ProductStockView> deduct(
        @PathVariable String sku,
        @RequestBody DeductRequest request,
        @RequestParam(required = false) Long delayMs
    ) {
        delay(delayMs);
        return ApiResponse.success(stockService.deduct(sku, request.quantity()));
    }

    /**
     * 故障注入：让接口按指定毫秒变慢，用来观察调用方超时与熔断，
     * 不需要额外搭一套故障环境。
     */
    private void delay(Long delayMs) {
        if (delayMs == null || delayMs <= 0) {
            return;
        }
        long bounded = Math.min(delayMs, 10_000L);
        try {
            Thread.sleep(bounded);
        } catch (InterruptedException interrupted) {
            Thread.currentThread().interrupt();
        }
    }
}
