package com.smartfridge.auth.family;

import jakarta.validation.constraints.NotBlank;

public record UpdateFamilyRoleRequest(
    @NotBlank(message = "成员角色不能为空")
    String role
) {
}
