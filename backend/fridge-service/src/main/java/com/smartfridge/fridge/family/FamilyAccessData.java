/*
 * 这个文件：权限服务返回的数据主体：当前用户在这个家庭里的角色。
 */

package com.smartfridge.fridge.family;

public record FamilyAccessData(
    long id,
    String name,
    String currentUserRole
) {
}
