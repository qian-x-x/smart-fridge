/*
 * 这个文件：冰箱里的容器（抽屉、隔板）信息。
 */

package com.smartfridge.fridge.fridge;

public record FridgeContainerView(
    long id,
    String name,
    String type,
    int sortOrder
) {
}
