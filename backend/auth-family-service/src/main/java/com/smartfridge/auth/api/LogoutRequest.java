/*
 * 这个文件：退出登录的请求体，可以顺带带上 refreshToken 一起作废。
 */

package com.smartfridge.auth.api;

public record LogoutRequest(String refreshToken) {
}
