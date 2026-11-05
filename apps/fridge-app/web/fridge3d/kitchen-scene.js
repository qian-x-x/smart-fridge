import * as THREE from '../vendor/three.module.min.js';
import { box } from './fridge-model.js?rev=warm-harvest-v1.5.1';

export function createTexture(kind) {
  const canvas = document.createElement('canvas'); canvas.width = 256; canvas.height = 512;
  const context = canvas.getContext('2d');
  let seed = 7159;
  const random = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
  const image = context.createImageData(256, 512);
  for (let y = 0; y < 512; y++) for (let x = 0; x < 256; x++) {
    const index = (y * 256 + x) * 4;
    const grain = kind === 'wood' ? Math.sin(x * 1.8 + Math.sin(y * 0.008) * 1.7) * 3 + random() * 4
      : kind === 'steel' ? Math.sin(y * 1.4) * 5 + random() * 8 : random() * 9;
    const base = kind === 'wood' ? [154, 105, 65] : kind === 'steel' ? [244, 237, 224] : [234, 221, 200];
    for (let channel = 0; channel < 3; channel++) image.data[index + channel] = base[channel] + grain;
    image.data[index + 3] = 255;
  }
  context.putImageData(image, 0, 0);
  const texture = new THREE.CanvasTexture(canvas); texture.colorSpace = THREE.SRGBColorSpace;
  texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
  return texture;
}

export function buildKitchen(scene, materials, pantryFoodGroup) {
  const room = new THREE.Group(); room.name = 'v1-kitchen'; scene.add(room);
  box(room, 'floor', [18, 0.08, 16], [0, -0.065, 2], materials.stone);
  box(room, 'back-wall', [17, 7, 0.12], [0, 3.4, -1.48], materials.wall);
  const grout = new THREE.MeshStandardMaterial({ color: 0xcac9c2, roughness: 1 });
  for (let x = -7; x < 8; x += 1.4) box(room, 'floor-grout-x', [0.009, 0.002, 12], [x, -0.023, 2], grout);
  for (let z = -1; z < 9; z += 1.4) box(room, 'floor-grout-z', [17, 0.002, 0.009], [0, -0.023, z], grout);
  for (const x of [-1.25, 1.25]) box(room, 'tall-oak-bay-panel', [0.095, 4.95, 1.25], [x, 2.49, -0.68], materials.wood);
  box(room, 'above-fridge-cabinet', [2.6, 0.48, 1.23], [0, 4.8, -0.69], materials.wood);
  box(room, 'above-fridge-door-seam', [0.012, 0.44, 0.012], [0, 4.8, -0.066], grout);
  const black = materials.dark;
  const ceramic = new THREE.MeshStandardMaterial({ color: 0xd9d9cf, roughness: 0.75 });
  for (const x of [-2.68, 2.68]) {
    box(room, 'base-cabinet', [2.68, 1.94, 1.5], [x, 1.05, -0.56], materials.wood);
    box(room, 'quartz-worktop', [2.75, 0.065, 1.61], [x, 2.055, -0.52], materials.stone);
    box(room, 'cabinet-toe-kick', [2.65, 0.12, 0.09], [x, 0.1, 0.1], black);
    for (let i = -1; i <= 1; i++) {
      box(room, 'cabinet-door-gap', [0.014, 1.74, 0.012], [x + i * 0.82, 1.08, 0.198], grout);
      box(room, 'cabinet-pull', [0.28, 0.018, 0.025], [x + i * 0.82 + 0.38, 1.83, 0.222], black);
    }
  }
  for (let x = 1.34; x < 4.1; x += 0.46) box(room, 'backsplash-vertical-joint', [0.008, 1.15, 0.008], [x, 2.65, -1.407], grout);
  for (let y = 2.14; y < 3.25; y += 0.27) box(room, 'backsplash-horizontal-joint', [2.76, 0.008, 0.008], [2.7, y, -1.407], grout);
  box(room, 'upper-white-cabinet', [2.7, 1.16, 0.7], [2.7, 3.86, -1.08], materials.white);
  for (const x of [2.25, 3.15]) box(room, 'upper-cabinet-seam', [0.009, 1.12, 0.012], [x, 3.86, -0.725], grout);
  box(room, 'under-cabinet-light', [2.5, 0.025, 0.025], [2.7, 3.27, -0.75], materials.led);
  const window = new THREE.Group(); window.position.set(-2.82, 3.55, -1.4); room.add(window);
  box(window, 'window-outside', [2.5, 2.35, 0.018], [0, 0, 0], new THREE.MeshBasicMaterial({ color: 0xe4eff0 }));
  for (const x of [-1.25, 0, 1.25]) box(window, 'window-frame-upright', [0.038, 2.46, 0.065], [x, 0, 0.045], black);
  for (const y of [-1.19, 1.19]) box(window, 'window-frame-horizontal', [2.58, 0.04, 0.065], [0, y, 0.045], black);
  box(window, 'window-sill', [2.7, 0.06, 0.25], [0, -1.23, 0.13], materials.stone);
  box(room, 'sink-rim', [0.85, 0.016, 0.73], [2.52, 2.096, -0.31], materials.steel, 0.05);
  box(room, 'sink-basin', [0.75, 0.021, 0.63], [2.52, 2.107, -0.31], black, 0.045);
  const curve = new THREE.CatmullRomCurve3([
    new THREE.Vector3(2.5, 2.1, -0.87), new THREE.Vector3(2.5, 2.7, -0.87),
    new THREE.Vector3(2.5, 2.82, -0.59), new THREE.Vector3(2.5, 2.58, -0.43),
  ]);
  const faucet = new THREE.Mesh(new THREE.TubeGeometry(curve, 24, 0.023, 10, false), black); room.add(faucet);
  box(room, 'induction-hob', [0.79, 0.015, 0.73], [3.55, 2.1, -0.3], black, 0.025);
  for (const x of [3.35, 3.76]) {
    const burner = new THREE.Mesh(new THREE.TorusGeometry(0.14, 0.003, 5, 32), materials.side);
    burner.rotation.x = Math.PI / 2; burner.position.set(x, 2.11, -0.25); room.add(burner);
  }
  box(room, 'oak-cutting-board', [0.45, 0.7, 0.035], [1.7, 2.46, -1.34], materials.wood, 0.08);
  const bowl = new THREE.Mesh(new THREE.SphereGeometry(0.21, 24, 12, 0, Math.PI * 2, Math.PI / 2, Math.PI / 2), ceramic);
  bowl.position.set(-3.45, 2.24, -0.18); bowl.scale.y = 0.7; room.add(bowl);
  pantryFoodGroup.position.set(-2.5, 2.1, -0.18); room.add(pantryFoodGroup);
  const pantryHit = box(room, 'ambient-storage-target', [1.6, 0.045, 1.12], [-2.5, 2.108, -0.22], materials.wood);
  pantryHit.userData.zone = 'pantry';
  return { room, pantryHit };
}
