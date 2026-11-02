import * as THREE from "three";

// A Google-Maps-like orbit: a target on the ground, a distance, a yaw and a pitch.
// Left drag pans along the ground, right drag (or Ctrl+left) rotates and tilts, the
// wheel zooms toward the cursor. Everything eases toward the desired state.

// KeyboardEvent.code, or its equivalent rebuilt from keyCode: the game's browser is sent
// key events without a scan code, so `code` arrives empty there.
const BY_KEYCODE: Record<number, string> = {
  8: "Backspace", 27: "Escape", 32: "Space", 37: "ArrowLeft", 38: "ArrowUp", 39: "ArrowRight", 40: "ArrowDown",
  46: "Delete", 107: "NumpadAdd", 109: "NumpadSubtract", 187: "Equal", 189: "Minus",
};
export function keyName(e: KeyboardEvent): string {
  if (e.code) return e.code;
  const c = e.keyCode;
  if (c >= 65 && c <= 90) return "Key" + String.fromCharCode(c);
  return BY_KEYCODE[c] ?? (e.key === "Escape" || e.key === "Esc" ? "Escape" : e.key ?? "");
}

export interface OrbitState { target: THREE.Vector3; distance: number; yaw: number; pitch: number }

export class MapControls {
  readonly current: OrbitState;
  readonly desired: OrbitState;
  minDistance = 60;
  maxDistance = 11000;
  minPitch = 0.0;
  maxPitch = THREE.MathUtils.degToRad(72);
  enabled = true;
  onChange: () => void = () => {};
  onPick: (ndc: THREE.Vector2) => THREE.Vector3 | null = () => null;

  private dragging: "pan" | "rotate" | null = null;
  private last = new THREE.Vector2();
  private panAnchor: THREE.Vector3 | null = null;
  private keys = new Set<string>();
  private plane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
  private ray = new THREE.Raycaster();

  constructor(private camera: THREE.PerspectiveCamera, private dom: HTMLElement, init: OrbitState) {
    this.current = { target: init.target.clone(), distance: init.distance, yaw: init.yaw, pitch: init.pitch };
    this.desired = { target: init.target.clone(), distance: init.distance, yaw: init.yaw, pitch: init.pitch };
    dom.addEventListener("pointerdown", this.down);
    window.addEventListener("pointermove", this.move);
    window.addEventListener("pointerup", this.up);
    dom.addEventListener("wheel", this.wheel, { passive: false });
    dom.addEventListener("contextmenu", (e) => e.preventDefault());
    window.addEventListener("keydown", (e) => { if (this.enabled && !(e.target instanceof HTMLInputElement)) this.keys.add(keyName(e)); });
    window.addEventListener("keyup", (e) => this.keys.delete(keyName(e)));
    window.addEventListener("blur", () => this.keys.clear());
  }

  private ndc(e: { clientX: number; clientY: number }): THREE.Vector2 {
    const r = this.dom.getBoundingClientRect();
    return new THREE.Vector2(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1);
  }
  private groundAt(ndc: THREE.Vector2, height = this.current.target.y): THREE.Vector3 | null {
    this.plane.constant = -height;
    this.ray.setFromCamera(ndc, this.camera);
    const p = new THREE.Vector3();
    return this.ray.ray.intersectPlane(this.plane, p) ? p : null;
  }

  private down = (e: PointerEvent) => {
    if (!this.enabled) return;
    this.dom.setPointerCapture?.(e.pointerId);
    this.last.set(e.clientX, e.clientY);
    if (e.button === 2 || e.button === 1 || (e.button === 0 && (e.ctrlKey || e.shiftKey))) this.dragging = "rotate";
    else if (e.button === 0) { this.dragging = "pan"; this.panAnchor = this.groundAt(this.ndc(e)); }
  };
  private move = (e: PointerEvent) => {
    if (!this.dragging) return;
    const dx = e.clientX - this.last.x, dy = e.clientY - this.last.y;
    this.last.set(e.clientX, e.clientY);
    if (this.dragging === "rotate") {
      this.desired.yaw -= dx * 0.0055;
      this.desired.pitch = THREE.MathUtils.clamp(this.desired.pitch + dy * 0.0045, this.minPitch, this.maxPitch);
    } else if (this.panAnchor) {
      // keep the grabbed ground point under the cursor
      this.syncCamera(this.desired);
      const p = this.groundAt(this.ndc(e), this.panAnchor.y);
      if (p) this.desired.target.add(this.panAnchor.clone().sub(p));
      this.syncCamera(this.current);
    }
    this.onChange();
  };
  private up = () => { this.dragging = null; this.panAnchor = null; };
  private wheel = (e: WheelEvent) => {
    if (!this.enabled) return;
    e.preventDefault();
    const factor = Math.exp(Math.sign(e.deltaY) * Math.min(Math.abs(e.deltaY), 240) * 0.0016);
    const next = THREE.MathUtils.clamp(this.desired.distance * factor, this.minDistance, this.maxDistance);
    // zoom toward the cursor: move the target along the cursor's ground point
    const p = this.onPick(this.ndc(e)) ?? this.groundAt(this.ndc(e));
    if (p) {
      const k = 1 - next / this.desired.distance;
      this.desired.target.lerp(new THREE.Vector3(p.x, this.desired.target.y, p.z), k);
    }
    this.desired.distance = next;
    this.onChange();
  };

  isBusy(): boolean { return this.dragging !== null || this.keys.size > 0; }

  flyTo(target: THREE.Vector3, distance?: number, yaw?: number, pitch?: number): void {
    this.desired.target.copy(target);
    if (distance !== undefined) this.desired.distance = THREE.MathUtils.clamp(distance, this.minDistance, this.maxDistance);
    if (yaw !== undefined) this.desired.yaw = yaw;
    if (pitch !== undefined) this.desired.pitch = THREE.MathUtils.clamp(pitch, this.minPitch, this.maxPitch);
  }

  /** Keyboard pan/rotate/zoom, then ease the current state toward the desired one. Returns true while moving. */
  update(dt: number): boolean {
    const d = this.desired;
    if (this.enabled && this.keys.size) {
      const speed = d.distance * 0.9 * dt;
      const fwd = new THREE.Vector3(-Math.sin(d.yaw), 0, -Math.cos(d.yaw));
      const right = new THREE.Vector3(Math.cos(d.yaw), 0, -Math.sin(d.yaw));
      const k = this.keys;
      if (k.has("KeyW") || k.has("ArrowUp")) d.target.addScaledVector(fwd, speed);
      if (k.has("KeyS") || k.has("ArrowDown")) d.target.addScaledVector(fwd, -speed);
      if (k.has("KeyD") || k.has("ArrowRight")) d.target.addScaledVector(right, speed);
      if (k.has("KeyA") || k.has("ArrowLeft")) d.target.addScaledVector(right, -speed);
      if (k.has("KeyQ")) d.yaw += 1.4 * dt;
      if (k.has("KeyE")) d.yaw -= 1.4 * dt;
      if (k.has("KeyR")) d.pitch = Math.min(this.maxPitch, d.pitch + 0.9 * dt);
      if (k.has("KeyF")) d.pitch = Math.max(this.minPitch, d.pitch - 0.9 * dt);
      if (k.has("Equal") || k.has("NumpadAdd")) d.distance = Math.max(this.minDistance, d.distance * (1 - 1.6 * dt));
      if (k.has("Minus") || k.has("NumpadSubtract")) d.distance = Math.min(this.maxDistance, d.distance * (1 + 1.6 * dt));
    }
    const c = this.current;
    const a = 1 - Math.exp(-dt * 10);
    const before = c.distance + c.yaw + c.pitch + c.target.x + c.target.z;
    c.target.lerp(d.target, a);
    c.distance += (d.distance - c.distance) * a;
    c.yaw += (d.yaw - c.yaw) * a;
    c.pitch += (d.pitch - c.pitch) * a;
    this.syncCamera(c);
    const after = c.distance + c.yaw + c.pitch + c.target.x + c.target.z;
    return Math.abs(after - before) > 1e-4 || this.keys.size > 0;
  }

  syncCamera(s: OrbitState): void {
    const off = new THREE.Vector3(
      Math.sin(s.yaw) * Math.sin(s.pitch),
      Math.cos(s.pitch),
      Math.cos(s.yaw) * Math.sin(s.pitch),
    ).multiplyScalar(s.distance);
    this.camera.position.copy(s.target).add(off);
    this.camera.up.set(-Math.sin(s.yaw), 0, -Math.cos(s.yaw)).lerp(new THREE.Vector3(0, 1, 0), Math.min(1, s.pitch / 0.35));
    this.camera.lookAt(s.target);
    this.camera.near = Math.max(1, s.distance * 0.02);
    this.camera.far = s.distance * 12 + 20000;
    this.camera.updateProjectionMatrix();
    this.camera.updateMatrixWorld();
  }
}
