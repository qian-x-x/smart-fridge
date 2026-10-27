package com.smartfridge.fridge.family;

public record FamilyAccessEnvelope(
    String code,
    String message,
    FamilyAccessData data,
    String traceId
) {
}
