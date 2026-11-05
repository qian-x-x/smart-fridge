package com.smartfridge.fridge.cook;

import com.smartfridge.common.api.ErrorCode;
import com.smartfridge.common.error.BusinessException;
import com.smartfridge.fridge.family.FridgeAccessGuard;
import com.smartfridge.fridge.food.FoodRecord;
import com.smartfridge.fridge.food.FoodRepository;
import com.smartfridge.fridge.fridge.FridgeView;
import com.smartfridge.fridge.security.CurrentUser;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;

@Service
public class CookService {

    private final CookRepository cookRepository;
    private final FoodRepository foodRepository;
    private final FridgeAccessGuard accessGuard;
    private final TransactionTemplate transactionTemplate;

    public CookService(
        CookRepository cookRepository,
        FoodRepository foodRepository,
        FridgeAccessGuard accessGuard,
        TransactionTemplate transactionTemplate
    ) {
        this.cookRepository = cookRepository;
        this.foodRepository = foodRepository;
        this.accessGuard = accessGuard;
        this.transactionTemplate = transactionTemplate;
    }

    /**
     * Confirms a cooking session. The client generated request id makes the call
     * idempotent: a replay returns the stored record instead of deducting twice.
     */
    public CookResult cook(
        long fridgeId,
        CurrentUser user,
        String authorization,
        CookRequest request
    ) {
        FridgeView fridge = accessGuard.requireEditor(fridgeId, authorization);

        var replay = cookRepository.findByRequestId(fridgeId, request.requestId());
        if (replay.isPresent()) {
            return new CookResult(replay.get(), false);
        }

        try {
            CookRecordView created = Objects.requireNonNull(
                transactionTemplate.execute(status -> write(fridge, user, request))
            );
            return new CookResult(created, true);
        } catch (DuplicateKeyException duplicate) {
            // A concurrent request with the same id won the unique constraint.
            return cookRepository.findByRequestId(fridgeId, request.requestId())
                .map(record -> new CookResult(record, false))
                .orElseThrow(() -> BusinessException.conflict("重复的做饭请求，请刷新后重试"));
        }
    }

    public List<CookRecordView> history(long fridgeId, Integer limit, String authorization) {
        accessGuard.requireMember(fridgeId, authorization);
        int bounded = limit == null ? 20 : Math.min(Math.max(limit, 1), 50);
        return cookRepository.list(fridgeId, bounded);
    }

    private CookRecordView write(FridgeView fridge, CurrentUser user, CookRequest request) {
        List<FoodRecord> foods = new ArrayList<>(request.items().size());
        Set<Long> seen = new HashSet<>();
        for (CookItemRequest item : request.items()) {
            if (!seen.add(item.foodItemId())) {
                throw validation("扣减清单中存在重复食材");
            }
            FoodRecord food = foodRepository.findRecordById(item.foodItemId())
                .filter(record -> record.fridgeId() == fridge.id())
                .orElseThrow(() -> BusinessException.notFound("食材不存在或已丢弃"));
            if (food.quantity().compareTo(item.quantity()) < 0) {
                throw BusinessException.conflict("「" + food.name() + "」库存不足，请调整扣减数量");
            }
            if (item.version() != null && item.version() != food.version()) {
                throw BusinessException.conflict("「" + food.name() + "」已被其他成员更新，请刷新后重试");
            }
            foods.add(food);
        }

        long cookRecordId = cookRepository.insert(
            fridge.id(),
            request.recipeId(),
            request.recipeName().trim(),
            user.id(),
            request.servings(),
            request.requestId(),
            trimToNull(request.note())
        );

        String operationNote = "做饭：" + request.recipeName().trim();
        for (int index = 0; index < foods.size(); index++) {
            FoodRecord food = foods.get(index);
            CookItemRequest item = request.items().get(index);
            int expectedVersion = item.version() == null ? food.version() : item.version();
            if (!foodRepository.consumeForCook(
                food,
                item.quantity(),
                expectedVersion,
                user.id(),
                operationNote
            )) {
                throw BusinessException.conflict("「" + food.name() + "」库存已变化，请刷新后重试");
            }
            cookRepository.insertItem(
                cookRecordId,
                food.id(),
                food.name(),
                item.quantity(),
                food.unit()
            );
        }

        return cookRepository.findById(cookRecordId, fridge.id())
            .orElseThrow(() -> new IllegalStateException("Cook record was not persisted"));
    }

    private BusinessException validation(String message) {
        return new BusinessException(ErrorCode.VALIDATION_ERROR, HttpStatus.BAD_REQUEST, message);
    }

    private String trimToNull(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return value.trim();
    }
}
