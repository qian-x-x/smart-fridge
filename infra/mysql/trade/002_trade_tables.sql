-- 交易链路建表：库存与订单分属两个库，Seata AT 的全局事务才能体现"跨库回滚"。
-- 首次初始化数据卷时由 docker-entrypoint-initdb.d 自动执行；已有数据卷需手工执行一次。
--
-- 显式声明客户端字符集：否则客户端按 latin1 解释脚本里的中文，
-- 会把「云南小番茄」存成双重编码的乱码（表现为接口返回 äº‘å—å°ç•ªèŒ„）。
SET NAMES utf8mb4;

USE stock_db;

CREATE TABLE IF NOT EXISTS stock_item
(
    sku        VARCHAR(32) NOT NULL COMMENT '商品编码',
    name       VARCHAR(80) NOT NULL COMMENT '商品名称',
    stock      INT         NOT NULL COMMENT '可售库存',
    updated_at DATETIME(6) NOT NULL COMMENT '最后更新时间',
    PRIMARY KEY (sku)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci COMMENT ='商品库存';

-- 用 INSERT IGNORE 而不是 REPLACE：脚本重复执行时不能把已扣减的库存重置回初始值。
INSERT IGNORE INTO stock_item (sku, name, stock, updated_at)
VALUES ('APPLE', '云南小番茄', 100, NOW(6)),
       ('MILK', '低温鲜牛奶', 50, NOW(6)),
       ('EGG', '谷物鲜鸡蛋', 30, NOW(6));

-- Seata AT 分支事务的回滚依据：每个被代理的数据源都要有这张表。
CREATE TABLE IF NOT EXISTS undo_log
(
    branch_id     BIGINT       NOT NULL COMMENT '分支事务 id',
    xid           VARCHAR(128) NOT NULL COMMENT '全局事务 id',
    context       VARCHAR(128) NOT NULL COMMENT '序列化方式等上下文',
    rollback_info LONGBLOB     NOT NULL COMMENT '回滚快照（前镜像 + 后镜像）',
    log_status    INT          NOT NULL COMMENT '0 正常，1 防悬挂',
    log_created   DATETIME(6)  NOT NULL,
    log_modified  DATETIME(6)  NOT NULL,
    UNIQUE KEY ux_undo_log (xid, branch_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci COMMENT ='AT 模式回滚日志';

USE order_db;

CREATE TABLE IF NOT EXISTS order_record
(
    id         BIGINT      NOT NULL AUTO_INCREMENT,
    order_id   VARCHAR(40) NOT NULL COMMENT '业务订单号',
    sku        VARCHAR(32) NOT NULL COMMENT '商品编码',
    quantity   INT         NOT NULL COMMENT '购买数量',
    status     VARCHAR(16) NOT NULL COMMENT 'CREATED / CANCELLED',
    request_id VARCHAR(64) NOT NULL COMMENT '幂等键，同一次下单重试复用',
    created_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_order_id (order_id),
    UNIQUE KEY uk_request_id (request_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci COMMENT ='订单';

CREATE TABLE IF NOT EXISTS undo_log
(
    branch_id     BIGINT       NOT NULL COMMENT '分支事务 id',
    xid           VARCHAR(128) NOT NULL COMMENT '全局事务 id',
    context       VARCHAR(128) NOT NULL COMMENT '序列化方式等上下文',
    rollback_info LONGBLOB     NOT NULL COMMENT '回滚快照（前镜像 + 后镜像）',
    log_status    INT          NOT NULL COMMENT '0 正常，1 防悬挂',
    log_created   DATETIME(6)  NOT NULL,
    log_modified  DATETIME(6)  NOT NULL,
    UNIQUE KEY ux_undo_log (xid, branch_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci COMMENT ='AT 模式回滚日志';
