import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import { TIERS, TOTAL_BLOCKS } from './config.js';

// Gitter-Koordinaten entsprechen Weltkoordinaten: Zelle (i,j,k) belegt [i,i+1]x[j,j+1]x[k,k+1].
const OFF = 64;
const DIM = 128;

const _m = new THREE.Matrix4();
const _c = new THREE.Color();

export class Chunk {
  constructor(scene) {
    this.grid = new Int16Array(DIM * DIM * DIM).fill(-1);
    const n = TOTAL_BLOCKS;
    this.n = n;
    this.bi = new Int16Array(n);
    this.bj = new Int16Array(n);
    this.bk = new Int16Array(n);
    this.tier = new Uint8Array(n);
    this.hp = new Float32Array(n);
    this.alive = new Uint8Array(n);
    this.inst = new Int32Array(n).fill(-1); // Slot im sichtbaren Instanz-Array, -1 = unsichtbar
    this.vis = TIERS.map(() => []);
    this.aliveCount = 0;
    this.tierAlive = [0, 0, 0, 0, 0];
    this.tierTotal = [0, 0, 0, 0, 0];
    this.flashes = new Map();
    this.dirty = new Set();
    this.onBreak = null;

    // Exponierte Blöcke (mind. ein freier Nachbar) für Drohnen-Zielwahl.
    this.exposedArr = [];
    this.exposedPos = new Int32Array(n).fill(-1);

    this.generate();
    this.buildMeshes(scene);
    this.recomputeExposed();
  }

  generate() {
    const cx = 0, cy = 8.5, cz = 0;
    const cells = [];
    for (let i = -20; i < 20; i++) {
      for (let j = 0; j < 30; j++) {
        for (let k = -20; k < 20; k++) {
          const px = i + 0.5, py = j + 0.5, pz = k + 0.5;
          const dx = px - cx, dy = (py - cy) * 1.1, dz = pz - cz;
          const wobble = 1
            + 0.12 * Math.sin(px * 0.45 + 1.3) * Math.cos(pz * 0.38)
            + 0.08 * Math.sin(py * 0.6 + pz * 0.3)
            + 0.05 * Math.cos(px * 0.9 - py * 0.4);
          cells.push({ i, j, k, d: Math.sqrt(dx * dx + dy * dy + dz * dz) / wobble });
        }
      }
    }
    cells.sort((a, b) => a.d - b.d);

    // Rang 0 = Zentrum. Innere Stufen sind härter.
    const bounds = [];
    let acc = 0;
    for (let t = TIERS.length - 1; t >= 0; t--) {
      acc += TIERS[t].frac;
      bounds.push({ t, upTo: acc });
    }

    for (let r = 0; r < this.n; r++) {
      const c = cells[r];
      const f = r / this.n;
      let tier = 0;
      for (const b of bounds) { if (f < b.upTo) { tier = b.t; break; } }
      this.bi[r] = c.i; this.bj[r] = c.j; this.bk[r] = c.k;
      this.tier[r] = tier;
      this.hp[r] = TIERS[tier].hp;
      this.alive[r] = 1;
      this.tierTotal[tier]++;
      this.grid[this.key(c.i, c.j, c.k)] = r;
    }
    this.aliveCount = this.n;
    this.tierAlive = this.tierTotal.slice();
  }

  buildMeshes(scene) {
    const geo = new RoundedBoxGeometry(0.97, 0.97, 0.97, 1, 0.1);
    this.meshes = TIERS.map((t, ti) => {
      const mat = new THREE.MeshPhysicalMaterial({
        color: 0xffffff,
        roughness: ti === 3 ? 0.08 : 0.18,
        metalness: ti === 3 ? 0.85 : 0.0,
        clearcoat: 1,
        clearcoatRoughness: 0.05,
        iridescence: ti === 4 ? 1 : 0,
        iridescenceIOR: 1.6,
      });
      const mesh = new THREE.InstancedMesh(geo, mat, Math.max(1, this.tierTotal[ti]));
      mesh.castShadow = true;
      mesh.receiveShadow = true;
      mesh.count = 0;
      mesh.setColorAt(0, _c.setHex(0xffffff));
      mesh.boundingSphere = new THREE.Sphere(new THREE.Vector3(0, 10, 0), 30);
      scene.add(mesh);
      return mesh;
    });
  }

  // Nur freiliegende Blöcke werden gezeichnet; innere Blöcke sind ohnehin verdeckt.
  showBlock(b) {
    const t = this.tier[b];
    const slot = this.vis[t].length;
    this.vis[t].push(b);
    this.inst[b] = slot;
    const mesh = this.meshes[t];
    _m.makeTranslation(this.bi[b] + 0.5, this.bj[b] + 0.5, this.bk[b] + 0.5);
    mesh.setMatrixAt(slot, _m);
    mesh.setColorAt(slot, this.baseColor(b));
    mesh.count = this.vis[t].length;
    this.dirty.add(t);
  }

  hideBlock(b) {
    const t = this.tier[b];
    const slot = this.inst[b];
    if (slot < 0) return;
    const list = this.vis[t];
    const last = list.pop();
    const mesh = this.meshes[t];
    if (last !== b) {
      list[slot] = last;
      this.inst[last] = slot;
      _m.makeTranslation(this.bi[last] + 0.5, this.bj[last] + 0.5, this.bk[last] + 0.5);
      mesh.setMatrixAt(slot, _m);
      mesh.setColorAt(slot, this.flashes.has(last) ? _c.setHex(0xffffff) : this.baseColor(last));
    }
    this.inst[b] = -1;
    mesh.count = list.length;
    this.dirty.add(t);
  }

  baseColor(b) {
    const t = this.tier[b];
    const ratio = this.hp[b] / TIERS[t].hp;
    // Leichte Variation pro Block für den glänzenden Fliesen-Look.
    const v = 0.92 + 0.08 * Math.sin(this.bi[b] * 12.9 + this.bj[b] * 78.2 + this.bk[b] * 37.7);
    _c.setHex(TIERS[t].color).multiplyScalar(v * (0.55 + 0.45 * ratio));
    return _c;
  }

  key(i, j, k) {
    return ((i + OFF) * DIM + j) * DIM + (k + OFF);
  }

  get(i, j, k) {
    if (i < -OFF || i >= OFF || j < 0 || j >= DIM || k < -OFF || k >= OFF) return -1;
    return this.grid[this.key(i, j, k)];
  }

  isSolid(x, y, z) {
    return this.get(Math.floor(x), Math.floor(y), Math.floor(z)) >= 0;
  }

  center(b, out = new THREE.Vector3()) {
    return out.set(this.bi[b] + 0.5, this.bj[b] + 0.5, this.bk[b] + 0.5);
  }

  // Voxel-DDA. Liefert bis zu maxHits Treffer entlang des Strahls.
  raycast(o, d, maxDist, maxHits = 1) {
    let x = Math.floor(o.x), y = Math.floor(o.y), z = Math.floor(o.z);
    const stepX = d.x > 0 ? 1 : -1, stepY = d.y > 0 ? 1 : -1, stepZ = d.z > 0 ? 1 : -1;
    const tdx = d.x !== 0 ? Math.abs(1 / d.x) : Infinity;
    const tdy = d.y !== 0 ? Math.abs(1 / d.y) : Infinity;
    const tdz = d.z !== 0 ? Math.abs(1 / d.z) : Infinity;
    let tmx = d.x !== 0 ? (d.x > 0 ? x + 1 - o.x : o.x - x) * tdx : Infinity;
    let tmy = d.y !== 0 ? (d.y > 0 ? y + 1 - o.y : o.y - y) * tdy : Infinity;
    let tmz = d.z !== 0 ? (d.z > 0 ? z + 1 - o.z : o.z - z) * tdz : Infinity;
    let t = 0;
    const hits = [];
    while (t <= maxDist) {
      const idx = this.get(x, y, z);
      if (idx >= 0) {
        hits.push({ index: idx, dist: t });
        if (hits.length >= maxHits) break;
      }
      if (tmx < tmy && tmx < tmz) { x += stepX; t = tmx; tmx += tdx; }
      else if (tmy < tmz) { y += stepY; t = tmy; tmy += tdy; }
      else { z += stepZ; t = tmz; tmz += tdz; }
    }
    return hits;
  }

  damage(b, amount) {
    if (!this.alive[b]) return false;
    this.hp[b] -= amount;
    if (this.hp[b] <= 0) {
      this.destroy(b, true);
      return true;
    }
    this.flashes.set(b, 0.06);
    if (this.inst[b] >= 0) {
      this.meshes[this.tier[b]].setColorAt(this.inst[b], _c.setHex(0xffffff));
      this.dirty.add(this.tier[b]);
    }
    return false;
  }

  damageSphere(p, radius, amount) {
    const r2 = radius * radius;
    let broke = 0;
    for (let i = Math.floor(p.x - radius); i <= Math.floor(p.x + radius); i++) {
      for (let j = Math.max(0, Math.floor(p.y - radius)); j <= Math.floor(p.y + radius); j++) {
        for (let k = Math.floor(p.z - radius); k <= Math.floor(p.z + radius); k++) {
          const b = this.get(i, j, k);
          if (b < 0) continue;
          const dx = i + 0.5 - p.x, dy = j + 0.5 - p.y, dz = k + 0.5 - p.z;
          const d2 = dx * dx + dy * dy + dz * dz;
          if (d2 > r2) continue;
          const falloff = 1 - 0.5 * Math.sqrt(d2) / radius;
          if (this.damage(b, amount * falloff)) broke++;
        }
      }
    }
    return broke;
  }

  destroy(b, emit) {
    this.alive[b] = 0;
    this.hp[b] = 0;
    const t = this.tier[b];
    this.grid[this.key(this.bi[b], this.bj[b], this.bk[b])] = -1;
    this.flashes.delete(b);
    this.aliveCount--;
    this.tierAlive[t]--;
    this.removeExposed(b);
    if (emit) {
      const i = this.bi[b], j = this.bj[b], k = this.bk[b];
      for (const [di, dj, dk] of NEIGHBORS) {
        const nb = this.get(i + di, j + dj, k + dk);
        if (nb >= 0) this.addExposed(nb);
      }
      if (this.onBreak) this.onBreak(b, t);
    }
  }

  addExposed(b) {
    if (this.exposedPos[b] >= 0) return;
    this.exposedPos[b] = this.exposedArr.length;
    this.exposedArr.push(b);
    this.showBlock(b);
  }

  removeExposed(b) {
    const p = this.exposedPos[b];
    if (p < 0) return;
    const last = this.exposedArr.pop();
    if (last !== b) {
      this.exposedArr[p] = last;
      this.exposedPos[last] = p;
    }
    this.exposedPos[b] = -1;
    this.hideBlock(b);
  }

  recomputeExposed() {
    this.exposedArr.length = 0;
    this.exposedPos.fill(-1);
    this.inst.fill(-1);
    this.vis.forEach((l, t) => { l.length = 0; this.meshes[t].count = 0; });
    for (let b = 0; b < this.n; b++) {
      if (!this.alive[b]) continue;
      const i = this.bi[b], j = this.bj[b], k = this.bk[b];
      for (const [di, dj, dk] of NEIGHBORS) {
        if (j + dj < 0) continue; // Boden zählt als bedeckt
        if (this.get(i + di, j + dj, k + dk) < 0) { this.addExposed(b); break; }
      }
    }
  }

  randomExposed() {
    if (!this.exposedArr.length) return -1;
    return this.exposedArr[(Math.random() * this.exposedArr.length) | 0];
  }

  update(dt) {
    for (const [b, time] of this.flashes) {
      const left = time - dt;
      if (left <= 0) {
        this.flashes.delete(b);
        if (this.alive[b] && this.inst[b] >= 0) {
          this.meshes[this.tier[b]].setColorAt(this.inst[b], this.baseColor(b));
          this.dirty.add(this.tier[b]);
        }
      } else {
        this.flashes.set(b, left);
      }
    }
    for (const t of this.dirty) {
      this.meshes[t].instanceMatrix.needsUpdate = true;
      this.meshes[t].instanceColor.needsUpdate = true;
    }
    this.dirty.clear();
  }

  // Speicherstand: Bitfeld der noch lebenden Blöcke als Base64.
  serialize() {
    const bytes = new Uint8Array(Math.ceil(this.n / 8));
    for (let b = 0; b < this.n; b++) if (this.alive[b]) bytes[b >> 3] |= 1 << (b & 7);
    let s = '';
    for (const x of bytes) s += String.fromCharCode(x);
    return btoa(s);
  }

  restore(str) {
    const s = atob(str);
    for (let b = 0; b < this.n; b++) {
      const bit = (s.charCodeAt(b >> 3) >> (b & 7)) & 1;
      if (!bit && this.alive[b]) this.destroy(b, false);
    }
    this.recomputeExposed();
    this.update(0);
  }
}

const NEIGHBORS = [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]];
