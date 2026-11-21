/*
 * 这个文件：公共组件的自动装配入口：哪个服务引入了 common-core，就自动带上请求追踪等通用能力。
 */

package com.smartfridge.common.web;

import com.smartfridge.common.error.GlobalExceptionHandler;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnWebApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;

@AutoConfiguration
@ConditionalOnWebApplication(type = ConditionalOnWebApplication.Type.SERVLET)
@Import(GlobalExceptionHandler.class)
public class CommonWebAutoConfiguration {

    @Bean
    public RequestTraceFilter requestTraceFilter() {
        return new RequestTraceFilter();
    }
}
