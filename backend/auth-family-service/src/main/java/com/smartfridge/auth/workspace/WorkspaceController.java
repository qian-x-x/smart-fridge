/*
 * 这个文件：创建家庭工作区的 HTTP 入口。
 */

package com.smartfridge.auth.workspace;

import com.smartfridge.auth.security.CurrentUser;
import com.smartfridge.auth.security.JwtAuthInterceptor;
import com.smartfridge.common.api.ApiResponse;
import com.smartfridge.common.api.ErrorCode;
import com.smartfridge.common.error.BusinessException;
import io.seata.core.context.RootContext;
import jakarta.validation.Valid;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
public class WorkspaceController {
    private final WorkspaceService service;

    public WorkspaceController(WorkspaceService service) {
        this.service = service;
    }

    @PostMapping("/api/v1/families/workspaces")
    public ResponseEntity<ApiResponse<WorkspaceView>> create(
        @RequestAttribute(JwtAuthInterceptor.CURRENT_USER_ATTRIBUTE) CurrentUser user,
        @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization,
        @Valid @RequestBody CreateWorkspaceRequest request
    ) {
        if (RootContext.getXID() != null) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, HttpStatus.BAD_REQUEST,
                "家庭创建入口不接受外部事务上下文");
        }
        var result = service.create(user.id(), authorization, request);
        return ResponseEntity.status(result.created() ? HttpStatus.CREATED : HttpStatus.OK)
            .body(ApiResponse.success(result.workspace()));
    }
}
