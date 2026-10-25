package com.smartfridge.auth.user;

public record UserAccount(
    long id,
    String username,
    String phone,
    String passwordHash,
    String displayName,
    String platformRole,
    String status
) {
}
