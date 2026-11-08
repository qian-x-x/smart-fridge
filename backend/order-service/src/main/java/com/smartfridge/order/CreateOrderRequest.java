package com.smartfridge.order;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;

/**
 * @param stockDelayMs    仅用于演示：让库存服务延迟响应，观察超时与熔断。正常下单不传。
 * @param failAfterDeduct 仅用于演示全局回滚：库存扣减成功后主动失败，
 *                        用来验证订单与库存是否一起回滚。正常下单不传。
 */
public record CreateOrderRequest(
    @NotBlank(message = "商品编码不能为空")
    String sku,

    @Min(value = 1, message = "购买数量至少为 1")
    int quantity,

    Long stockDelayMs,

    Boolean failAfterDeduct
) {
}
