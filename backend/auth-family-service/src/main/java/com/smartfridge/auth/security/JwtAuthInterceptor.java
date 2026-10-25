package com.smartfridge.auth.security;

import com.smartfridge.common.api.ErrorCode;
import com.smartfridge.common.error.BusinessException;
import com.smartfridge.auth.session.TokenRevocationService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

@Component
public class JwtAuthInterceptor implements HandlerInterceptor {

    public static final String CURRENT_USER_ATTRIBUTE = "smart-fridge.current-user";

    private final JwtTokenService tokenService;
    private final TokenRevocationService tokenRevocationService;

    public JwtAuthInterceptor(
        JwtTokenService tokenService,
        TokenRevocationService tokenRevocationService
    ) {
        this.tokenService = tokenService;
        this.tokenRevocationService = tokenRevocationService;
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        String authorization = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (authorization == null || !authorization.startsWith("Bearer ")) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, HttpStatus.UNAUTHORIZED, "缺少访问令牌");
        }
        TokenClaims claims = tokenService.parseAccessToken(authorization.substring(7));
        if (tokenRevocationService.isRevoked(claims.tokenId())) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, HttpStatus.UNAUTHORIZED, "访问令牌已撤销");
        }
        request.setAttribute(
            CURRENT_USER_ATTRIBUTE,
            new CurrentUser(claims.userId(), claims.username(), claims.platformRole())
        );
        return true;
    }
}
