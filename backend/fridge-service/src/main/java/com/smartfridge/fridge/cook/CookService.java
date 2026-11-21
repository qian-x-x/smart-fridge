/*
 * 这个文件：做饭的核心逻辑。做之前先检查：食材属于这个冰箱、没过期、数量够、版本没被别人改过；
 * 检查通过后，扣库存和写记录在同一个事务里完成；
 * 同一个 requestId 重复提交不会扣两次，直接返回第一次的结果。
 */

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

import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
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
    private final Clock clock;

    public CookService(
        CookRepository cookRepository,
        FoodRepository foodRepository,
        FridgeAccessGuard accessGuard,
        TransactionTemplate transactionTemplate,
        Clock clock
    ) {
        this.cookRepository = cookRepository;
        this.foodRepository = foodRepository;
        this.accessGuard = accessGuard;
        this.transactionTemplate = transactionTemplate;
        this.clock = clock;
    }

    /**
     * 确认一次做饭。
     * 入口先查这个 requestId 是不是已经做过（客户端网络重试会重复发）：
     * 做过就直接返回旧记录，不再扣第二次库存。
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
            return replay(replay.get(), user, request);
        }

        try {
            CookRecordView created = Objects.requireNonNull(
                transactionTemplate.execute(status -> write(fridge, user, request))
            );
            return new CookResult(created, true);
        } catch (DuplicateKeyException duplicate) {
            // A concurrent request with the same id won the unique constraint.
            return cookRepository.findByRequestId(fridgeId, request.requestId())
                .map(record -> replay(record, user, request))
                .orElseThrow(() -> BusinessException.conflict("重复的做饭请求，请刷新后重试"));
        }
    }

    public List<CookRecordView> history(long fridgeId, Integer limit, String authorization) {
        accessGuard.requireMember(fridgeId, authorization);
        int bounded = limit == null ? 20 : Math.min(Math.max(limit, 1), 50);
        return cookRepository.list(fridgeId, bounded);
    }

    /**
     * 真正落库的一步，整体在一个事务里：
     * 1) 先占住 requestId（唯一索引保证并发下只有一个人能占成功）；
     * 2) 逐条检查食材：属于本冰箱、没过期、数量够、版本没被别人改；
     * 3) 全部检查通过后才逐个扣减，并记录每条食材扣了多少。
     */
    private CookRecordView write(FridgeView fridge, CurrentUser user, CookRequest request) {
        // Reserve the request before checking versions. A concurrent replay may
        // see stock already deducted, but still gets the original record.
        long cookRecordId = cookRepository.insert(
            fridge.id(), request.recipeId(), request.recipeName().trim(), user.id(),
            request.servings(), request.requestId(), trimToNull(request.note())
        );

        LocalDate today = LocalDate.now(clock.withZone(ZoneId.of(fridge.timezone())));
        List<FoodRecord> foods = new ArrayList<>(request.items().size());
        Set<String> portionNames = new HashSet<>();
        Set<Long> seen = new HashSet<>();
        for (CookItemRequest item : request.items()) {
            if (!seen.add(item.foodItemId())) {
                throw validation("扣减清单中存在重复食材");
            }
            FoodRecord food = foodRepository.findRecordById(item.foodItemId())
                .filter(record -> record.fridgeId() == fridge.id())
                .orElseThrow(() -> BusinessException.notFound("食材不存在或已丢弃"));
            if (food.expiresOn().isBefore(today)) {
                throw BusinessException.conflict("「" + food.name() + "」已过期，不能用于制作");
            }
            if (FoodRecord.isStickerModel(food.modelKey()) &&
                (item.quantity().compareTo(BigDecimal.ONE) != 0 || !portionNames.add(food.name()))) {
                throw validation("每道菜对同一种食材只扣减一份");
            }
            if (food.quantity().compareTo(item.quantity()) < 0) {
                throw BusinessException.conflict("「" + food.name() + "」库存不足，请调整扣减数量");
            }
            if (item.version() != null && item.version() != food.version()) {
                throw BusinessException.conflict("「" + food.name() + "」已被其他成员更新，请刷新后重试");
            }
            foods.add(food);
        }

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

    /**
     * 重放校验：同一个 requestId 再次请求时，内容必须和第一次完全一致才返回旧结果，
     * 否则说明这个编号被拿去下了一单不同的菜，直接报冲突。
     */
    private CookResult replay(CookRecordView record, CurrentUser user, CookRequest request) {
        if (record.actorUserId() != user.id() ||
            record.recipeId() != request.recipeId() ||
            !record.recipeName().equals(request.recipeName().trim()) ||
            record.servings() != request.servings() ||
            !Objects.equals(record.note(), trimToNull(request.note())) ||
            record.items().size() != request.items().size()) {
            throw BusinessException.conflict("这次制作的请求标识已被使用");
        }
        for (int index = 0; index < record.items().size(); index++) {
            var saved = record.items().get(index);
            var sent = request.items().get(index);
            if (saved.foodItemId() != sent.foodItemId() ||
                saved.quantity().compareTo(sent.quantity()) != 0) {
                throw BusinessException.conflict("这次制作的请求标识已被使用");
            }
        }
        return new CookResult(record, false);
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
