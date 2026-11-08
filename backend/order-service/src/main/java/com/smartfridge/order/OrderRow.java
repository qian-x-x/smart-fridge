package com.smartfridge.order;

import java.time.Instant;

/** 订单行，用于查询接口返回。 */
public record OrderRow(
    String orderId,
    String sku,
    int quantity,
    String status,
    Instant createdAt
) {
}
