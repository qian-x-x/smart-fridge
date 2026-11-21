/*
 * 这个文件：测试调用权限服务的封装层：各种下游错误是否正确翻译成对应的业务错误。
 */

package com.smartfridge.fridge;

import com.smartfridge.fridge.family.*;
import com.smartfridge.common.error.BusinessException;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

import static org.mockito.Mockito.*;
import static org.assertj.core.api.Assertions.*;

class FamilyAccessServiceTest {
    @Test
    void rejectsMalformedUpstreamResponsesAsServiceUnavailable() {
        var client = mock(FamilyAccessFeignClient.class);
        var service = new FamilyAccessService(client);
        for (var envelope : new FamilyAccessEnvelope[]{null,
            new FamilyAccessEnvelope("OK", "success", null, "test"),
            new FamilyAccessEnvelope("OK", "success", new FamilyAccessData(1, "家庭", null), "test")}) {
            when(client.getFamily(1, "Bearer test")).thenReturn(envelope);
            assertThatThrownBy(() -> service.requireMember(1, "Bearer test"))
                .isInstanceOfSatisfying(BusinessException.class,
                    error -> assertThat(error.getStatus()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE));
        }
    }

    @Test
    void acceptsKnownRolesAndRejectsUnknownRoles() {
        var client = mock(FamilyAccessFeignClient.class);
        var service = new FamilyAccessService(client);
        when(client.getFamily(1, "Bearer test")).thenReturn(
            new FamilyAccessEnvelope("OK", "success", new FamilyAccessData(1, "家庭", "EDITOR"), "test"));
        assertThat(service.requireMember(1, "Bearer test")).isEqualTo("EDITOR");
        when(client.getFamily(1, "Bearer test")).thenReturn(
            new FamilyAccessEnvelope("OK", "success", new FamilyAccessData(1, "家庭", "UNKNOWN"), "test"));
        assertThatThrownBy(() -> service.requireMember(1, "Bearer test"))
            .isInstanceOfSatisfying(BusinessException.class,
                error -> assertThat(error.getStatus()).isEqualTo(HttpStatus.FORBIDDEN));
    }
}
