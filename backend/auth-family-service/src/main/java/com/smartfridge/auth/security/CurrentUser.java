/*
 * 这个文件：当前登录用户的简化信息（用户 id + 用户名），由拦截器放进请求里，业务代码直接取。
 */

package com.smartfridge.auth.security;

public record CurrentUser(long id, String username, String platformRole) {
}
