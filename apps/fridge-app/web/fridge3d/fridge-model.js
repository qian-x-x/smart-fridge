import * as THREE from '../vendor/three.module.min.js';
import { DRAWERS, TRAY } from './fridge-state.js?rev=blender-scene-v1';

const MODEL_SCALE = 2.33;
const MODEL_DEPTH_OFFSET = -0.76;
const DOOR_ANGLE = 1.75;
const CASE_MESHES = [
  'Fridge_Body', 'Fridge_Cap', 'Fridge_Plinth', 'Door_Gasket',
  'Foot_L_105', 'Foot_L_545', 'Foot_R_105', 'Foot_R_545',
];
const DRAWER_FACES = { variable: 'Drawer_Middle', freezer: 'Drawer_Bottom' };
const FREEZER_BASKETS = [
  { name: 'upper-sliding-basket', height: 0.22, depth: 0.64, y: 0.16, z: -0.31 },
  { name: 'lower-freezer-basket', height: 0.42, depth: TRAY.depth, y: -0.24, z: TRAY.z },
];

function box(parent, name, size, position, material, radius = 0) {
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

function createMaterials() {
  return {
    steel: new THREE.MeshStandardMaterial({ color: 0xd1d5d8, metalness: 0.18, roughness: 0.55, envMapIntensity: 0.35 }),
    side: new THREE.MeshStandardMaterial({ color: 0x929da6, metalness: 0.2, roughness: 0.6, envMapIntensity: 0.3 }),
    white: new THREE.MeshStandardMaterial({ color: 0xdfe3e6, roughness: 0.65, envMapIntensity: 0.3 }),
    gasket: new THREE.MeshStandardMaterial({ color: 0x56616a, roughness: 0.85 }),
    dark: new THREE.MeshStandardMaterial({ color: 0x191e23, roughness: 0.8, envMapIntensity: 0.2 }),
    glass: new THREE.MeshPhysicalMaterial({ color: 0xb7cbd6, transparent: true, opacity: 0.38, roughness: 0.1, metalness: 0, depthWrite: false, side: THREE.DoubleSide }),
    led: new THREE.MeshBasicMaterial({ color: 0xd4e0e9 }),
  };
}

function findMesh(imported, name) {
  const object = imported.getObjectByName(name);
  if (!object) throw new Error(`冰箱模型缺少部件 ${name}`);
  return object;
}

function attachPanels(part, panels, hitTargets) {
  for (const panel of panels) {
    part.attach(panel);
    panel.traverse((object) => {
      if (!object.isMesh) return;
      object.userData.part = part.name;
      hitTargets.push(object);
    });
  }
}

function ring(parent, name, width, height, thickness, z, material) {
  box(parent, `${name}-top`, [width, thickness, 0.024], [0, height / 2, z], material);
  box(parent, `${name}-bottom`, [width, thickness, 0.024], [0, -height / 2, z], material);
  for (const side of [-1, 1]) box(parent, `${name}-side`, [thickness, height, 0.024], [side * width / 2, 0, z], material);
}

function createDoor(fridge, imported, side, materials, hitTargets) {
  const dir = side === 'left' ? 1 : -1;
  const suffix = side === 'left' ? 'L' : 'R';
  const face = findMesh(imported, `Door_Upper_${suffix}`);
  const bounds = new THREE.Box3().setFromObject(face, true);
  const { x: width, y: height } = bounds.getSize(new THREE.Vector3());
  const center = bounds.getCenter(new THREE.Vector3());
  const door = new THREE.Group();
  door.name = `${side}Door`;
  door.position.set(dir > 0 ? bounds.min.x : bounds.max.x, center.y, bounds.min.z);
  door.userData.zone = 'fresh';
  door.userData.part = door.name;
  fridge.add(door);
  attachPanels(door, [
    face,
    ...[`Handle_Bar_${suffix}`, `Handle_Standoff_${suffix}_0`, `Handle_Standoff_${suffix}_1`]
      .map((name) => findMesh(imported, name)),
  ], hitTargets);
  const centerX = center.x - door.position.x;
  box(door, 'molded-door-liner', [width - 0.05, height - 0.08, 0.055], [centerX, 0, -0.028], materials.white, 0.04);
  const seal = new THREE.Group();
  seal.position.x = centerX;
  ring(seal, 'magnetic-gasket', width - 0.06, height - 0.1, 0.018, -0.06, materials.gasket);
  door.add(seal);
  for (const [index, y] of [-0.88, -0.08, 0.72].entries()) {
    const bin = new THREE.Group();
    bin.name = `door-bin-${index}`;
    bin.position.set(centerX, y, -0.21);
    box(bin, 'bin-floor', [0.85, 0.028, 0.29], [0, 0, 0], materials.glass);
    box(bin, 'bin-front', [0.85, 0.19, 0.022], [0, 0.08, -0.15], materials.glass, 0.015);
    for (const x of [-0.425, 0.425]) box(bin, 'bin-side', [0.022, 0.19, 0.29], [x, 0.08, 0], materials.glass);
    door.add(bin);
  }
  // The sealing mullion follows the left door; the cabinet has no fixed center post.
  if (side === 'left') box(door, 'sealing-mullion', [0.08, height - 0.02, 0.055], [width - 0.016, 0, -0.08], materials.dark);
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

function createDrawer(fridge, imported, kind, materials, hitTargets) {
  const { part, y, height } = DRAWERS[kind];
  const group = new THREE.Group();
  group.name = part;
  group.userData.part = part;
  group.userData.zone = kind;
  group.position.y = y;
  fridge.add(group);
  const face = DRAWER_FACES[kind];
  attachPanels(group, [findMesh(imported, face), findMesh(imported, `${face}_Pocket`)], hitTargets);
  box(group, 'drawer-liner', [1.96, height - 0.075, 0.035], [0, 0, 0.768], materials.white);
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
    box(group, 'telescopic-inner-rail', [0.032, 0.075, 1.28], [x, -height / 2 + 0.08, 0.06], materials.side);
  }
  return group;
}

export function buildFridge(imported) {
  const materials = createMaterials();
  const root = new THREE.Group();
  root.name = 'blender-fridge-scene';
  // The export is Y-up with its back at Z=0. Keep the existing camera and
  // inventory coordinates centred on the depth of the cabinet.
  imported.name = 'kitchen';
  imported.scale.setScalar(MODEL_SCALE);
  imported.position.z = MODEL_DEPTH_OFFSET;
  imported.traverse((object) => {
    if (!object.isMesh) return;
    object.castShadow = object.name !== 'Floor' && object.name !== 'Wall_Back';
    object.receiveShadow = true;
  });
  const fridge = new THREE.Group();
  fridge.name = 'fridge';
  root.add(imported, fridge);
  for (const name of CASE_MESHES) fridge.attach(findMesh(imported, name));
  const hitTargets = [];
  for (const sign of [-1, 1]) {
    box(fridge, 'fresh-liner-side', [0.035, 2.45, 1.40], [sign * 1.028, 3.02, 0.03], materials.white);
  }
  box(fridge, 'fresh-liner-back', [2.06, 2.45, 0.035], [0, 3.02, -0.644], materials.white, 0.025);
  box(fridge, 'fresh-liner-ceiling', [2.06, 0.04, 1.40], [0, 4.255, 0.03], materials.white);
  box(fridge, 'fresh-liner-floor', [2.06, 0.04, 1.40], [0, 1.78, 0.03], materials.white);
  for (const y of [3.75, 3.81, 4.04, 4.1]) for (const x of [-0.52, 0.52]) {
    box(fridge, 'rear-air-vent', [0.47, 0.018, 0.006], [x, y, -0.623], materials.gasket);
  }
  for (const x of [-0.89, 0.89]) {
    box(fridge, 'shelf-mounting-rail', [0.026, 1.85, 0.018], [x, 3.13, -0.615], materials.side);
    for (let y = 2.28; y < 4.03; y += 0.14) box(fridge, 'rail-slot', [0.012, 0.047, 0.006], [x, y, -0.602], materials.dark);
    box(fridge, 'interior-led-strip', [0.018, 2.05, 0.025], [x * 1.055, 3.06, 0.39], materials.led);
  }
  for (const y of [2.34, 2.98, 3.63]) {
    box(fridge, 'tempered-glass-shelf', [1.86, 0.025, 1.05], [0, y, -0.1], materials.glass, 0.01);
    box(fridge, 'shelf-front-trim', [1.87, 0.035, 0.027], [0, y, 0.43], materials.steel);
  }
  for (const x of [-0.475, 0.475]) {
    const crisper = new THREE.Group(); crisper.name = 'humidity-crisper'; crisper.position.set(x, 2.04, -0.04);
    box(crisper, 'crisper-floor', [0.89, 0.025, 1.08], [0, -0.22, 0], materials.white);
    box(crisper, 'clear-crisper-front', [0.9, 0.43, 0.025], [0, 0, 0.55], materials.glass, 0.025);
    for (const side of [-1, 1]) box(crisper, 'clear-crisper-side', [0.02, 0.43, 1.08], [side * 0.45, 0, 0], materials.glass);
    box(crisper, 'crisper-handle', [0.66, 0.025, 0.025], [0, 0.2, 0.575], materials.white);
    fridge.add(crisper);
  }
  const parts = {
    leftDoor: createDoor(fridge, imported, 'left', materials, hitTargets),
    rightDoor: createDoor(fridge, imported, 'right', materials, hitTargets),
  };
  for (const [zone, { part, y, height }] of Object.entries(DRAWERS)) {
    parts[part] = createDrawer(fridge, imported, zone, materials, hitTargets);
    for (const x of [-1.028, 1.028]) {
      box(fridge, 'fixed-outer-rail', [0.025, 0.07, 1.31], [x, y - height / 2 + 0.08, 0.05], materials.side);
    }
  }
  return { root, parts, hitTargets };
}

export function poseFridge(parts, state) {
  parts.leftDoor.rotation.y = -DOOR_ANGLE * state.leftDoor;
  parts.rightDoor.rotation.y = DOOR_ANGLE * state.rightDoor;
  for (const { part, travel } of Object.values(DRAWERS)) {
    parts[part].position.z = travel * state[part];
  }
}
