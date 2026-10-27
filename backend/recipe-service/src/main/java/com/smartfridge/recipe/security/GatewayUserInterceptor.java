package com.smartfridge.recipe.security;

import com.smartfridge.common.api.ErrorCode;
import com.smartfridge.common.error.BusinessException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

@Component
public class GatewayUserInterceptor implements HandlerInterceptor {

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        String userId = request.getHeader("X-User-Id");
        if (userId == null || userId.isBlank()) {
            throw new BusinessException(
                ErrorCode.UNAUTHORIZED,
                HttpStatus.UNAUTHORIZED,
                "缺少用户身份"
            );
        }
        try {
            Long.parseLong(userId);
            return true;
        } catch (NumberFormatException exception) {
            throw new BusinessException(
                ErrorCode.UNAUTHORIZED,
                HttpStatus.UNAUTHORIZED,
                "用户身份无效"
            );
        }
    }
}
