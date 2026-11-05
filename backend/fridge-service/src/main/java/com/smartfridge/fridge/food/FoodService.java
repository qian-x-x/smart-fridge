package com.smartfridge.fridge.food;

import com.smartfridge.common.error.BusinessException;
import com.smartfridge.fridge.family.FamilyAccessService;
import com.smartfridge.fridge.fridge.FridgeRepository;
import com.smartfridge.fridge.fridge.FridgeView;
import com.smartfridge.fridge.security.CurrentUser;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.List;

@Service
public class FoodService {

    private final FoodRepository foodRepository;
    private final FridgeRepository fridgeRepository;
    private final FamilyAccessService familyAccessService;
    private final Clock clock;

    public FoodService(
        FoodRepository foodRepository,
        FridgeRepository fridgeRepository,
        FamilyAccessService familyAccessService,
        Clock clock
    ) {
        this.foodRepository = foodRepository;
        this.fridgeRepository = fridgeRepository;
        this.familyAccessService = familyAccessService;
        this.clock = clock;
    }

    @Transactional
    public FoodView create(CurrentUser user, String authorization, CreateFoodRequest request) {
        FridgeView fridge = fridgeRepository.findById(request.fridgeId())
            .orElseThrow(() -> BusinessException.notFound("冰箱不存在"));
        String role = familyAccessService.requireMember(fridge.familyId(), authorization);
        if ("VIEWER".equals(role)) {
            throw BusinessException.forbidden("只读成员不能修改食材");
        }
        validateLocation(request);
        validateDates(request);
        validateTags(request.tags());
        return expiryAware(foodRepository.create(request, user.id()), fridge);
    }

    public FoodView get(long foodId, String authorization) {
        FoodView food = foodRepository.findById(foodId)
            .orElseThrow(() -> BusinessException.notFound("食材不存在"));
        FridgeView fridge = fridgeRepository.findById(food.fridgeId())
            .orElseThrow(() -> BusinessException.notFound("冰箱不存在"));
        familyAccessService.requireMember(fridge.familyId(), authorization);
        return expiryAware(food, fridge);
    }

    public List<FoodView> search(long fridgeId, FoodSearchFilter filter, String authorization) {
        FridgeView fridge = fridgeRepository.findById(fridgeId)
            .orElseThrow(() -> BusinessException.notFound("冰箱不存在"));
        familyAccessService.requireMember(fridge.familyId(), authorization);
        LocalDate today = LocalDate.now(clock.withZone(ZoneId.of(fridge.timezone())));
        return foodRepository.search(fridgeId, filter, today).stream()
            .map(food -> expiryAware(food, fridge))
            .toList();
    }

    @Transactional
    public FoodView move(
        long foodId,
        CurrentUser user,
        String authorization,
        MoveFoodRequest request
    ) {
        FoodRecord food = foodRepository.findRecordById(foodId)
            .orElseThrow(() -> BusinessException.notFound("食材不存在"));
        FridgeView fridge = requireEditor(food.fridgeId(), authorization);
        if (!foodRepository.zoneBelongsToFridge(request.zoneId(), food.fridgeId())) {
            throw BusinessException.conflict("目标区域不属于该冰箱");
        }
        if (!foodRepository.containerBelongsToZone(request.containerId(), request.zoneId())) {
            throw BusinessException.conflict("储物容器不属于该区域");
        }
        if (!foodRepository.move(food, request.zoneId(), request.containerId(), request.version(), user.id())) {
            throw BusinessException.conflict("食材已被其他成员更新，请刷新后重试");
        }
        return expiryAware(foodRepository.requireById(foodId), fridge);
    }

    @Transactional
    public FoodView consume(
        long foodId,
        CurrentUser user,
        String authorization,
        ConsumeFoodRequest request
    ) {
        FoodRecord food = foodRepository.findRecordById(foodId)
            .orElseThrow(() -> BusinessException.notFound("食材不存在"));
        FridgeView fridge = requireEditor(food.fridgeId(), authorization);
        if (food.quantity().compareTo(request.quantity()) < 0) {
            throw BusinessException.conflict("使用数量不能超过剩余数量");
        }
        if (!foodRepository.consume(food, request.quantity(), request.version(), user.id())) {
            throw BusinessException.conflict("食材已被其他成员更新，请刷新后重试");
        }
        return expiryAware(foodRepository.requireById(foodId), fridge);
    }

    @Transactional
    public FoodView update(
        long foodId,
        CurrentUser user,
        String authorization,
        UpdateFoodRequest request
    ) {
        FoodRecord food = foodRepository.findRecordById(foodId)
            .orElseThrow(() -> BusinessException.notFound("食材不存在"));
        FridgeView fridge = requireEditor(food.fridgeId(), authorization);
        if (!foodRepository.zoneBelongsToFridge(request.zoneId(), food.fridgeId())) {
            throw BusinessException.conflict("目标区域不属于该冰箱");
        }
        if (!foodRepository.containerBelongsToZone(request.containerId(), request.zoneId())) {
            throw BusinessException.conflict("储物容器不属于该区域");
        }
        if (request.expiresOn().isBefore(request.productionDate())) {
            throw BusinessException.conflict("到期日期不能早于生产日期");
        }
        validateTags(request.tags());
        if (!foodRepository.update(food, request, user.id())) {
            throw BusinessException.conflict("食材已被其他成员更新，请刷新后重试");
        }
        return expiryAware(foodRepository.requireById(foodId), fridge);
    }

    @Transactional
    public void discard(
        long foodId,
        CurrentUser user,
        String authorization,
        int version
    ) {
        FoodRecord food = foodRepository.findRecordById(foodId)
            .orElseThrow(() -> BusinessException.notFound("食材不存在"));
        requireEditor(food.fridgeId(), authorization);
        if (!foodRepository.discard(food, version, user.id())) {
            throw BusinessException.conflict("食材已被其他成员更新，请刷新后重试");
        }
    }

    private FridgeView requireEditor(long fridgeId, String authorization) {
        FridgeView fridge = fridgeRepository.findById(fridgeId)
            .orElseThrow(() -> BusinessException.notFound("冰箱不存在"));
        String role = familyAccessService.requireMember(fridge.familyId(), authorization);
        if ("VIEWER".equals(role)) {
            throw BusinessException.forbidden("只读成员不能修改食材");
        }
        return fridge;
    }

    private void validateLocation(CreateFoodRequest request) {
        if (!foodRepository.zoneBelongsToFridge(request.zoneId(), request.fridgeId())) {
            throw BusinessException.conflict("存放区域不属于该冰箱");
        }
        if (!foodRepository.containerBelongsToZone(request.containerId(), request.zoneId())) {
            throw BusinessException.conflict("储物容器不属于该区域");
        }
    }

    private void validateDates(CreateFoodRequest request) {
        if (request.expiresOn().isBefore(request.productionDate())) {
            throw BusinessException.conflict("到期日期不能早于生产日期");
        }
    }

    private void validateTags(List<String> tags) {
        if (tags != null && tags.stream().map(String::trim).distinct()
            .collect(java.util.stream.Collectors.joining(",")).length() > 500) {
            throw new com.smartfridge.common.error.BusinessException(
                com.smartfridge.common.api.ErrorCode.VALIDATION_ERROR,
                org.springframework.http.HttpStatus.BAD_REQUEST,
                "标签总长度不能超过 500 个字符"
            );
        }
    }

    private FoodView expiryAware(FoodView food, FridgeView fridge) {
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
