const DOORS = ['leftDoor', 'rightDoor'];
export const DRAWERS = Object.freeze({
  variable: { part: 'middleDrawer', y: 1.47, height: 0.51, travel: 1.68 },
  freezer: { part: 'freezerDrawer', y: 0.68, height: 0.98, travel: 1.68 },
});
export const TRAY = Object.freeze({ width: 1.89, depth: 1.4, z: 0.035, floorY: -0.18, rimDepth: 0.052 });
export const DRAWER_FRONT = Object.freeze({
  width: 2.09, depth: 0.18, z: 0.86, handleDepth: 0.045, handleZ: 0.963,
});
const DRAWER_ZONES = Object.keys(DRAWERS);
export const ZONES = Object.freeze(['fresh', ...DRAWER_ZONES]);
export const PARTS = Object.freeze([...DOORS, ...DRAWER_ZONES.map((zone) => DRAWERS[zone].part)]);
export const CAMERA_TRANSITION_MS = 400;
export const CAMERA_FOV = 32;

const CAMERA_VIEWS = Object.freeze({
  overview: { x: 0, y: 2.15, z: 0.56, height: 5.05, width: 3.0, depth: 0.64, yaw: 0.025, pitch: 0.07 },
  fresh: { x: 0, y: 3.02, z: 0.48, height: 2.95, width: 2.4, depth: 0.4, yaw: 0, pitch: 0.06 },
});

export function createViewState() {
  return { zone: 'fresh', focus: null, ...Object.fromEntries(PARTS.map((part) => [part, 0])) };
}

export function transition(state, action, value) {
  if (action === 'overview') {
    return { ...createViewState(), ...Object.fromEntries(PARTS.map((part) => [part, 1])) };
  }
  if (action === 'closeAll') return { ...createViewState(), zone: state.zone };
  if (action === 'focusZone') {
    if (value === 'fresh') return { ...state, zone: value, focus: value, leftDoor: 1, rightDoor: 1 };
    if (isOverhead(value)) return openDrawer(value);
  }
  if (action === 'togglePart' && PARTS.includes(value)) {
    const zone = DRAWER_ZONES.find((candidate) => DRAWERS[candidate].part === value);
    if (zone) {
      return state.focus === zone && state[value] ? { ...createViewState(), zone } : openDrawer(zone);
    }

    const next = { ...state, zone: 'fresh', [value]: state[value] ? 0 : 1 };
    return { ...next, focus: DOORS.some((door) => next[door]) ? 'fresh' : null };
  }
  return state;
}

function openDrawer(zone) {
  return { ...createViewState(), zone, focus: zone, [DRAWERS[zone].part]: 1 };
}

export function isOverhead(focus) {
  return DRAWER_ZONES.includes(focus);
}

export function cameraPose(focus, aspect) {
  const halfFovTangent = Math.tan(CAMERA_FOV * Math.PI / 360);
  const viewportAspect = Math.max(0.25, aspect);
  if (isOverhead(focus)) {
    const { y, height, travel } = DRAWERS[focus];
    const back = TRAY.z - (TRAY.depth + TRAY.rimDepth) / 2;
    const front = DRAWER_FRONT.handleZ + DRAWER_FRONT.handleDepth / 2;
    // Frame the whole outline at the drawer's highest edge, including its front.
    const frameHeight = Math.max(front - back, DRAWER_FRONT.width / viewportAspect) / 0.92;
    return { x: 0, y: y + height / 2, z: travel + (back + front) / 2,
      yaw: 0, pitch: Math.PI / 2, distance: frameHeight / (2 * halfFovTangent) };
  }
  const { x, y, z, height, width, depth, yaw, pitch } = CAMERA_VIEWS[focus ?? 'overview'];
  const frameHeight = Math.max(height, width / viewportAspect);
  const distance = depth + frameHeight / (2 * halfFovTangent);
  return { x, y, z, yaw, pitch, distance };
}

export function applyCameraPose(camera, { x, y, z, yaw, pitch, distance }) {
  const elevation = Math.max(0.015, Math.min(Math.PI / 2, pitch));
  const sinYaw = Math.sin(yaw);
  const cosYaw = Math.cos(yaw);
  const horizontal = Math.cos(elevation) * distance;
  const vertical = Math.sin(elevation);
  camera.position.set(x + sinYaw * horizontal, y + vertical * distance, z + cosYaw * horizontal);
  // The camera's up direction follows the orbit even when looking straight down.
  camera.up.set(-sinYaw * vertical, Math.cos(elevation), -cosYaw * vertical);
  camera.lookAt(x, y, z);
}

export function interpolateCamera(from, to, elapsedMs) {
  if (elapsedMs <= 0) return from;
  if (elapsedMs >= CAMERA_TRANSITION_MS) return to;
  const progress = elapsedMs / CAMERA_TRANSITION_MS;
  const weight = progress * progress * (3 - 2 * progress);
  return Object.fromEntries(
    Object.keys(from).map((key) => [key, from[key] + (to[key] - from[key]) * weight]),
  );
}

export function normalizeFoods(value) {
  if (!Array.isArray(value)) return [];
  return value.filter((food) => food && ZONES.includes(food.zone) &&
    typeof food.id === 'string' && food.id.length > 0 && food.id.length <= 80 &&
    typeof food.name === 'string' && food.name.length > 0 && food.name.length <= 80 &&
    typeof food.quantity === 'number' && Number.isFinite(food.quantity) && food.quantity > 0)
    .map((food) => ({
      id: food.id, name: food.name,
      zone: food.zone, quantity: food.quantity,
      artwork: typeof food.artwork === 'string' && /^[\p{L}\p{N}_-]{1,80}$/u.test(food.artwork) ? food.artwork : null,
      emoji: typeof food.emoji === 'string' && food.emoji.length <= 12 ? food.emoji : '🍽️',
      layers: Number.isInteger(food.layers) ? Math.min(3, Math.max(1, food.layers)) : 1,
      portions: typeof food.portions === 'string' && /^\d{1,16}(?:\.\d{1,3})?$/.test(food.portions)
        ? food.portions : null,
    }));
}
