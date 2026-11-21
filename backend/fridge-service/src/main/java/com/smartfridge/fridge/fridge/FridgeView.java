/*
 * 这个文件：返回给前端的冰箱结构：基本信息 + 分区 + 容器。
 */

package com.smartfridge.fridge.fridge;

import java.time.Instant;
import java.util.List;

public record FridgeView(
    long id,
    long familyId,
    String name,
    String timezone,
    List<FridgeZoneView> zones,
    Instant createdAt,
    Instant updatedAt
) {
}
