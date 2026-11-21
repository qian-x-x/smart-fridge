/*
 * 这个文件：订单表的 SQL 操作。
 */

package com.smartfridge.order;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

/** 订单读写。与库存分属两个库，一次下单才是跨库事务。 */
@Repository
public class OrderRepository {

    private static final RowMapper<OrderRow> ROW_MAPPER = (rs, rowNum) -> new OrderRow(
        rs.getString("order_id"),
        rs.getString("sku"),
        rs.getInt("quantity"),
        rs.getString("status"),
        rs.getTimestamp("created_at").toInstant()
    );

    private final JdbcTemplate jdbcTemplate;

    public OrderRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /**
     * 先落一条 PENDING 订单。全局回滚时这一行会被 undo_log 撤销，
     * 所以"回滚前查得到、回滚后查不到"正好说明一阶段确实写过库。
     */
    public void insertPending(String orderId, String sku, int quantity) {
        jdbcTemplate.update(
            """
                INSERT INTO order_record (order_id, sku, quantity, status, request_id, created_at)
                VALUES (?, ?, ?, 'PENDING', ?, ?)
                """,
            orderId, sku, quantity, orderId, Timestamp.from(Instant.now())
        );
    }

    /** 库存扣减成功后才把订单标记为已创建。 */
    public void markCreated(String orderId) {
        jdbcTemplate.update(
            "UPDATE order_record SET status = 'CREATED' WHERE order_id = ?", orderId
        );
    }

    public Optional<OrderRow> findById(String orderId) {
        List<OrderRow> rows = jdbcTemplate.query(
            "SELECT order_id, sku, quantity, status, created_at FROM order_record WHERE order_id = ?",
            ROW_MAPPER, orderId
        );
        return rows.stream().findFirst();
    }

    public List<OrderRow> recent(int limit) {
        return jdbcTemplate.query(
            """
                SELECT order_id, sku, quantity, status, created_at
                FROM order_record ORDER BY id DESC LIMIT ?
                """,
            ROW_MAPPER, limit
        );
    }

    public int count() {
        Integer total = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM order_record", Integer.class);
        return total == null ? 0 : total;
    }
}
