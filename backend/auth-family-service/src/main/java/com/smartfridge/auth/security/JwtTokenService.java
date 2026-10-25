package com.smartfridge.auth.security;

import com.smartfridge.auth.user.UserAccount;
import com.smartfridge.common.api.ErrorCode;
import com.smartfridge.common.error.BusinessException;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import java.util.UUID;

@Service
public class JwtTokenService {

    private final JwtProperties properties;
    private final SecretKey signingKey;

    public JwtTokenService(JwtProperties properties) {
        this.properties = properties;
        this.signingKey = Keys.hmacShaKeyFor(properties.secret().getBytes(StandardCharsets.UTF_8));
    }

    public IssuedTokenPair issue(UserAccount user) {
        Instant now = Instant.now();
        Instant accessExpiresAt = now.plus(properties.accessTokenTtl());
        Instant refreshExpiresAt = now.plus(properties.refreshTokenTtl());
        String refreshTokenId = UUID.randomUUID().toString();

        String accessToken = buildToken(
            user, "access", UUID.randomUUID().toString(), now, accessExpiresAt
        );
        String refreshToken = buildToken(
            user, "refresh", refreshTokenId, now, refreshExpiresAt
        );
        return new IssuedTokenPair(
            accessToken,
            refreshToken,
            refreshTokenId,
            refreshExpiresAt,
            properties.accessTokenTtl().toSeconds()
        );
    }

    public TokenClaims parseAccessToken(String token) {
        return parse(token, TokenType.ACCESS);
    }

    public TokenClaims parseRefreshToken(String token) {
        return parse(token, TokenType.REFRESH);
    }

    private String buildToken(
        UserAccount user,
        String type,
        String tokenId,
        Instant issuedAt,
        Instant expiresAt
    ) {
        return Jwts.builder()
            .subject(Long.toString(user.id()))
            .id(tokenId)
            .claim("username", user.username())
            .claim("role", user.platformRole())
            .claim("type", type)
            .issuedAt(Date.from(issuedAt))
            .expiration(Date.from(expiresAt))
            .signWith(signingKey)
            .compact();
    }

    private TokenClaims parse(String token, TokenType expectedType) {
        try {
            Claims claims = Jwts.parser()
                .verifyWith(signingKey)
                .build()
                .parseSignedClaims(token)
                .getPayload();
            String type = claims.get("type", String.class);
            if (!expectedType.name().toLowerCase().equals(type)) {
                throw unauthorized();
            }
            return new TokenClaims(
                Long.parseLong(claims.getSubject()),
                claims.get("username", String.class),
                claims.get("role", String.class),
                claims.getId(),
                expectedType,
                claims.getExpiration().toInstant()
            );
        } catch (JwtException | IllegalArgumentException exception) {
            throw unauthorized();
        }
    }

    private BusinessException unauthorized() {
        return new BusinessException(ErrorCode.UNAUTHORIZED, HttpStatus.UNAUTHORIZED, "令牌无效或已过期");
    }
}
