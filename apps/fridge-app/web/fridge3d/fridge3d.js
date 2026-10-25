import * as THREE from 'three';
import { RoomEnvironment } from '../vendor/RoomEnvironment.js';

const canvas = document.querySelector('#fridge-canvas');
const fallback = document.querySelector('#fallback');
const loading = document.querySelector('#loading');
const liveStatus = document.querySelector('#live-status');
const reducedMotion = window.matchMedia(
  '(prefers-reduced-motion: reduce)',
).matches;

const palette = {
  canvas: 0xf7f2ea,
  champagne: 0xe8d8c8,
  champagneDark: 0xc7ad94,
  cocoa: 0x4f382e,
  sage: 0x6f8569,
  terracotta: 0xb95f48,
  interior: 0xeef1e7,
  steel: 0xa89a8d,
};

let renderer;
let scene;
let camera;
let frameId = 0;
let lastFrame = performance.now();
let hovering = false;
let dragging = false;
let dragMoved = false;
let pointerStartX = 0;
let pointerStartY = 0;
let yaw = 0.19;
let pitch = 0.08;
let targetYaw = yaw;
let targetPitch = pitch;
let currentFitRadius = 10.2;
let hasRendered = false;
const pointer = new THREE.Vector2();
const raycaster = new THREE.Raycaster();

const movingParts = {};
const interactiveObjects = [];
const foodMeshes = [];

try {
  init();
} catch (error) {
  showFallback(error);
}

function init() {
  renderer = new THREE.WebGLRenderer({
    canvas,
    alpha: true,
    antialias: true,
    powerPreference: 'high-performance',
  });
  renderer.setClearAlpha(0);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.16;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;

  scene = new THREE.Scene();
  camera = new THREE.PerspectiveCamera(28, 1, 0.1, 100);
  camera.position.set(0, 0.5, 10);

  const pmrem = new THREE.PMREMGenerator(renderer);
  const roomEnvironment = new RoomEnvironment();
  scene.environment = pmrem.fromScene(roomEnvironment, 0.04).texture;
  roomEnvironment.dispose();
  pmrem.dispose();

  addLighting();
  buildFridge();
  bindInteractions();
  resize();

  const observer = new ResizeObserver(resize);
  observer.observe(document.body);
  window.addEventListener('resize', resize);

  animate();
  postToFlutter({ type: 'ready' });
}

function addLighting() {
  const hemi = new THREE.HemisphereLight(0xfffaf2, 0xb7a797, 1.85);
  scene.add(hemi);

  const key = new THREE.DirectionalLight(0xfff6e8, 3.2);
  key.position.set(-4.5, 7.5, 6.5);
  key.castShadow = true;
  key.shadow.mapSize.set(2048, 2048);
  key.shadow.camera.left = -5;
  key.shadow.camera.right = 5;
  key.shadow.camera.top = 6;
  key.shadow.camera.bottom = -5;
  key.shadow.bias = -0.0002;
  scene.add(key);

  const fill = new THREE.DirectionalLight(0xdce8db, 1.25);
  fill.position.set(5, 2.2, 5);
  scene.add(fill);

  const rim = new THREE.DirectionalLight(0xd9b79d, 1.8);
  rim.position.set(2, 4.5, -5);
  scene.add(rim);

  const floorBounce = new THREE.PointLight(0xffead5, 1.5, 8, 2);
  floorBounce.position.set(0, -2.4, 2.8);
  scene.add(floorBounce);
}

function buildFridge() {
  const root = new THREE.Group();
  root.position.y = -0.05;
  scene.add(root);

  const doorTexture = makeBrushedTexture();
  const doorMaterial = new THREE.MeshPhysicalMaterial({
    map: doorTexture,
    color: 0xffffff,
    metalness: 0.82,
    roughness: 0.29,
    clearcoat: 0.22,
    clearcoatRoughness: 0.24,
    envMapIntensity: 1.18,
  });
  const cabinetMaterial = new THREE.MeshPhysicalMaterial({
    map: doorTexture,
    color: 0xd6c4b3,
    metalness: 0.64,
    roughness: 0.38,
    clearcoat: 0.14,
  });
  const handleMaterial = new THREE.MeshPhysicalMaterial({
    color: palette.cocoa,
    metalness: 0.38,
    roughness: 0.27,
    clearcoat: 0.28,
  });
  const trimMaterial = new THREE.MeshPhysicalMaterial({
    color: palette.cocoa,
    metalness: 0.2,
    roughness: 0.48,
  });
  const hingeMaterial = new THREE.MeshPhysicalMaterial({
    color: 0x7b6a5d,
    metalness: 0.92,
    roughness: 0.22,
  });
  const interiorMaterial = new THREE.MeshStandardMaterial({
    color: palette.interior,
    roughness: 0.72,
    metalness: 0.03,
    side: THREE.DoubleSide,
  });
  const shelfMaterial = new THREE.MeshPhysicalMaterial({
    color: 0xeaf3ea,
    transparent: true,
    opacity: 0.74,
    transmission: 0.2,
    roughness: 0.08,
    thickness: 0.04,
  });

  const carcass = roundedPanel(
    2.28,
    4.46,
    0.98,
    0.2,
    cabinetMaterial,
  );
  carcass.position.z = 0.05;
  carcass.castShadow = true;
  carcass.receiveShadow = true;
  root.add(carcass);

  const cavity = roundedPanel(
    2.04,
    4.06,
    0.2,
    0.14,
    new THREE.MeshStandardMaterial({
      color: 0x927d6b,
      roughness: 0.8,
      metalness: 0.05,
    }),
  );
  cavity.position.set(0, 0.02, 0.57);
  root.add(cavity);

  const freshInterior = createUpperInterior(
    interiorMaterial,
    shelfMaterial,
  );
  freshInterior.position.set(0, 1.17, 0.69);
  root.add(freshInterior);

  const topTrim = roundedPanel(
    2.3,
    0.09,
    0.15,
    0.04,
    trimMaterial,
  );
  topTrim.position.set(0, 2.23, 0.63);
  root.add(topTrim);

  const leftDoor = createSwingDoor({
    side: 'left',
    material: doorMaterial,
    handleMaterial,
    hingeMaterial,
  });
  const rightDoor = createSwingDoor({
    side: 'right',
    material: doorMaterial,
    handleMaterial,
    hingeMaterial,
  });
  root.add(leftDoor, rightDoor);
  movingParts.leftDoor = {
    object: leftDoor,
    current: 0,
    target: 0,
    closed: 0,
    open: -1.34,
  };
  movingParts.rightDoor = {
    object: rightDoor,
    current: 0,
    target: 0,
    closed: 0,
    open: 1.34,
  };

  const middleDrawer = createDrawer({
    y: -0.42,
    height: 1.0,
    material: doorMaterial,
    handleMaterial,
    interiorMaterial,
    contents: 'variable',
    zone: 'variable',
  });
  const freezerDrawer = createDrawer({
    y: -1.51,
    height: 1.03,
    material: doorMaterial,
    handleMaterial,
    interiorMaterial,
    contents: 'freezer',
    zone: 'freezer',
  });
  root.add(middleDrawer, freezerDrawer);
  movingParts.middleDrawer = {
    object: middleDrawer,
    current: 0,
    target: 0,
    closed: 0,
    open: 1.32,
  };
  movingParts.freezerDrawer = {
    object: freezerDrawer,
    current: 0,
    target: 0,
    closed: 0,
    open: 1.24,
  };

  const railMaterial = new THREE.MeshPhysicalMaterial({
    color: 0x8d8074,
    metalness: 0.9,
    roughness: 0.2,
  });
  for (const y of [-0.83, -1.93]) {
    for (const x of [-0.56, 0.56]) {
      const rail = new THREE.Mesh(
        new THREE.BoxGeometry(0.045, 0.035, 0.92),
        railMaterial,
      );
      rail.position.set(x, y, 0.92);
      rail.castShadow = true;
      root.add(rail);
    }
  }

  const plinth = roundedPanel(
    2.18,
    0.18,
    0.8,
    0.05,
    trimMaterial,
  );
  plinth.position.set(0, -2.28, 0.2);
  plinth.castShadow = true;
  root.add(plinth);

  for (const y of [0.11, -0.94]) {
    const separator = roundedPanel(
      2.14,
      0.025,
      0.04,
      0.012,
      trimMaterial,
    );
    separator.position.set(0, y, 0.705);
    root.add(separator);
  }

  const doorSeam = new THREE.Mesh(
    new THREE.BoxGeometry(0.018, 2.03, 0.02),
    trimMaterial,
  );
  doorSeam.position.set(0, 1.2, 0.705);
  root.add(doorSeam);

  addBrandMark(root);
  addContactShadow(root);
}

function createSwingDoor({ side, material, handleMaterial, hingeMaterial }) {
  const direction = side === 'left' ? 1 : -1;
  const pivotX = side === 'left' ? -1.09 : 1.09;
  const pivot = new THREE.Group();
  pivot.position.set(pivotX, 1.15, 0.61);
  pivot.userData.zone = side === 'left' ? 'fresh' : 'pantry';

  const panel = roundedPanel(1.06, 2.02, 0.23, 0.12, material);
  panel.position.x = direction * 0.53;
  panel.castShadow = true;
  panel.receiveShadow = true;
  panel.userData.zone = pivot.userData.zone;
  pivot.add(panel);
  interactiveObjects.push(panel);

  const inset = roundedPanel(
    0.96,
    1.91,
    0.012,
    0.09,
    new THREE.MeshPhysicalMaterial({
      color: 0xf4e9de,
      metalness: 0.74,
      roughness: 0.33,
      envMapIntensity: 1.08,
    }),
  );
  inset.position.set(direction * 0.53, 0, 0.12);
  pivot.add(inset);

  const handle = new THREE.Mesh(
    new THREE.CapsuleGeometry(0.028, 0.72, 6, 12),
    handleMaterial,
  );
  handle.position.set(direction * 0.91, 0.03, 0.135);
  handle.castShadow = true;
  handle.userData.zone = pivot.userData.zone;
  pivot.add(handle);
  interactiveObjects.push(handle);

  for (const y of [-0.28, 0.28]) {
    const mount = new THREE.Mesh(
      new THREE.CylinderGeometry(0.035, 0.035, 0.09, 16),
      handleMaterial,
    );
    mount.rotation.x = Math.PI / 2;
    mount.position.set(direction * 0.91, y, 0.08);
    mount.userData.zone = pivot.userData.zone;
    pivot.add(mount);
    interactiveObjects.push(mount);
  }

  for (const hingeY of [-0.76, 0.76]) {
    const hinge = new THREE.Mesh(
      new THREE.CylinderGeometry(0.046, 0.046, 0.13, 16),
      hingeMaterial,
    );
    hinge.position.set(0, hingeY, 0.02);
    pivot.add(hinge);
  }

  if (side === 'right') {
    const display = new THREE.Mesh(
      new THREE.PlaneGeometry(0.52, 0.25),
      new THREE.MeshBasicMaterial({
        map: makeTemperatureDisplayTexture(),
        transparent: true,
        depthWrite: false,
      }),
    );
    display.position.set(-0.53, 0.64, 0.132);
    pivot.add(display);
  }

  return pivot;
}

function createDrawer({
  y,
  height,
  material,
  handleMaterial,
  interiorMaterial,
  contents,
  zone,
}) {
  const drawer = new THREE.Group();
  drawer.position.set(0, y, 0);
  drawer.userData.zone = zone;

  const bin = new THREE.Group();
  bin.position.z = -0.34;
  drawer.add(bin);

  const bottom = new THREE.Mesh(
    new THREE.BoxGeometry(1.86, 0.06, 0.74),
    interiorMaterial,
  );
  bottom.position.y = -0.35;
  bin.add(bottom);

  for (const x of [-0.9, 0.9]) {
    const side = new THREE.Mesh(
      new THREE.BoxGeometry(0.055, 0.48, 0.74),
      interiorMaterial,
    );
    side.position.set(x, -0.1, 0);
    bin.add(side);
  }

  const back = new THREE.Mesh(
    new THREE.BoxGeometry(1.86, 0.48, 0.045),
    interiorMaterial,
  );
  back.position.set(0, -0.1, -0.36);
  bin.add(back);

  addTrayContents(bin, contents);

  const face = roundedPanel(2.12, height, 0.18, 0.1, material);
  face.position.set(0, 0, 0.64);
  face.castShadow = true;
  face.receiveShadow = true;
  face.userData.zone = zone;
  drawer.add(face);
  interactiveObjects.push(face);

  const handle = new THREE.Mesh(
    new THREE.CapsuleGeometry(0.038, 0.72, 6, 12),
    handleMaterial,
  );
  handle.rotation.z = Math.PI / 2;
  handle.position.set(0, height * 0.33, 0.755);
  handle.castShadow = true;
  handle.userData.zone = zone;
  drawer.add(handle);
  interactiveObjects.push(handle);

  const label = new THREE.Mesh(
    new THREE.PlaneGeometry(0.48, 0.13),
    new THREE.MeshBasicMaterial({
      map: makeDrawerLabelTexture(
        contents === 'variable' ? '变温 0°C' : '冷冻 -18°C',
      ),
      transparent: true,
      depthWrite: false,
    }),
  );
  label.position.set(-0.74, -0.16, 0.755);
  drawer.add(label);

  for (const x of [-0.43, 0.43]) {
    const rail = new THREE.Mesh(
      new THREE.BoxGeometry(0.06, 0.055, 0.72),
      new THREE.MeshStandardMaterial({
        color: palette.steel,
        metalness: 0.8,
        roughness: 0.25,
      }),
    );
    rail.position.set(x, -0.37, 0.23);
    drawer.add(rail);
  }

  return drawer;
}

function createUpperInterior(interiorMaterial, shelfMaterial) {
  const group = new THREE.Group();
  group.userData.zone = 'fresh';

  const back = new THREE.Mesh(
    new THREE.BoxGeometry(2.02, 2.02, 0.05),
    interiorMaterial,
  );
  back.position.z = -0.24;
  back.receiveShadow = true;
  group.add(back);

  for (const y of [-0.57, 0.04, 0.63]) {
    const shelf = roundedPanel(1.92, 0.035, 0.54, 0.018, shelfMaterial);
    shelf.position.set(0, y, 0.03);
    shelf.receiveShadow = true;
    group.add(shelf);
  }

  const crisp = roundedPanel(
    1.82,
    0.34,
    0.48,
    0.07,
    new THREE.MeshPhysicalMaterial({
      color: 0xd5e1d4,
      transparent: true,
      opacity: 0.76,
      roughness: 0.12,
      transmission: 0.12,
    }),
  );
  crisp.position.set(0, -0.82, 0.05);
  group.add(crisp);

  addTomatoes(group, -0.58, 0.25, 0.11);
  addMilk(group, 0.56, 0.12, -0.02);
  addEggCarton(group, -0.35, 0.18, -0.02);
  addLettuce(group, 0.46, -0.42, 0.0);
  return group;
}

function addTomatoes(parent, x, y, z) {
  const red = new THREE.MeshPhysicalMaterial({
    color: palette.terracotta,
    roughness: 0.42,
    clearcoat: 0.2,
  });
  const leaf = new THREE.MeshStandardMaterial({
    color: 0x56704f,
    roughness: 0.75,
  });

  for (let index = 0; index < 4; index += 1) {
    const tomato = new THREE.Mesh(
      new THREE.SphereGeometry(0.125, 24, 16),
      red,
    );
    tomato.scale.y = 0.82;
    tomato.position.set(
      x + (index % 2) * 0.23,
      y + Math.floor(index / 2) * 0.17,
      z,
    );
    tomato.castShadow = true;
    parent.add(tomato);
    foodMeshes.push(tomato);

    const stem = new THREE.Mesh(
      new THREE.CylinderGeometry(0.018, 0.03, 0.07, 6),
      leaf,
    );
    stem.position.copy(tomato.position);
    stem.position.y += 0.11;
    parent.add(stem);
  }
}

function addMilk(parent, x, y, z) {
  const bottleMaterial = new THREE.MeshPhysicalMaterial({
    color: 0xf8f6ed,
    roughness: 0.32,
    transmission: 0.08,
  });
  const capMaterial = new THREE.MeshStandardMaterial({
    color: palette.sage,
    roughness: 0.5,
  });

  for (let index = 0; index < 2; index += 1) {
    const bottle = new THREE.Mesh(
      new THREE.CylinderGeometry(0.11, 0.13, 0.46, 20),
      bottleMaterial,
    );
    bottle.position.set(x + index * 0.28, y, z);
    bottle.castShadow = true;
    parent.add(bottle);
    foodMeshes.push(bottle);

    const cap = new THREE.Mesh(
      new THREE.CylinderGeometry(0.085, 0.085, 0.075, 20),
      capMaterial,
    );
    cap.position.copy(bottle.position);
    cap.position.y += 0.265;
    parent.add(cap);
  }
}

function addEggCarton(parent, x, y, z) {
  const carton = roundedPanel(
    0.55,
    0.12,
    0.38,
    0.06,
    new THREE.MeshStandardMaterial({
      color: 0xcbb99d,
      roughness: 0.9,
    }),
  );
  carton.rotation.x = -Math.PI / 2;
  carton.position.set(x, y - 0.03, z);
  parent.add(carton);

  const eggMaterial = new THREE.MeshPhysicalMaterial({
    color: 0xf3ddbf,
    roughness: 0.42,
  });
  for (let index = 0; index < 6; index += 1) {
    const egg = new THREE.Mesh(
      new THREE.SphereGeometry(0.07, 20, 12),
      eggMaterial,
    );
    egg.scale.y = 1.25;
    egg.position.set(
      x - 0.17 + (index % 3) * 0.17,
      y + 0.07,
      z - 0.1 + Math.floor(index / 3) * 0.2,
    );
    egg.castShadow = true;
    parent.add(egg);
    foodMeshes.push(egg);
  }
}

function addLettuce(parent, x, y, z) {
  const material = new THREE.MeshStandardMaterial({
    color: 0x729268,
    roughness: 0.8,
    flatShading: true,
  });
  for (let index = 0; index < 3; index += 1) {
    const lettuce = new THREE.Mesh(
      new THREE.IcosahedronGeometry(0.17 + index * 0.02, 1),
      material,
    );
    lettuce.scale.set(1.15, 0.8, 1);
    lettuce.position.set(x + index * 0.18, y, z);
    lettuce.rotation.y = index * 0.7;
    lettuce.castShadow = true;
    parent.add(lettuce);
    foodMeshes.push(lettuce);
  }
}

function addTrayContents(parent, contents) {
  const tray = roundedPanel(
    1.38,
    0.08,
    0.58,
    0.05,
    new THREE.MeshStandardMaterial({
      color: 0xdce7dc,
      roughness: 0.58,
    }),
  );
  tray.rotation.x = -Math.PI / 2;
  tray.position.set(0, -0.31, -0.03);
  parent.add(tray);

  if (contents === 'variable') {
    const meatMaterial = new THREE.MeshPhysicalMaterial({
      color: 0xa94f43,
      roughness: 0.55,
      clearcoat: 0.15,
    });
    for (let index = 0; index < 3; index += 1) {
      const meat = new THREE.Mesh(
        new THREE.CapsuleGeometry(0.1, 0.24, 4, 10),
        meatMaterial,
      );
      meat.rotation.z = Math.PI / 2;
      meat.rotation.y = -0.2 + index * 0.2;
      meat.position.set(-0.34 + index * 0.25, -0.2, -0.04);
      parent.add(meat);
    }

    const shrimpMaterial = new THREE.MeshPhysicalMaterial({
      color: 0xdf8e73,
      roughness: 0.46,
    });
    for (let index = 0; index < 3; index += 1) {
      const shrimp = new THREE.Mesh(
        new THREE.TorusGeometry(0.075, 0.032, 8, 18, Math.PI * 1.25),
        shrimpMaterial,
      );
      shrimp.rotation.x = Math.PI / 2;
      shrimp.position.set(0.34 + index * 0.13, -0.2, 0.05);
      parent.add(shrimp);
    }
  } else {
    const dumplingMaterial = new THREE.MeshStandardMaterial({
      color: 0xf0dfc3,
      roughness: 0.78,
    });
    for (let index = 0; index < 8; index += 1) {
      const dumpling = new THREE.Mesh(
        new THREE.SphereGeometry(0.07, 14, 10),
        dumplingMaterial,
      );
      dumpling.scale.set(1.2, 0.65, 0.85);
      dumpling.position.set(
        -0.42 + (index % 4) * 0.2,
        -0.25,
        -0.14 + Math.floor(index / 4) * 0.2,
      );
      parent.add(dumpling);
    }
  }
}

function addBrandMark(root) {
  const markCanvas = document.createElement('canvas');
  markCanvas.width = 512;
  markCanvas.height = 256;
  const context = markCanvas.getContext('2d');
  context.clearRect(0, 0, 512, 256);
  context.fillStyle = '#4f382e';
  context.textAlign = 'center';
  context.textBaseline = 'middle';
  context.font = '700 64px "Microsoft YaHei UI", "Noto Sans SC", sans-serif';
  context.fillText('小满', 256, 96);
  context.font = '500 26px "Microsoft YaHei UI", "Noto Sans SC", sans-serif';
  context.letterSpacing = '8px';
  context.fillStyle = 'rgba(79,56,46,.52)';
  context.fillText('SMART FRIDGE', 256, 154);

  const texture = new THREE.CanvasTexture(markCanvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  const mark = new THREE.Mesh(
    new THREE.PlaneGeometry(0.76, 0.38),
    new THREE.MeshBasicMaterial({
      map: texture,
      transparent: true,
      depthWrite: false,
    }),
  );
  mark.position.set(0, 2.08, 0.72);
  root.add(mark);
}

function addContactShadow(root) {
  const shadowCanvas = document.createElement('canvas');
  shadowCanvas.width = 512;
  shadowCanvas.height = 512;
  const context = shadowCanvas.getContext('2d');
  const gradient = context.createRadialGradient(256, 256, 28, 256, 256, 230);
  gradient.addColorStop(0, 'rgba(57,38,28,.34)');
  gradient.addColorStop(0.48, 'rgba(57,38,28,.16)');
  gradient.addColorStop(1, 'rgba(57,38,28,0)');
  context.fillStyle = gradient;
  context.fillRect(0, 0, 512, 512);

  const texture = new THREE.CanvasTexture(shadowCanvas);
  const shadow = new THREE.Mesh(
    new THREE.PlaneGeometry(4.7, 2.2),
    new THREE.MeshBasicMaterial({
      map: texture,
      transparent: true,
      opacity: 0.72,
      depthWrite: false,
    }),
  );
  shadow.rotation.x = -Math.PI / 2;
  shadow.position.set(0, -2.36, 0.58);
  root.add(shadow);
}

function roundedPanel(width, height, depth, radius, material) {
  const bevel = Math.min(0.045, depth * 0.18, width * 0.02, height * 0.02);
  const shape = roundedRectShape(width, height, Math.min(radius, height / 2));
  const geometry = new THREE.ExtrudeGeometry(shape, {
    depth: Math.max(0.01, depth - bevel * 2),
    bevelEnabled: true,
    bevelSegments: 4,
    steps: 1,
    bevelSize: bevel,
    bevelThickness: bevel,
    curveSegments: 14,
  });
  geometry.center();
  geometry.computeVertexNormals();
  const mesh = new THREE.Mesh(geometry, material);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  return mesh;
}

function roundedRectShape(width, height, radius) {
  const x = -width / 2;
  const y = -height / 2;
  const shape = new THREE.Shape();
  shape.moveTo(x + radius, y);
  shape.lineTo(x + width - radius, y);
  shape.quadraticCurveTo(x + width, y, x + width, y + radius);
  shape.lineTo(x + width, y + height - radius);
  shape.quadraticCurveTo(
    x + width,
    y + height,
    x + width - radius,
    y + height,
  );
  shape.lineTo(x + radius, y + height);
  shape.quadraticCurveTo(x, y + height, x, y + height - radius);
  shape.lineTo(x, y + radius);
  shape.quadraticCurveTo(x, y, x + radius, y);
  return shape;
}

function makeBrushedTexture() {
  const brushCanvas = document.createElement('canvas');
  brushCanvas.width = 256;
  brushCanvas.height = 512;
  const context = brushCanvas.getContext('2d');
  const gradient = context.createLinearGradient(0, 0, 256, 0);
  gradient.addColorStop(0, '#d8c9ba');
  gradient.addColorStop(0.32, '#eee6dd');
  gradient.addColorStop(0.58, '#ddd0c3');
  gradient.addColorStop(0.82, '#f2ebe3');
  gradient.addColorStop(1, '#d9cabd');
  context.fillStyle = gradient;
  context.fillRect(0, 0, 256, 512);

  for (let index = 0; index < 650; index += 1) {
    const x = Math.random() * 256;
    const alpha = 0.008 + Math.random() * 0.018;
    context.strokeStyle = `rgba(255,255,255,${alpha * 1.5})`;
    context.lineWidth = 0.25 + Math.random() * 0.45;
    context.beginPath();
    context.moveTo(x, 0);
    context.lineTo(x + Math.random() * 1.2 - 0.6, 512);
    context.stroke();
  }

  const texture = new THREE.CanvasTexture(brushCanvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.wrapS = THREE.RepeatWrapping;
  texture.wrapT = THREE.RepeatWrapping;
  texture.repeat.set(2, 2);
  texture.anisotropy = renderer.capabilities.getMaxAnisotropy();
  return texture;
}

function makeDrawerLabelTexture(label) {
  const labelCanvas = document.createElement('canvas');
  labelCanvas.width = 512;
  labelCanvas.height = 128;
  const context = labelCanvas.getContext('2d');
  context.clearRect(0, 0, 512, 128);
  context.fillStyle = 'rgba(79,56,46,.82)';
  context.textAlign = 'center';
  context.textBaseline = 'middle';
  context.font = '700 42px "Microsoft YaHei UI", "Noto Sans SC", sans-serif';
  context.fillText(label, 256, 66);
  const texture = new THREE.CanvasTexture(labelCanvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.anisotropy = renderer.capabilities.getMaxAnisotropy();
  return texture;
}

function makeTemperatureDisplayTexture() {
  const displayCanvas = document.createElement('canvas');
  displayCanvas.width = 512;
  displayCanvas.height = 256;
  const context = displayCanvas.getContext('2d');
  context.fillStyle = '#33241e';
  context.beginPath();
  context.roundRect(18, 18, 476, 220, 42);
  context.fill();

  context.fillStyle = '#eef5e8';
  context.textAlign = 'left';
  context.textBaseline = 'middle';
  context.font = '800 112px "Microsoft YaHei UI", "Noto Sans SC", sans-serif';
  context.fillText('4°C', 54, 132);
  context.fillStyle = 'rgba(238,245,232,.58)';
  context.font = '600 30px "Microsoft YaHei UI", "Noto Sans SC", sans-serif';
  context.fillText('冷藏运行中', 58, 202);

  context.beginPath();
  context.arc(430, 86, 13, 0, Math.PI * 2);
  context.fillStyle = '#8eb184';
  context.fill();

  const texture = new THREE.CanvasTexture(displayCanvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.anisotropy = renderer.capabilities.getMaxAnisotropy();
  return texture;
}

function bindInteractions() {
  canvas.addEventListener('pointerdown', (event) => {
    dragging = true;
    dragMoved = false;
    pointerStartX = event.clientX;
    pointerStartY = event.clientY;
    canvas.classList.add('is-dragging');
    canvas.setPointerCapture(event.pointerId);
  });

  canvas.addEventListener('pointermove', (event) => {
    updatePointer(event);
    const hoverHit = raycaster.intersectObjects(interactiveObjects, false);
    hovering = hoverHit.length > 0;
    canvas.style.cursor = dragging
      ? 'grabbing'
      : hovering
        ? 'pointer'
        : 'grab';

    if (!dragging) {
      return;
    }

    const dx = event.clientX - pointerStartX;
    const dy = event.clientY - pointerStartY;
    if (Math.abs(dx) + Math.abs(dy) > 5) {
      dragMoved = true;
    }
    targetYaw = THREE.MathUtils.clamp(targetYaw + dx * 0.005, -0.52, 0.52);
    targetPitch = THREE.MathUtils.clamp(
      targetPitch - dy * 0.0032,
      -0.12,
      0.28,
    );
    pointerStartX = event.clientX;
    pointerStartY = event.clientY;
  });

  canvas.addEventListener('pointerup', (event) => {
    dragging = false;
    canvas.classList.remove('is-dragging');
    canvas.releasePointerCapture(event.pointerId);
    if (dragMoved) {
      return;
    }

    updatePointer(event);
    raycaster.setFromCamera(pointer, camera);
    const hit = raycaster.intersectObjects(interactiveObjects, false)[0];
    const zone = hit ? findZone(hit.object) : null;
    if (zone) {
      focusZone(zone, false);
    }
  });

  canvas.addEventListener('pointercancel', () => {
    dragging = false;
    canvas.classList.remove('is-dragging');
  });

  canvas.addEventListener('keydown', (event) => {
    const keyMap = {
      '1': 'fresh',
      '2': 'variable',
      '3': 'freezer',
      '4': 'pantry',
    };
    if (keyMap[event.key]) {
      focusZone(keyMap[event.key], false);
    }
  });

  window.addEventListener('message', (event) => {
    if (event.source !== window.parent) {
      return;
    }
    let message;
    try {
      message =
        typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
    } catch {
      return;
    }
    if (!message || message.type !== 'smart-fridge-command') {
      return;
    }
    if (message.action === 'focusZone' && message.zone) {
      focusZone(String(message.zone), true);
    }
    if (message.action === 'resetView') {
      targetYaw = 0.19;
      targetPitch = 0.08;
      closeAll(false);
    }
  });
}

function updatePointer(event) {
  const rect = canvas.getBoundingClientRect();
  pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
  pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
  raycaster.setFromCamera(pointer, camera);
}

function findZone(object) {
  let current = object;
  while (current) {
    if (current.userData?.zone) {
      return current.userData.zone;
    }
    current = current.parent;
  }
  return null;
}

function focusZone(zone, fromFlutter) {
  const isFreshOpen = movingParts.leftDoor.target > 0;
  const isPantryOpen = movingParts.rightDoor.target > 0;
  const isMiddleOpen = movingParts.middleDrawer.target > 0;
  const isFreezerOpen = movingParts.freezerDrawer.target > 0;

  closeAll();
  if (zone === 'fresh') {
    movingParts.leftDoor.target = isFreshOpen ? 0 : 1;
    targetPitch = 0.1;
  } else if (zone === 'pantry') {
    movingParts.rightDoor.target = isPantryOpen ? 0 : 1;
    targetPitch = 0.1;
  } else if (zone === 'variable') {
    movingParts.middleDrawer.target = isMiddleOpen ? 0 : 1;
    targetPitch = 0.2;
  } else if (zone === 'freezer') {
    movingParts.freezerDrawer.target = isFreezerOpen ? 0 : 1;
    targetPitch = 0.2;
  }

  const labels = {
    fresh: '冷藏室',
    variable: '变温室',
    freezer: '冷冻室',
    pantry: '常温与饮品区',
  };
  const isOpen = [
    movingParts.leftDoor.target,
    movingParts.rightDoor.target,
    movingParts.middleDrawer.target,
    movingParts.freezerDrawer.target,
  ].some(Boolean);
  const description = isOpen
    ? `${labels[zone] ?? '冰箱'}已打开`
    : `${labels[zone] ?? '冰箱'}已关闭`;
  liveStatus.textContent = description;

  postToFlutter({
    type: 'zone-selected',
    zone,
    open: isOpen,
    fromFlutter: Boolean(fromFlutter),
  });
}

function closeAll(postChange = true) {
  for (const part of Object.values(movingParts)) {
    part.target = 0;
  }
  if (postChange) {
    postToFlutter({ type: 'panels-closed' });
  }
}

function resize() {
  const width = Math.max(1, document.body.clientWidth);
  const height = Math.max(1, document.body.clientHeight);
  const aspect = width / height;
  renderer.setSize(width, height, false);
  camera.aspect = aspect;
  const portraitStage = aspect < 1.05;
  camera.fov = portraitStage ? 32 : 28;
  camera.updateProjectionMatrix();
  currentFitRadius = portraitStage ? 10.4 : 9.8;
}

function animate(now = performance.now()) {
  const delta = Math.min(0.05, (now - lastFrame) / 1000);
  lastFrame = now;

  const damping = 1 - Math.pow(0.001, delta);
  yaw += (targetYaw - yaw) * damping;
  pitch += (targetPitch - pitch) * damping;

  const horizontalRadius = Math.cos(pitch) * currentFitRadius;
  camera.position.x = Math.sin(yaw) * horizontalRadius;
  camera.position.z = Math.cos(yaw) * horizontalRadius;
  camera.position.y = 0.35 + Math.sin(pitch) * currentFitRadius;
  camera.lookAt(0, -0.03, 0.16);

  for (const part of Object.values(movingParts)) {
    part.current += (part.target - part.current) * (1 - Math.pow(0.008, delta));
    if (part.object === movingParts.middleDrawer?.object ||
        part.object === movingParts.freezerDrawer?.object) {
      part.object.position.z = part.current * part.open;
    } else {
      part.object.rotation.y = part.current * part.open;
    }
  }

  if (!reducedMotion && !dragging) {
    const idle = Math.sin(now * 0.00035) * 0.008;
    camera.position.x += idle;
  }

  renderer.render(scene, camera);
  if (!hasRendered) {
    hasRendered = true;
    loading?.classList.add('is-hidden');
  }
  frameId = requestAnimationFrame(animate);
}

function postToFlutter(payload) {
  window.parent?.postMessage(
    JSON.stringify({
      source: 'smart-fridge-3d',
      ...payload,
    }),
    window.location.origin,
  );
}

function showFallback(error) {
  console.error('WebGL fridge failed to initialize', error);
  if (frameId) {
    cancelAnimationFrame(frameId);
  }
  fallback?.classList.add('is-visible');
  loading?.classList.add('is-hidden');
  canvas.style.display = 'none';
  postToFlutter({
    type: 'error',
    message: error instanceof Error ? error.message : String(error),
  });
}
