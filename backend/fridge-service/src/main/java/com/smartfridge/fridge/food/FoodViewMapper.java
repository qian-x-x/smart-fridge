package com.smartfridge.fridge.food;

import com.smartfridge.fridge.fridge.FridgeView;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;

/**
 * Adds fridge-local expiry information to a stored food row. Shared by the food
 * endpoints and the operation timeline so both report identical numbers.
 */
@Component
public class FoodViewMapper {

    private final Clock clock;

    public FoodViewMapper(Clock clock) {
        this.clock = clock;
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
            remainingDays <= 3,
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
