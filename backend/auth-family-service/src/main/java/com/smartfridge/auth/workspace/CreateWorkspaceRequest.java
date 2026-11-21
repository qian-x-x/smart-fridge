/*
 * 这个文件：「一次创建家庭和默认冰箱」的请求体：家庭名 + 一个客户端生成的 requestId（用来防重复提交）。
 */

package com.smartfridge.auth.workspace;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record CreateWorkspaceRequest(
    @NotBlank(message = "请输入家庭名称") @Size(max = 60) String name,
    @NotBlank @Pattern(regexp = "[A-Za-z0-9_-]{8,64}", message = "创建请求标识格式不正确")
    String requestId
) {
    public String normalizedName() {
        return name.trim();
    }
}
