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
