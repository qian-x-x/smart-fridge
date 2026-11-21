/*
 * 这个文件：订单状态枚举（待处理、已创建等）。
 */

package com.smartfridge.order;

public enum OrderStatus {
    /** 库存扣减成功，订单已创建。 */
    CREATED,
    /** 被 Sentinel 流控拦截，未进入业务逻辑。 */
    RATE_LIMITED,
    /** 库存服务不可用或被熔断，订单未创建。 */
    STOCK_UNAVAILABLE
}
