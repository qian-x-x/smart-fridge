package com.smartfridge.stock;

import com.smartfridge.common.api.ErrorCode;
import com.smartfridge.common.error.BusinessException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;

/**
 * 库存读写。库存在 `stock_db.stock_item`，与订单不在同一个库，
 * 这样一次下单才是真正的跨库事务，Seata 的回滚才可观察。
 */
@Service
public class StockService {

    private static final Logger log = LoggerFactory.getLogger(StockService.class);

    private final JdbcTemplate jdbcTemplate;

    public StockService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public ProductStockView stockOf(String sku) {
        List<ProductStockView> rows = jdbcTemplate.query(
            "SELECT sku, name, stock FROM stock_item WHERE sku = ?",
            (rs, rowNum) -> new ProductStockView(
                rs.getString("sku"), rs.getString("name"), rs.getInt("stock")
            ),
            sku
        );
        if (rows.isEmpty()) {
            throw BusinessException.notFound("商品不存在");
        }
        return rows.get(0);
    }

    /**
     * 扣减库存。
     *
     * <p>用一条带 {@code stock >= ?} 条件的 UPDATE 同时完成“判断 + 扣减”，
     * 避免先查后改的竞态；受影响行数为 0 时再回头区分“商品不存在”和“库存不足”。
     *
     * <p>{@code @Transactional} 声明的是本地事务。Seata 代理数据源后，
     * 这条连接会加入全局事务，本次扣减成为分支事务，前后镜像写进 `undo_log`——
     * 这正是全局回滚时能还原库存的依据。
     */
    @Transactional
    public ProductStockView deduct(String sku, int quantity) {
        if (quantity <= 0) {
            throw new BusinessException(
                ErrorCode.VALIDATION_ERROR, HttpStatus.BAD_REQUEST, "扣减数量必须大于 0"
            );
        }
        int updated = jdbcTemplate.update(
            "UPDATE stock_item SET stock = stock - ?, updated_at = ? WHERE sku = ? AND stock >= ?",
            quantity, Timestamp.from(Instant.now()), sku, quantity
        );
        if (updated == 0) {
            // 不存在会抛 404；存在但不够则抛 409，两者都不能触发熔断统计。
            ProductStockView current = stockOf(sku);
            throw BusinessException.conflict("库存不足，剩余 " + current.stock());
        }
        ProductStockView after = stockOf(sku);
        log.info("stock deducted sku={} quantity={} remaining={}", sku, quantity, after.stock());
        return after;
    }
}
