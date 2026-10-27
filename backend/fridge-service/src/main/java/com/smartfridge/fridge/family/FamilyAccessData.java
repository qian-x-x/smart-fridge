package com.smartfridge.fridge.family;

public record FamilyAccessData(
    long id,
    String name,
    String currentUserRole
) {
}
