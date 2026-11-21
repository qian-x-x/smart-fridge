/*
 * 这个文件：健康检查接口返回的服务信息（服务名、状态等）。
 */

package com.smartfridge.common.api;

public record ServiceInfo(String service, String status, String stage) {
}
