import * as THREE from 'three';
import { TIERS } from './config.js';
import { ISLAND_RADIUS } from './world.js';

const MAX = 3000;
const _m = new THREE.Matrix4();
const _q = new THREE.Quaternion();
const _e = new THREE.Euler();
const _p = new THREE.Vector3();
const _s = new THREE.Vector3();
const _c = new THREE.Color();

// Scherben: dichte Arrays mit Swap-Remove, gerendert als ein InstancedMesh.
export class Shards {
  constructor(scene) {
    this.pos = new Float32Array(MAX * 3);
    this.vel = new Float32Array(MAX * 3);
    this.tier = new Uint8Array(MAX);
    this.age = new Float32Array(MAX);
    this.pull = new Uint8Array(MAX);
    this.count = 0;
    const geo = new THREE.OctahedronGeometry(0.17, 0);
    const mat = new THREE.MeshPhysicalMaterial({
      color: 0xffffff, roughness: 0.1, clearcoat: 1, emissive: 0x223344, emissiveIntensity: 0.4,
    });
    this.mesh = new THREE.InstancedMesh(geo, mat, MAX);
    this.mesh.count = 0;
    this.mesh.frustumCulled = false;
    this.mesh.castShadow = true;
    this.mesh.setColorAt(0, _c.setHex(0xffffff));
    scene.add(this.mesh);
  }

  spawn(p, tier, n) {
    for (let s = 0; s < n; s++) {
      if (this.count >= MAX) this.remove(0); // älteste Scherbe verfällt
      const i = this.count++;
      const a = Math.random() * Math.PI * 2;
      const sp = 1.5 + Math.random() * 3;
      this.pos[i * 3] = p.x + (Math.random() - 0.5) * 0.4;
      this.pos[i * 3 + 1] = p.y + (Math.random() - 0.5) * 0.4;
      this.pos[i * 3 + 2] = p.z + (Math.random() - 0.5) * 0.4;
      this.vel[i * 3] = Math.cos(a) * sp;
      this.vel[i * 3 + 1] = 3 + Math.random() * 4;
      this.vel[i * 3 + 2] = Math.sin(a) * sp;
      this.tier[i] = tier;
      this.age[i] = 0;
      this.pull[i] = 0;
      this.mesh.setColorAt(i, _c.setHex(TIERS[tier].color));
    }
    this.mesh.instanceColor.needsUpdate = true;
  }

  remove(i) {
    const last = --this.count;
    if (i !== last) {
      for (let k = 0; k < 3; k++) {
        this.pos[i * 3 + k] = this.pos[last * 3 + k];
        this.vel[i * 3 + k] = this.vel[last * 3 + k];
      }
      this.tier[i] = this.tier[last];
      this.age[i] = this.age[last];
      this.pull[i] = this.pull[last];
      this.mesh.setColorAt(i, _c.setHex(TIERS[this.tier[i]].color));
      this.mesh.instanceColor.needsUpdate = true;
    }
  }

  // canCollect(tier) -> bool, collect(tier)
  update(dt, chunk, playerPos, magnet, canCollect, collect) {
    const px = playerPos.x, py = playerPos.y + 0.9, pz = playerPos.z;
    const mag2 = magnet * magnet;
    for (let i = 0; i < this.count; i++) {
      const o = i * 3;
      this.age[i] += dt;
      const dx = px - this.pos[o], dy = py - this.pos[o + 1], dz = pz - this.pos[o + 2];
      const d2 = dx * dx + dy * dy + dz * dz;

      if (!this.pull[i] && d2 < mag2 && this.age[i] > 0.35 && canCollect(this.tier[i])) this.pull[i] = 1;

      if (this.pull[i]) {
        const d = Math.sqrt(d2) || 1;
        if (d < 0.8) {
          if (canCollect(this.tier[i])) {
            collect(this.tier[i]);
            this.remove(i);
            i--;
            continue;
          }
          this.pull[i] = 0;
        } else {
          const sp = 10 + 30 / (d + 0.5) + this.age[i] * 2;
          this.vel[o] = (dx / d) * sp;
          this.vel[o + 1] = (dy / d) * sp;
          this.vel[o + 2] = (dz / d) * sp;
          this.pos[o] += this.vel[o] * dt;
          this.pos[o + 1] += this.vel[o + 1] * dt;
          this.pos[o + 2] += this.vel[o + 2] * dt;
        }
      } else {
        this.vel[o + 1] -= 20 * dt;
        this.pos[o] += this.vel[o] * dt;
        this.pos[o + 1] += this.vel[o + 1] * dt;
        this.pos[o + 2] += this.vel[o + 2] * dt;
        const floorY = 0.14;
        if (this.pos[o + 1] < floorY) {
          this.pos[o + 1] = floorY;
          this.vel[o + 1] = Math.abs(this.vel[o + 1]) * 0.3;
          this.vel[o] *= 0.6; this.vel[o + 2] *= 0.6;
        }
        if (chunk.isSolid(this.pos[o], this.pos[o + 1] - 0.14, this.pos[o + 2])) {
          this.pos[o + 1] = Math.floor(this.pos[o + 1] - 0.14) + 1.14;
          this.vel[o + 1] = Math.abs(this.vel[o + 1]) * 0.3;
          this.vel[o] *= 0.6; this.vel[o + 2] *= 0.6;
        }
        const r = Math.hypot(this.pos[o], this.pos[o + 2]);
        if (r > ISLAND_RADIUS) {
          const k = ISLAND_RADIUS / r;
          this.pos[o] *= k; this.pos[o + 2] *= k;
          this.vel[o] *= -0.5; this.vel[o + 2] *= -0.5;
        }
      }

      const a = this.age[i];
      const bob = this.pull[i] ? 0 : Math.max(0, Math.sin(a * 2.5)) * 0.06;
      _p.set(this.pos[o], this.pos[o + 1] + bob, this.pos[o + 2]);
      _q.setFromEuler(_e.set(a * 1.3, a * 2.1, 0));
      _s.setScalar(Math.min(1, a * 4) * (this.pull[i] ? 0.8 : 1));
      this.mesh.setMatrixAt(i, _m.compose(_p, _q, _s));
    }
    this.mesh.count = this.count;
    this.mesh.instanceMatrix.needsUpdate = true;
  }

  clear() {
    this.count = 0;
    this.mesh.count = 0;
  }
}
