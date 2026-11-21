/*
 * 这个文件：创建工作区成功的返回：家庭信息 + 默认冰箱 id。
 */

package com.smartfridge.auth.workspace;

import com.smartfridge.auth.family.FamilyView;

public record WorkspaceView(FamilyView family, long fridgeId) {
}
