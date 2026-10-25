package com.smartfridge.auth.security;

public record CurrentUser(long id, String username, String platformRole) {
}
