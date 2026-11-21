/*
 * 这个文件：扣减库存的请求体。
 */

package com.smartfridge.stock;

import jakarta.validation.constraints.Min;

public record DeductRequest(
    @Min(value = 1, message = "扣减数量至少为 1")
    int quantity
) {
}
