package com.smartfridge.common.error;

import com.smartfridge.common.api.ApiResponse;
import com.smartfridge.common.api.ErrorCode;
import com.smartfridge.common.api.FieldViolation;
import jakarta.validation.ConstraintViolationException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.beans.TypeMismatchException;
import org.springframework.web.bind.ServletRequestBindingException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.HttpMediaTypeNotAcceptableException;
import org.springframework.web.ErrorResponse;
import org.springframework.web.servlet.NoHandlerFoundException;
import org.springframework.web.servlet.resource.NoResourceFoundException;
import org.springframework.validation.BindException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.List;

@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ApiResponse<Void>> handleBusinessException(BusinessException exception) {
        return ResponseEntity.status(exception.getStatus())
            .body(ApiResponse.error(exception.getErrorCode(), exception.getMessage()));
    }

    @ExceptionHandler({MethodArgumentNotValidException.class, BindException.class})
    public ResponseEntity<ApiResponse<List<FieldViolation>>> handleBindingException(BindException exception) {
        List<FieldViolation> violations = exception.getBindingResult().getFieldErrors().stream()
            .map(error -> new FieldViolation(error.getField(), error.getDefaultMessage()))
            .toList();
        return ResponseEntity.badRequest()
            .body(ApiResponse.error(ErrorCode.VALIDATION_ERROR.name(), "请求参数校验失败", violations));
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ApiResponse<List<FieldViolation>>> handleConstraintViolation(
        ConstraintViolationException exception
    ) {
        List<FieldViolation> violations = exception.getConstraintViolations().stream()
            .map(error -> new FieldViolation(error.getPropertyPath().toString(), error.getMessage()))
            .toList();
        return ResponseEntity.badRequest()
            .body(ApiResponse.error(ErrorCode.VALIDATION_ERROR.name(), "请求参数校验失败", violations));
    }

    @ExceptionHandler({HttpMessageNotReadableException.class, TypeMismatchException.class,
        ServletRequestBindingException.class})
    public ResponseEntity<ApiResponse<Void>> handleInvalidRequest(Exception exception) {
        return ResponseEntity.badRequest()
            .body(ApiResponse.error(ErrorCode.VALIDATION_ERROR, "请求参数格式不正确或缺少必填参数"));
    }

    @ExceptionHandler({HttpRequestMethodNotSupportedException.class, HttpMediaTypeNotSupportedException.class,
        HttpMediaTypeNotAcceptableException.class, NoHandlerFoundException.class, NoResourceFoundException.class})
    public ResponseEntity<ApiResponse<Void>> handleHttpError(Exception exception) {
        ErrorResponse error = (ErrorResponse) exception;
        boolean notFound = error.getStatusCode().value() == 404;
        return ResponseEntity.status(error.getStatusCode()).headers(error.getHeaders())
            .body(ApiResponse.error(notFound ? ErrorCode.NOT_FOUND : ErrorCode.VALIDATION_ERROR,
                notFound ? "接口不存在" : "请求方法或媒体类型不受支持"));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Void>> handleUnexpectedException(Exception exception) {
        log.error("Unhandled request failure", exception);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(ApiResponse.error(ErrorCode.INTERNAL_ERROR, "服务暂时不可用"));
    }
}
