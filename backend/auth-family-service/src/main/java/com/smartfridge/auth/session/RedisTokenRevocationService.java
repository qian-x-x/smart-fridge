/*
 * 这个文件：把已登出的 accessToken 记进 Redis 黑名单。
 * 记录只保留到该 token 本来会过期的时间，所以黑名单不会越攒越多。
 */

package com.smartfridge.auth.session;

import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;

@Service
public class RedisTokenRevocationService implements TokenRevocationService {

    private static final String KEY_PREFIX = "auth:revoked:";

    private final StringRedisTemplate redisTemplate;

    public RedisTokenRevocationService(StringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    @Override
    public void revoke(String tokenId, Duration remainingLifetime) {
        if (remainingLifetime.isNegative() || remainingLifetime.isZero()) {
            return;
        }
        redisTemplate.opsForValue().set(KEY_PREFIX + tokenId, "1", remainingLifetime);
    }

    @Override
    public boolean isRevoked(String tokenId) {
        return Boolean.TRUE.equals(redisTemplate.hasKey(KEY_PREFIX + tokenId));
    }
}
