/*
 * 这个文件：把当前 Seata 事务号塞进发给其他服务的请求头里，保证跨服务调用还在同一个事务中。
 */

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
