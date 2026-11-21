/*
 * 这个文件：工作区登记表的一行：请求编号、家庭 id、冰箱 id、事务编号、是否完成。
 */

package com.smartfridge.auth.workspace;

record WorkspaceRecord(long userId, String requestId, String familyName, long familyId,
                       Long fridgeId, String xid, boolean completed) {
}
