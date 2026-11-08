package com.smartfridge.order;

public enum OrderStatus {
    /** 库存扣减成功，订单已创建。 */
    CREATED,
    /** 被 Sentinel 流控拦截，未进入业务逻辑。 */
    RATE_LIMITED,
    /** 库存服务不可用或被熔断，订单未创建。 */
    STOCK_UNAVAILABLE
}
