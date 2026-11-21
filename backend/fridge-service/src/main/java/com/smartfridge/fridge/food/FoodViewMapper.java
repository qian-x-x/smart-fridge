/*
 * 这个文件：按冰箱所在时区计算「还有几天到期、算不算临期」，统一给食材列表和流水用，
 * 保证两个地方显示的结论一致。
 */

package com.smartfridge.fridge.food;

import com.smartfridge.fridge.config.FridgeSettings;
import com.smartfridge.fridge.fridge.FridgeView;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;

/**
 * Adds fridge-local expiry information to a stored food row. Shared by the food
 * endpoints and the operation timeline so both report identical numbers.
 *
 * <p>The "expiring" flag uses the threshold from {@link FridgeSettings} instead
 * of a hard-coded number, so it follows the value published from Nacos.
 */
@Component
public class FoodViewMapper {

    private final Clock clock;
    private final FridgeSettings settings;

    public FoodViewMapper(Clock clock, FridgeSettings settings) {
        this.clock = clock;
        this.settings = settings;
    }

    public FoodView withExpiry(FoodView food, FridgeView fridge) {
        LocalDate today = LocalDate.now(clock.withZone(ZoneId.of(fridge.timezone())));
        long remainingDays = ChronoUnit.DAYS.between(today, food.expiresOn());
        return new FoodView(
            food.id(),
            food.fridgeId(),
            food.zoneId(),
            food.containerId(),
            food.name(),
            food.category(),
            food.quantity(),
            food.unit(),
            food.productionDate(),
            food.expiresOn(),
            remainingDays,
            remainingDays <= settings.expiringThresholdDays(),
            food.tags(),
            food.modelKey(),
            food.photoUrl(),
            food.createdBy(),
            food.updatedBy(),
            food.version(),
            food.createdAt(),
            food.updatedAt()
        );
    }
}
