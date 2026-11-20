import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from '../../apps/fridge-app/web/vendor/three.module.min.js';
import { buildFridge, createMaterials, poseFridge } from '../../apps/fridge-app/web/fridge3d/fridge-model.js';
import { buildKitchen } from '../../apps/fridge-app/web/fridge3d/kitchen-scene.js';
import { projectStickerSlot, stickerLayout } from '../../apps/fridge-app/web/fridge3d/sticker-layout.js';
import {
  CAMERA_FOV, CAMERA_TRANSITION_MS, DRAWERS, PARTS, ZONES, applyCameraPose,
  cameraPose, createViewState, interpolateCamera, normalizeFoods, transition,
} from '../../apps/fridge-app/web/fridge3d/fridge-state.js';

const openParts = (state) => PARTS.filter((part) => state[part]);

test('selecting either drawer closes every other part, including when all are open in overview', () => {
  const bothDoors = transition(createViewState(), 'focusZone', 'fresh');
  const overview = transition(bothDoors, 'overview');
  assert.deepEqual(openParts(overview), PARTS);
  for (const [zone, { part }] of Object.entries(DRAWERS)) {
    const selected = transition(overview, 'togglePart', part);
    assert.equal(selected.focus, zone);
    assert.deepEqual(openParts(selected), [part]);
    const otherZone = zone === 'freezer' ? 'variable' : 'freezer';
    const switched = transition(selected, 'focusZone', otherZone);
    assert.deepEqual(openParts(switched), [DRAWERS[otherZone].part]);
    assert.deepEqual(openParts(transition(selected, 'togglePart', part)), []);
  }
  assert.deepEqual(openParts(transition(overview, 'closeAll')), []);
});

test('the upper cold-storage doors retain their shared compartment and independent controls', () => {
  const right = transition(createViewState(), 'togglePart', 'rightDoor');
  assert.equal(right.zone, 'fresh'); assert.equal(right.rightDoor, 1);
  const fresh = transition(right, 'focusZone', 'fresh');
  assert.equal(fresh.leftDoor, 1); assert.equal(fresh.rightDoor, 1);
  assert.deepEqual(openParts(transition(fresh, 'togglePart', 'rightDoor')), ['leftDoor']);
  assert.equal(cameraPose('fresh', 1).pitch, 0.06);
  assert.deepEqual(transition(fresh, 'togglePart', 'unknown'), fresh);
});

test('doors pivot on the outer edges and the drawers move with their trays and baskets', () => {
  const model = buildFridge(createMaterials());
  poseFridge(model.parts, transition(createViewState(), 'closeAll'));
  assert.equal(Math.abs(model.parts.leftDoor.rotation.y), 0);
  assert.equal(model.parts.rightDoor.userData.zone, 'fresh');
  assert.equal(model.parts.leftDoor.position.x, -model.parts.rightDoor.position.x);
  const origin = model.parts.freezerDrawer.position.clone();
  const middleOrigin = model.parts.middleDrawer.position.clone();
  poseFridge(model.parts, transition(createViewState(), 'overview'));
  assert.equal(model.parts.freezerDrawer.position.z - origin.z, DRAWERS.freezer.travel);
  assert.equal(model.parts.middleDrawer.position.z - middleOrigin.z, DRAWERS.variable.travel);
  assert.ok(model.parts.leftDoor.rotation.y < 0 && model.parts.rightDoor.rotation.y > 0);
  assert.ok(model.parts.freezerDrawer.getObjectByName('lower-freezer-basket'));
  assert.ok(model.parts.freezerDrawer.getObjectByName('upper-sliding-basket'));
  assert.ok(model.parts.middleDrawer.getObjectByName('tray-floor'));
  assert.ok(model.parts.middleDrawer.position.y > model.parts.freezerDrawer.position.y);
  assert.ok(!model.root.getObjectByName('carcass-solid'));
  const bounds = new THREE.Box3().setFromObject(model.root);
  assert.ok(bounds.min.y >= -0.02 && bounds.max.y < 4.5);
});

test('inventory normalization filters invalid stock and unsafe asset names without capping inventory', () => {
  const food = { name: 'milk', zone: 'fresh', quantity: 2 };
  assert.deepEqual(normalizeFoods(null), []);
  const foods = normalizeFoods([
    { ...food, id: '1', artwork: '\u725b\u5976', layers: 6, portions: '5.5' },
    { ...food, id: '2', artwork: '../private', layers: 0, portions: '123<invalid' },
    { ...food, id: '3', zone: 'pantry' },
    { ...food, id: '4', quantity: 0 },
    { ...food, quantity: -1 },
  ]);
  assert.equal(foods.length, 2);
  assert.equal(foods[0].artwork, '\u725b\u5976');
  assert.equal(foods[1].artwork, null);
  assert.deepEqual(foods.map(({ layers, portions }) => [layers, portions]), [[3, '5.5'], [1, null]]);
  assert.equal(normalizeFoods(Array.from({ length: 235 }, (_, id) => ({ ...food, id: String(id) }))).length, 235);
});

test('shelves show only the side opened and make space for both sets of positions', () => {
  const closed = createViewState();
  assert.deepEqual(stickerLayout('fresh', closed, 24), { capacity: 24, slots: [] });
  assert.deepEqual(stickerLayout('freezer', closed, 16), { capacity: 16, slots: [] });
  const left = transition(closed, 'togglePart', 'leftDoor');
  const right = transition(closed, 'togglePart', 'rightDoor');
  const leftSlots = stickerLayout('fresh', left, 24).slots;
  const rightSlots = stickerLayout('fresh', right, 24).slots;
  assert.equal(leftSlots.length, 12);
  assert.equal(rightSlots.length, 12);
  assert.ok(leftSlots.every((slot) => slot.center[0] < 0 && slot.index % 2 === 0));
  assert.ok(rightSlots.every((slot) => slot.center[0] > 0 && slot.index % 2 === 1));
  const both = stickerLayout('fresh', transition(closed, 'focusZone', 'fresh'), 25);
  assert.equal(both.capacity, 24);
  assert.deepEqual(both.slots.map((slot) => slot.index).sort((a, b) => a - b),
    Array.from({ length: 24 }, (_, i) => i));
});

test('a seventeenth ingredient kind changes each drawer from 16 to 32 slots', () => {
  for (const zone of Object.keys(DRAWERS)) {
    const opened = transition(createViewState(), 'focusZone', zone);
    for (const [kinds, capacity] of [[0, 16], [16, 16], [17, 32], [32, 32], [33, 32]]) {
      const layout = stickerLayout(zone, opened, kinds);
      assert.equal(layout.capacity, capacity);
      assert.equal(layout.slots.length, capacity);
      assert.equal(new Set(layout.slots.map((slot) => slot.center.join(','))).size, capacity);
    }
  }
});

test('the model and the kitchen contain only the three retained storage areas', () => {
  const materials = createMaterials();
  const scene = new THREE.Scene();
  const { parts } = buildFridge(materials);
  buildKitchen(scene, materials);
  assert.deepEqual(ZONES, ['fresh', 'variable', 'freezer']);
  assert.deepEqual(PARTS, ['leftDoor', 'rightDoor', 'middleDrawer', 'freezerDrawer']);
  assert.deepEqual(Object.keys(parts), PARTS);
  const worktops = scene.getObjectByName('kitchen').children.filter((object) => object.name === 'worktop');
  assert.equal(worktops.length, 2);
  assert.ok(worktops.every((worktop) => !worktop.userData.zone));
  assert.equal(scene.getObjectByName('sink-basin'), undefined);
  assert.equal(transition(createViewState(), 'focusZone', 'pantry').focus, null);
});

test('the first click on cold storage and clicks on other zones start a focused view', () => {
  let view = createViewState();
  assert.equal(view.zone, 'fresh');
  assert.equal(view.focus, null);
  for (const zone of ZONES) {
    view = transition(view, 'focusZone', zone);
    assert.equal(view.focus, zone);
  }
  assert.equal(transition(view, 'overview').focus, null);
});

test('the camera advances through intermediate poses over 400 ms and retargets from its current pose', () => {
  assert.equal(CAMERA_TRANSITION_MS, 400);
  const overview = cameraPose(null, 0.7);
  assert.ok(cameraPose(null, 0.55).distance > cameraPose(null, 1.6).distance);
  for (const zone of ZONES) {
    const target = cameraPose(zone, 0.7);
    const progress = [0, 100, 200, 300, 400].map((ms) => interpolateCamera(overview, target, ms));
    assert.equal(progress[0], overview);
    assert.equal(progress[4], target);
    assert.ok(progress.every((pose, i) => i === 0 || pose.distance < progress[i - 1].distance));
    assert.notEqual(progress[2].pitch, target.pitch);
    assert.equal(interpolateCamera(progress[2], cameraPose('variable', 0.7), 0), progress[2]);
  }
});

test('both vertical views frame the complete drawer and its inventory on narrow and wide screens', () => {
  const model = buildFridge(createMaterials());
  for (const [zone, { part, travel }] of Object.entries(DRAWERS)) {
    const opened = transition(createViewState(), 'focusZone', zone);
    poseFridge(model.parts, opened);
    model.root.updateMatrixWorld(true);
    assert.equal(model.parts[part].position.z, travel);
    const outline = new THREE.Box3().setFromObject(model.parts[part], true);
    assert.ok(outline.min.z > 0.98, 'the drawer rear clears the closed cabinet');
    for (const aspect of [284 / 352, 354 / 352, 1, 948 / 502]) {
      const camera = new THREE.PerspectiveCamera(CAMERA_FOV, aspect, 0.1, 60);
      const pose = cameraPose(zone, aspect);
      applyCameraPose(camera, pose);
      camera.updateMatrixWorld(true);
      assert.ok(camera.getWorldDirection(new THREE.Vector3()).distanceTo(new THREE.Vector3(0, -1, 0)) < 1e-8);
      let extent = 0;
      for (const x of [outline.min.x, outline.max.x]) for (const z of [outline.min.z, outline.max.z]) {
        const screen = new THREE.Vector3(x, outline.max.y, z).project(camera);
        extent = Math.max(extent, Math.abs(screen.x), Math.abs(screen.y));
      }
      assert.ok(extent > 0.85 && extent < 0.95, `${zone} outline at aspect ${aspect} has a visible margin`);
      const height = 352, width = height * aspect;
      const sparse = stickerLayout(zone, opened, 16).slots;
      const dense = stickerLayout(zone, opened, 17).slots;
      assert.ok(projectStickerSlot(dense[0], camera, width, height).size <
        projectStickerSlot(sparse[0], camera, width, height).size);
      for (const slot of [...sparse, ...dense]) assertStickerFits(slot, camera, width, height);
    }
  }
});

test('cold door stickers fit their cells in an angled view as well as straight on', () => {
  const opened = transition(createViewState(), 'focusZone', 'fresh');
  for (const aspect of [284 / 352, 948 / 502]) {
    const height = 352, width = height * aspect;
    const camera = new THREE.PerspectiveCamera(CAMERA_FOV, aspect, 0.1, 60);
    const pose = cameraPose('fresh', aspect);
    for (const yaw of [-.24, 0, .24]) {
      applyCameraPose(camera, { ...pose, yaw });
      camera.updateMatrixWorld(true);
      for (const slot of stickerLayout('fresh', opened, 24).slots) {
        assertStickerFits(slot, camera, width, height);
      }
    }
  }
});

function assertStickerFits(slot, camera, width, height) {
  const { x, y, size } = projectStickerSlot(slot, camera, width, height);
  assert.ok(size > 0);
  const corners = slot.corners.map(([px, py, pz]) => {
    const point = new THREE.Vector3(px, py, pz).project(camera);
    return [(1 + point.x) * width / 2, (1 - point.y) * height / 2];
  });
  // The visible, raised hover picture stays within the slot too.
  for (const px of [x - size * .52, x + size * .52]) {
    for (const py of [y - size * .62, y + size * .42]) {
      assert.ok(px > 0 && px < width && py > 0 && py < height);
      const sides = corners.map(([left, top], index) => {
        const [right, bottom] = corners[(index + 1) % corners.length];
        return (right - left) * (py - top) - (bottom - top) * (px - left);
      });
      assert.ok(sides.every((side) => side >= 0) || sides.every((side) => side <= 0));
    }
  }
}
