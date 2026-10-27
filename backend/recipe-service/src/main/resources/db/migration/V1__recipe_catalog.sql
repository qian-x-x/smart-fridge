CREATE TABLE IF NOT EXISTS recipe (
    id BIGINT PRIMARY KEY,
    name VARCHAR(80) NOT NULL,
    summary VARCHAR(300) NOT NULL,
    category VARCHAR(40) NOT NULL,
    duration_minutes INT NOT NULL,
    calories INT NOT NULL,
    difficulty VARCHAR(20) NOT NULL,
    servings INT NOT NULL DEFAULT 2,
    cover_emoji VARCHAR(16) NOT NULL,
    steps VARCHAR(2000) NOT NULL,
    featured BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_recipe_name UNIQUE (name)
);

CREATE TABLE IF NOT EXISTS recipe_ingredient (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    recipe_id BIGINT NOT NULL,
    name VARCHAR(80) NOT NULL,
    quantity DECIMAL(12, 3),
    unit VARCHAR(20),
    optional BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order INT NOT NULL DEFAULT 0,
    CONSTRAINT fk_recipe_ingredient_recipe FOREIGN KEY (recipe_id) REFERENCES recipe (id)
);

CREATE INDEX idx_recipe_ingredient_recipe ON recipe_ingredient (recipe_id, sort_order);

INSERT INTO recipe (
    id, name, summary, category, duration_minutes, calories, difficulty,
    servings, cover_emoji, steps, featured
) VALUES
    (1, '番茄滑蛋', '酸甜番茄裹住嫩滑鸡蛋，十几分钟完成的家常菜。', '家常菜', 15, 260, '简单', 2, '🍅',
     '番茄切块，鸡蛋加少量盐打散|热锅放油，将鸡蛋炒至刚凝固后盛出|下番茄炒出汁水，加少量生抽调味|倒回鸡蛋快速翻匀即可',
     TRUE),
    (2, '蒜蓉生菜', '大火快炒保留生菜脆嫩口感，适合优先消耗叶菜。', '素菜', 8, 120, '简单', 2, '🥬',
     '生菜洗净沥干，蒜切末|热锅放油，小火炒香蒜末|转大火放入生菜快速翻炒|加盐调味后立即出锅',
     FALSE),
    (3, '青椒炒鸡胸', '高蛋白低脂的快手小炒，搭配青椒清脆爽口。', '快手菜', 20, 310, '简单', 2, '🥩',
     '鸡胸肉切片，用生抽和少量油腌制|青椒去籽切块|热锅将鸡胸炒至变色后盛出|下青椒翻炒，再倒回鸡胸炒匀',
     TRUE),
    (4, '香煎三文鱼', '外皮焦香、内部柔嫩的简单鱼类料理。', '高蛋白', 18, 360, '中等', 2, '🐟',
     '三文鱼擦干水分并撒少量盐|平底锅放油，鱼皮朝下煎至金黄|翻面继续煎至中心熟透|出锅前撒黑胡椒',
     FALSE),
    (5, '虾仁玉米炒饭', '利用冷冻虾仁、玉米和米饭完成的家庭快手主食。', '主食', 25, 480, '中等', 2, '🍤',
     '虾仁解冻，鸡蛋打散|热锅炒蛋并盛出|下虾仁和玉米粒炒熟|加入米饭炒散，最后拌入鸡蛋和调料',
     TRUE),
    (6, '鲜蔬蛋饼', '面粉、鸡蛋和黄瓜组合成轻盈早餐。', '早餐', 20, 290, '简单', 2, '🥚',
     '面粉加水和鸡蛋调成面糊|黄瓜切细丝后拌入面糊|平底锅刷油倒入面糊摊平|两面煎熟后切块装盘',
     FALSE);

INSERT INTO recipe_ingredient (recipe_id, name, quantity, unit, optional, sort_order) VALUES
    (1, '西红柿', 2, '个', FALSE, 10),
    (1, '鸡蛋', 3, '枚', FALSE, 20),
    (1, '食用油', 10, '毫升', FALSE, 30),
    (1, '盐', 2, '克', FALSE, 40),
    (2, '生菜', 1, '把', FALSE, 10),
    (2, '大蒜', 3, '瓣', FALSE, 20),
    (2, '食用油', 10, '毫升', FALSE, 30),
    (3, '青椒', 2, '个', FALSE, 10),
    (3, '鸡胸肉', 250, '克', FALSE, 20),
    (3, '生抽', 10, '毫升', FALSE, 30),
    (3, '食用油', 10, '毫升', FALSE, 40),
    (4, '三文鱼', 250, '克', FALSE, 10),
    (4, '黑胡椒', 2, '克', TRUE, 20),
    (4, '食用油', 8, '毫升', FALSE, 30),
    (5, '冷冻虾仁', 200, '克', FALSE, 10),
    (5, '速冻玉米粒', 150, '克', FALSE, 20),
    (5, '大米', 200, '克', FALSE, 30),
    (5, '鸡蛋', 2, '枚', FALSE, 40),
    (6, '鸡蛋', 2, '枚', FALSE, 10),
    (6, '中筋面粉', 150, '克', FALSE, 20),
    (6, '黄瓜', 1, '根', FALSE, 30),
    (6, '食用油', 8, '毫升', FALSE, 40);
