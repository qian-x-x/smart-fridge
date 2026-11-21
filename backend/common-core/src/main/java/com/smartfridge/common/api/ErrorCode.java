/*
 * 这个文件：全系统的错误码清单（参数错误、未登录、无权限、找不到、冲突、限流、服务器错误等），返回体和异常里都用这里的枚举。
 */

package com.smartfridge.common.api;

public enum ErrorCode {
    OK,
    VALIDATION_ERROR,
    UNAUTHORIZED,
    FORBIDDEN,
    NOT_FOUND,
    CONFLICT,
    TOO_MANY_REQUESTS,
    INTERNAL_ERROR
}
