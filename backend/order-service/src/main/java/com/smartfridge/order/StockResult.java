/*
 * 这个文件：库存调用结果：成功带着剩余库存，失败带着原因。
 */

package com.smartfridge.order;

/**
 * 扣减库存的结果。用返回值而不是抛异常表达失败，是为了让限流、熔断、业务失败
 * 在调用方看来是可区分的三种状态，controller 可以映射成不同 HTTP 状态码。
 */
public record StockResult(boolean ok, int remaining, String message) {

    public static StockResult ok(int remaining) {
        return new StockResult(true, remaining, "success");
    }

    public static StockResult failure(String message) {
        return new StockResult(false, -1, message);
    }
}
