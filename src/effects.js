import * as THREE from 'three';

const _m = new THREE.Matrix4();
const _v = new THREE.Vector3();
const _c = new THREE.Color();
const UP = new THREE.Vector3(0, 1, 0);

// Funken, Projektile, Strahlen und Explosionsringe.
export class Effects {
  constructor(scene) {
    this.scene = scene;

    // Funken
    this.sparkMax = 600;
    this.sparks = [];
    this.sparkMesh = new THREE.InstancedMesh(
      new THREE.SphereGeometry(0.07, 6, 4),
      new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.9, depthWrite: false }),
      this.sparkMax,
    );
    this.sparkMesh.count = 0;
    this.sparkMesh.frustumCulled = false;
    this.sparkMesh.setColorAt(0, _c.setHex(0xffffff));
    scene.add(this.sparkMesh);

    // Projektile
    this.projGeo = new THREE.SphereGeometry(0.16, 16, 12);
    this.projectiles = [];

    // Strahl
    this.beam = new THREE.Mesh(
      new THREE.CylinderGeometry(0.05, 0.05, 1, 8, 1, true).translate(0, 0.5, 0),
      new THREE.MeshBasicMaterial({ color: 0xff9be8, transparent: true, opacity: 0.85, depthWrite: false, blending: THREE.AdditiveBlending }),
    );
    this.beam.visible = false;
    this.beam.frustumCulled = false;
    scene.add(this.beam);

    // Drohnen-Laser
    this.lasers = [];

    // Ringe
    this.rings = [];
    this.ringGeo = new THREE.SphereGeometry(1, 24, 16);
  }

  burst(p, color, n = 8, speed = 4) {
    for (let i = 0; i < n; i++) {
      if (this.sparks.length >= this.sparkMax) this.sparks.shift();
      const v = new THREE.Vector3(Math.random() - 0.5, Math.random() * 0.8 + 0.1, Math.random() - 0.5)
        .normalize().multiplyScalar(speed * (0.4 + Math.random()));
      this.sparks.push({ p: p.clone(), v, life: 0.5 + Math.random() * 0.3, max: 0.8, color });
    }
  }

  projectile(from, to, color, size, onArrive) {
    const mat = new THREE.MeshPhysicalMaterial({
      color, roughness: 0, transparent: true, opacity: 0.6, iridescence: 1, clearcoat: 1, emissive: color, emissiveIntensity: 0.4,
    });
    const mesh = new THREE.Mesh(this.projGeo, mat);
    mesh.scale.setScalar(size);
    mesh.position.copy(from);
    this.scene.add(mesh);
    const dist = from.distanceTo(to);
    this.projectiles.push({ mesh, from: from.clone(), to: to.clone(), t: 0, dur: Math.max(0.03, dist / 75), onArrive });
  }

  ring(p, color, radius) {
    const mesh = new THREE.Mesh(this.ringGeo, new THREE.MeshPhysicalMaterial({
      color, transparent: true, opacity: 0.5, roughness: 0, iridescence: 1, depthWrite: false, emissive: color, emissiveIntensity: 0.5,
    }));
    mesh.position.copy(p);
    mesh.scale.setScalar(0.1);
    this.scene.add(mesh);
    this.rings.push({ mesh, t: 0, radius });
  }

  setBeam(from, to, color) {
    if (!from) { this.beam.visible = false; return; }
    this.beam.visible = true;
    this.beam.material.color.setHex(color);
    this.beam.position.copy(from);
    _v.subVectors(to, from);
    const len = _v.length();
    this.beam.scale.set(1 + Math.random() * 0.6, len, 1 + Math.random() * 0.6);
    this.beam.quaternion.setFromUnitVectors(UP, _v.normalize());
  }

  laser(from, to, color) {
    const geo = new THREE.BufferGeometry().setFromPoints([from, to]);
    const line = new THREE.Line(geo, new THREE.LineBasicMaterial({ color, transparent: true, opacity: 1 }));
    this.scene.add(line);
    this.lasers.push({ line, t: 0 });
  }

  update(dt) {
    // Projektile
    for (let i = this.projectiles.length - 1; i >= 0; i--) {
      const pr = this.projectiles[i];
      pr.t += dt;
      const k = Math.min(1, pr.t / pr.dur);
      pr.mesh.position.lerpVectors(pr.from, pr.to, k);
      if (k >= 1) {
        this.scene.remove(pr.mesh);
        pr.mesh.material.dispose();
        this.projectiles.splice(i, 1);
        pr.onArrive?.(pr.to);
      }
    }

    // Funken
    let n = 0;
    for (let i = this.sparks.length - 1; i >= 0; i--) {
      const s = this.sparks[i];
      s.life -= dt;
      if (s.life <= 0) { this.sparks.splice(i, 1); continue; }
      s.v.y -= 9 * dt;
      s.p.addScaledVector(s.v, dt);
      const sc = s.life / s.max;
      _m.makeScale(sc, sc, sc).setPosition(s.p);
      this.sparkMesh.setMatrixAt(n, _m);
      this.sparkMesh.setColorAt(n, _c.setHex(s.color).lerp(WHITE, 0.4));
      n++;
    }
    this.sparkMesh.count = n;
    this.sparkMesh.instanceMatrix.needsUpdate = true;
    if (this.sparkMesh.instanceColor) this.sparkMesh.instanceColor.needsUpdate = true;

    // Ringe
    for (let i = this.rings.length - 1; i >= 0; i--) {
      const r = this.rings[i];
      r.t += dt;
      const k = r.t / 0.45;
      r.mesh.scale.setScalar(r.radius * (1 - Math.pow(1 - Math.min(k, 1), 3)));
      r.mesh.material.opacity = 0.5 * (1 - k);
      if (k >= 1) {
        this.scene.remove(r.mesh);
        r.mesh.material.dispose();
        this.rings.splice(i, 1);
      }
    }

    // Laser
    for (let i = this.lasers.length - 1; i >= 0; i--) {
      const l = this.lasers[i];
      l.t += dt;
      l.line.material.opacity = 1 - l.t / 0.18;
      if (l.t > 0.18) {
        this.scene.remove(l.line);
        l.line.geometry.dispose();
        l.line.material.dispose();
        this.lasers.splice(i, 1);
      }
    }
  }
}

const WHITE = new THREE.Color(0xffffff);
