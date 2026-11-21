/*
 * 这个文件：库存查询的返回数据。
 */

package com.smartfridge.stock;

/**
 * 商品库存快照。库存持久化在 `stock_db.stock_item`：
 * 只有落到数据库，Seata 的分支事务才有 undo_log 可写，回滚才能被观察到。
 */
public record ProductStockView(String sku, String name, int stock) {
}
