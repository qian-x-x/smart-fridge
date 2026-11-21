/*
 * 这个文件：返回给前端的家庭成员信息（昵称、角色、加入时间等）。
 */

package com.smartfridge.auth.family;

import java.time.Instant;

public record FamilyMemberView(
    long userId,
    String username,
    String displayName,
    String role,
    Instant joinedAt,
    boolean currentUser
) {
}
