import { Vector3 } from '../vendor/three.module.min.js';
import { DRAWERS, TRAY } from './fridge-state.js?rev=fridge-sticker-grid-v2.3';

const SLOT_ROWS = 4;
const COLD_COLUMNS = 6;
const STICKER_FILL = 0.78;
const MAX_STICKER_SIZE = 78;
const point = new Vector3();

export function stickerLayout(zone, view, ingredientKinds) {
  if (zone === 'fresh') {
    const levels = [4.11, 3.63, 2.98, 2.34, 1.82];
    const columnWidth = 1.72 / COLD_COLUMNS;
    const slots = [];
    for (let row = 0; row < SLOT_ROWS; row++) {
      for (let column = 0; column < COLD_COLUMNS; column++) {
        const leftDoor = column < COLD_COLUMNS / 2;
        if (!(leftDoor ? view.leftDoor : view.rightDoor)) continue;
        const left = -0.86 + column * columnWidth;
        const right = left + columnWidth;
        const top = levels[row], bottom = levels[row + 1];
        // Give the left and right shelves alternating inventory slots.
        const index = row * COLD_COLUMNS + (column % 3) * 2 + Number(!leftDoor);
        slots.push({
          index,
          center: [(left + right) / 2, (top + bottom) / 2, 0.25],
          corners: [[left, top, 0.25], [right, top, 0.25], [right, bottom, 0.25], [left, bottom, 0.25]],
        });
      }
    }
    return { capacity: COLD_COLUMNS * SLOT_ROWS, slots };
  }

  const columns = ingredientKinds > 16 ? 8 : 4;
  const capacity = columns * SLOT_ROWS;
  const drawer = DRAWERS[zone];
  if (!drawer || view.focus !== zone || !view[drawer.part]) {
    return { capacity, slots: [] };
  }
  const innerWidth = TRAY.width - 0.16, innerDepth = TRAY.depth - 0.16;
  const cellWidth = innerWidth / columns, cellDepth = innerDepth / SLOT_ROWS;
  const back = TRAY.z + drawer.travel - innerDepth / 2;
  const y = drawer.y + 0.1;
  const slots = Array.from({ length: capacity }, (_, index) => {
    const left = -innerWidth / 2 + (index % columns) * cellWidth;
    const right = left + cellWidth;
    const rear = back + Math.floor(index / columns) * cellDepth;
    const front = rear + cellDepth;
    return {
      index,
      center: [(left + right) / 2, y, (rear + front) / 2],
      corners: [[left, y, rear], [right, y, rear], [right, y, front], [left, y, front]],
    };
  });
  return { capacity, slots };
}

export function projectStickerSlot(slot, camera, width, height, travelOffset = 0) {
  const toScreen = ([x, y, z]) => {
    point.set(x, y, z + travelOffset).project(camera);
    return [(point.x + 1) * width / 2, (1 - point.y) * height / 2];
  };
  const [x, y] = toScreen(slot.center);
  const corners = slot.corners.map(toScreen);
  let half = Math.min(x, width - x, y, height - y);
  for (let index = 0; index < corners.length; index++) {
    const [left, top] = corners[index];
    const [right, bottom] = corners[(index + 1) % corners.length];
    const dx = right - left, dy = bottom - top;
    const denominator = Math.abs(dx) + Math.abs(dy);
    if (denominator <= 0) return { x, y, size: 0 };
    // An axis-aligned square must fit against every edge, even mid-transition.
    const maxHalf = Math.abs(dx * (y - top) - dy * (x - left)) / denominator;
    half = Math.min(half, maxHalf);
  }
  return { x, y, size: Math.max(0, Math.min(MAX_STICKER_SIZE, 2 * half * STICKER_FILL)) };
}
