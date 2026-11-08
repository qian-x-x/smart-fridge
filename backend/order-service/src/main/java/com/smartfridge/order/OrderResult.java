package com.smartfridge.order;

public record OrderResult(OrderStatus status, OrderView order, String message) {

    public static OrderResult created(OrderView order) {
        return new OrderResult(OrderStatus.CREATED, order, "created");
    }

    public static OrderResult rateLimited(String message) {
        return new OrderResult(OrderStatus.RATE_LIMITED, null, message);
    }

    public static OrderResult stockUnavailable(String message) {
        return new OrderResult(OrderStatus.STOCK_UNAVAILABLE, null, message);
    }
}
