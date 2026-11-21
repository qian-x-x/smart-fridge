/*
 * 这个文件：返回给前端的家庭信息，额外带上「当前用户在这个家庭里是什么角色」。
 */

package com.smartfridge.auth.family;

import java.time.Instant;

public record FamilyView(
    long id,
    String name,
    String inviteCode,
    long ownerUserId,
    String currentUserRole,
    Instant createdAt
) {
}
