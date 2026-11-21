/*
 * 这个文件：注册、登录、刷新、退出这四个流程的业务逻辑。
 * 要点：刷新时旧的 refreshToken 立刻作废，一个只能用一次；
 * 退出时把 accessToken 的编号记进 Redis 黑名单，refreshToken 也从会话表撤销。
 */

package com.smartfridge.auth.application;

import com.smartfridge.auth.api.AuthTokenResponse;
import com.smartfridge.auth.api.LoginRequest;
import com.smartfridge.auth.api.RegisterRequest;
import com.smartfridge.auth.api.UserView;
import com.smartfridge.auth.security.IssuedTokenPair;
import com.smartfridge.auth.security.JwtTokenService;
import com.smartfridge.auth.security.TokenClaims;
import com.smartfridge.auth.session.RefreshSessionRepository;
import com.smartfridge.auth.session.TokenRevocationService;
import com.smartfridge.auth.user.UserAccount;
import com.smartfridge.auth.user.UserRepository;
import com.smartfridge.common.api.ErrorCode;
import com.smartfridge.common.error.BusinessException;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.Duration;
import java.time.Instant;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final RefreshSessionRepository refreshSessionRepository;
    private final TokenRevocationService tokenRevocationService;
    private final JwtTokenService tokenService;
    private final PasswordEncoder passwordEncoder;

    public AuthService(
        UserRepository userRepository,
        RefreshSessionRepository refreshSessionRepository,
        TokenRevocationService tokenRevocationService,
        JwtTokenService tokenService,
        PasswordEncoder passwordEncoder
    ) {
        this.userRepository = userRepository;
        this.refreshSessionRepository = refreshSessionRepository;
        this.tokenRevocationService = tokenRevocationService;
        this.tokenService = tokenService;
        this.passwordEncoder = passwordEncoder;
    }

    /**
     * 注册新用户：用户名和手机号至少填一个，重复的直接拒绝，
     * 密码只存 BCrypt 哈希；注册成功立刻签发一对令牌，用户不用再登录一次。
     */
    @Transactional
    public AuthTokenResponse register(RegisterRequest request) {
        String username = normalize(request.username());
        String phone = normalize(request.phone());
        if (!StringUtils.hasText(username) && !StringUtils.hasText(phone)) {
            throw new BusinessException(
                ErrorCode.VALIDATION_ERROR,
                HttpStatus.BAD_REQUEST,
                "用户名和手机号至少填写一项"
            );
        }
        if (username != null && userRepository.existsByUsername(username)) {
            throw BusinessException.conflict("用户名已存在");
        }
        if (phone != null && userRepository.existsByPhone(phone)) {
            throw BusinessException.conflict("手机号已注册");
        }

        try {
            UserAccount user = userRepository.insert(
                username,
                phone,
                passwordEncoder.encode(request.password()),
                request.displayName().trim()
            );
            return issueTokens(user);
        } catch (DuplicateKeyException exception) {
            throw BusinessException.conflict("用户名或手机号已存在");
        }
    }

    /**
     * 登录：用户名或手机号都能当账号用。
     * 用户不存在和密码错误返回同一句提示，避免被别人试探出「这个账号存不存在」。
     */
    @Transactional
    public AuthTokenResponse login(LoginRequest request) {
        UserAccount user = userRepository.findByIdentifier(request.identifier().trim())
            .orElseThrow(this::invalidCredentials);
        if (!"ACTIVE".equals(user.status()) || !passwordEncoder.matches(request.password(), user.passwordHash())) {
            throw invalidCredentials();
        }
        return issueTokens(user);
    }

    /**
     * 用 refreshToken 换一对新令牌。
     * consumeActive 会把旧 refreshToken 标记为已用：同一个只能用一次，
     * 这样即使它被偷走，攻击者最多也只能用一次，而正常用户下次刷新会失败并要求重新登录。
     */
    @Transactional
    public AuthTokenResponse refresh(String refreshToken) {
        TokenClaims claims = tokenService.parseRefreshToken(refreshToken);
        if (!refreshSessionRepository.consumeActive(claims.tokenId())) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, HttpStatus.UNAUTHORIZED, "刷新令牌已失效");
        }
        UserAccount user = userRepository.findById(claims.userId())
            .filter(candidate -> "ACTIVE".equals(candidate.status()))
            .orElseThrow(this::invalidCredentials);
        return issueTokens(user);
    }

    /**
     * 退出登录：把 accessToken 的编号写进 Redis 黑名单（有效到它本来过期那一刻），
     * 同时撤销 refreshToken，防止退出后还能用刷新接口续命。
     */
    @Transactional
    public void logout(String accessToken, String refreshToken) {
        TokenClaims accessClaims = tokenService.parseAccessToken(accessToken);
        TokenClaims refreshClaims = StringUtils.hasText(refreshToken)
            ? tokenService.parseRefreshToken(refreshToken) : null;
        if (refreshClaims != null && refreshClaims.userId() != accessClaims.userId()) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, HttpStatus.BAD_REQUEST,
                "刷新令牌不属于当前用户");
        }
        Duration accessRemaining = Duration.between(Instant.now(), accessClaims.expiresAt());
        tokenRevocationService.revoke(accessClaims.tokenId(), accessRemaining);

        if (refreshClaims != null) {
            refreshSessionRepository.revoke(refreshClaims.tokenId());
        }
    }

    public boolean isAccessTokenRevoked(String token) {
        TokenClaims claims = tokenService.parseAccessToken(token);
        return tokenRevocationService.isRevoked(claims.tokenId());
    }

    private AuthTokenResponse issueTokens(UserAccount user) {
        IssuedTokenPair tokens = tokenService.issue(user);
        refreshSessionRepository.save(tokens.refreshTokenId(), user.id(), tokens.refreshExpiresAt());
        return new AuthTokenResponse(
            tokens.accessToken(),
            tokens.refreshToken(),
            "Bearer",
            tokens.expiresInSeconds(),
            UserView.from(user)
        );
    }

    private BusinessException invalidCredentials() {
        return new BusinessException(ErrorCode.UNAUTHORIZED, HttpStatus.UNAUTHORIZED, "账号或密码错误");
    }

    private String normalize(String value) {
        return StringUtils.hasText(value) ? value.trim() : null;
    }
}
