CREATE DATABASE IF NOT EXISTS auth_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS fridge_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS recipe_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS notify_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

GRANT ALL PRIVILEGES ON auth_db.* TO 'smart_fridge'@'%';
GRANT ALL PRIVILEGES ON fridge_db.* TO 'smart_fridge'@'%';
GRANT ALL PRIVILEGES ON recipe_db.* TO 'smart_fridge'@'%';
GRANT ALL PRIVILEGES ON notify_db.* TO 'smart_fridge'@'%';
FLUSH PRIVILEGES;
