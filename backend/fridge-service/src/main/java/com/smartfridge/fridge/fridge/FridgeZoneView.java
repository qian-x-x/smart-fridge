package com.smartfridge.fridge.fridge;

import java.math.BigDecimal;
import java.util.List;

public record FridgeZoneView(
    long id,
    String code,
    String name,
    BigDecimal temperatureC,
    int sortOrder,
    List<FridgeContainerView> containers
) {
}
