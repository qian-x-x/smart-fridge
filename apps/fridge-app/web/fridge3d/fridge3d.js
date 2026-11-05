import * as THREE from '../vendor/three.module.min.js';
import { RoomEnvironment } from '../vendor/RoomEnvironment.js';
import { buildFridge, createMaterials, poseFridge, replaceInventory } from './fridge-model.js?rev=warm-harvest-v1.5.1';
import { buildKitchen, createTexture } from './kitchen-scene.js?rev=warm-harvest-v1.5.1';
import { createViewState, transition, fitDistance, normalizeFoods, PARTS, ZONES } from './fridge-state.js?rev=warm-harvest-v1.5.1';

const canvas = document.querySelector('#fridge-canvas');
const stage = document.querySelector('#scene');
const loading = document.querySelector('#loading');
const liveStatus = document.querySelector('#live-status');
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
let renderer, scene, camera, model, room, observer;
let view = createViewState();
let animated = { ...view };
let yaw = 0.1, targetYaw = yaw, pitch = 0.09, targetPitch = pitch;
let distance = 10;
let lastFrame = performance.now();
let pointerDown = null;
let moved = 0;
let pantrySelected = false;
let sceneFailed = false;
const pointer = new THREE.Vector2();
const raycaster = new THREE.Raycaster();

try { init(); } catch (error) { showError(error); }

function init() {
  renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: false, powerPreference: 'high-performance' });
  renderer.setPixelRatio(Math.min(devicePixelRatio || 1, 1.75));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 0.9;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  scene = new THREE.Scene(); scene.background = new THREE.Color(0xfcf5e9);
  scene.fog = new THREE.Fog(0xfcf5e9, 17, 33);
  camera = new THREE.PerspectiveCamera(32, 1, 0.1, 60);
  const pmrem = new THREE.PMREMGenerator(renderer);
  const environment = new RoomEnvironment();
  const environmentTarget = pmrem.fromScene(environment, 0.04);
  scene.environment = environmentTarget.texture;
  environment.dispose(); pmrem.dispose();
  const materials = createMaterials({ steel: createTexture('steel'), wood: createTexture('wood'), stone: createTexture('stone') });
  model = buildFridge(materials); scene.add(model.root);
  room = buildKitchen(scene, materials, model.foodGroups.pantry);
  scene.add(new THREE.HemisphereLight(0xfff7e9, 0xbba382, 1.15));
  const sun = new THREE.DirectionalLight(0xffedd8, 2.25);
  sun.position.set(-4.5, 6.5, 4.5); sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048); sun.shadow.camera.left = -6; sun.shadow.camera.right = 6;
  sun.shadow.camera.top = 6; sun.shadow.camera.bottom = -4; sun.shadow.normalBias = 0.018;
  sun.target.position.set(0, 1.5, 0); scene.add(sun, sun.target);
  const fill = new THREE.DirectionalLight(0xfff1e1, 0.7); fill.position.set(4, 4, 7); scene.add(fill);
  const interiorLight = new THREE.PointLight(0xf0fffa, 1.8, 3.2, 2); interiorLight.position.set(0, 3.72, 0.1); scene.add(interiorLight);
  bindInputs();
  observer = new ResizeObserver(resize); observer.observe(document.body);
  resize(); updateStatus();
  renderer.setAnimationLoop(render);
  stage.dataset.ready = 'true';
  post({ type: 'ready' });
  window.addEventListener('pagehide', () => {
    renderer.setAnimationLoop(null); observer.disconnect();
    scene.traverse((object) => { object.geometry?.dispose(); });
    Object.values(materials).forEach((material) => { material.map?.dispose(); material.dispose(); });
    environmentTarget.dispose(); renderer.dispose();
  }, { once: true });
}

function render(now) {
  const delta = Math.min(0.05, (now - lastFrame) / 1000); lastFrame = now;
  const amount = reducedMotion ? 1 : 1 - Math.exp(-9 * delta);
  yaw += (targetYaw - yaw) * amount; pitch += (targetPitch - pitch) * amount;
  for (const part of PARTS) animated[part] += (view[part] - animated[part]) * amount;
  const settled = PARTS.every((part) => Math.abs(view[part] - animated[part]) < 0.003) &&
    Math.abs(yaw - targetYaw) < 0.002 && Math.abs(pitch - targetPitch) < 0.002;
  const settledValue = String(settled);
  if (stage.dataset.settled !== settledValue) stage.dataset.settled = settledValue;
  poseFridge(model.parts, animated);
  camera.position.set(Math.sin(yaw) * distance, 2.04 + Math.sin(pitch) * distance, Math.cos(yaw) * distance);
  camera.lookAt(pantrySelected ? -0.4 : 0, 2.04, 0.15);
  renderer.render(scene, camera);
  loading.classList.add('is-hidden');
}

function resize() {
  if (!renderer) return;
  const { width, height } = document.body.getBoundingClientRect();
  camera.aspect = Math.max(width, 1) / Math.max(height, 1);
  distance = fitDistance(camera.aspect, 32) * (height < 480 ? 1.08 : 1);
  camera.updateProjectionMatrix(); renderer.setSize(Math.max(width, 1), Math.max(height, 1), false);
}

function setView(action, value, fromFlutter = false) {
  stage.dataset.settled = 'false';
  view = transition(view, action, value);
  pantrySelected = view.zone === 'pantry';
  if (action === 'overview') { targetYaw = 0.1; targetPitch = 0.09; }
  targetPitch = view.zone === 'variable' || view.zone === 'freezer' ? 0.16 : 0.09;
  updateStatus();
  if (action === 'togglePart' || action === 'focusZone' || action === 'overview') post({ type: 'zone-selected', zone: view.zone, fromFlutter });
}

function updateStatus() {
  const openParts = PARTS.filter((part) => view[part] > 0);
  document.querySelectorAll('.controls [data-part]').forEach((button) => {
    const isOpen = openParts.includes(button.dataset.part);
    button.setAttribute('aria-pressed', String(isOpen));
    button.title = `${button.textContent}：已${isOpen ? '开启，点击关闭' : '关闭，点击开启'}`;
  });
  stage.dataset.zone = view.zone; stage.dataset.openParts = openParts.join(',');
  stage.dataset.sceneVersion = 'warm-harvest-v1.5.1';
  const label = { fresh: '冷藏室', variable: '变温抽屉', freezer: '冷冻抽屉', pantry: '厨房常温柜台' }[view.zone];
  liveStatus.textContent = `${label}，${openParts.length === 0 ? '冰箱已关闭' : '可拖动查看内部结构'}`;
}

function bindInputs() {
  document.querySelector('#overview').addEventListener('click', () => setView('overview'));
  document.querySelector('#close-all').addEventListener('click', () => setView('closeAll'));
  document.querySelector('#left-door').addEventListener('click', () => setView('togglePart', 'leftDoor'));
  document.querySelector('#right-door').addEventListener('click', () => setView('togglePart', 'rightDoor'));
  document.querySelector('#variable-drawer').addEventListener('click', () => setView('togglePart', 'middleDrawer'));
  document.querySelector('#freezer-drawer').addEventListener('click', () => setView('togglePart', 'freezerDrawer'));
  canvas.addEventListener('pointerdown', (event) => {
    pointerDown = { x: event.clientX, y: event.clientY, id: event.pointerId }; moved = 0;
    canvas.setPointerCapture(event.pointerId); canvas.style.cursor = 'grabbing';
  });
  canvas.addEventListener('pointermove', (event) => {
    if (!pointerDown) return;
    const dx = event.clientX - pointerDown.x, dy = event.clientY - pointerDown.y;
    moved += Math.abs(dx) + Math.abs(dy);
    targetYaw = THREE.MathUtils.clamp(targetYaw + dx * 0.004, -0.28, 0.28);
    targetPitch = THREE.MathUtils.clamp(targetPitch + dy * 0.0016, 0.02, 0.24);
    pointerDown.x = event.clientX; pointerDown.y = event.clientY;
  });
  canvas.addEventListener('pointerup', (event) => {
    if (!pointerDown) return;
    pointerDown = null;
    if (canvas.hasPointerCapture(event.pointerId)) canvas.releasePointerCapture(event.pointerId);
    canvas.style.cursor = 'grab';
    if (moved > 6) return;
    const rect = canvas.getBoundingClientRect();
    pointer.set((event.clientX - rect.left) / rect.width * 2 - 1, -(event.clientY - rect.top) / rect.height * 2 + 1);
    raycaster.setFromCamera(pointer, camera);
    const hit = raycaster.intersectObjects([...model.hitTargets, room.pantryHit], false)[0];
    if (!hit) return;
    let object = hit.object;
    while (object && !object.userData.part && !object.userData.zone) object = object.parent;
    if (object?.userData.part) setView('togglePart', object.userData.part);
    else if (object?.userData.zone) setView('focusZone', object.userData.zone);
  });
  canvas.addEventListener('pointercancel', () => { pointerDown = null; canvas.style.cursor = 'grab'; });
  canvas.addEventListener('keydown', (event) => {
    if (/^[1-4]$/.test(event.key)) { event.preventDefault(); setView('focusZone', ZONES[Number(event.key) - 1]); }
    if (event.key === '0') setView('overview');
    if (event.key === 'Escape') setView('closeAll');
  });
  canvas.addEventListener('webglcontextlost', (event) => { event.preventDefault(); showError(new Error('三维场景已暂停，请重新加载页面或打开食材清单')); });
  window.addEventListener('message', (event) => {
    if (event.source !== parent || event.origin !== location.origin) return;
    let message;
    try { message = typeof event.data === 'string' ? JSON.parse(event.data) : event.data; } catch { return; }
    if (message?.type !== 'smart-fridge-command') return;
    if (message.action === 'setInteractive' && typeof message.enabled === 'boolean') {
      stage.dataset.active = String(message.enabled);
      if (pointerDown && canvas.hasPointerCapture(pointerDown.id)) canvas.releasePointerCapture(pointerDown.id);
      pointerDown = null;
      canvas.style.cursor = 'grab';
      lastFrame = performance.now();
      if (!sceneFailed) renderer.setAnimationLoop(message.enabled ? render : null);
    }
    if (message.action === 'focusZone' && ZONES.includes(message.zone)) setView('focusZone', message.zone, true);
    if (message.action === 'resetView') setView('overview');
    if (message.action === 'inventory') {
      const foods = normalizeFoods(message.foods);
      replaceInventory(model.foodGroups, foods);
      stage.dataset.inventoryCount = String(foods.length);
    }
  });
}

function post(payload) { parent.postMessage(JSON.stringify({ source: 'smart-fridge-3d', ...payload }), location.origin); }
function showError(error) {
  sceneFailed = true;
  renderer?.setAnimationLoop(null);
  document.querySelector('#fallback').classList.add('is-visible');
  loading.classList.add('is-hidden'); canvas.style.display = 'none';
  stage.dataset.ready = 'error';
  post({ type: 'error', message: error instanceof Error ? error.message : String(error) });
  console.error('Kitchen scene unavailable', error);
}
