/*
 * 这个文件：权限服务返回的外层包装：{code, data}，和统一返回格式保持一致。
 */

package com.smartfridge.fridge.family;

public record FamilyAccessEnvelope(
    String code,
    String message,
    FamilyAccessData data,
    String traceId
) {
}
