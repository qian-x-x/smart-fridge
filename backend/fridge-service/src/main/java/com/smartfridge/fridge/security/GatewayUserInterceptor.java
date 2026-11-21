/*
 * 这个文件：从网关注入的 X-User-Id / X-User-Name 头取用户身份，放进请求上下文。
 * 拿不到就返回 401，说明请求没经过网关或者网关没放行。
 */

package com.smartfridge.fridge.security;

import com.smartfridge.common.api.ErrorCode;
import com.smartfridge.common.error.BusinessException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

@Component
public class GatewayUserInterceptor implements HandlerInterceptor {

    public static final String CURRENT_USER_ATTRIBUTE = "smart-fridge.current-user";
    public static final String USER_ID_HEADER = "X-User-Id";
    public static final String USER_NAME_HEADER = "X-User-Name";

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        String userId = request.getHeader(USER_ID_HEADER);
        if (userId == null || userId.isBlank()) {
            throw new BusinessException(
                ErrorCode.UNAUTHORIZED,
                HttpStatus.UNAUTHORIZED,
                "缺少用户身份"
            );
        }
        try {
            request.setAttribute(
                CURRENT_USER_ATTRIBUTE,
                new CurrentUser(Long.parseLong(userId), request.getHeader(USER_NAME_HEADER))
            );
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
