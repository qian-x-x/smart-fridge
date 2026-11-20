package com.smartfridge.fridge.food;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.smartfridge.common.api.ErrorCode;
import com.smartfridge.common.error.BusinessException;
import com.smartfridge.fridge.family.FridgeAccessGuard;
import com.smartfridge.fridge.fridge.FridgeView;
import com.smartfridge.fridge.security.CurrentUser;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

import java.math.BigDecimal;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.HashSet;
import java.util.HexFormat;
import java.util.List;
import java.util.Objects;

@Service
public class FoodService {

    private final FoodRepository foodRepository;
    private final FridgeAccessGuard accessGuard;
    private final FoodViewMapper foodViewMapper;
    private final Clock clock;
    private final TransactionTemplate transactionTemplate;
    private final ObjectMapper objectMapper;

    public FoodService(
        FoodRepository foodRepository,
        FridgeAccessGuard accessGuard,
        FoodViewMapper foodViewMapper,
        Clock clock,
        TransactionTemplate transactionTemplate,
        ObjectMapper objectMapper
    ) {
        this.foodRepository = foodRepository;
        this.accessGuard = accessGuard;
        this.foodViewMapper = foodViewMapper;
        this.clock = clock;
        this.transactionTemplate = transactionTemplate;
        this.objectMapper = objectMapper;
    }

    @Transactional
    public FoodView create(CurrentUser user, String authorization, CreateFoodRequest request) {
        FridgeView fridge = accessGuard.requireEditor(request.fridgeId(), authorization);
        validateLocation(request);
        validateDates(request);
        validateTags(request.tags());
        if (FoodRecord.isStickerModel(request.modelKey())) {
            validateCatalogQuantity(request.unit(), request.quantity());
        }
        return foodViewMapper.withExpiry(foodRepository.create(request, user.id()), fridge);
    }

    public CatalogBatchResult createCatalogBatch(CurrentUser user, String authorization, CatalogFoodBatchRequest request) {
        FridgeView fridge = accessGuard.requireEditor(request.fridgeId(), authorization);
        String hash = catalogPayloadHash(request.items());
        var existing = foodRepository.findCatalogBatch(fridge.id(), user.id(), request.requestId());
        if (existing.isPresent()) {
            return catalogReplay(existing.get(), hash);
        }

        try {
            return Objects.requireNonNull(transactionTemplate.execute(status -> {
                foodRepository.insertCatalogBatch(fridge.id(), user.id(), request.requestId(), hash, request.items().size());
                var names = new HashSet<String>();
                LocalDate today = LocalDate.now(clock.withZone(ZoneId.of(fridge.timezone())));
                for (var item : request.items()) {
                    String name = item.name().trim();
                    String category = item.category().trim();
                    if (!names.add(name)) {
                        throw validation("同一种食材只能勾选一次");
                    }
                    var zone = fridge.zones().stream().filter(value -> value.id() == item.zoneId()).findFirst()
                        .orElseThrow(() -> BusinessException.conflict("存放区域不属于该冰箱"));
                    Long container = zone.containers().isEmpty() ? null : zone.containers().get(0).id();
                    int reminderDays = switch (zone.code()) {
                        case "FREEZER" -> 30;
                        case "VARIABLE" -> "肉类".equals(category) || "海鲜".equals(category) ? 1 : 7;
                        default -> 7;
                    };
                    foodRepository.create(new CreateFoodRequest(
                        fridge.id(), zone.id(), container, name, category, item.portions(),
                        "份", today, today.plusDays(reminderDays), List.of(), "sticker:" + name, null
                    ), user.id());
                }
                return new CatalogBatchResult(request.items().size(), true);
            }));
        } catch (DuplicateKeyException duplicate) {
            return foodRepository.findCatalogBatch(fridge.id(), user.id(), request.requestId())
                .map(batch -> catalogReplay(batch, hash))
                .orElseThrow(() -> duplicate);
        }
    }

    private CatalogBatchResult catalogReplay(FoodRepository.CatalogBatch batch, String hash) {
        if (!batch.payloadHash().equals(hash)) {
            throw BusinessException.conflict("这批食材的请求标识已被使用");
        }
        return new CatalogBatchResult(batch.itemCount(), false);
    }

    private String catalogPayloadHash(List<CatalogFoodBatchRequest.Item> items) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(objectMapper.writeValueAsBytes(items)));
        } catch (JsonProcessingException | NoSuchAlgorithmException error) {
            throw new IllegalStateException("Unable to identify the catalog batch", error);
        }
    }

    public record CatalogBatchResult(int added, boolean created) {}

    public FoodView get(long foodId, String authorization) {
        FoodView food = foodRepository.findById(foodId)
            .orElseThrow(() -> BusinessException.notFound("食材不存在"));
        FridgeView fridge = accessGuard.requireMember(food.fridgeId(), authorization);
        return foodViewMapper.withExpiry(food, fridge);
    }

    public List<FoodView> search(long fridgeId, FoodSearchFilter filter, String authorization) {
        FridgeView fridge = accessGuard.requireMember(fridgeId, authorization);
        LocalDate today = LocalDate.now(clock.withZone(ZoneId.of(fridge.timezone())));
        return foodRepository.search(fridgeId, filter, today).stream()
            .map(food -> foodViewMapper.withExpiry(food, fridge))
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
        FridgeView fridge = accessGuard.requireEditor(food.fridgeId(), authorization);
        if (!foodRepository.zoneBelongsToFridge(request.zoneId(), food.fridgeId())) {
            throw BusinessException.conflict("目标区域不属于该冰箱");
        }
        if (!foodRepository.containerBelongsToZone(request.containerId(), request.zoneId())) {
            throw BusinessException.conflict("储物容器不属于该区域");
        }
        if (!foodRepository.move(food, request.zoneId(), request.containerId(), request.version(), user.id())) {
            throw BusinessException.conflict("食材已被其他成员更新，请刷新后重试");
        }
        return foodViewMapper.withExpiry(foodRepository.requireById(foodId), fridge);
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
        FridgeView fridge = accessGuard.requireEditor(food.fridgeId(), authorization);
        if (FoodRecord.isStickerModel(food.modelKey())) {
            validateCatalogQuantity(food.unit(), request.quantity());
        }
        if (food.quantity().compareTo(request.quantity()) < 0) {
            throw BusinessException.conflict("使用数量不能超过剩余数量");
        }
        if (!foodRepository.consume(food, request.quantity(), request.version(), user.id())) {
            throw BusinessException.conflict("食材已被其他成员更新，请刷新后重试");
        }
        return foodViewMapper.withExpiry(foodRepository.requireById(foodId), fridge);
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
        FridgeView fridge = accessGuard.requireEditor(food.fridgeId(), authorization);
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
        if (FoodRecord.isStickerModel(food.modelKey()) || FoodRecord.isStickerModel(request.modelKey())) {
            validateCatalogQuantity(request.unit(), request.quantity());
            if (FoodRecord.isStickerModel(food.modelKey()) && (!Objects.equals(food.modelKey(), request.modelKey()) ||
                !food.name().equals(request.name().trim()) || !food.category().equals(request.category().trim()))) {
                throw validation("贴纸食材的名称和分类不能修改");
            }
        }
        if (!foodRepository.update(food, request, user.id())) {
            throw BusinessException.conflict("食材已被其他成员更新，请刷新后重试");
        }
        return foodViewMapper.withExpiry(foodRepository.requireById(foodId), fridge);
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
        accessGuard.requireEditor(food.fridgeId(), authorization);
        if (!foodRepository.discard(food, version, user.id(), null)) {
            throw BusinessException.conflict("食材已被其他成员更新，请刷新后重试");
        }
    }

    /**
     * Discards every active food item that is already past its expiry date.
     * Expiry is evaluated in the fridge timezone with the server clock, so a
     * client with a wrong clock cannot wipe fresh stock. Each row keeps its own
     * DISCARD record, which makes the cleanup reversible one item at a time.
     */
    @Transactional
    public ExpiredCleanupView discardExpired(
        long fridgeId,
        CurrentUser user,
        String authorization
    ) {
        FridgeView fridge = accessGuard.requireEditor(fridgeId, authorization);
        LocalDate today = LocalDate.now(clock.withZone(ZoneId.of(fridge.timezone())));
        List<FoodRecord> expired = foodRepository.findExpired(fridgeId, today);
        List<FoodView> discarded = new java.util.ArrayList<>(expired.size());
        for (FoodRecord food : expired) {
            // Snapshot the view before the row is soft deleted: the item is no
            // longer ACTIVE afterwards, so it can no longer be read back.
            FoodView snapshot = foodViewMapper.withExpiry(foodRepository.viewOf(food), fridge);
            // Version comes from the row we just read, so the only way this
            // misses is a concurrent write to the same item; that item is then
            // skipped instead of failing the whole batch.
            if (foodRepository.discard(food, food.version(), user.id(), "过期清理")) {
                discarded.add(snapshot);
            }
        }
        return new ExpiredCleanupView(discarded.size(), expired.size() - discarded.size(), discarded);
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

    private void validateCatalogQuantity(String unit, BigDecimal quantity) {
        if (!"份".equals(unit.trim()) || quantity.stripTrailingZeros().scale() > 0) {
            throw validation("贴纸食材以整份为单位");
        }
    }

    private BusinessException validation(String message) {
        return new BusinessException(ErrorCode.VALIDATION_ERROR, HttpStatus.BAD_REQUEST, message);
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

}
