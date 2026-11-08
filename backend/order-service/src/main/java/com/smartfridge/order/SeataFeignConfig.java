package com.smartfridge.order;

import feign.RequestInterceptor;
import io.seata.core.context.RootContext;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * 把全局事务 XID 透传到下游。
 *
 * <p>Seata 与 OpenFeign 的集成在多数版本里会自动完成，但这里显式写一遍：
 * 一旦自动配置因版本调整失效，表现是"库存扣了但回滚不了"，而且没有任何报错，
 * 排查成本极高。显式拦截器让 XID 传播成为可读代码，也让答辩时能直接指出这一行。
 *
 * <p>服务端由 Seata 的 MVC 拦截器从 {@code TX_XID} 头读取并绑定到 RootContext，
 * 库存服务的扣减因此才会注册成同一次全局事务的分支。
 */
@Configuration
public class SeataFeignConfig {

    @Bean
    public RequestInterceptor seataXidRequestInterceptor() {
        return template -> {
            String xid = RootContext.getXID();
            if (xid != null && !xid.isEmpty()) {
                template.header(RootContext.KEY_XID, xid);
            }
        };
    }
}
