/*
 * 这个文件：真正发起权限查询的地方：调用认证服务，把 404/401/其他故障各自翻译成
 * 对应的业务错误，不让底层的 Feign 细节泄漏到业务代码。
 */

package com.smartfridge.fridge.family;

import com.smartfridge.common.api.ErrorCode;
import com.smartfridge.common.error.BusinessException;
import feign.FeignException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.Set;

@Service
public class FamilyAccessService {

    private static final Set<String> MEMBER_ROLES = Set.of("OWNER", "EDITOR", "VIEWER");

    private final FamilyAccessFeignClient client;

    public FamilyAccessService(FamilyAccessFeignClient client) {
        this.client = client;
    }

    public String requireMember(long familyId, String authorization) {
        try {
            FamilyAccessEnvelope response = client.getFamily(familyId, authorization);
            if (response == null || !"OK".equals(response.code()) || response.data() == null ||
                response.data().currentUserRole() == null) {
                throw new BusinessException(ErrorCode.INTERNAL_ERROR, HttpStatus.SERVICE_UNAVAILABLE,
                    "家庭权限服务返回了无效响应");
            }
            String role = response.data().currentUserRole();
            if (!MEMBER_ROLES.contains(role)) {
                throw BusinessException.forbidden("无权访问该家庭");
            }
            return role;
        } catch (FeignException.NotFound exception) {
            throw BusinessException.notFound("家庭不存在或无权访问");
        } catch (FeignException.Unauthorized exception) {
            throw BusinessException.unauthorized("访问令牌无效或已过期");
        } catch (BusinessException exception) {
            throw exception;
        } catch (FeignException exception) {
            throw new BusinessException(
                ErrorCode.INTERNAL_ERROR,
                HttpStatus.SERVICE_UNAVAILABLE,
                "家庭权限服务暂时不可用"
            );
        }
    }
}
