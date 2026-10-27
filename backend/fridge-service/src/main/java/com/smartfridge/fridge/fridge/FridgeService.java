package com.smartfridge.fridge.fridge;

import com.smartfridge.common.error.BusinessException;
import com.smartfridge.fridge.family.FamilyAccessService;
import com.smartfridge.fridge.security.CurrentUser;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class FridgeService {

    private final FridgeRepository repository;
    private final FamilyAccessService familyAccessService;

    public FridgeService(FridgeRepository repository, FamilyAccessService familyAccessService) {
        this.repository = repository;
        this.familyAccessService = familyAccessService;
    }

    @Transactional
    public FridgeView create(CurrentUser user, String authorization, CreateFridgeRequest request) {
        String role = familyAccessService.requireMember(request.familyId(), authorization);
        if (!"OWNER".equals(role)) {
            throw BusinessException.forbidden("仅家庭拥有者可以创建和配置冰箱");
        }
        if (repository.findOwnedFridgeForFamily(request.familyId()).isPresent()) {
            throw BusinessException.conflict("该家庭已经创建冰箱");
        }
        try {
            return repository.create(request.familyId(), request.name().trim());
        } catch (DataIntegrityViolationException exception) {
            throw BusinessException.conflict("该家庭已经创建冰箱");
        }
    }

    public FridgeView get(long fridgeId, String authorization) {
        FridgeView fridge = repository.findById(fridgeId)
            .orElseThrow(() -> BusinessException.notFound("冰箱不存在"));
        familyAccessService.requireMember(fridge.familyId(), authorization);
        return fridge;
    }

    public FridgeView getByFamily(long familyId, String authorization) {
        familyAccessService.requireMember(familyId, authorization);
        return repository.findOwnedFridgeForFamily(familyId)
            .orElseThrow(() -> BusinessException.notFound("该家庭尚未创建冰箱"));
    }
}
