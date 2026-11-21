/*
 * 这个文件：转交家庭所有权的请求体：把家交给哪个成员。
 */

package com.smartfridge.auth.family;

import jakarta.validation.constraints.Positive;

public record TransferFamilyOwnerRequest(
    @Positive(message = "目标用户 ID 必须为正数")
    long targetUserId
) {
}
