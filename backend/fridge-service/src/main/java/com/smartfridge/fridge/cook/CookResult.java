/*
 * 这个文件：做饭结果：记录本身 + 是不是这次新建的（false 说明是重复请求直接返回旧结果）。
 */

package com.smartfridge.fridge.cook;

public record CookResult(CookRecordView record, boolean created) {
}
