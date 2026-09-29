import { Client } from '@colyseus/sdk';
import {
    V3, $, canvas, renderer, scene, camera, sun, solids, kills, triggers, prompts, tickers,
    billboard, buildRig, animRig, airPose, buildAuraFx, updateAuraFx, football, burst, confettiAt,
    floatText, updateEffects, lerpAngle,
} from './engine.js';
import { S, actions, net } from './state.js';
import { initAudio, startMusic, sfx } from './audio.js';
import { render, setSpeedLines, updateFx, dust, sparkleColumn, ring, fireworks } from './fx.js';
import { buildWorld, SPAWN, pickups, beltTex, refreshShop, renderBoards, treadLocked, updateSlabs } from './world.js';
import {
    updateHud, toast, levelUp, showStageTitle, buy, showRevive, hideRevive, closeModal,
    refreshModal, promptEl, promptTxtEl, showGoal, animateCounters,
} from './ui.js';
import {
    CFG, STAGES, soccerById, auraById, KITS, SKINS, maxSpeedFor, fmt, clamp,
} from '../../shared/config.js';

// =====================================================================================
// Local player
// =====================================================================================
const HW = 1, PH = 5, STEP = 1.7, GRAV = 196.2, JUMP_V = 50;
const P = {
    pos: SPAWN.clone(), vel: new V3(), push: new V3(), onGround: false, ground: null, facing: 0,
    dead: false, shield: 0, stamina: CFG.staminaMax, staminaIdle: 0, sprinting: false,
    lastSafe: SPAWN.clone(), safeTimer: 0, stage: -1, moving: false, animPhase: 0, lockToastT: -9,
    squash: 1, squashV: 0, airTime: 0, lastStep: 0,
};
const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
let shake = 0;
function addShake(a) { if (!reduceMotion) shake = Math.min(1.2, shake + a); }
let rig, auraFx, headLabel, headLabelText = '', follower = null, followerId = null;

function buildPlayer(kit, skin) {
    if (rig) scene.remove(rig);
    const k = KITS[kit % KITS.length];
    rig = buildRig({ ...k, skin: SKINS[skin % SKINS.length], hair: 0x3a2618, num: 1 + (kit % 99), numC: '#ffffff' });
    scene.add(rig);
    headLabelText = '';
    headLabel = billboard([{ t: '0 Speed', c: '#ffffff', s: '#16121f', px: 60 }], 6, 512, new V3(0, 7.4, 0), rig);
    auraFx = buildAuraFx(rig);
    rig.position.copy(P.pos);
}
function refreshFollower() {
    if (followerId === S.equipped) return;
    if (follower) scene.remove(follower);
    followerId = S.equipped;
    const d = soccerById[S.equipped];
    follower = d ? buildRig(d) : null;
    if (follower) { follower.position.copy(P.pos).add(new V3(3, 0, -3)); scene.add(follower); }
}
// Follower soccer player trots behind-right of its owner
function updateFollower(f, ownerPos, ownerFacing, dt, visible) {
    const side = new V3(Math.cos(ownerFacing), 0, -Math.sin(ownerFacing));
    const back = new V3(Math.sin(ownerFacing), 0, Math.cos(ownerFacing));
    const goal = ownerPos.clone().addScaledVector(back, -3.5).addScaledVector(side, -3);
    const before = f.position.clone();
    if (f.position.distanceToSquared(goal) > 400) f.position.copy(goal);
    f.position.lerp(goal, 1 - Math.exp(-dt * 6));
    f.position.y = ownerPos.y;
    const dx = f.position.x - before.x, dz = f.position.z - before.z;
    const sp = Math.hypot(dx, dz) / Math.max(dt, 1e-3);
    if (sp > 1) f.rotation.y = lerpAngle(f.rotation.y, Math.atan2(dx, dz), 1 - Math.exp(-dt * 10));
    f.userData.phase = (f.userData.phase || 0) + dt * Math.min(18, 4 + sp * 0.2);
    animRig(f, f.userData.phase, sp > 1 ? 0.9 : 0);
    f.visible = visible;
}

function overlapsBox(c, x, y, z) {
    return c.max.x > x - HW && c.min.x < x + HW && c.max.y > y && c.min.y < y + PH && c.max.z > z - HW && c.min.z < z + HW;
}
function freeAt(x, y, z) {
    for (const c of solids) if (overlapsBox(c, x, y, z)) return false;
    return true;
}
function moveAxis(axis, d) {
    if (d === 0) return;
    const p = P.pos;
    p[axis] += d;
    for (const c of solids) {
        if (!overlapsBox(c, p.x, p.y, p.z)) continue;
        if (axis === 'y') {
            if (d < 0) { p.y = c.max.y; P.vel.y = Math.max(0, P.vel.y); P.onGround = true; P.ground = c; }
            else { p.y = c.min.y - PH - 1e-4; if (P.vel.y > 0) P.vel.y = 0; }
        } else {
            const rise = c.max.y - p.y;
            if (rise > 0 && rise <= STEP && (P.onGround || P.vel.y <= 0) && freeAt(p.x, c.max.y + 0.01, p.z)) { p.y = c.max.y + 0.001; continue; }
            if (d > 0) p[axis] = c.min[axis] - HW - 1e-4; else p[axis] = c.max[axis] + HW + 1e-4;
        }
    }
}
function walkSpeed() {
    const max = maxSpeedFor(S.level, S.rebirths);
    let s = S.customSpeed > 0 && S.customSpeed <= max ? S.customSpeed : max;
    if (P.sprinting) s *= CFG.sprintMult;
    return s;
}

function teleport(pos, yaw) {
    P.pos.copy(pos); P.vel.set(0, 0, 0); P.push.set(0, 0, 0);
    P.lastSafe.copy(pos);
    P.facing = yaw || 0; cam.yaw = (yaw || 0) + Math.PI;
    if (follower) follower.position.copy(pos).add(new V3(3, 0, -3));
    for (const t of triggers) t.inside = overlapsBox(t, pos.x, pos.y, pos.z);
    resetChase();
    sendMove(true);
}
function teleportLobby() { P.stage = -1; teleport(SPAWN, 0); }

function die() {
    if (P.dead || P.shield > 0) return;
    P.dead = true;
    burst(P.pos.clone().add(new V3(0, 2.5, 0)), 0x2f7bff);
    sfx('death'); addShake(0.9);
    resetChase();
    sendMove(true);
    showRevive();
}
actions.revive = (atSpot) => {
    hideRevive();
    if (!P.dead) return;
    P.dead = false;
    if (atSpot) {
        teleport(P.lastSafe.clone(), P.facing);
        P.shield = CFG.shieldTime;
        const s = STAGES[P.stage];
        if (s && s.type === 'Chase') startChase(P.stage);
    } else teleportLobby();
};

// =====================================================================================
// Stage runtime: balls (server timeline), chase wall (local)
// =====================================================================================
const balls = [];
function spawnBall(m) {
    const s = STAGES[m.s];
    if (!s) return;
    const r = m.d / 2;
    balls.push({ m: football(m.d), r, x: m.x, y: r, s, t0: m.t });
}
function updateBalls() {
    const now = net.now();
    for (let i = balls.length - 1; i >= 0; i--) {
        const b = balls[i];
        const age = (now - b.t0) / 1000;
        const z = b.s.cE - 4 - b.s.bs * Math.max(0, age);
        b.m.position.set(b.x, b.y, z);
        b.m.rotation.x = -(b.s.bs * age) / b.r;
        if (age > CFG.ballLifetime || z < b.s.zS + 10) { scene.remove(b.m); balls.splice(i, 1); continue; }
        if (P.dead || P.shield > 0) continue;
        const cx = clamp(b.x, P.pos.x - HW, P.pos.x + HW), cy = clamp(b.y, P.pos.y, P.pos.y + PH), cz = clamp(z, P.pos.z - HW, P.pos.z + HW);
        const dx = cx - b.x, dy = cy - b.y, dz = cz - z;
        if (dx * dx + dy * dy + dz * dz < b.r * b.r) {
            let sx = P.pos.x - b.x; if (Math.abs(sx) < 0.5) sx = Math.random() < 0.5 ? -1 : 1;
            P.push.copy(new V3(Math.sign(sx) * 0.55, 0, -1).normalize().multiplyScalar(CFG.ballKnockback));
            P.vel.y = 38; P.onGround = false;
            P.shield = 0.35;
            sfx('hit'); addShake(0.7);
        }
    }
}

const chase = { active: false, stage: null, z: 0, wait: 0 };
function resetChase() {
    if (chase.stage) { chase.stage.chaseMesh.visible = false; chase.stage.chaseKill.active = false; }
    chase.active = false; chase.stage = null;
}
function startChase(idx) {
    resetChase();
    const s = STAGES[idx];
    Object.assign(chase, { active: true, stage: s, z: s.zS - 6, wait: s.chaseWait });
    s.chaseMesh.visible = true; s.chaseKill.active = true;
}
function updateChase(dt) {
    if (!chase.active) return;
    const s = chase.stage;
    if (chase.wait > 0) chase.wait -= dt;
    else chase.z = Math.min(s.cE - 2, chase.z + s.chaseSpeed * dt);
    s.chaseMesh.position.set(0, CFG.wallHeight / 2, chase.z);
    s.chaseKill.min.z = chase.z - 2; s.chaseKill.max.z = chase.z + 2;
    if (chase.z >= s.cE - 2) resetChase();
}

// =====================================================================================
// Actions triggered by world objects
// =====================================================================================
actions.enterStage = (idx) => {
    if (P.stage === idx) return;
    P.stage = idx;
    const s = STAGES[idx];
    showStageTitle(s);
    sfx('whoosh');
    if (s.type === 'Chase') setTimeout(() => sfx('whistle'), 300);
    if (s.type === 'Chase') startChase(idx); else resetChase();
    if (S.level < s.rec && S.rebirths === 0) toast('Recommended Level ' + s.rec + '!', '#ffb51c');
};
actions.pad = (idx) => {
    sendMove(true);
    net.send('pad', { s: idx });
    teleportLobby();
};
actions.portal = (p) => net.send('portal', { stage: p.stage });
actions.buy = (kind, key) => {
    if (kind === 'pass' && key === 'DoubleWins' && S.passes.DoubleWins) { toast('x2 Wins is active!', '#e27bff'); return; }
    buy(kind, key);
};
actions.shop = (d) => {
    if (!S.owned[d.id] && d.pass) { buy('pass', d.pass); return; }
    if (!S.owned[d.id] && S.wins < d.req) { toast('Need ' + fmt(d.req - S.wins) + ' more Wins!', '#ff5a5a'); return; }
    net.send('shop', { id: d.id });
};

// =====================================================================================
// Other players
// =====================================================================================
const remotes = new Map();
class Remote {
    constructor(p) {
        this.kit = p.kit; this.skin = p.skin;
        const k = KITS[p.kit % KITS.length];
        this.rig = buildRig({ ...k, skin: SKINS[p.skin % SKINS.length], hair: 0x3a2618, num: 1 + (p.kit % 99), numC: '#ffffff' });
        this.rig.position.set(p.x, p.y, p.z);
        this.rig.rotation.y = p.ry;
        scene.add(this.rig);
        this.labelText = '';
        this.label = billboard([{ t: p.name, c: '#ffffff', s: '#16121f', px: 56 }], 6, 512, new V3(0, 7.8, 0), this.rig);
        this.aura = buildAuraFx(this.rig);
        this.follower = null; this.followerId = null;
        this.phase = Math.random() * 6;
    }
    update(p, dt, t) {
        const r = this.rig;
        const k = 1 - Math.exp(-dt * 12);
        const tx = p.x, ty = p.y, tz = p.z;
        if ((r.position.x - tx) ** 2 + (r.position.z - tz) ** 2 > 900) r.position.set(tx, ty, tz);
        else { r.position.x += (tx - r.position.x) * k; r.position.y += (ty - r.position.y) * k; r.position.z += (tz - r.position.z) * k; }
        r.rotation.y = lerpAngle(r.rotation.y, p.ry, k);
        r.visible = p.anim !== 3;
        if (p.anim === 2) airPose(r);
        else { this.phase += dt * (p.anim === 1 ? 14 : 0); animRig(r, this.phase, p.anim === 1 ? 0.9 : 0); }
        const text = p.name + '|' + fmt(p.speed);
        if (text !== this.labelText) {
            this.labelText = text;
            this.label.userData.set([{ t: p.name, c: '#ffffff', s: '#16121f', px: 50 }, { t: fmt(p.speed) + ' Speed', c: '#7dff6b', s: '#16121f', px: 56 }]);
        }
        updateAuraFx(this.aura, auraById[p.aura], t);
        if (this.followerId !== p.equipped) {
            if (this.follower) scene.remove(this.follower);
            this.followerId = p.equipped;
            const d = soccerById[p.equipped];
            this.follower = d ? buildRig(d) : null;
            if (this.follower) { this.follower.position.copy(r.position); scene.add(this.follower); }
        }
        if (this.follower) updateFollower(this.follower, r.position, r.rotation.y, dt, r.visible);
    }
    dispose() {
        scene.remove(this.rig);
        if (this.follower) scene.remove(this.follower);
    }
}
function syncRemotes(dt, t) {
    const room = net.room;
    if (!room || !room.state || !room.state.players) return 1;
    const seen = new Set();
    room.state.players.forEach((p, id) => {
        if (id === room.sessionId) {
            // Our own public stats come from the server
            const oldLevel = S.level;
            S.name = p.name; S.speed = p.speed; S.wins = p.wins; S.level = p.level; S.xp = p.xp; S.rebirths = p.rebirths;
            if (!rig || rig.userData.kit !== p.kit) { buildPlayer(p.kit, p.skin); rig.userData.kit = p.kit; }
            if (oldLevel !== S.level) refreshModal();
            return;
        }
        seen.add(id);
        let r = remotes.get(id);
        if (!r) { r = new Remote(p); remotes.set(id, r); }
        r.update(p, dt, t);
    });
    for (const [id, r] of remotes) if (!seen.has(id)) { r.dispose(); remotes.delete(id); }
    return room.state.players.size;
}

// =====================================================================================
// Networking
// =====================================================================================
const SERVER_URL = import.meta.env.VITE_SERVER_URL
    || (import.meta.env.DEV ? `${location.protocol}//${location.hostname}:2567` : location.origin);
let lastMoveSent = 0, lastMoveKey = '';
function sendMove(force) {
    const now = performance.now();
    if (!force && now - lastMoveSent < 66) return;
    const a = P.dead ? 3 : !P.onGround ? 2 : P.moving ? 1 : 0;
    const m = { x: +P.pos.x.toFixed(2), y: +P.pos.y.toFixed(2), z: +P.pos.z.toFixed(2), ry: +P.facing.toFixed(3), a, mv: P.moving ? 1 : 0 };
    const key = m.x + ',' + m.y + ',' + m.z + ',' + m.ry + ',' + a + ',' + m.mv;
    if (!force && key === lastMoveKey && now - lastMoveSent < 500) return;
    lastMoveKey = key; lastMoveSent = now;
    net.send('move', m);
}

function storageGet(k) { try { return localStorage.getItem(k); } catch (e) { return null; } }
function storageSet(k, v) { try { localStorage.setItem(k, v); } catch (e) { /* private mode */ } }
function playerUid() {
    let uid = storageGet('sfs_uid');
    if (!uid) {
        uid = (crypto.randomUUID ? crypto.randomUUID() : String(Math.random()).slice(2) + Date.now());
        storageSet('sfs_uid', uid);
    }
    return uid;
}

async function connect(name) {
    const client = new Client(SERVER_URL);
    const room = await client.joinOrCreate('speed', { uid: playerUid(), name });
    net.room = room;
    room.onMessage('hello', (m) => { net.offset = m.now - Date.now(); });
    room.onMessage('profile', (m) => {
        Object.assign(S, m);
        refreshShop(); refreshFollower(); refreshModal();
    });
    room.onMessage('toast', (m) => toast(m.text, m.color));
    room.onMessage('levelUp', (m) => {
        levelUp(m.from, m.to);
        sfx('levelUp');
        ring(P.pos, 0x46ec50, 10, 0.8);
        sparkleColumn(P.pos, 0x7dff6b);
    });
    room.onMessage('gain', (m) => {
        if (m.pickup) { floatText('+' + fmt(m.n) + ' Speed', '#7dff6b', P.pos.clone().add(new V3(0, 6, 0))); sfx('pickup'); }
        else if (m.tread) { floatText('+' + fmt(m.n), '#c28cff', P.pos.clone().add(new V3(0, 7, 0))); sfx('gain'); }
    });
    room.onMessage('wins', (m) => {
        refreshShop();
        showGoal(m.n);
        sfx('cheer');
        confettiAt(P.pos.clone().add(new V3(0, 4, 0)));
        fireworks(P.pos, 6, () => sfx('firework'));
    });
    room.onMessage('portalOk', (m) => {
        const idx = m.stage - 1;
        teleport(new V3(0, 0.5, STAGES[idx].zS + 8), 0);
        actions.enterStage(idx);
    });
    room.onMessage('revived', () => actions.revive(true));
    room.onMessage('fx', () => {
        confettiAt(P.pos.clone().add(new V3(0, 4, 0)));
        sparkleColumn(P.pos, 0xffd028);
        sfx('buy');
    });
    room.onMessage('ball', spawnBall);
    room.onMessage('boards', renderBoards);
    room.onLeave((code) => {
        net.room = null;
        if (code !== 1000) {
            $('#offline').hidden = false;
        }
    });
    return room;
}

// =====================================================================================
// Camera & input
// =====================================================================================
const cam = { yaw: Math.PI, pitch: 0.35, dist: 20, target: new V3() };
const keys = {};
const touchMove = { x: 0, y: 0 };
let touchSprint = false, touchJump = false, running = false;

addEventListener('keydown', (e) => {
    if (e.target && e.target.tagName === 'INPUT') { if (e.key === 'Enter') e.target.blur(); return; }
    keys[e.code] = true;
    if (e.code === 'Space' || e.code.startsWith('Arrow')) e.preventDefault();
    if (e.code === 'KeyE' && running) usePrompt();
    if (e.code === 'Escape') closeModal();
});
addEventListener('keyup', (e) => { keys[e.code] = false; });
addEventListener('blur', () => { for (const k in keys) keys[k] = false; });
canvas.addEventListener('contextmenu', (e) => e.preventDefault());

const drags = new Map();
canvas.addEventListener('pointerdown', (e) => { canvas.setPointerCapture(e.pointerId); drags.set(e.pointerId, { x: e.clientX, y: e.clientY }); canvas.focus(); });
canvas.addEventListener('pointermove', (e) => {
    const d = drags.get(e.pointerId);
    if (!d) return;
    const k = e.pointerType === 'touch' ? 0.008 : 0.005;
    cam.yaw -= (e.clientX - d.x) * k;
    cam.pitch = clamp(cam.pitch + (e.clientY - d.y) * k, -0.25, 1.35);
    d.x = e.clientX; d.y = e.clientY;
});
const endDrag = (e) => drags.delete(e.pointerId);
canvas.addEventListener('pointerup', endDrag);
canvas.addEventListener('pointercancel', endDrag);
canvas.addEventListener('wheel', (e) => { cam.dist = clamp(cam.dist + Math.sign(e.deltaY) * 2, 8, 45); e.preventDefault(); }, { passive: false });

const isTouch = matchMedia('(pointer: coarse)').matches || 'ontouchstart' in window;
if (isTouch) document.body.classList.add('touch');
(function joystick() {
    const stick = $('#stick'), knob = $('#knob');
    let id = null;
    const set = (e) => {
        const r = stick.getBoundingClientRect();
        let dx = e.clientX - (r.left + r.width / 2), dy = e.clientY - (r.top + r.height / 2);
        const max = r.width / 2, l = Math.hypot(dx, dy);
        if (l > max) { dx *= max / l; dy *= max / l; }
        knob.style.transform = `translate(${dx}px, ${dy}px)`;
        touchMove.x = dx / max; touchMove.y = dy / max;
    };
    stick.addEventListener('pointerdown', (e) => { id = e.pointerId; stick.setPointerCapture(id); set(e); });
    stick.addEventListener('pointermove', (e) => { if (e.pointerId === id) set(e); });
    const end = (e) => { if (e.pointerId !== id) return; id = null; knob.style.transform = ''; touchMove.x = touchMove.y = 0; };
    stick.addEventListener('pointerup', end); stick.addEventListener('pointercancel', end);
    const jb = $('#jumpBtn');
    jb.addEventListener('pointerdown', (e) => { e.preventDefault(); touchJump = true; });
    jb.addEventListener('pointerup', () => { touchJump = false; });
    jb.addEventListener('pointercancel', () => { touchJump = false; });
    const sb = $('#sprintBtn');
    sb.addEventListener('click', () => { touchSprint = !touchSprint; sb.classList.toggle('on', touchSprint); });
})();

function rayHit(o, d, maxT) {
    let best = maxT;
    for (const c of solids) {
        let t0 = 0, t1 = best, hit = true;
        for (const a of ['x', 'y', 'z']) {
            if (Math.abs(d[a]) < 1e-9) { if (o[a] < c.min[a] || o[a] > c.max[a]) { hit = false; break; } continue; }
            let ta = (c.min[a] - o[a]) / d[a], tb = (c.max[a] - o[a]) / d[a];
            if (ta > tb) { const q = ta; ta = tb; tb = q; }
            t0 = Math.max(t0, ta); t1 = Math.min(t1, tb);
            if (t0 > t1) { hit = false; break; }
        }
        if (hit && t0 > 0 && t0 < best) best = t0;
    }
    return best;
}
const camDir = new V3(), camGoal = new V3(), camPos = new V3(), lookTmp = new V3();
const ATTRACT_LOOK = new V3(0, 8, 10);
let intro = null, baseFov = camera.fov;
const ease = (k) => (k < 0.5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2);
function updateCamera(dt) {
    if (!running) {
        const t = performance.now() / 1000;
        camera.position.set(Math.sin(t * 0.08) * 55, 22, Math.cos(t * 0.08) * 45 - 5);
        camera.lookAt(ATTRACT_LOOK);
        baseFov = camera.fov;
        return;
    }
    cam.target.lerp(camGoal.set(P.pos.x, P.pos.y + 4.5, P.pos.z), 1 - Math.exp(-dt * 18));
    const cp = Math.cos(cam.pitch);
    camDir.set(Math.sin(cam.yaw) * cp, Math.sin(cam.pitch), Math.cos(cam.yaw) * cp);
    const dist = Math.max(3, rayHit(cam.target, camDir, cam.dist) - 0.8);
    camPos.copy(cam.target).addScaledVector(camDir, dist);
    if (intro) {
        // Fly from the menu orbit down to the player
        intro.t += dt;
        const k = ease(Math.min(1, intro.t / intro.dur));
        camera.position.lerpVectors(intro.from, camPos, k);
        camera.lookAt(lookTmp.lerpVectors(ATTRACT_LOOK, cam.target, k));
        if (intro.t >= intro.dur) intro = null;
    } else {
        camera.position.copy(camPos);
        camera.lookAt(cam.target);
    }
    if (shake > 0.001) {
        const s = shake * shake * 0.9;
        camera.position.x += (Math.random() * 2 - 1) * s;
        camera.position.y += (Math.random() * 2 - 1) * s;
        shake = Math.max(0, shake - dt * 2.2);
    }
    // Field of view widens with speed and sprint
    const fovBase = innerWidth < innerHeight ? 85 : 70;
    const speedKick = P.moving ? Math.min(8, Math.max(0, walkSpeed() - 30) * 0.08) : 0;
    const want = fovBase + speedKick + (P.sprinting && !reduceMotion ? 9 : 0);
    baseFov += (want - baseFov) * Math.min(1, dt * 5);
    if (Math.abs(camera.fov - baseFov) > 0.01) { camera.fov = baseFov; camera.updateProjectionMatrix(); }
    sun.position.set(P.pos.x + 40, P.pos.y + 90, P.pos.z - 30);
    sun.target.position.copy(P.pos);
}

// Proximity prompts ("E  Equip Saka")
let activePrompt = null;
const projV = new V3();
function updatePrompt() {
    let best = null, bd = Infinity;
    if (!P.dead) for (const p of prompts) {
        const d = p.pos.distanceTo(P.pos);
        if (d < p.r && d < bd) { bd = d; best = p; }
    }
    activePrompt = best;
    if (!best) { promptEl.hidden = true; return; }
    projV.copy(best.pos).setY(best.pos.y + 2).project(camera);
    if (projV.z > 1) { promptEl.hidden = true; return; }
    promptEl.hidden = false;
    promptEl.style.left = ((projV.x + 1) / 2 * innerWidth) + 'px';
    promptEl.style.top = ((1 - projV.y) / 2 * innerHeight) + 'px';
    const txt = best.label();
    if (promptTxtEl.textContent !== txt) promptTxtEl.textContent = txt;
}
function usePrompt() { if (activePrompt) activePrompt.act(); }
promptEl.addEventListener('click', usePrompt);

// =====================================================================================
// Main update
// =====================================================================================
let clockT = 0, hudT = 0, online = 1;
const tmpF = new V3(), tmpR = new V3(), mv = new V3();

function update(dt) {
    clockT += dt;
    const t = clockT;
    let f = 0, r = 0;
    if (keys.KeyW || keys.ArrowUp) f += 1;
    if (keys.KeyS || keys.ArrowDown) f -= 1;
    if (keys.KeyD || keys.ArrowRight) r += 1;
    if (keys.KeyA || keys.ArrowLeft) r -= 1;
    f -= touchMove.y; r += touchMove.x;
    tmpF.set(-Math.sin(cam.yaw), 0, -Math.cos(cam.yaw));
    tmpR.set(Math.cos(cam.yaw), 0, -Math.sin(cam.yaw));
    mv.set(0, 0, 0).addScaledVector(tmpF, f).addScaledVector(tmpR, r);
    if (mv.lengthSq() > 1) mv.normalize();
    if (P.dead) mv.set(0, 0, 0);
    P.moving = mv.lengthSq() > 0.01;

    const wantSprint = keys.ShiftLeft || keys.ShiftRight || touchSprint;
    P.sprinting = wantSprint && P.moving && P.stamina > 0;
    if (P.sprinting) { P.stamina = Math.max(0, P.stamina - CFG.staminaDrain * dt); P.staminaIdle = 0; }
    else { P.staminaIdle += dt; if (P.staminaIdle > CFG.staminaDelay) P.stamina = Math.min(CFG.staminaMax, P.stamina + CFG.staminaRegen * dt); }

    if (!P.dead) {
        const ws = walkSpeed();
        if ((keys.Space || touchJump) && P.onGround) {
            P.vel.y = JUMP_V; P.onGround = false;
            sfx('jump'); P.squashV += 5; dust(P.pos, 4, 0.6);
        }
        P.vel.y -= GRAV * dt;
        P.push.multiplyScalar(Math.exp(-(P.onGround ? 4 : 1.2) * dt));
        let vx = mv.x * ws + P.push.x, vz = mv.z * ws + P.push.z;
        if (P.onGround && P.ground && P.ground.belt) { vx += P.ground.belt.x; vz += P.ground.belt.z; }
        const dist = Math.max(Math.abs(vx), Math.abs(vz), Math.abs(P.vel.y)) * dt;
        const n = Math.max(1, Math.ceil(dist / 0.6));
        const sdt = dt / n;
        const wasGround = P.ground;
        P.onGround = false; P.ground = null;
        for (let i = 0; i < n; i++) {
            moveAxis('x', vx * sdt);
            moveAxis('z', vz * sdt);
            moveAxis('y', P.vel.y * sdt);
        }
        if (!P.onGround && wasGround && P.vel.y <= 0 && P.vel.y > -40) {
            // Stick to the ground when walking down small steps
            const y0 = P.pos.y;
            moveAxis('y', -0.3);
            if (!P.onGround) P.pos.y = y0;
        }
        if (P.onGround) {
            if (P.airTime > 0.3) {
                sfx('land');
                dust(P.pos, P.airTime > 0.7 ? 12 : 7, P.airTime > 0.7 ? 1.4 : 1);
                P.squashV -= Math.min(9, 3 + P.airTime * 6);
                if (P.airTime > 0.9) { ring(P.pos, 0xffffff, 5, 0.45); addShake(0.35); }
            }
            P.airTime = 0;
        } else P.airTime += dt;
        if (P.moving) P.facing = lerpAngle(P.facing, Math.atan2(mv.x, mv.z), 1 - Math.exp(-dt * 14));

        if (P.shield > 0) P.shield -= dt;
        if (P.pos.y < CFG.voidY) { P.shield = 0; die(); }
        for (const k of kills) {
            if (!k.active) continue;
            if (k.max.x > P.pos.x - HW + 0.2 && k.min.x < P.pos.x + HW - 0.2 && k.max.y > P.pos.y + 0.1 && k.min.y < P.pos.y + PH && k.max.z > P.pos.z - HW + 0.2 && k.min.z < P.pos.z + HW - 0.2) { die(); break; }
        }
        P.safeTimer -= dt;
        if (P.onGround && P.safeTimer <= 0 && !(P.ground && P.ground.belt)) { P.lastSafe.copy(P.pos); P.safeTimer = 0.3; }

        for (const tr of triggers) {
            const inside = overlapsBox(tr, P.pos.x, P.pos.y, P.pos.z);
            if (inside && !tr.inside && tr.enter) tr.enter();
            tr.inside = inside;
            if (P.dead) break;
        }
        if (P.pos.z < 70 && P.stage !== -1) { P.stage = -1; resetChase(); }

        // Shoe pickups: collected locally, Speed granted by the server
        for (const p of pickups) {
            if (p.respawnAt > t) continue;
            if (!p.g.visible) p.g.visible = true;
            if (Math.abs(p.g.position.x - P.pos.x) < 2.8 && Math.abs(p.g.position.z - P.pos.z) < 2.8 && Math.abs(p.g.position.y - (P.pos.y + 1.8)) < 3.5) {
                sendMove(true);
                net.send('pickup', { id: p.id, s: p.stage });
                p.g.visible = false; p.respawnAt = t + CFG.pickupRespawn;
            }
        }

        // Locked treadmill: offer the pass / explain the requirement
        const tread = P.onGround && P.ground && P.ground.tread;
        if (tread && P.moving && treadLocked(tread) && t - P.lockToastT > 3) {
            P.lockToastT = t;
            if (tread.pass) buy('pass', tread.pass); else toast('Need ' + tread.req + ' Wins for this treadmill!', '#ff5a5a');
        }
    }

    const crushed = updateSlabs(net.now() / 1000, (s) => !P.dead && Math.abs(P.pos.z - s.z) < 5 && overlapsBox(s.c, P.pos.x, P.pos.y, P.pos.z));
    if (crushed) { P.shield = 0; die(); }
    updateChase(dt);
    updateBalls();
    updateEffects(dt);
    updateFx(dt);
    for (const fn of tickers) fn(dt, t);
    beltTex.offset.x = (beltTex.offset.x + dt * 0.75) % 1;
    for (const p of pickups) {
        if (!p.g.visible) continue;
        p.g.rotation.y += dt * 2;
        p.g.position.y = p.base + Math.sin(t * 3 + p.phase) * 0.4;
    }

    online = syncRemotes(dt, t);

    rig.position.copy(P.pos);
    rig.rotation.y = P.facing;
    const hs = P.moving ? walkSpeed() : 0;
    P.animPhase += dt * (P.onGround ? Math.min(18, 4 + hs * 0.2) : 0);
    if (P.onGround) animRig(rig, P.animPhase, P.moving ? 0.9 : 0); else airPose(rig);
    const stepN = Math.floor(P.animPhase / Math.PI);
    if (P.onGround && P.moving && !P.dead && stepN !== P.lastStep) {
        sfx('step');
        if ((P.sprinting || hs > 45) && stepN % 2 === 0) dust(P.pos, 1, 0.5);
    }
    P.lastStep = stepN;
    // Squash & stretch spring around 1
    P.squashV += (1 - P.squash) * 180 * dt;
    P.squashV *= Math.exp(-12 * dt);
    P.squash = clamp(P.squash + P.squashV * dt, 0.7, 1.3);
    rig.scale.set(1 / Math.sqrt(P.squash), P.squash, 1 / Math.sqrt(P.squash));
    setSpeedLines(!P.dead && P.moving && (P.sprinting || hs > 60) && !reduceMotion ? (P.sprinting ? 1 : 0.5) : 0, dt);
    rig.visible = !P.dead && (P.shield <= 0 || Math.floor(t * 12) % 2 === 0);
    updateAuraFx(auraFx, auraById[S.aura], t);
    const label = fmt(S.speed) + ' Speed';
    if (label !== headLabelText) { headLabelText = label; headLabel.userData.set([{ t: label, c: '#ffffff', s: '#16121f', px: 60 }]); }

    refreshFollower();
    if (follower) updateFollower(follower, P.pos, P.facing, dt, !P.dead);

    sendMove(false);
    updatePrompt();
    animateCounters(dt);
    hudT -= dt;
    if (hudT <= 0) { hudT = 0.1; updateHud(P, online); refreshShop(); }
}

// =====================================================================================
// Boot
// =====================================================================================
let lastFrame = 0;
function frame(now) {
    const dt = Math.min(0.05, (now - (lastFrame || now)) / 1000);
    lastFrame = now;
    if (running) update(dt);
    else { beltTex.offset.x = (beltTex.offset.x + dt * 0.75) % 1; updateSlabs(now / 1000); }
    updateCamera(dt);
    render();
    requestAnimationFrame(frame);
}

async function play() {
    const nameInput = $('#nameInput');
    const name = nameInput.value.trim().slice(0, 20);
    storageSet('sfs_name', name);
    const btn = $('#playBtn'), err = $('#connectErr');
    btn.disabled = true; btn.textContent = 'JOINING…'; err.hidden = true;
    initAudio();
    try {
        const room = await connect(name);
        const me = room.state.players && room.state.players.get(room.sessionId);
        S.name = me ? me.name : name;
    } catch (e) {
        console.error(e);
        err.hidden = false;
        err.textContent = 'Could not reach the game server. Check your connection and try again.';
        btn.disabled = false; btn.textContent = 'PLAY';
        return;
    }
    intro = { t: 0, dur: 2.2, from: camera.position.clone() };
    running = true;
    startMusic();
    sfx('whistle');
    $('#start').hidden = true;
    $('#hud').hidden = false;
    $('#touch').hidden = !isTouch;
    if (!rig) buildPlayer(0, 0);
    teleportLobby();
    toast('Run to gain Speed!', '#7dff6b');
    canvas.focus();
}

async function boot() {
    try { await Promise.race([document.fonts.load('700 40px Fredoka'), new Promise((r) => setTimeout(r, 2500))]); } catch (e) { /* fallback font */ }
    buildWorld();
    $('#nameInput').value = storageGet('sfs_name') || '';
    $('#loading').hidden = true;
    $('#joinRow').hidden = false;
    if (isTouch) $('#controlsKb').hidden = true;
    $('#playBtn').addEventListener('click', play);
    $('#nameInput').addEventListener('keydown', (e) => { if (e.key === 'Enter') play(); });
    $('#reconnectBtn').addEventListener('click', () => location.reload());
    requestAnimationFrame(frame);
}
boot();
