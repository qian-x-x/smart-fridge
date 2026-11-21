/*
 * 这个文件：数据库里一行用户记录（包含密码哈希，只在服务内部用，不会返回给前端）。
 */

package com.smartfridge.auth.user;

public record UserAccount(
    long id,
    String username,
    String phone,
    String passwordHash,
    String displayName,
    String platformRole,
    String status
) {
}
