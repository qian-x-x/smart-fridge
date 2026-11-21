/*
 * 这个文件：数据库里一行家庭记录：家庭名、邀请码、拥有者、创建时间。
 */

package com.smartfridge.auth.family;

import java.time.Instant;

record FamilyRecord(
    long id,
    String name,
    String inviteCode,
    long ownerUserId,
    Instant createdAt
) {
    FamilyView viewFor(String role) {
        return new FamilyView(id, name, inviteCode, ownerUserId, role, createdAt);
    }
}
