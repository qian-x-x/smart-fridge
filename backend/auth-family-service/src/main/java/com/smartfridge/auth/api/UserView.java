/*
 * 这个文件：返回给前端的用户资料。注意：故意不包含密码哈希。
 */

package com.smartfridge.auth.api;

import com.smartfridge.auth.user.UserAccount;

public record UserView(long id, String username, String phone, String displayName, String role) {

    public static UserView from(UserAccount user) {
        return new UserView(
            user.id(),
            user.username(),
            user.phone(),
            user.displayName(),
            user.platformRole()
        );
    }
}
