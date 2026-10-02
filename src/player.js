import * as THREE from 'three';
import { ISLAND_RADIUS } from './world.js';

const HALF = 0.3;
const HEIGHT = 1.75;
const EYE = 1.6;

export class Player {
  constructor(camera, dom) {
    this.camera = camera;
    this.dom = dom;
    this.pos = new THREE.Vector3(0, 0, 40);
    this.vel = new THREE.Vector3();
    this.yaw = 0;
    this.pitch = -0.08;
    this.onGround = false;
    this.keys = new Set();
    this.mouseDown = false;
    camera.rotation.order = 'YXZ';

    document.addEventListener('mousemove', (e) => {
      if (document.pointerLockElement !== dom) return;
      this.yaw -= e.movementX * 0.0022;
      this.pitch -= e.movementY * 0.0022;
      this.pitch = Math.max(-1.5, Math.min(1.5, this.pitch));
    });
    document.addEventListener('keydown', (e) => this.keys.add(e.code));
    document.addEventListener('keyup', (e) => this.keys.delete(e.code));
    dom.addEventListener('mousedown', (e) => { if (e.button === 0) this.mouseDown = true; });
    document.addEventListener('mouseup', (e) => { if (e.button === 0) this.mouseDown = false; });
    window.addEventListener('blur', () => { this.keys.clear(); this.mouseDown = false; });
  }

  get locked() { return document.pointerLockElement === this.dom; }

  collides(chunk, px, py, pz) {
    for (let x = Math.floor(px - HALF); x <= Math.floor(px + HALF); x++) {
      for (let y = Math.floor(py + 0.001); y <= Math.floor(py + HEIGHT); y++) {
        for (let z = Math.floor(pz - HALF); z <= Math.floor(pz + HALF); z++) {
          if (chunk.get(x, y, z) >= 0) return true;
        }
      }
    }
    return false;
  }

  update(dt, chunk, colliders, speed) {
    const k = this.keys;
    const f = (k.has('KeyW') || k.has('ArrowUp') ? 1 : 0) - (k.has('KeyS') || k.has('ArrowDown') ? 1 : 0);
    const s = (k.has('KeyD') || k.has('ArrowRight') ? 1 : 0) - (k.has('KeyA') || k.has('ArrowLeft') ? 1 : 0);
    const sprint = k.has('ShiftLeft') || k.has('ShiftRight') ? 1.45 : 1;
    const sin = Math.sin(this.yaw), cos = Math.cos(this.yaw);
    let wx = -sin * f + cos * s;
    let wz = -cos * f - sin * s;
    const len = Math.hypot(wx, wz);
    if (len > 0) { wx /= len; wz /= len; }
    const target = this.locked ? speed * sprint : 0;
    const accel = this.onGround ? 14 : 4;
    this.vel.x += (wx * target - this.vel.x) * Math.min(1, accel * dt);
    this.vel.z += (wz * target - this.vel.z) * Math.min(1, accel * dt);

    if (this.locked && k.has('Space') && this.onGround) {
      this.vel.y = 8;
      this.onGround = false;
    }
    this.vel.y -= 22 * dt;

    const p = this.pos;
    let nx = p.x + this.vel.x * dt;
    if (!this.collides(chunk, nx, p.y, p.z)) p.x = nx; else this.vel.x = 0;
    let nz = p.z + this.vel.z * dt;
    if (!this.collides(chunk, p.x, p.y, nz)) p.z = nz; else this.vel.z = 0;

    this.onGround = false;
    let ny = p.y + this.vel.y * dt;
    if (ny <= 0) {
      ny = 0;
      this.vel.y = 0;
      this.onGround = true;
    }
    if (this.collides(chunk, p.x, ny, p.z)) {
      if (this.vel.y <= 0) { p.y = Math.floor(ny + 0.001) + 1; this.onGround = true; }
      this.vel.y = 0;
    } else {
      p.y = ny;
    }

    // Runde Hindernisse (Station, Bäume) und Inselrand
    for (const c of colliders) {
      const dx = p.x - c.x, dz = p.z - c.z;
      const d = Math.hypot(dx, dz);
      const min = c.r + HALF;
      if (d < min && d > 0.0001) { p.x = c.x + (dx / d) * min; p.z = c.z + (dz / d) * min; }
    }
    const r = Math.hypot(p.x, p.z);
    if (r > ISLAND_RADIUS) { p.x *= ISLAND_RADIUS / r; p.z *= ISLAND_RADIUS / r; }

    // Kopfwippen beim Laufen
    const moving = Math.hypot(this.vel.x, this.vel.z);
    this.bob = (this.bob || 0) + dt * moving * 1.6;
    const bobY = this.onGround ? Math.sin(this.bob) * 0.04 * Math.min(1, moving / 5) : 0;

    this.camera.position.set(p.x, p.y + EYE + bobY, p.z);
    this.camera.rotation.set(this.pitch, this.yaw, 0);
  }

  serialize() {
    return { x: this.pos.x, y: this.pos.y, z: this.pos.z, yaw: this.yaw, pitch: this.pitch };
  }

  restore(d) {
    if (!d) return;
    this.pos.set(d.x, d.y, d.z);
    this.yaw = d.yaw;
    this.pitch = d.pitch;
  }
}
