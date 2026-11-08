package com.smartfridge.fridge.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.cloud.context.config.annotation.RefreshScope;
import org.springframework.stereotype.Component;

/**
 * Business thresholds that must be tunable without a redeploy.
 *
 * <p>{@code @RefreshScope} makes this bean re-create itself after Nacos pushes a
 * config change, so the next call reads the new value. The expiry warning that
 * used to be a hard-coded 3 lives here now: it is the first item we use to show
 * the refresh mechanism end to end.
 */
@Component
@RefreshScope
public class FridgeSettings {

    @Value("${smart-fridge.fridge.expiring-threshold-days:3}")
    private int expiringThresholdDays;

    /**
     * An item counts as "expiring" when its remaining days are at or below this
     * number, which also covers already-expired items (negative days).
     */
    public int expiringThresholdDays() {
        return expiringThresholdDays;
    }
}
