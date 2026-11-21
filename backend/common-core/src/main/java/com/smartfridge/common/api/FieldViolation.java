/*
 * 这个文件：表单校验失败时，用来说明「哪个字段、错在哪里」，会放进返回体的 data 里。
 */

package com.smartfridge.common.api;

public record FieldViolation(String field, String message) {
}
