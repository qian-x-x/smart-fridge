import * as THREE from '../vendor/three.module.min.js';
import { box } from './fridge-model.js?rev=fridge-sticker-grid-v2.3';

export function createTexture(kind) {
  const canvas = document.createElement('canvas'); canvas.width = 256; canvas.height = 512;
  const context = canvas.getContext('2d');
  let seed = 7159;
  const random = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
  const image = context.createImageData(256, 512);
  for (let y = 0; y < 512; y++) for (let x = 0; x < 256; x++) {
    const index = (y * 256 + x) * 4;
    const grain = kind === 'wood' ? Math.sin(x * 0.9) * 0.5 + random() * 0.8
      : kind === 'steel' ? Math.sin(y * 1.4) * 2 + random() * 3 : random() * 3.5;
    const base = kind === 'wood' ? [63, 72, 80] : kind === 'steel' ? [211, 216, 219] : [195, 201, 206];
    for (let channel = 0; channel < 3; channel++) image.data[index + channel] = base[channel] + grain;
    image.data[index + 3] = 255;
  }
  context.putImageData(image, 0, 0);
  const texture = new THREE.CanvasTexture(canvas); texture.colorSpace = THREE.SRGBColorSpace;
  texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
  return texture;
}

export function buildKitchen(scene, materials) {
  const room = new THREE.Group();
  room.name = 'kitchen';
  scene.add(room);
  box(room, 'floor', [18, 0.08, 16], [0, -0.065, 2], materials.floor);
  box(room, 'back-wall', [17, 7, 0.12], [0, 3.4, -1.48], materials.wall);

  const counterOffset = 1.76;
  const counterHeight = 1.77;
  for (const side of [-1, 1]) {
    const x = counterOffset * side;
    box(room, 'counter-base', [1.18, counterHeight - 0.05, 1.25], [x, (counterHeight - 0.05) / 2, -0.6], materials.wood);
    box(room, 'worktop', [1.27, 0.05, 1.30], [x, counterHeight - 0.025, -0.6], materials.stone);
  }

  box(room, 'hob', [0.66, 0.018, 0.66], [-counterOffset, counterHeight + 0.009, -0.56], materials.dark, 0.025);
  const burner = new THREE.Mesh(new THREE.TorusGeometry(0.21, 0.004, 5, 32), materials.side);
  burner.rotation.x = -Math.PI / 2;
  burner.position.set(-counterOffset, counterHeight + 0.019, -0.56);
  room.add(burner);
}
