package com.smartfridge.auth.family;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record JoinFamilyRequest(
    @NotBlank(message = "邀请码不能为空")
    @Pattern(regexp = "^[A-Za-z0-9]{8}$", message = "邀请码应为 8 位字母或数字")
    String inviteCode
) {
    public JoinFamilyRequest {
        inviteCode = inviteCode == null ? null : inviteCode.trim();
    }
}
