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
