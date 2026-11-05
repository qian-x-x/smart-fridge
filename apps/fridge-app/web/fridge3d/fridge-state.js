export const ZONES = Object.freeze(['fresh', 'variable', 'freezer', 'pantry']);
export const PARTS = Object.freeze(['leftDoor', 'rightDoor', 'middleDrawer', 'freezerDrawer']);

export function createViewState() {
  return { zone: 'fresh', leftDoor: 1, rightDoor: 1, middleDrawer: 0.35, freezerDrawer: 0.55 };
}

export function transition(state, action, value) {
  if (action === 'overview') return createViewState();
  if (action === 'closeAll') return { ...state, leftDoor: 0, rightDoor: 0, middleDrawer: 0, freezerDrawer: 0 };
  if (action === 'togglePart' && PARTS.includes(value)) {
    return { ...state, [value]: state[value] > 0 ? 0 : 1,
      zone: value === 'middleDrawer' ? 'variable' : value === 'freezerDrawer' ? 'freezer' : 'fresh' };
  }
  if (action === 'focusZone' && ZONES.includes(value)) {
    const next = { ...state, zone: value };
    if (value === 'fresh') return { ...next, leftDoor: 1, rightDoor: 1 };
    if (value === 'variable') return { ...next, middleDrawer: 1 };
    if (value === 'freezer') return { ...next, freezerDrawer: 1 };
    // Ambient storage belongs on the kitchen counter, never behind a fridge door.
    return next;
  }
  return state;
}

export function fitDistance(aspect, fov = 32) {
  return Math.max(6.05, 3.8 / Math.max(0.25, aspect)) / (2 * Math.tan(fov * Math.PI / 360));
}

export function normalizeFoods(value) {
  if (!Array.isArray(value)) return [];
  return value.filter((food) => food && ZONES.includes(food.zone) &&
    typeof food.name === 'string' && food.name.length <= 80 &&
    typeof food.quantity === 'number' && Number.isFinite(food.quantity) && food.quantity > 0)
    .slice(0, 200).map((food) => ({
      id: String(food.id ?? ''), name: food.name, category: String(food.category ?? ''),
      zone: food.zone, quantity: food.quantity,
    }));
}
