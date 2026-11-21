/*
 * 这个文件：返回给前端的订单信息。
 */

package com.smartfridge.order;

public record OrderView(
    String orderId,
    String sku,
    int quantity,
    int remainingStock,
    String status
) {
}
