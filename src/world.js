import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';

export const ISLAND_RADIUS = 66;
export const RECYCLER_POS = new THREE.Vector3(-8, 0, 30);
export const SHOP_POS = new THREE.Vector3(8, 0, 30);

const glossy = (color, extra = {}) => new THREE.MeshPhysicalMaterial({
  color, roughness: 0.25, clearcoat: 1, clearcoatRoughness: 0.08, ...extra,
});

export function buildWorld(scene) {
  const updaters = [];

  // Himmel: Verlauf + Sonnenschein
  const skyMat = new THREE.ShaderMaterial({
    side: THREE.BackSide,
    depthWrite: false,
    fog: false,
    uniforms: {
      top: { value: new THREE.Color(0x1477d6) },
      mid: { value: new THREE.Color(0x63c3ff) },
      bottom: { value: new THREE.Color(0xe8fbff) },
      sunDir: { value: new THREE.Vector3(0.4, 0.55, -0.7).normalize() },
    },
    vertexShader: `varying vec3 vDir; void main(){ vDir = normalize(position); gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }`,
    fragmentShader: `
      uniform vec3 top, mid, bottom, sunDir; varying vec3 vDir;
      void main(){
        float h = vDir.y;
        vec3 c = mix(bottom, mid, smoothstep(-0.05, 0.25, h));
        c = mix(c, top, smoothstep(0.25, 0.9, h));
        float s = max(dot(vDir, sunDir), 0.0);
        c += vec3(1.0,0.97,0.85) * (pow(s, 600.0) * 2.0 + pow(s, 12.0) * 0.25);
        gl_FragColor = vec4(c, 1.0);
      }`,
  });
  scene.add(new THREE.Mesh(new THREE.SphereGeometry(500, 32, 16), skyMat));
  scene.fog = new THREE.Fog(0xcdefff, 90, 320);

  // Licht
  scene.add(new THREE.HemisphereLight(0xdff6ff, 0x5fae3a, 0.85));
  const sun = new THREE.DirectionalLight(0xfff6e0, 2.4);
  sun.position.set(40, 70, -55);
  sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  Object.assign(sun.shadow.camera, { left: -45, right: 45, top: 45, bottom: -45, near: 1, far: 200 });
  sun.shadow.bias = -0.0005;
  scene.add(sun);

  // Insel
  const grass = new THREE.Mesh(
    new THREE.CylinderGeometry(70, 64, 6, 96),
    new THREE.MeshPhysicalMaterial({ color: 0x67cf43, roughness: 0.55, clearcoat: 0.4, clearcoatRoughness: 0.4 }),
  );
  grass.position.y = -3;
  grass.receiveShadow = true;
  scene.add(grass);
  const sand = new THREE.Mesh(
    new THREE.CylinderGeometry(74, 68, 6, 96),
    new THREE.MeshStandardMaterial({ color: 0xf3e2b0, roughness: 0.9 }),
  );
  sand.position.y = -3.45;
  scene.add(sand);

  // Pfad zur Station
  const path = new THREE.Mesh(
    new THREE.CircleGeometry(5, 48),
    new THREE.MeshStandardMaterial({ color: 0xeef8ff, roughness: 0.4 }),
  );
  path.rotation.x = -Math.PI / 2;
  path.scale.set(3.6, 1.4, 1);
  path.position.set(0, 0.01, 31);
  path.receiveShadow = true;
  scene.add(path);

  // Wasser
  const waterMat = new THREE.MeshPhysicalMaterial({
    color: 0x2fb8ea, roughness: 0.04, metalness: 0.1, clearcoat: 1, transparent: true, opacity: 0.9,
  });
  const water = new THREE.Mesh(new THREE.PlaneGeometry(1200, 1200), waterMat);
  water.rotation.x = -Math.PI / 2;
  water.position.y = -1.1;
  scene.add(water);
  updaters.push((t) => {
    water.position.y = -1.1 + Math.sin(t * 0.6) * 0.08;
    waterMat.color.setHSL(0.54, 0.8, 0.53 + Math.sin(t * 0.4) * 0.02);
  });

  // Ferne Hügelinseln
  const hillMat = glossy(0x5cc93c, { roughness: 0.5 });
  for (let i = 0; i < 9; i++) {
    const a = (i / 9) * Math.PI * 2 + 0.3;
    const r = 170 + (i % 3) * 40;
    const s = 18 + (i * 7) % 20;
    const hill = new THREE.Mesh(new THREE.SphereGeometry(s, 32, 16), hillMat);
    hill.position.set(Math.cos(a) * r, -s * 0.45, Math.sin(a) * r);
    hill.scale.y = 0.8;
    scene.add(hill);
  }

  // Bäume
  const trunkMat = new THREE.MeshStandardMaterial({ color: 0xb48a5a, roughness: 0.8 });
  const leafMats = [glossy(0x48c43a), glossy(0x7adf4a), glossy(0x36b06a)];
  for (let i = 0; i < 16; i++) {
    const a = (i / 16) * Math.PI * 2 + Math.sin(i * 3.1) * 0.15;
    if (Math.abs(Math.atan2(Math.sin(a), Math.cos(a)) - Math.PI / 2) < 0.35) continue; // Station frei lassen
    const r = 44 + (i * 13) % 14;
    const tree = new THREE.Group();
    const h = 3.5 + (i % 4) * 0.8;
    const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.45, h, 10), trunkMat);
    trunk.position.y = h / 2;
    trunk.castShadow = true;
    tree.add(trunk);
    for (let c = 0; c < 3; c++) {
      const leaf = new THREE.Mesh(new THREE.SphereGeometry(1.8 - c * 0.3, 20, 14), leafMats[(i + c) % 3]);
      leaf.position.set(Math.sin(c * 2.1) * 0.9, h + c * 0.9, Math.cos(c * 2.1) * 0.9);
      leaf.castShadow = true;
      tree.add(leaf);
    }
    tree.position.set(Math.cos(a) * r, 0, Math.sin(a) * r);
    tree.userData.collider = 0.8;
    scene.add(tree);
  }

  // Wolken
  const cloudMat = new THREE.MeshStandardMaterial({ color: 0xffffff, emissive: 0xdfefff, emissiveIntensity: 0.35, roughness: 1 });
  const clouds = [];
  for (let i = 0; i < 14; i++) {
    const cloud = new THREE.Group();
    const parts = 4 + (i % 3);
    for (let p = 0; p < parts; p++) {
      const s = 4 + ((p * 7 + i) % 4);
      const puff = new THREE.Mesh(new THREE.SphereGeometry(s, 16, 12), cloudMat);
      puff.position.set(p * 5 - parts * 2.5, Math.sin(p * 1.7) * 1.5, Math.cos(p * 2.3) * 3);
      cloud.add(puff);
    }
    const a = (i / 14) * Math.PI * 2;
    cloud.position.set(Math.cos(a) * (120 + i * 9), 55 + (i % 4) * 9, Math.sin(a) * (120 + i * 9));
    clouds.push(cloud);
    scene.add(cloud);
  }
  updaters.push((t, dt) => {
    for (const c of clouds) {
      c.position.x += dt * 1.2;
      if (c.position.x > 260) c.position.x = -260;
    }
  });

  // Aufsteigende Seifenblasen
  const bubbleMat = new THREE.MeshPhysicalMaterial({
    color: 0xffffff, roughness: 0, transmission: 0, transparent: true, opacity: 0.28,
    iridescence: 1, iridescenceIOR: 1.3, clearcoat: 1, depthWrite: false,
  });
  const bubbleGeo = new THREE.SphereGeometry(1, 24, 16);
  const bubbles = [];
  for (let i = 0; i < 40; i++) {
    const b = new THREE.Mesh(bubbleGeo, bubbleMat);
    resetBubble(b, true);
    bubbles.push(b);
    scene.add(b);
  }
  function resetBubble(b, anyHeight) {
    const a = Math.random() * Math.PI * 2;
    const r = 15 + Math.random() * 60;
    b.position.set(Math.cos(a) * r, anyHeight ? Math.random() * 40 : -1, Math.sin(a) * r);
    b.scale.setScalar(0.2 + Math.random() * 0.7);
    b.userData.speed = 0.6 + Math.random() * 1.2;
    b.userData.phase = Math.random() * 10;
  }
  updaters.push((t, dt) => {
    for (const b of bubbles) {
      b.position.y += b.userData.speed * dt;
      b.position.x += Math.sin(t + b.userData.phase) * dt * 0.4;
      if (b.position.y > 45) resetBubble(b, false);
    }
  });

  // Station: Recycler + Shop
  const recycler = buildRecycler();
  recycler.position.copy(RECYCLER_POS);
  scene.add(recycler);
  const shop = buildShop();
  shop.position.copy(SHOP_POS);
  scene.add(shop);
  updaters.push((t) => {
    recycler.userData.ring.rotation.z = t * 1.5;
    recycler.userData.ring.position.y = 3.2 + Math.sin(t * 2) * 0.12;
    shop.userData.screen.material.emissiveIntensity = 0.9 + Math.sin(t * 3) * 0.1;
  });

  const colliders = [
    { x: RECYCLER_POS.x, z: RECYCLER_POS.z, r: 1.9 },
    { x: SHOP_POS.x, z: SHOP_POS.z, r: 1.6 },
  ];
  scene.traverse((o) => {
    if (o.userData.collider) colliders.push({ x: o.position.x, z: o.position.z, r: o.userData.collider });
  });

  return {
    sun,
    colliders,
    update(t, dt) { for (const u of updaters) u(t, dt); },
  };
}

function labelTexture(text, from, to) {
  const c = document.createElement('canvas');
  c.width = 512; c.height = 256;
  const g = c.getContext('2d');
  const grad = g.createLinearGradient(0, 0, 0, 256);
  grad.addColorStop(0, from);
  grad.addColorStop(1, to);
  g.fillStyle = grad;
  g.fillRect(0, 0, 512, 256);
  g.fillStyle = 'rgba(255,255,255,0.35)';
  g.beginPath();
  g.ellipse(256, 30, 300, 110, 0, 0, Math.PI * 2);
  g.fill();
  g.fillStyle = '#fff';
  g.font = 'bold 92px "Segoe UI", Arial, sans-serif';
  g.textAlign = 'center';
  g.textBaseline = 'middle';
  g.shadowColor = 'rgba(0,60,120,0.6)';
  g.shadowBlur = 12;
  g.fillText(text, 256, 140);
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

function buildRecycler() {
  const g = new THREE.Group();
  const body = new THREE.Mesh(new THREE.CylinderGeometry(1.5, 1.7, 2.4, 40), glossy(0xf5fbff));
  body.position.y = 1.2;
  body.castShadow = true;
  g.add(body);
  const band = new THREE.Mesh(new THREE.CylinderGeometry(1.56, 1.62, 0.7, 40), glossy(0x3ccf5a));
  band.position.y = 1.3;
  g.add(band);
  const funnel = new THREE.Mesh(
    new THREE.CylinderGeometry(1.9, 1.1, 0.9, 40, 1, true),
    glossy(0x9fe9ff, { side: THREE.DoubleSide, transparent: true, opacity: 0.75 }),
  );
  funnel.position.y = 2.85;
  g.add(funnel);
  const ring = new THREE.Mesh(
    new THREE.TorusGeometry(1.4, 0.08, 12, 48),
    new THREE.MeshStandardMaterial({ color: 0x8bffb0, emissive: 0x3bff7a, emissiveIntensity: 1.2 }),
  );
  ring.rotation.x = Math.PI / 2;
  g.add(ring);
  g.userData.ring = ring;
  const sign = new THREE.Mesh(
    new THREE.PlaneGeometry(2.2, 1.1),
    new THREE.MeshStandardMaterial({ map: labelTexture('RECYCLE', '#5be37a', '#16a05a'), emissive: 0xffffff, emissiveIntensity: 0.25, emissiveMap: null }),
  );
  sign.position.set(0, 1.25, 1.72);
  g.add(sign);
  return g;
}

function buildShop() {
  const g = new THREE.Group();
  const base = new THREE.Mesh(new RoundedBoxGeometry(2.4, 1.2, 1.6, 4, 0.25), glossy(0xf5fbff));
  base.position.y = 0.6;
  base.castShadow = true;
  g.add(base);
  const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.18, 0.18, 1.4, 16), glossy(0xdde8f2, { metalness: 0.6 }));
  pole.position.y = 1.8;
  g.add(pole);
  const tex = labelTexture('SHOP', '#5ac8ff', '#1662d6');
  const screen = new THREE.Mesh(
    new RoundedBoxGeometry(2.6, 1.5, 0.2, 4, 0.08),
    new THREE.MeshStandardMaterial({ color: 0xffffff, map: tex, emissive: 0xffffff, emissiveMap: tex, emissiveIntensity: 1 }),
  );
  screen.position.set(0, 2.9, 0);
  screen.rotation.x = -0.12;
  g.add(screen);
  g.userData.screen = screen;
  return g;
}
