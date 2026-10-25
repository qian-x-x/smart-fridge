CREATE DATABASE IF NOT EXISTS stock_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS order_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

GRANT ALL PRIVILEGES ON stock_db.* TO 'smart_fridge_trade'@'%';
GRANT ALL PRIVILEGES ON order_db.* TO 'smart_fridge_trade'@'%';
FLUSH PRIVILEGES;
