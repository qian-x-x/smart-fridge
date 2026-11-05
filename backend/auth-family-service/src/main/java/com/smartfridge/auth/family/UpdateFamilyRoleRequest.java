package com.smartfridge.auth.family;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record UpdateFamilyRoleRequest(
    @NotBlank(message = "成员角色不能为空")
    @Pattern(regexp = "OWNER|EDITOR|VIEWER", message = "无效的家庭成员角色")
    String role
) {
}
