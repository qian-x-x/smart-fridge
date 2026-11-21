/*
 * 这个文件：业务异常。和系统崩溃不同，它代表「用户操作不合法」这类可预期的错误，
 * 自带错误码和 HTTP 状态码。conflict()、forbidden()、notFound() 这些静态方法是为了少写样板代码。
 */

package com.smartfridge.common.error;

import com.smartfridge.common.api.ErrorCode;
import org.springframework.http.HttpStatus;

public class BusinessException extends RuntimeException {

    private final ErrorCode errorCode;
    private final HttpStatus status;

    public BusinessException(ErrorCode errorCode, HttpStatus status, String message) {
        super(message);
        this.errorCode = errorCode;
        this.status = status;
    }

    public ErrorCode getErrorCode() {
        return errorCode;
    }

    public HttpStatus getStatus() {
        return status;
    }

    public static BusinessException conflict(String message) {
        return new BusinessException(ErrorCode.CONFLICT, HttpStatus.CONFLICT, message);
    }

    public static BusinessException unauthorized(String message) {
        return new BusinessException(ErrorCode.UNAUTHORIZED, HttpStatus.UNAUTHORIZED, message);
    }

    public static BusinessException forbidden(String message) {
        return new BusinessException(ErrorCode.FORBIDDEN, HttpStatus.FORBIDDEN, message);
    }

    public static BusinessException notFound(String message) {
        return new BusinessException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND, message);
    }
}
