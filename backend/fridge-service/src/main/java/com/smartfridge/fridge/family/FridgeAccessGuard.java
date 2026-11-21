/*
 * 这个文件：所有食材、流水、做饭接口的统一权限闸门。
 * requireMember：必须是这个家庭的成员（OWNER/EDITOR/VIEWER 都行）；
 * requireEditor：在成员的基础上，VIEWER（只读）会被拒绝修改。
 * 统一走这里，保证每个功能的权限提示都一致。
 */

package com.smartfridge.fridge.family;

import com.smartfridge.common.error.BusinessException;
import com.smartfridge.fridge.fridge.FridgeRepository;
import com.smartfridge.fridge.fridge.FridgeView;
import org.springframework.stereotype.Component;

/**
 * Resolves a fridge and enforces the family role required by the caller. Every
 * food, operation and cooking entry point goes through this guard so the role
 * check and the error responses stay identical across features.
 */
@Component
public class FridgeAccessGuard {

    private final FridgeRepository fridgeRepository;
    private final FamilyAccessService familyAccessService;

    public FridgeAccessGuard(FridgeRepository fridgeRepository, FamilyAccessService familyAccessService) {
        this.fridgeRepository = fridgeRepository;
        this.familyAccessService = familyAccessService;
    }

    public FridgeView requireMember(long fridgeId, String authorization) {
        FridgeView fridge = fridgeRepository.findById(fridgeId)
            .orElseThrow(() -> BusinessException.notFound("冰箱不存在"));
        familyAccessService.requireMember(fridge.familyId(), authorization);
        return fridge;
    }

    public FridgeView requireEditor(long fridgeId, String authorization) {
        FridgeView fridge = fridgeRepository.findById(fridgeId)
            .orElseThrow(() -> BusinessException.notFound("冰箱不存在"));
        String role = familyAccessService.requireMember(fridge.familyId(), authorization);
        if ("VIEWER".equals(role)) {
            throw BusinessException.forbidden("只读成员不能修改食材");
        }
        return fridge;
    }
}
