/*
 * 这个文件：测试统一返回格式：成功和失败时 code / message / data / traceId 是否按约定输出。
 */

package com.smartfridge.common.api;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.slf4j.MDC;

import static org.assertj.core.api.Assertions.assertThat;

class ApiResponseTest {

    @AfterEach
    void clearTrace() {
        MDC.clear();
    }

    @Test
    void propagatesTraceIdIntoResponse() {
        MDC.put("traceId", "trace-001");

        ApiResponse<String> response = ApiResponse.success("ok");

        assertThat(response.code()).isEqualTo("OK");
        assertThat(response.data()).isEqualTo("ok");
        assertThat(response.traceId()).isEqualTo("trace-001");
    }
}
