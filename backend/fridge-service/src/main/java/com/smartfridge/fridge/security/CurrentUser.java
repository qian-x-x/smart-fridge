/*
 * 这个文件：当前用户（id + 用户名），由拦截器从网关传来的头里解析出来。
 */

package com.smartfridge.fridge.security;

public record CurrentUser(long id, String username) {
}
