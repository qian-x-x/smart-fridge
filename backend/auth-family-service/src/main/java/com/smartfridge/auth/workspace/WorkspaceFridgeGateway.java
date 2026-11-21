/*
 * 这个文件：调用冰箱服务的封装层：校验返回是否合理，把 401/403/409 翻译成用户看得懂的中文，
 * 并用 Sentinel 做限流和熔断兜底。
 */

package com.smartfridge.auth.workspace;

import com.alibaba.csp.sentinel.annotation.SentinelResource;
import com.alibaba.csp.sentinel.slots.block.BlockException;
import com.smartfridge.common.api.ErrorCode;
import com.smartfridge.common.error.BusinessException;
import feign.FeignException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

@Service
public class WorkspaceFridgeGateway {
    private final WorkspaceFridgeClient client;

    public WorkspaceFridgeGateway(WorkspaceFridgeClient client) {
        this.client = client;
    }

    @SentinelResource(value = "family-fridge-initialize", blockHandler = "blocked",
        fallback = "unavailable", exceptionsToIgnore = BusinessException.class)
    public long initialize(long familyId, long userId, String authorization) {
        try {
            var response = client.create(authorization, Long.toString(userId),
                new WorkspaceFridgeClient.NewFridge(familyId, "家庭冰箱"));
            if (response == null || !"OK".equals(response.code()) || response.data() == null
                || response.data().id() <= 0 || response.data().familyId() != familyId) {
                throw new IllegalStateException("冰箱初始化返回了无效响应");
            }
            return response.data().id();
        } catch (FeignException exception) {
            if (exception.status() == 401) throw BusinessException.unauthorized("访问令牌已失效，请重新登录");
            if (exception.status() == 403) throw BusinessException.forbidden("无权初始化该家庭的冰箱");
            if (exception.status() == 409) throw BusinessException.conflict("家庭冰箱状态已变化，请刷新后重试");
            throw exception;
        }
    }

    public long blocked(long familyId, long userId, String authorization, BlockException exception) {
        throw failure("冰箱初始化暂时繁忙，请稍后重试");
    }

    public long unavailable(long familyId, long userId, String authorization, Throwable exception) {
        throw failure("家庭初始化未完成，请稍后使用原请求重试");
    }

    private BusinessException failure(String message) {
        return new BusinessException(ErrorCode.INTERNAL_ERROR, HttpStatus.SERVICE_UNAVAILABLE, message);
    }
}
