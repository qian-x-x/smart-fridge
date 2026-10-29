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
