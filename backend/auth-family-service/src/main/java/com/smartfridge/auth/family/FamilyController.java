package com.smartfridge.auth.family;

import com.smartfridge.auth.security.CurrentUser;
import com.smartfridge.auth.security.JwtAuthInterceptor;
import com.smartfridge.common.api.ApiResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

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
}
