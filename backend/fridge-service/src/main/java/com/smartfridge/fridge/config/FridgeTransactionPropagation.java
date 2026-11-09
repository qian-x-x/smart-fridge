package com.smartfridge.fridge.config;

import feign.RequestInterceptor;
import io.seata.core.context.RootContext;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class FridgeTransactionPropagation {
    @Bean
    RequestInterceptor familyTransactionPropagation() {
        return template -> {
            String xid = RootContext.getXID();
            if (xid != null) template.header(RootContext.KEY_XID, xid);
        };
    }
}
