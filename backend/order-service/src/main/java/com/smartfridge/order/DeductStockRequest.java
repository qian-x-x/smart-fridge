/*
 * 这个文件：调用库存服务扣减时的请求体。
 */

package com.smartfridge.order;

public record DeductStockRequest(int quantity) {
}
