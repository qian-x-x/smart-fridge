package com.smartfridge.fridge.fridge;

public record FridgeContainerView(
    long id,
    String name,
    String type,
    int sortOrder
) {
}
