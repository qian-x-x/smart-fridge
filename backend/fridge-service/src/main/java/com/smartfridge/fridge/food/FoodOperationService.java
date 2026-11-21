/*
 * 这个文件：撤销和恢复的业务计算。
 * 撤销：把数量、位置、状态全部算回操作之前的样子，同时写一条 UNDO 流水；
 * 恢复：再反向算回去，写一条 RESTORE 流水。
 * 每一步都用版本号 + 数据库锁防止并发冲突。
 */

package com.smartfridge.fridge.food;

import com.smartfridge.common.error.BusinessException;
import com.smartfridge.fridge.family.FridgeAccessGuard;
import com.smartfridge.fridge.fridge.FridgeView;
import com.smartfridge.fridge.security.CurrentUser;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;

@Service
public class FoodOperationService {

    private final FoodRepository foodRepository;
    private final FoodOperationRepository operationRepository;
    private final FridgeAccessGuard accessGuard;
    private final FoodViewMapper foodViewMapper;

    public FoodOperationService(
        FoodRepository foodRepository,
        FoodOperationRepository operationRepository,
        FridgeAccessGuard accessGuard,
        FoodViewMapper foodViewMapper
    ) {
        this.foodRepository = foodRepository;
        this.operationRepository = operationRepository;
        this.accessGuard = accessGuard;
        this.foodViewMapper = foodViewMapper;
    }

    public List<FoodOperationView> timeline(
        long fridgeId,
        Long foodId,
        Integer limit,
        String authorization
    ) {
        FridgeView fridge = accessGuard.requireMember(fridgeId, authorization);
        int bounded = limit == null ? 30 : Math.min(Math.max(limit, 1), 100);
        return operationRepository.timeline(fridgeId, foodId, bounded);
    }

    /**
     * 撤销一次历史操作。
     * 做法：先锁住这条食材行，再根据原操作的类型算出「撤销后应该是什么状态」，
     * 然后写一条 UNDO 流水，最后把原流水标记成「已被这条 UNDO 撤销」。
     * 标记这一步是条件更新，两个成员同时点撤销时只有一个能成功。
     */
    @Transactional
    public FoodView undo(
        long foodId,
        long operationId,
        Integer expectedVersion,
        CurrentUser user,
        String authorization
    ) {
        FoodRecord food = lockFood(foodId);
        FridgeView fridge = accessGuard.requireEditor(food.fridgeId(), authorization);
        FoodOperationRecord operation = requireOperation(food, operationId);
        if (operation.revertedByOperationId() != null) {
            throw BusinessException.conflict("该操作已撤销，如需重做请使用恢复");
        }
        if (!FoodOperationRepository.UNDOABLE_ACTIONS.contains(operation.action())) {
            throw BusinessException.conflict("该操作不支持撤销");
        }
        requireVersion(food, expectedVersion);

        // 按原操作类型反推目标状态：
        // MOVE 挪回原位置；CONSUME/COOK 把吃掉的加回去；DISCARD 重新置为启用并恢复数量。
        Target target = switch (operation.action()) {
            case "MOVE" -> new Target(
                food.status(),
                food.quantity(),
                operation.oldZoneId() == null ? food.zoneId() : operation.oldZoneId(),
                operation.oldContainerId()
            );
            case "CONSUME", "COOK" -> new Target(
                food.status(),
                food.quantity().add(consumedQuantity(operation)),
                food.zoneId(),
                food.containerId()
            );
            case "DISCARD" -> new Target(
                "ACTIVE",
                operation.oldQuantity() == null ? food.quantity() : operation.oldQuantity(),
                food.zoneId(),
                food.containerId()
            );
            default -> throw BusinessException.conflict("该操作不支持撤销");
        };

        apply(food, target, user.id());
        long undoId = operationRepository.insertOperation(
            food.fridgeId(),
            food.id(),
            user.id(),
            "UNDO",
            food.zoneId(),
            food.containerId(),
            food.quantity(),
            target.zoneId(),
            target.containerId(),
            target.quantity(),
            "撤销" + label(operation.action()),
            operation.id()
        );
        if (!operationRepository.markUndone(operation.id(), undoId)) {
            throw BusinessException.conflict("该操作已被其他成员撤销，请刷新后重试");
        }
        return currentView(foodId, fridge);
    }

    /**
     * 恢复一次「已撤销」的操作，相当于把撤销再撤销。
     * 前提是这条记录确实被撤销过，而且食材还处在启用状态。
     */
    @Transactional
    public FoodView restore(
        long foodId,
        long operationId,
        Integer expectedVersion,
        CurrentUser user,
        String authorization
    ) {
        FoodRecord food = lockFood(foodId);
        FridgeView fridge = accessGuard.requireEditor(food.fridgeId(), authorization);
        FoodOperationRecord operation = requireOperation(food, operationId);
        if (operation.revertedByOperationId() == null) {
            throw BusinessException.conflict("该操作尚未撤销，无需恢复");
        }
        FoodOperationRecord undoRecord = operationRepository.findById(operation.revertedByOperationId())
            .orElseThrow(() -> BusinessException.conflict("撤销记录缺失，无法恢复"));
        if (undoRecord.originalOperationId() == null || undoRecord.originalOperationId() != operation.id()) {
            throw BusinessException.conflict("撤销记录与操作不匹配，无法恢复");
        }
        if (!"ACTIVE".equals(food.status())) {
            throw BusinessException.conflict("食材已不在启用状态，无法恢复该操作");
        }
        requireVersion(food, expectedVersion);

        Target target = switch (operation.action()) {
            case "MOVE" -> new Target(
                food.status(),
                food.quantity(),
                operation.newZoneId() == null ? food.zoneId() : operation.newZoneId(),
                operation.newContainerId()
            );
            case "CONSUME", "COOK" -> {
                BigDecimal restored = food.quantity().subtract(consumedQuantity(operation));
                if (restored.signum() < 0) {
                    throw BusinessException.conflict("当前数量不足以恢复该操作，请先补充库存");
                }
                yield new Target(food.status(), restored, food.zoneId(), food.containerId());
            }
            case "DISCARD" -> new Target("DISCARDED", BigDecimal.ZERO, food.zoneId(), food.containerId());
            default -> throw BusinessException.conflict("该操作不支持恢复");
        };

        apply(food, target, user.id());
        operationRepository.insertOperation(
            food.fridgeId(),
            food.id(),
            user.id(),
            "RESTORE",
            food.zoneId(),
            food.containerId(),
            food.quantity(),
            target.zoneId(),
            target.containerId(),
            target.quantity(),
            "恢复" + label(operation.action()),
            operation.id()
        );
        if (!operationRepository.clearReversion(operation.id(), undoRecord.id())) {
            throw BusinessException.conflict("该操作已被其他成员恢复，请刷新后重试");
        }
        return currentView(foodId, fridge);
    }

    private void apply(FoodRecord food, Target target, long userId) {
        boolean applied = foodRepository.applyState(
            food,
            target.status(),
            target.quantity(),
            target.zoneId(),
            target.containerId(),
            userId
        );
        if (!applied) {
            throw BusinessException.conflict("食材已被其他成员更新，请刷新后重试");
        }
    }

    private FoodView currentView(long foodId, FridgeView fridge) {
        return foodRepository.lockRecordById(foodId)
            .map(record -> foodViewMapper.withExpiry(foodRepository.viewOf(record), fridge))
            .orElseThrow(() -> BusinessException.notFound("食材不存在"));
    }

    private FoodRecord lockFood(long foodId) {
        return foodRepository.lockRecordById(foodId)
            .orElseThrow(() -> BusinessException.notFound("食材不存在"));
    }

    private FoodOperationRecord requireOperation(FoodRecord food, long operationId) {
        return operationRepository.findOperation(operationId, food.fridgeId())
            .filter(operation -> operation.foodItemId() == food.id())
            .orElseThrow(() -> BusinessException.notFound("操作记录不存在"));
    }

    private void requireVersion(FoodRecord food, Integer expectedVersion) {
        if (expectedVersion != null && expectedVersion != food.version()) {
            throw BusinessException.conflict("食材已被其他成员更新，请刷新后重试");
        }
    }

    private BigDecimal consumedQuantity(FoodOperationRecord operation) {
        if (operation.oldQuantity() == null || operation.newQuantity() == null) {
            return BigDecimal.ZERO;
        }
        return operation.oldQuantity().subtract(operation.newQuantity());
    }


    private String label(String action) {
        return switch (action) {
            case "MOVE" -> "移动";
            case "CONSUME" -> "使用";
            case "COOK" -> "做饭扣减";
            case "DISCARD" -> "丢弃";
            default -> action;
        };
    }

    private record Target(String status, BigDecimal quantity, long zoneId, Long containerId) {
    }
}
