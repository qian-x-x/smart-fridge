import * as THREE from '../vendor/three.module.min.js';
import { DRAWERS, DRAWER_FRONT, TRAY } from './fridge-state.js?rev=fridge-sticker-grid-v2.3';

export const SIZE = Object.freeze({ width: 2.12, height: 4.36, depth: 1.68, doorAngle: 1.75 });
const FREEZER_BASKETS = [
  { name: 'upper-sliding-basket', height: 0.22, depth: 0.64, y: 0.16, z: -0.355 },
  { name: 'lower-freezer-basket', height: 0.42, depth: TRAY.depth, y: -0.24, z: TRAY.z },
];

export function box(parent, name, size, position, material, radius = 0) {
  let geometry;
  if (radius > 0) {
    const [w, h, d] = size;
    const r = Math.min(radius, w / 2, h / 2);
    const shape = new THREE.Shape();
    shape.moveTo(-w / 2 + r, -h / 2);
    shape.lineTo(w / 2 - r, -h / 2);
    shape.quadraticCurveTo(w / 2, -h / 2, w / 2, -h / 2 + r);
    shape.lineTo(w / 2, h / 2 - r);
    shape.quadraticCurveTo(w / 2, h / 2, w / 2 - r, h / 2);
    shape.lineTo(-w / 2 + r, h / 2);
    shape.quadraticCurveTo(-w / 2, h / 2, -w / 2, h / 2 - r);
    shape.lineTo(-w / 2, -h / 2 + r);
    shape.quadraticCurveTo(-w / 2, -h / 2, -w / 2 + r, -h / 2);
    geometry = new THREE.ExtrudeGeometry(shape, { depth: d, bevelEnabled: false, curveSegments: 5 });
    geometry.translate(0, 0, -d / 2);
  } else geometry = new THREE.BoxGeometry(...size);
  const mesh = new THREE.Mesh(geometry, material);
  mesh.name = name;
  mesh.position.set(...position);
  mesh.castShadow = !material.transparent;
  mesh.receiveShadow = true;
  parent.add(mesh);
  return mesh;
}

export function createMaterials(textures = {}) {
  return {
    steel: new THREE.MeshStandardMaterial({ color: 0xd1d5d8, metalness: 0.18, roughness: 0.55, map: textures.steel ?? null, envMapIntensity: 0.35 }),
    side: new THREE.MeshStandardMaterial({ color: 0x929da6, metalness: 0.2, roughness: 0.6, envMapIntensity: 0.3 }),
    white: new THREE.MeshStandardMaterial({ color: 0xdfe3e6, roughness: 0.65, envMapIntensity: 0.3 }),
    gasket: new THREE.MeshStandardMaterial({ color: 0x56616a, roughness: 0.85 }),
    dark: new THREE.MeshStandardMaterial({ color: 0x191e23, roughness: 0.8, envMapIntensity: 0.2 }),
    glass: new THREE.MeshPhysicalMaterial({ color: 0xb7cbd6, transparent: true, opacity: 0.38, roughness: 0.1, metalness: 0, depthWrite: false, side: THREE.DoubleSide }),
    led: new THREE.MeshBasicMaterial({ color: 0xd4e0e9 }),
    wood: new THREE.MeshStandardMaterial({ color: 0xffffff, map: textures.wood ?? null, roughness: 0.85, envMapIntensity: 0.2 }),
    stone: new THREE.MeshStandardMaterial({ color: 0x3d4750, map: textures.stone ?? null, roughness: 0.78, envMapIntensity: 0.2 }),
    floor: new THREE.MeshStandardMaterial({ color: 0x7e8992, map: textures.stone ?? null, roughness: 0.9, envMapIntensity: 0.2 }),
    wall: new THREE.MeshStandardMaterial({ color: 0x9ea8b0, roughness: 0.95, envMapIntensity: 0.2 }),
  };
}

function ring(parent, name, width, height, thickness, z, material) {
  box(parent, `${name}-top`, [width, thickness, 0.024], [0, height / 2, z], material);
  box(parent, `${name}-bottom`, [width, thickness, 0.024], [0, -height / 2, z], material);
  for (const side of [-1, 1]) box(parent, `${name}-side`, [thickness, height, 0.024], [side * width / 2, 0, z], material);
}

function createDoor(side, materials, hitTargets) {
  const dir = side === 'left' ? 1 : -1;
  const door = new THREE.Group();
  door.name = `${side}Door`;
  door.position.set(-dir * 1.045, 3.02, 0.84);
  door.userData.zone = 'fresh';
  door.userData.part = door.name;
  const face = box(door, 'insulated-door', [1.025, 2.46, 0.17], [dir * 0.518, 0, 0.01], materials.steel, 0.035);
  hitTargets.push(face);
  box(door, 'molded-door-liner', [0.965, 2.35, 0.055], [dir * 0.518, 0, -0.106], materials.white, 0.04);
  const seal = new THREE.Group();
  seal.position.x = dir * 0.518;
  ring(seal, 'magnetic-gasket', 0.97, 2.36, 0.018, -0.143, materials.gasket);
  door.add(seal);
  // A shallow side recess instead of the old dark ornamental handles.
  box(door, 'recessed-handle', [0.026, 0.69, 0.028], [dir * 0.975, -0.1, 0.107], materials.dark, 0.01);
  for (const y of [-1.16, 1.16]) {
    const hinge = new THREE.Mesh(new THREE.CylinderGeometry(0.046, 0.046, 0.085, 16), materials.side);
    hinge.position.set(0, y, -0.025);
    door.add(hinge);
  }
  for (const [index, y] of [-0.88, -0.08, 0.72].entries()) {
    const bin = new THREE.Group();
    bin.name = `door-bin-${index}`;
    bin.position.set(dir * 0.518, y, -0.27);
    box(bin, 'bin-floor', [0.85, 0.028, 0.29], [0, 0, 0], materials.glass);
    box(bin, 'bin-front', [0.85, 0.19, 0.022], [0, 0.08, -0.15], materials.glass, 0.015);
    for (const x of [-0.425, 0.425]) box(bin, 'bin-side', [0.022, 0.19, 0.29], [x, 0.08, 0], materials.glass);
    door.add(bin);
  }
  // The sealing mullion follows the left door; the cabinet has no fixed center post.
  if (side === 'left') box(door, 'sealing-mullion', [0.055, 2.34, 0.055], [1.018, 0, -0.13], materials.white);
  return door;
}

function basket(parent, name, width, height, depth, y, z, materials) {
  const group = new THREE.Group();
  group.name = name;
  group.position.set(0, y, z);
  box(group, 'basket-floor', [width, 0.035, depth], [0, -height / 2, 0], materials.white);
  for (const x of [-width / 2, width / 2]) {
    box(group, 'basket-rim', [0.035, 0.035, depth], [x, height / 2, 0], materials.white);
    for (let i = 0; i < 9; i++) box(group, 'basket-slot-bar', [0.026, height, 0.022], [x, 0, -depth / 2 + i * depth / 8], materials.white);
  }
  for (const sign of [-1, 1]) {
    box(group, 'basket-end-rim', [width, 0.035, 0.03], [0, height / 2, sign * depth / 2], materials.white);
    for (let i = 0; i < 12; i++) box(group, 'basket-end-bar', [0.026, height, 0.025], [-width / 2 + i * width / 11, 0, sign * depth / 2], materials.white);
  }
  box(group, 'basket-divider', [0.025, height, depth], [0, 0, 0], materials.white);
  parent.add(group);
  return group;
}

function createDrawer(kind, materials, hitTargets) {
  const { part, y, height } = DRAWERS[kind];
  const group = new THREE.Group();
  group.name = part;
  group.userData.part = part;
  group.userData.zone = kind;
  group.position.y = y;
  const front = DRAWER_FRONT;
  const face = box(group, 'drawer-insulated-front', [front.width, height, front.depth], [0, 0, front.z], materials.steel, 0.025);
  hitTargets.push(face);
  box(group, 'drawer-liner', [1.89, height - 0.06, 0.05], [0, 0, 0.735], materials.white);
  box(group, 'drawer-handle-recess', [1.5, 0.045, front.handleDepth], [0, height / 2 - 0.045, front.handleZ], materials.dark, 0.012);
  if (kind === 'variable') {
    const { width, depth, z, floorY, rimDepth } = TRAY;
    box(group, 'tray-floor', [width, 0.035, depth], [0, floorY, z], materials.white);
    for (const sign of [-1, 1]) {
      box(group, 'tray-side', [0.044, 0.31, depth], [sign * width / 2, -0.015, z], materials.white);
      box(group, 'tray-end', [width, 0.31, rimDepth], [0, -0.015, z + sign * depth / 2], materials.white);
    }
    box(group, 'tray-divider', [0.024, 0.23, depth - 0.08], [0, -0.06, z], materials.glass);
  } else {
    for (const sign of [-1, 1]) {
      box(group, 'freezer-liner-side', [0.04, 0.64, TRAY.depth],
        [sign * (TRAY.width / 2 + 0.035), -0.155, TRAY.z], materials.white);
    }
    for (const { name, height, depth, y, z } of FREEZER_BASKETS) {
      basket(group, name, TRAY.width, height, depth, y, z, materials);
    }
  }
  for (const x of [-1, 1]) {
    box(group, 'telescopic-inner-rail', [0.032, 0.075, 1.28], [x, -height / 2 + 0.08, 0.05], materials.side);
  }
  return group;
}

export function buildFridge(materials) {
  const root = new THREE.Group();
  root.name = 'realistic-fridge-v1';
  const hitTargets = [];
  const parts = {};
  // Hollow construction: sides, back, top and dividers, never a solid box.
  for (const sign of [-1, 1]) {
    box(root, 'cabinet-side', [0.075, 4.14, 1.6], [sign * 1.035, 2.23, 0], materials.side, 0.014);
    box(root, 'fresh-liner-side', [0.045, 2.37, 1.46], [sign * 0.965, 3.01, 0], materials.white);
  }
  box(root, 'cabinet-back', [2.04, 4.15, 0.065], [0, 2.23, -0.79], materials.side);
  box(root, 'cabinet-top', [2.12, 0.065, 1.64], [0, 4.33, 0], materials.steel, 0.015);
  box(root, 'fresh-liner-back', [1.91, 2.36, 0.05], [0, 3.02, -0.705], materials.white, 0.025);
  box(root, 'fresh-liner-ceiling', [1.94, 0.05, 1.46], [0, 4.22, 0], materials.white);
  for (const y of [0.16, 1.19, 1.77]) box(root, 'insulated-divider', [2.02, 0.065, 1.5], [0, y, 0], materials.white);
  box(root, 'recessed-plinth', [1.98, 0.11, 1.4], [0, 0.1, -0.03], materials.dark);
  for (const x of [-0.87, 0.87]) for (const z of [-0.62, 0.62]) {
    const foot = new THREE.Mesh(new THREE.CylinderGeometry(0.045, 0.05, 0.09, 12), materials.dark);
    foot.position.set(x, 0.045, z); root.add(foot);
  }
  for (const y of [3.75, 3.81, 4.04, 4.1]) for (const x of [-0.52, 0.52]) {
    box(root, 'rear-air-vent', [0.47, 0.018, 0.006], [x, y, -0.673], materials.gasket);
  }
  for (const x of [-0.89, 0.89]) {
    box(root, 'shelf-mounting-rail', [0.026, 1.85, 0.018], [x, 3.13, -0.67], materials.side);
    for (let y = 2.28; y < 4.03; y += 0.14) box(root, 'rail-slot', [0.012, 0.047, 0.006], [x, y, -0.657], materials.dark);
    box(root, 'interior-led-strip', [0.018, 2.05, 0.025], [x * 1.055, 3.06, 0.39], materials.led);
  }
  for (const y of [2.34, 2.98, 3.63]) {
    box(root, 'tempered-glass-shelf', [1.86, 0.025, 1.05], [0, y, -0.1], materials.glass, 0.01);
    box(root, 'shelf-front-trim', [1.87, 0.035, 0.027], [0, y, 0.43], materials.steel);
  }
  for (const x of [-0.475, 0.475]) {
    const crisper = new THREE.Group(); crisper.name = 'humidity-crisper'; crisper.position.set(x, 2.04, -0.04);
    box(crisper, 'crisper-floor', [0.89, 0.025, 1.08], [0, -0.22, 0], materials.white);
    box(crisper, 'clear-crisper-front', [0.9, 0.43, 0.025], [0, 0, 0.55], materials.glass, 0.025);
    for (const side of [-1, 1]) box(crisper, 'clear-crisper-side', [0.02, 0.43, 1.08], [side * 0.45, 0, 0], materials.glass);
    box(crisper, 'crisper-handle', [0.66, 0.025, 0.025], [0, 0.2, 0.575], materials.white);
    root.add(crisper);
  }
  parts.leftDoor = createDoor('left', materials, hitTargets);
  parts.rightDoor = createDoor('right', materials, hitTargets);
  Object.values(parts).forEach((part) => root.add(part));
  for (const [zone, { part, y, height }] of Object.entries(DRAWERS)) {
    const drawer = createDrawer(zone, materials, hitTargets);
    parts[part] = drawer;
    root.add(drawer);
    for (const x of [-1, 1]) {
      box(root, 'fixed-outer-rail', [0.04, 0.07, 1.4], [x, y - height / 2 + 0.08, 0], materials.side);
    }
  }
  return { root, parts, hitTargets };
}

export function poseFridge(parts, state) {
  parts.leftDoor.rotation.y = -SIZE.doorAngle * state.leftDoor;
  parts.rightDoor.rotation.y = SIZE.doorAngle * state.rightDoor;
  for (const { part, travel } of Object.values(DRAWERS)) {
    parts[part].position.z = travel * state[part];
  }
}
