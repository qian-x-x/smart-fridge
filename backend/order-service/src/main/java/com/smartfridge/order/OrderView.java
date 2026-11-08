package com.smartfridge.order;

public record OrderView(
    String orderId,
    String sku,
    int quantity,
    int remainingStock,
    String status
) {
}
