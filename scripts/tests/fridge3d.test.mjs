import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from '../../apps/fridge-app/web/vendor/three.module.min.js';
import { buildFridge, createMaterials, poseFridge, replaceInventory, SIZE } from '../../apps/fridge-app/web/fridge3d/fridge-model.js';
import { PARTS, createViewState, transition, fitDistance, normalizeFoods } from '../../apps/fridge-app/web/fridge3d/fridge-state.js';

test('all doors and drawers keep independent open states until individually or collectively closed', () => {
  let state = transition(createViewState(), 'closeAll');
  for (const part of PARTS) {
    state = transition(state, 'togglePart', part);
    assert.equal(state[part], 1);
  }
  assert.ok(PARTS.every((part) => state[part] > 0));
  state = transition(state, 'togglePart', 'leftDoor');
  assert.equal(state.leftDoor, 0);
  assert.ok(PARTS.filter((part) => part !== 'leftDoor').every((part) => state[part] > 0));
  state = transition(state, 'focusZone', 'fresh');
  assert.ok(PARTS.every((part) => state[part] > 0));
  state = transition(state, 'closeAll');
  assert.ok(PARTS.every((part) => state[part] === 0));
});

test('both upper doors serve the fresh cavity; ambient storage does not move either', () => {
  const closed = transition(createViewState(), 'closeAll');
  const pantry = transition(closed, 'focusZone', 'pantry');
  assert.equal(pantry.leftDoor, 0); assert.equal(pantry.rightDoor, 0);
  const right = transition(pantry, 'togglePart', 'rightDoor');
  assert.equal(right.zone, 'fresh'); assert.equal(right.rightDoor, 1);
  const fresh = transition(right, 'focusZone', 'fresh');
  assert.equal(fresh.leftDoor, 1); assert.equal(fresh.rightDoor, 1);
  assert.deepEqual(transition(fresh, 'togglePart', 'unknown'), fresh);
});

test('doors pivot on the outer edges, drawer movement preserves its rails and basket hierarchy', () => {
  const model = buildFridge(createMaterials());
  poseFridge(model.parts, transition(createViewState(), 'closeAll'));
  assert.equal(Math.abs(model.parts.leftDoor.rotation.y), 0);
  assert.equal(model.parts.rightDoor.userData.zone, 'fresh');
  assert.equal(model.parts.leftDoor.position.x, -model.parts.rightDoor.position.x);
  const origin = model.parts.freezerDrawer.position.clone();
  poseFridge(model.parts, { ...createViewState(), freezerDrawer: 1, middleDrawer: 1 });
  assert.equal(model.parts.freezerDrawer.position.z - origin.z, SIZE.freezerTravel);
  assert.ok(model.parts.leftDoor.rotation.y < 0 && model.parts.rightDoor.rotation.y > 0);
  assert.ok(model.parts.freezerDrawer.getObjectByName('lower-freezer-basket'));
  assert.ok(model.parts.freezerDrawer.getObjectByName('upper-sliding-basket'));
  assert.ok(!model.root.getObjectByName('carcass-solid'));
  const bounds = new THREE.Box3().setFromObject(model.root);
  assert.ok(bounds.min.y >= -0.02 && bounds.max.y < 4.5);
});

test('empty real inventory clears scene objects and bounds each record placement', () => {
  const model = buildFridge(createMaterials());
  const foods = normalizeFoods([
    { id: '1', name: '牛奶', zone: 'fresh', quantity: 2 },
    { id: '2', name: '调料', zone: 'pantry', quantity: 1 },
    { name: '无效', zone: 'fresh', quantity: -1 },
    { name: '未知区', zone: 'invalid', quantity: 1 },
  ]);
  replaceInventory(model.foodGroups, foods);
  assert.equal(model.foodGroups.fresh.children.length, 1);
  assert.equal(model.foodGroups.pantry.children.length, 1);
  assert.equal(model.foodGroups.pantry.parent, null);
  replaceInventory(model.foodGroups, []);
  assert.ok(Object.values(model.foodGroups).every((group) => group.children.length === 0));
});

test('portrait camera increases fit distance enough to retain open doors', () => {
  assert.ok(fitDistance(0.6) > fitDistance(1.6));
  for (const aspect of [0.6, 0.8, 1.6, 2.5]) {
    const visibleHeight = 2 * fitDistance(aspect) * Math.tan(32 * Math.PI / 360);
    assert.ok(visibleHeight >= 5.24);
    assert.ok(visibleHeight * aspect >= 3.44);
  }
});
