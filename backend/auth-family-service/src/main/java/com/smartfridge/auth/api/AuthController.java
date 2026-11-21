/*
 * 这个文件：认证相关的 HTTP 接口：注册、登录、刷新令牌、退出、令牌有效性查询。
 */

package com.smartfridge.auth.api;

import com.smartfridge.auth.application.AuthService;
import com.smartfridge.auth.security.JwtAuthInterceptor;
import com.smartfridge.auth.security.TokenClaims;
import com.smartfridge.auth.security.JwtTokenService;
import com.smartfridge.common.api.ApiResponse;
import com.smartfridge.common.api.ErrorCode;
import com.smartfridge.common.error.BusinessException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    private final AuthService authService;
    private final JwtTokenService tokenService;

    public AuthController(AuthService authService, JwtTokenService tokenService) {
        this.authService = authService;
        this.tokenService = tokenService;
    }

    @PostMapping("/register")
    public ResponseEntity<ApiResponse<AuthTokenResponse>> register(
        @Valid @RequestBody RegisterRequest request
    ) {
        return ResponseEntity.status(HttpStatus.CREATED)
            .body(ApiResponse.success(authService.register(request)));
    }

    @PostMapping("/login")
    public ApiResponse<AuthTokenResponse> login(@Valid @RequestBody LoginRequest request) {
        return ApiResponse.success(authService.login(request));
    }

    @PostMapping("/refresh")
    public ApiResponse<AuthTokenResponse> refresh(@Valid @RequestBody RefreshRequest request) {
        return ApiResponse.success(authService.refresh(request.refreshToken()));
    }

    @PostMapping("/logout")
    public ApiResponse<Void> logout(
        HttpServletRequest request,
        @RequestBody(required = false) LogoutRequest logoutRequest
    ) {
        authService.logout(
            bearerToken(request),
            logoutRequest == null ? null : logoutRequest.refreshToken()
        );
        return ApiResponse.success(null);
    }

    @PostMapping("/introspect")
    public ApiResponse<TokenClaims> introspect(HttpServletRequest request) {
        String token = bearerToken(request);
        TokenClaims claims = tokenService.parseAccessToken(token);
        if (authService.isAccessTokenRevoked(token)) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, HttpStatus.UNAUTHORIZED, "访问令牌已撤销");
        }
        return ApiResponse.success(claims);
    }

    private String bearerToken(HttpServletRequest request) {
        String authorization = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (authorization == null || !authorization.startsWith("Bearer ")) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, HttpStatus.UNAUTHORIZED, "缺少访问令牌");
        }
        return authorization.substring(7);
    }
}
