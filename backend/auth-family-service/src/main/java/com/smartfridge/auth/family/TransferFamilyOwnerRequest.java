package com.smartfridge.auth.family;

import jakarta.validation.constraints.Positive;

public record TransferFamilyOwnerRequest(
    @Positive(message = "目标用户 ID 必须为正数")
    long targetUserId
) {
}
