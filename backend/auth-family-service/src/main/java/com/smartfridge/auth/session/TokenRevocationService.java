/*
 * 这个文件：黑名单服务的接口定义，真正实现是 Redis 那一版。
 */

package com.smartfridge.auth.session;

import java.time.Duration;

public interface TokenRevocationService {

    void revoke(String tokenId, Duration remainingLifetime);

    boolean isRevoked(String tokenId);
}
