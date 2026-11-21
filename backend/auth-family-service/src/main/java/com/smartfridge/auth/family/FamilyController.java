/*
 * 这个文件：家庭相关接口：创建、我的家庭列表、详情、用邀请码加入、成员列表、改角色、移除成员、转交所有权。
 */

package com.smartfridge.auth.family;

import com.smartfridge.auth.security.CurrentUser;
import com.smartfridge.auth.security.JwtAuthInterceptor;
import com.smartfridge.common.api.ApiResponse;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/families")
public class FamilyController {

    private final FamilyService familyService;

    public FamilyController(FamilyService familyService) {
        this.familyService = familyService;
    }

    @PostMapping
    public ResponseEntity<ApiResponse<FamilyView>> create(
        @RequestAttribute(JwtAuthInterceptor.CURRENT_USER_ATTRIBUTE) CurrentUser user,
        @Valid @RequestBody CreateFamilyRequest request
    ) {
        return ResponseEntity.status(HttpStatus.CREATED)
            .body(ApiResponse.success(familyService.create(user.id(), request.name())));
    }

    @GetMapping
    public ApiResponse<List<FamilyView>> list(
        @RequestAttribute(JwtAuthInterceptor.CURRENT_USER_ATTRIBUTE) CurrentUser user
    ) {
        return ApiResponse.success(familyService.list(user.id()));
    }

    @GetMapping("/{familyId}")
    public ApiResponse<FamilyView> get(
        @RequestAttribute(JwtAuthInterceptor.CURRENT_USER_ATTRIBUTE) CurrentUser user,
        @PathVariable long familyId
    ) {
        return ApiResponse.success(familyService.requireMember(user.id(), familyId));
    }
    @PostMapping("/join")
    public ApiResponse<FamilyView> join(
        @RequestAttribute(JwtAuthInterceptor.CURRENT_USER_ATTRIBUTE) CurrentUser user,
        @Valid @RequestBody JoinFamilyRequest request
    ) {
        return ApiResponse.success(familyService.join(user.id(), request.inviteCode()));
    }

    @GetMapping("/{familyId}/members")
    public ApiResponse<List<FamilyMemberView>> members(
        @RequestAttribute(JwtAuthInterceptor.CURRENT_USER_ATTRIBUTE) CurrentUser user,
        @PathVariable long familyId
    ) {
        return ApiResponse.success(familyService.listMembers(user.id(), familyId));
    }

    @PatchMapping("/{familyId}/members/{userId}")
    public ApiResponse<FamilyMemberView> updateMemberRole(
        @RequestAttribute(JwtAuthInterceptor.CURRENT_USER_ATTRIBUTE) CurrentUser user,
        @PathVariable long familyId,
        @PathVariable long userId,
        @Valid @RequestBody UpdateFamilyRoleRequest request
    ) {
        return ApiResponse.success(
            familyService.updateMemberRole(user.id(), familyId, userId, request.role())
        );
    }

    @DeleteMapping("/{familyId}/members/{userId}")
    public ResponseEntity<Void> removeMember(
        @RequestAttribute(JwtAuthInterceptor.CURRENT_USER_ATTRIBUTE) CurrentUser user,
        @PathVariable long familyId,
        @PathVariable long userId
    ) {
        familyService.removeMember(user.id(), familyId, userId);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{familyId}/transfer-owner")
    public ApiResponse<FamilyView> transferOwner(
        @RequestAttribute(JwtAuthInterceptor.CURRENT_USER_ATTRIBUTE) CurrentUser user,
        @PathVariable long familyId,
        @Valid @RequestBody TransferFamilyOwnerRequest request
    ) {
        return ApiResponse.success(
            familyService.transferOwner(user.id(), familyId, request.targetUserId())
        );
    }

}
