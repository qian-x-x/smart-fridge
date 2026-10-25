package com.smartfridge.auth.session;

import java.time.Duration;

public interface TokenRevocationService {

    void revoke(String tokenId, Duration remainingLifetime);

    boolean isRevoked(String tokenId);
}
