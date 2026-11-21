/*
 * 这个文件：过期清理的结果：这次清掉了几条食材。
 */

package com.smartfridge.fridge.food;

import java.util.List;

/**
 * Result of a bulk expired-stock cleanup.
 *
 * @param count   number of items actually discarded
 * @param skipped items that were expired when scanned but changed concurrently
 * @param foods   the discarded items as they looked right before deletion
 */
public record ExpiredCleanupView(int count, int skipped, List<FoodView> foods) {
}
