/*
 * 这个文件：所有接口统一的返回格式：{code, message, data, traceId}。前端只需要认这一种结构，成功失败都长得一样。
 */

package com.smartfridge.common.api;

import org.slf4j.MDC;

public record ApiResponse<T>(String code, String message, T data, String traceId) {

    public static <T> ApiResponse<T> success(T data) {
        return new ApiResponse<>(ErrorCode.OK.name(), "success", data, currentTraceId());
    }

    public static <T> ApiResponse<T> error(ErrorCode code, String message) {
        return new ApiResponse<>(code.name(), message, null, currentTraceId());
    }

    public static <T> ApiResponse<T> error(String code, String message, T data) {
        return new ApiResponse<>(code, message, data, currentTraceId());
    }

    private static String currentTraceId() {
        String traceId = MDC.get("traceId");
        return traceId == null ? "" : traceId;
    }
}
