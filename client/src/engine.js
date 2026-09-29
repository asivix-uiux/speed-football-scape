import * as THREE from 'three';

export const T = THREE;
export const V3 = THREE.Vector3;
export const $ = (s) => document.querySelector(s);
export const hexCss = (h) => '#' + h.toString(16).padStart(6, '0');

// ----- renderer, scene, camera, lights -----
export const canvas = $('#view');
export const renderer = new T.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(devicePixelRatio || 1, 1.5));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = T.PCFShadowMap;

export const scene = new T.Scene();
const FOG = 0x3a3150;
scene.background = new T.Color(FOG);
scene.fog = new T.Fog(FOG, 170, 460);

export const camera = new T.PerspectiveCamera(70, 1, 0.3, 700);
function resize() {
    const w = innerWidth, h = innerHeight;
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.fov = w < h ? 85 : 70;
    camera.updateProjectionMatrix();
}
addEventListener('resize', resize);
resize();

// Physically based light units: intensities are ~pi times the legacy values
scene.add(new T.HemisphereLight(0xffffff, 0x6a5f80, 2.5));
scene.add(new T.AmbientLight(0xffffff, 0.7));
export const sun = new T.DirectionalLight(0xffffff, 1.9);
sun.castShadow = true;
sun.shadow.mapSize.set(1024, 1024);
Object.assign(sun.shadow.camera, { left: -45, right: 45, top: 45, bottom: -45, near: 1, far: 220 });
sun.shadow.bias = -0.0015;
scene.add(sun, sun.target);

// ----- materials & textures -----
export const UNIT = new T.BoxGeometry(1, 1, 1);
const matCache = new Map();
export function mat(color, o) {
    o = o || {};
    const key = color + '|' + (o.neon ? 1 : 0) + '|' + (o.opacity || 1);
    let m = matCache.get(key);
    if (!m) {
        m = o.neon ? new T.MeshBasicMaterial({ color }) : new T.MeshLambertMaterial({ color });
        if (o.opacity && o.opacity < 1) { m.transparent = true; m.opacity = o.opacity; m.depthWrite = false; }
        matCache.set(key, m);
    }
    return m;
}
export function texFrom(cv) {
    const t = new T.CanvasTexture(cv);
    t.colorSpace = T.SRGBColorSpace;
    t.anisotropy = 4;
    return t;
}
const studCanvas = (() => {
    const c = document.createElement('canvas'); c.width = c.height = 64;
    const x = c.getContext('2d');
    x.fillStyle = '#f2f2f2'; x.fillRect(0, 0, 64, 64);
    x.fillStyle = '#d6d6d6'; x.beginPath(); x.arc(33, 34, 17, 0, Math.PI * 2); x.fill();
    x.fillStyle = '#ffffff'; x.beginPath(); x.arc(31, 31, 16, 0, Math.PI * 2); x.fill();
    x.strokeStyle = '#e2e2e2'; x.lineWidth = 2; x.strokeRect(1, 1, 62, 62);
    return c;
})();
const studBase = texFrom(studCanvas);
studBase.wrapS = studBase.wrapT = T.RepeatWrapping;
studBase.anisotropy = renderer.capabilities.getMaxAnisotropy();
function studMat(color, rx, rz) {
    rx = Math.max(1, Math.round(rx)); rz = Math.max(1, Math.round(rz));
    const key = 'stud|' + color + '|' + rx + '|' + rz;
    let m = matCache.get(key);
    if (!m) {
        const t = studBase.clone(); t.needsUpdate = true; t.repeat.set(rx, rz);
        m = new T.MeshLambertMaterial({ color, map: t });
        matCache.set(key, m);
    }
    return m;
}

// ----- world collections -----
export const solids = [];   // {min,max,belt,tread}
export const kills = [];    // {min,max,active}
export const triggers = []; // {min,max,enter,inside}
export const prompts = [];  // {pos,r,label(),act()}
export const tickers = [];  // per-frame callbacks (dt, t)

export function aabb(x, y, z, sx, sy, sz) {
    return { min: new V3(x - sx / 2, y - sy / 2, z - sz / 2), max: new V3(x + sx / 2, y + sy / 2, z + sz / 2) };
}

// box(sx,sy,sz, x,y,z, color, {studs, neon, opacity, decor, kill, cast})
export function box(sx, sy, sz, x, y, z, color, o) {
    o = o || {};
    let m;
    if (o.studs) {
        const side = mat(color), top = studMat(color, sx / 2, sz / 2);
        m = new T.Mesh(UNIT, [side, side, top, side, side, side]);
    } else {
        m = new T.Mesh(UNIT, mat(color, o));
    }
    m.scale.set(sx, sy, sz);
    m.position.set(x, y, z);
    if (!o.neon) m.receiveShadow = true;
    if (o.cast) m.castShadow = true;
    m.matrixAutoUpdate = false;
    m.updateMatrix();
    scene.add(m);
    if (o.kill) {
        const k = aabb(x, y, z, sx, sy, sz); k.active = true; kills.push(k);
    } else if (!o.decor) {
        solids.push(aabb(x, y, z, sx, sy, sz));
    }
    return m;
}

// ----- text -----
export function textCanvas(lines, W) {
    const pad = 10;
    let H = pad * 2;
    for (const l of lines) H += l.px * 1.2;
    const cv = document.createElement('canvas');
    cv.width = W; cv.height = Math.ceil(H);
    const x = cv.getContext('2d');
    let y = pad;
    for (const l of lines) {
        let px = l.px;
        const font = (p) => `${l.w || 700} ${p}px Fredoka, "Arial Rounded MT Bold", sans-serif`;
        x.font = font(px);
        while (x.measureText(l.t).width > W - 24 && px > 8) { px -= 2; x.font = font(px); }
        x.textAlign = 'center'; x.textBaseline = 'middle';
        const cy = y + l.px * 0.62;
        if (l.s) { x.lineJoin = 'round'; x.lineWidth = Math.max(4, px * 0.22); x.strokeStyle = l.s; x.strokeText(l.t, W / 2, cy); }
        x.fillStyle = l.c || '#fff';
        x.fillText(l.t, W / 2, cy);
        y += l.px * 1.2;
    }
    return cv;
}
export function billboard(lines, worldW, W, pos, parent) {
    W = W || 512;
    const cv = textCanvas(lines, W);
    const sp = new T.Sprite(new T.SpriteMaterial({ map: texFrom(cv), transparent: true, depthWrite: false }));
    sp.scale.set(worldW, worldW * cv.height / cv.width, 1);
    if (pos) sp.position.copy(pos);
    sp.userData.set = (nl) => {
        const c2 = textCanvas(nl, W);
        sp.material.map.dispose();
        sp.material.map = texFrom(c2);
        sp.material.needsUpdate = true;
        sp.scale.set(worldW, worldW * c2.height / c2.width, 1);
    };
    (parent || scene).add(sp);
    return sp;
}
export function textPlane(lines, worldW, W, pos, look) {
    const cv = textCanvas(lines, W || 512);
    const h = worldW * cv.height / cv.width;
    const m = new T.Mesh(new T.PlaneGeometry(worldW, h), new T.MeshBasicMaterial({ map: texFrom(cv), transparent: true, depthWrite: false }));
    m.position.copy(pos);
    m.lookAt(look);
    scene.add(m);
    return m;
}
// Board facing `dir` (horizontal unit vector) with a border and text
export function signBoard(center, dir, w, h, lines, boardColor) {
    const g = new T.Group();
    g.position.copy(center); g.rotation.y = Math.atan2(dir.x, dir.z);
    const b1 = new T.Mesh(UNIT, mat(0x78372d)); b1.scale.set(w + 2, h + 2, 0.4); b1.position.z = -0.4; g.add(b1);
    const b2 = new T.Mesh(UNIT, mat(boardColor)); b2.scale.set(w, h, 0.4); b2.position.z = -0.1; g.add(b2);
    const cv = textCanvas(lines, 1024);
    const th = Math.min(h - 1, (w - 2) * cv.height / cv.width);
    const tw = th * cv.width / cv.height;
    const tp = new T.Mesh(new T.PlaneGeometry(tw, th), new T.MeshBasicMaterial({ map: texFrom(cv), transparent: true, depthWrite: false }));
    tp.position.z = 0.15; g.add(tp);
    scene.add(g);
    return g;
}

// ----- blocky football player rigs -----
const numberTexCache = new Map();
function numberTex(n, color) {
    const key = n + color;
    if (!numberTexCache.has(key)) {
        const c = document.createElement('canvas'); c.width = c.height = 128;
        const x = c.getContext('2d');
        x.font = '700 92px Fredoka, sans-serif'; x.textAlign = 'center'; x.textBaseline = 'middle';
        x.lineWidth = 8; x.strokeStyle = 'rgba(0,0,0,0.35)'; x.strokeText(String(n), 64, 70);
        x.fillStyle = color; x.fillText(String(n), 64, 70);
        numberTexCache.set(key, texFrom(c));
    }
    return numberTexCache.get(key);
}
export function buildRig(d) {
    const g = new T.Group();
    const part = (sx, sy, sz, x, y, z, c, parent) => {
        const m = new T.Mesh(UNIT, mat(c)); m.scale.set(sx, sy, sz); m.position.set(x, y, z); m.castShadow = true; (parent || g).add(m); return m;
    };
    part(2, 2, 1, 0, 3, 0, d.shirt);
    if (d.stripes) { part(0.35, 2.02, 1.02, -0.5, 3, 0, d.stripes); part(0.35, 2.02, 1.02, 0.5, 3, 0, d.stripes); }
    const num = new T.Mesh(new T.PlaneGeometry(1.5, 1.5), new T.MeshBasicMaterial({ map: numberTex(d.num || 10, d.numC || '#fff'), transparent: true }));
    num.position.set(0, 3.05, -0.52); num.rotation.y = Math.PI; g.add(num);
    part(1.2, 1.2, 1.2, 0, 4.6, 0, d.skin);
    part(1.3, 0.42, 1.3, 0, 5.15, -0.03, d.hair);
    part(1.3, 0.8, 0.35, 0, 4.85, -0.5, d.hair);
    part(0.16, 0.24, 0.05, -0.26, 4.72, 0.61, 0x141418);
    part(0.16, 0.24, 0.05, 0.26, 4.72, 0.61, 0x141418);
    part(0.42, 0.08, 0.05, 0, 4.36, 0.61, 0x6b2a2a);
    const legs = [], arms = [];
    for (const side of [-0.5, 0.5]) {
        const p = new T.Group(); p.position.set(side, 2, 0); g.add(p);
        part(1, 0.9, 1, 0, -0.45, 0, d.shorts, p);
        part(0.98, 1.1, 0.98, 0, -1.45, 0, d.socks, p);
        part(1.05, 0.38, 1.3, 0, -1.84, 0.12, d.shoes || 0x141418, p);
        legs.push(p);
    }
    for (const side of [-1.5, 1.5]) {
        const p = new T.Group(); p.position.set(side, 3.9, 0); g.add(p);
        part(1, 0.8, 1, 0, -0.4, 0, d.shirt, p);
        part(0.98, 1.2, 0.98, 0, -1.4, 0, d.gloves || d.skin, p);
        arms.push(p);
    }
    g.userData.legs = legs; g.userData.arms = arms;
    return g;
}
export function animRig(g, phase, amt) {
    const s = Math.sin(phase) * amt;
    const u = g.userData;
    u.legs[0].rotation.x = s; u.legs[1].rotation.x = -s;
    u.arms[0].rotation.x = -s * 0.9; u.arms[1].rotation.x = s * 0.9;
}
export function airPose(g) {
    const u = g.userData;
    u.legs[0].rotation.x = 0.5; u.legs[1].rotation.x = -0.3;
    u.arms[0].rotation.x = -2.6; u.arms[1].rotation.x = -2.6;
}
export function armsUp(g) { g.userData.arms[0].rotation.x = Math.PI; g.userData.arms[1].rotation.x = Math.PI; }

// Glowing ring + orbiting cubes, attached to a rig
export function buildAuraFx(parent) {
    const fx = new T.Group();
    const ringM = new T.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.55, depthWrite: false });
    const ring = new T.Mesh(new T.RingGeometry(1.6, 2.6, 32), ringM);
    ring.rotation.x = -Math.PI / 2; ring.position.y = 0.15; fx.add(ring);
    const bits = [];
    for (let i = 0; i < 8; i++) {
        const b = new T.Mesh(UNIT, new T.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.85 }));
        b.scale.setScalar(0.35); fx.add(b); bits.push(b);
    }
    fx.userData = { ringM, bits };
    fx.visible = false;
    parent.add(fx);
    return fx;
}
const tmpColor = new T.Color();
export function updateAuraFx(fx, aura, t) {
    fx.visible = !!aura;
    if (!aura) return;
    const u = fx.userData;
    const rainbow = aura.id === 'Rainbow';
    u.ringM.color.copy(rainbow ? tmpColor.setHSL((t * 0.3) % 1, 1, 0.6) : tmpColor.set(aura.color));
    u.ringM.opacity = 0.4 + Math.sin(t * 4) * 0.15;
    u.bits.forEach((b, i) => {
        const ang = t * 2.2 + i * Math.PI / 4;
        b.material.color.copy(rainbow ? tmpColor.setHSL(((t * 0.3) + i / 8) % 1, 1, 0.6) : tmpColor.set(aura.color));
        b.position.set(Math.cos(ang) * 2.2, 1 + ((i * 0.7 + t * 1.5) % 5), Math.sin(ang) * 2.2);
        b.rotation.set(t * 3, t * 2, 0);
    });
}

// ----- football -----
const ballTex = (() => {
    const W = 512, H = 256;
    const c = document.createElement('canvas'); c.width = W; c.height = H;
    const x = c.getContext('2d');
    x.fillStyle = '#fbfbfb'; x.fillRect(0, 0, W, H);
    const phi = (1 + Math.sqrt(5)) / 2;
    const verts = [[0, 1, phi], [0, -1, phi], [0, 1, -phi], [0, -1, -phi], [1, phi, 0], [-1, phi, 0], [1, -phi, 0], [-1, -phi, 0], [phi, 0, 1], [-phi, 0, 1], [phi, 0, -1], [-phi, 0, -1]];
    x.fillStyle = '#18181c';
    for (const v of verts) {
        const l = Math.hypot(v[0], v[1], v[2]);
        const lon = Math.atan2(v[0] / l, v[2] / l), lat = Math.asin(v[1] / l);
        const u = (lon / (Math.PI * 2) + 0.5) * W, vv = (0.5 - lat / Math.PI) * H;
        const ry = H * 0.075, rx = Math.min(W * 0.5, ry / Math.max(0.12, Math.cos(lat)));
        for (const off of [-W, 0, W]) {
            x.beginPath();
            for (let k = 0; k < 5; k++) { const a = -Math.PI / 2 + k * Math.PI * 2 / 5; x.lineTo(u + off + Math.cos(a) * rx, vv + Math.sin(a) * ry); }
            x.closePath(); x.fill();
        }
    }
    return texFrom(c);
})();
const BALL_GEO = new T.SphereGeometry(1, 28, 18);
const BALL_MAT = new T.MeshLambertMaterial({ map: ballTex });
export function football(d, parent) {
    const m = new T.Mesh(BALL_GEO, BALL_MAT);
    m.scale.setScalar(d / 2); m.castShadow = true;
    (parent || scene).add(m);
    return m;
}

// ----- particles & floating text -----
const particles = [];
export function burst(pos, color) {
    for (let i = 0; i < 26; i++) {
        const m = new T.Mesh(UNIT, mat(i % 3 ? color : 0xffffff));
        m.scale.setScalar(0.5 + Math.random() * 0.5);
        m.position.copy(pos);
        scene.add(m);
        particles.push({ m, v: new V3((Math.random() * 2 - 1) * 25, Math.random() * 30 + 5, (Math.random() * 2 - 1) * 25), t: 1.2 });
    }
}
export function confettiAt(pos) {
    for (const c of [0xffd028, 0x46ec50, 0x28c8ff, 0xe82434, 0xc428ff]) burst(pos, c);
}
const floaters = [];
export function floatText(text, color, pos) {
    const sp = billboard([{ t: text, c: color, s: '#16121f', px: 70 }], 5, 512, pos);
    floaters.push({ sp, t: 1.1 });
}
export function updateEffects(dt) {
    for (let i = particles.length - 1; i >= 0; i--) {
        const p = particles[i];
        p.t -= dt; p.v.y -= 80 * dt;
        p.m.position.addScaledVector(p.v, dt);
        p.m.rotation.x += dt * 5; p.m.rotation.y += dt * 4;
        if (p.t <= 0) { scene.remove(p.m); particles.splice(i, 1); }
    }
    for (let i = floaters.length - 1; i >= 0; i--) {
        const f = floaters[i];
        f.t -= dt; f.sp.position.y += dt * 4; f.sp.material.opacity = Math.min(1, f.t * 2);
        if (f.t <= 0) { scene.remove(f.sp); f.sp.material.map.dispose(); f.sp.material.dispose(); floaters.splice(i, 1); }
    }
}

export function lerpAngle(a, b, k) {
    let d = (b - a) % (Math.PI * 2);
    if (d > Math.PI) d -= Math.PI * 2;
    if (d < -Math.PI) d += Math.PI * 2;
    return a + d * k;
}
