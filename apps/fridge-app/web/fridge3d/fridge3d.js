import * as THREE from '../vendor/three.module.min.js';
import { RoomEnvironment } from '../vendor/RoomEnvironment.js';
import { buildFridge, createMaterials, poseFridge } from './fridge-model.js?rev=fridge-sticker-grid-v2.3';
import { buildKitchen, createTexture } from './kitchen-scene.js?rev=fridge-sticker-grid-v2.3';
import { StickerInventory } from './sticker-inventory.js?rev=fridge-sticker-grid-v2.3';
import {
  CAMERA_FOV, CAMERA_TRANSITION_MS, PARTS, ZONES, applyCameraPose, cameraPose,
  createViewState, interpolateCamera, isOverhead, transition,
} from './fridge-state.js?rev=fridge-sticker-grid-v2.3';

const canvas = document.querySelector('#fridge-canvas');
const stage = document.querySelector('#scene');
const loading = document.querySelector('#loading');
const liveStatus = document.querySelector('#live-status');
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
let renderer, scene, camera, model, observer;
let view = createViewState();
let animated = { ...view };
let cameraFrame, cameraMove, lastFrame;
let orbitYaw = 0, targetOrbitYaw = 0, orbitPitch = 0, targetOrbitPitch = 0;
let pointerDown = null;
let moved = 0;
let sceneFailed = false;
let needsRender = true;
const pointer = new THREE.Vector2();
const raycaster = new THREE.Raycaster();
const inventory = new StickerInventory(
  (foodId, revision) => post({ type: 'food-selected', foodId, revision }),
  () => { needsRender = true; },
);

try { init(); } catch (error) { showError(error); }

function init() {
  renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: false, powerPreference: 'high-performance' });
  renderer.setPixelRatio(Math.min(devicePixelRatio || 1, 1.75));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 0.78;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.shadowMap.autoUpdate = false;
  renderer.shadowMap.needsUpdate = true;
  scene = new THREE.Scene(); scene.background = new THREE.Color(0xc9cfd3);
  scene.fog = new THREE.Fog(0xc9cfd3, 17, 33);
  camera = new THREE.PerspectiveCamera(CAMERA_FOV, 1, 0.1, 60);
  const pmrem = new THREE.PMREMGenerator(renderer);
  const environment = new RoomEnvironment();
  const environmentTarget = pmrem.fromScene(environment, 0.04);
  scene.environment = environmentTarget.texture;
  scene.environmentIntensity = 0.55;
  environment.dispose(); pmrem.dispose();
  const materials = createMaterials({ steel: createTexture('steel'), wood: createTexture('wood'), stone: createTexture('stone') });
  model = buildFridge(materials); scene.add(model.root);
  buildKitchen(scene, materials);
  scene.add(new THREE.HemisphereLight(0xf2f6fa, 0x929da7, 0.9));
  const sun = new THREE.DirectionalLight(0xf2f6fa, 1.6);
  sun.position.set(-4.5, 6.5, 4.5); sun.castShadow = true;
  sun.shadow.mapSize.set(1024, 1024); sun.shadow.intensity = 0.55;
  sun.shadow.camera.left = -6; sun.shadow.camera.right = 6;
  sun.shadow.camera.top = 6; sun.shadow.camera.bottom = -4; sun.shadow.normalBias = 0.018;
  sun.target.position.set(0, 1.5, 0); scene.add(sun, sun.target);
  const fill = new THREE.DirectionalLight(0xe2eaf0, 0.3); fill.position.set(4, 4, 7); scene.add(fill);
  const interiorLight = new THREE.PointLight(0xe8f0f7, 0.8, 3.2, 2); interiorLight.position.set(0, 3.72, 0.1); scene.add(interiorLight);
  bindInputs();
  observer = new ResizeObserver(resize); observer.observe(document.body);
  resize(); updateStatus();
  stage.dataset.cameraProgress = '1';
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
  const frameMs = lastFrame === undefined ? 0 : Math.max(0, now - lastFrame);
  lastFrame = now;
  const amount = reducedMotion ? 1 : 1 - Math.exp(-15 * frameMs / 1000);
  orbitYaw += (targetOrbitYaw - orbitYaw) * amount;
  orbitPitch += (targetOrbitPitch - orbitPitch) * amount;
  for (const part of PARTS) animated[part] += (view[part] - animated[part]) * amount;

  if (cameraMove) {
    const visibleMs = Math.min(frameMs, Math.max(0, now - cameraMove.lastTime));
    // Preserve an intermediate view if the first frame misses most of the transition.
    cameraMove.elapsed += cameraMove.elapsed === 0 ? Math.min(visibleMs, CAMERA_TRANSITION_MS / 2) : visibleMs;
    cameraMove.lastTime = now;
    cameraFrame = interpolateCamera(cameraMove.from, cameraMove.to, cameraMove.elapsed);
    stage.dataset.cameraProgress = String(Math.min(1, cameraMove.elapsed / CAMERA_TRANSITION_MS));
    if (cameraMove.elapsed >= CAMERA_TRANSITION_MS) cameraMove = null;
  }

  const partsSettled = PARTS.every((part) => Math.abs(view[part] - animated[part]) < 0.003);
  if (partsSettled && PARTS.some((part) => animated[part] !== view[part])) {
    renderer.shadowMap.needsUpdate = true;
    animated = { ...view };
  }
  const settled = !cameraMove && partsSettled &&
    Math.abs(orbitYaw - targetOrbitYaw) < 0.002 && Math.abs(orbitPitch - targetOrbitPitch) < 0.002;
  const settledValue = String(settled);
  if (settled && stage.dataset.settled === 'true' && !needsRender) return;
  if (stage.dataset.settled !== settledValue) stage.dataset.settled = settledValue;
  poseFridge(model.parts, animated);
  applyCameraPose(camera, { ...cameraFrame, yaw: cameraFrame.yaw + orbitYaw, pitch: cameraFrame.pitch + orbitPitch });
  renderer.render(scene, camera);
  inventory.render(view, animated, camera, canvas.clientWidth, canvas.clientHeight);
  needsRender = false;
  loading.classList.add('is-hidden');
}

function resize() {
  if (!renderer) return;
  const { width, height } = canvas.getBoundingClientRect();
  camera.aspect = Math.max(width, 1) / Math.max(height, 1);
  const target = cameraPose(view.focus, camera.aspect);
  if (cameraMove) moveCamera(target);
  else cameraFrame = target;
  camera.updateProjectionMatrix(); renderer.setSize(Math.max(width, 1), Math.max(height, 1), false);
  needsRender = true;
}

function moveCamera(target) {
  const from = { ...cameraFrame, yaw: cameraFrame.yaw + orbitYaw,
    pitch: Math.max(0.015, Math.min(Math.PI / 2, cameraFrame.pitch + orbitPitch)) };
  orbitYaw = targetOrbitYaw = 0;
  orbitPitch = targetOrbitPitch = 0;
  if (reducedMotion) {
    cameraMove = null;
    cameraFrame = target;
    stage.dataset.cameraProgress = '1';
  } else {
    cameraMove = { from, to: target, elapsed: 0, lastTime: performance.now() };
    cameraFrame = from;
    stage.dataset.cameraProgress = '0';
  }
}

function setView(action, value, fromFlutter = false) {
  const previousFocus = view.focus;
  stage.dataset.settled = 'false';
  view = transition(view, action, value);
  renderer.shadowMap.needsUpdate = true;
  if (view.focus !== previousFocus) moveCamera(cameraPose(view.focus, camera.aspect));
  if (view.focus !== previousFocus || action === 'overview' || action === 'closeAll') {
    targetOrbitYaw = 0;
    targetOrbitPitch = 0;
  }
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
  stage.dataset.focus = view.focus ?? 'overview';
  stage.dataset.sceneVersion = 'fridge-sticker-grid-v2.3';
  const label = { fresh: '冷藏室', variable: '变温抽屉俯视', freezer: '冷冻抽屉俯视' }[view.focus];
  liveStatus.textContent = label ?? (openParts.length ? '冰箱概览' : '冰箱已关闭');
}

function bindInputs() {
  document.addEventListener('visibilitychange', () => { lastFrame = undefined; });
  document.querySelector('#overview').addEventListener('click', () => setView('overview'));
  document.querySelector('#close-all').addEventListener('click', () => setView('closeAll'));
  document.querySelectorAll('.controls [data-part]').forEach((button) => {
    button.addEventListener('click', () => setView('togglePart', button.dataset.part));
  });
  canvas.addEventListener('pointerdown', (event) => {
    pointerDown = { x: event.clientX, y: event.clientY, id: event.pointerId }; moved = 0;
    canvas.setPointerCapture(event.pointerId);
    if (!cameraMove && !isOverhead(view.focus)) canvas.style.cursor = 'grabbing';
  });
  canvas.addEventListener('pointermove', (event) => {
    if (!pointerDown) return;
    const dx = event.clientX - pointerDown.x, dy = event.clientY - pointerDown.y;
    moved += Math.abs(dx) + Math.abs(dy);
    if (!cameraMove && !isOverhead(view.focus)) {
      targetOrbitYaw = THREE.MathUtils.clamp(targetOrbitYaw + dx * 0.004, -0.24, 0.24);
      targetOrbitPitch = THREE.MathUtils.clamp(targetOrbitPitch + dy * 0.0016, -0.1, 0.12);
    }
    pointerDown.x = event.clientX; pointerDown.y = event.clientY;
  });
  canvas.addEventListener('pointerup', (event) => {
    if (!pointerDown) return;
    pointerDown = null;
    if (canvas.hasPointerCapture(event.pointerId)) canvas.releasePointerCapture(event.pointerId);
    canvas.style.cursor = '';
    if (moved > 6) return;
    const rect = canvas.getBoundingClientRect();
    pointer.set((event.clientX - rect.left) / rect.width * 2 - 1, -(event.clientY - rect.top) / rect.height * 2 + 1);
    raycaster.setFromCamera(pointer, camera);
    const hit = raycaster.intersectObjects(model.hitTargets, false)[0];
    const part = hit?.object.parent.userData.part;
    if (part) setView('togglePart', part);
  });
  canvas.addEventListener('pointercancel', () => { pointerDown = null; canvas.style.cursor = ''; });
  canvas.addEventListener('keydown', (event) => {
    if (/^[1-3]$/.test(event.key)) { event.preventDefault(); setView('focusZone', ZONES[Number(event.key) - 1]); }
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
      stage.inert = !message.enabled;
      if (pointerDown && canvas.hasPointerCapture(pointerDown.id)) canvas.releasePointerCapture(pointerDown.id);
      pointerDown = null;
      canvas.style.cursor = '';
      lastFrame = undefined;
      if (!sceneFailed) renderer.setAnimationLoop(message.enabled ? render : null);
    }
    if (message.action === 'focusZone' && ZONES.includes(message.zone)) setView('focusZone', message.zone, true);
    if (message.action === 'resetView') setView('overview');
    if (message.action === 'inventory') {
      stage.dataset.inventoryCount = String(inventory.replace(message.foods, message.revision));
      needsRender = true;
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
