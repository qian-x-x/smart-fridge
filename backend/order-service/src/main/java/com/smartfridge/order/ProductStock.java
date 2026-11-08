package com.smartfridge.order;

/** 库存服务返回的库存快照（本服务只保留需要的字段）。 */
public record ProductStock(String sku, String name, int stock) {
}
