import {
    T, V3, scene, mat, box, aabb, UNIT, solids, kills, triggers, prompts, tickers,
    texFrom, billboard, textPlane, signBoard, buildRig, animRig, armsUp, football, hexCss,
} from './engine.js';
import { S, actions } from './state.js';
import { lavaMaterial, brickMaterial, bannerMaterial } from './textures.js';
import { emitTread } from './fx.js';
import {
    CFG, LOBBY, STAGES, TREADMILLS, TREAD_GEO, PORTALS, PRODUCTS, PASSES, SOCCER, fmt, sci, clamp, rngFrom,
} from '../../shared/config.js';

const HX = LOBBY.halfX, HZ = LOBBY.halfZ, LOWER = LOBBY.lower, WALLH = LOBBY.wallHeight;
const LC = {
    floor: 0xcddaee, green: 0x3ce83c, platform: 0x807691, pink: 0xe4d0e4, pillar: 0xceBAD2, frame: 0xc0aac6, frameInner: 0xa592ac,
    brick: 0x963440, ceiling: 0x62282e, vine: 0x28e632, lavender: 0xaf8cff, treadSign: 0xe48c76, shopSign: 0xc46c62,
    pedestal: 0xffcd28, portal: 0xffdc28,
};
const CC = {
    floor: 0x46ec50, red: 0xe82434, wall: 0x544870, wallDark: 0x3c3454, sidewalk: 0x78708c, ceiling: 0x302a42,
    pillar: 0xff8418, lava: 0xffc414, spike: 0x605c6e, falling: 0x968aa8, yellow: 0xffd028, purple: 0xc428ff,
    chase: 0x6e648c, ledge: 0x766e8a, plaque: 0x7d69af,
};
const KEEPER = { shirt: 0xd2141e, shorts: 0xf5f5f5, socks: 0x141419, skin: 0xd7a578, hair: 0x231914, num: 1, numC: '#ffffff', gloves: 0xf5f5f5 };
const LOBBY_KEEPER = { shirt: 0x19288c, shorts: 0x19288c, socks: 0x19288c, skin: 0xd7a578, hair: 0x3c2819, num: 1, numC: '#ffcd28', gloves: 0xf5f5f5, stripes: 0xa51437 };
const GOLD = { shirt: 0xffcd32, shorts: 0xffcd32, socks: 0xffcd32, skin: 0xffd746, hair: 0xffc328, shoes: 0xffc328, num: 1, numC: '#ffffff' };

export const SPAWN = new V3(LOBBY.spawn.x, LOBBY.spawn.y, LOBBY.spawn.z);
export const slabs = [];
export const pickups = [];
export let beltTex;
const shopItems = [];
const treadItems = [];
const boards = {};

// =====================================================================================
// Lobby (src/Server/LobbyBuilder.lua)
// =====================================================================================
function goalWithKeeper(pos, face, keeperDef) {
    const g = new T.Group(); g.position.copy(pos); g.rotation.y = Math.atan2(face.x, face.z); scene.add(g);
    const post = (sx, sy, sz, x, y, z) => { const m = new T.Mesh(UNIT, mat(0xffffff, { neon: true })); m.scale.set(sx, sy, sz); m.position.set(x, y, z); g.add(m); };
    post(0.6, 7, 0.6, -7, 3.5, 0); post(0.6, 7, 0.6, 7, 3.5, 0); post(14.6, 0.6, 0.6, 0, 7, 0);
    post(0.4, 0.4, 5, -7, 7, -2.5); post(0.4, 0.4, 5, 7, 7, -2.5);
    const net = new T.Mesh(UNIT, mat(0xffffff, { opacity: 0.35 })); net.scale.set(14, 7, 0.2); net.position.set(0, 3.5, -5); g.add(net);
    const k = buildRig(keeperDef); armsUp(k); k.position.set(0, 0, -1); g.add(k);
    football(2.2, g).position.set(0, 8.6, -1);
    const w = new V3(); g.updateMatrixWorld(true);
    for (const sx of [-7, 7]) { g.localToWorld(w.set(sx, 0, 0)); solids.push(aabb(w.x, 3.5, w.z, 0.8, 7, 0.8)); }
}
function stadiumLight(pos, h) {
    box(0.8, h, 0.8, pos.x, h / 2, pos.z, 0x5a5a64);
    box(6, 3, 1.2, pos.x, h + 1, pos.z, 0x3c3c46, { decor: true });
    for (const dx of [-1.8, 0, 1.8]) box(1.4, 1.4, 0.3, pos.x + dx, h + 1, pos.z - 0.7 * Math.sign(pos.z || 1), 0xfff6c8, { neon: true, decor: true });
}
function vine(rng, x, z) {
    let y = WALLH;
    const n = 3 + Math.floor(rng() * 3);
    box(5, 2, 5, x, WALLH - 1, z, LC.vine, { decor: true });
    for (let i = 0; i < n; i++) {
        const h = 3 + Math.floor(rng() * 3);
        y -= h;
        box(2.5, h, 2.5, x + (rng() * 2 - 1), y + h / 2, z + (rng() * 2 - 1), LC.vine, { decor: true });
    }
}
function leaderboard(pos, title, color) {
    const g = new T.Group(); g.position.copy(pos); scene.add(g);
    for (const sx of [-9, 9]) {
        const leg = new T.Mesh(UNIT, mat(0x807691)); leg.scale.set(2, 26, 2); leg.position.set(sx, 13, 0); g.add(leg);
        solids.push(aabb(pos.x + sx, 13, pos.z, 2, 26, 2));
    }
    const back = new T.Mesh(UNIT, mat(0x9a88b8)); back.scale.set(20, 22, 1.4); back.position.set(0, 16, 0.4); g.add(back);
    const head = new T.Mesh(UNIT, mat(color)); head.scale.set(22, 4, 2); head.position.set(0, 28.5, 0); head.rotation.x = -0.18; g.add(head);
    const cv = document.createElement('canvas'); cv.width = 512; cv.height = 560;
    const tex = texFrom(cv);
    const scr = new T.Mesh(new T.PlaneGeometry(18, 19.7), new T.MeshBasicMaterial({ map: tex, toneMapped: false }));
    scr.position.set(0, 16, -0.35); scr.rotation.y = Math.PI; g.add(scr);
    textPlane([{ t: 'Most ' + title.split(' ')[1], c: '#fff', s: '#16121f', px: 60 }], 16, 512, new V3(pos.x, 28.6, pos.z - 1.2), new V3(pos.x, 28.6, pos.z - 10));
    billboard([{ t: title, c: hexCss(color), s: '#ffffff', px: 80 }], 18, 512, new V3(pos.x, 35, pos.z));
    return { cv, tex };
}
function drawBoard(b, rows, kind) {
    const x = b.cv.getContext('2d');
    x.fillStyle = '#1e1a2e'; x.fillRect(0, 0, 512, 560);
    x.font = '700 30px Fredoka, sans-serif'; x.textBaseline = 'middle';
    if (!rows.length) {
        x.textAlign = 'center'; x.fillStyle = '#cfc4f2'; x.fillText('Be the first!', 256, 280);
    }
    rows.forEach((r, i) => {
        const y = 32 + i * 54;
        x.fillStyle = r.you ? 'rgba(70,236,80,0.28)' : (i % 2 ? 'rgba(255,255,255,0.05)' : 'rgba(255,255,255,0.1)');
        x.fillRect(8, y - 24, 496, 48);
        const rank = r.rank || i + 1;
        x.fillStyle = rank === 1 ? '#ffd028' : rank === 2 ? '#dfe4f0' : rank === 3 ? '#e0925a' : '#ffffff';
        x.textAlign = 'left'; x.fillText('#' + rank, 18, y);
        x.fillStyle = r.you ? '#7dff6b' : '#ffffff'; x.fillText(r.n.slice(0, 16), 86, y);
        x.textAlign = 'right'; x.fillStyle = kind === 'speed' ? '#6fe0ff' : '#ffb51c';
        x.fillText(kind === 'speed' ? sci(r.v) : fmt(r.v), 496, y);
    });
    b.tex.needsUpdate = true;
}
// msg = { speed: [{n, v}], wins: [...] } from the server, top 10 each
export function renderBoards(msg) {
    if (!boards.speed || !msg) return;
    for (const kind of ['speed', 'wins']) {
        const rows = (msg[kind] || []).map((r, i) => ({ n: r.n, v: r.v, rank: i + 1, you: r.n === S.name }));
        drawBoard(boards[kind], rows, kind);
    }
}

function pedestalLines(d) {
    const lines = [{ t: d.name, c: '#ffffff', s: '#16121f', px: 64 }];
    if (d.tagline) lines.push({ t: d.tagline, c: '#ff4a4a', s: '#16121f', px: 44 });
    lines.push({ t: '+' + fmt(d.bonus) + ' Speed / step', c: '#7dff6b', s: '#16121f', px: 46 });
    if (S.equipped === d.id) lines.push({ t: 'EQUIPPED', c: '#6fe0ff', s: '#16121f', px: 48 });
    else if (S.owned[d.id]) lines.push({ t: 'OWNED', c: '#ffffff', s: '#16121f', px: 48 });
    else if (d.pass) lines.push({ t: 'R$' + PASSES[d.pass].price, c: '#7dff6b', s: '#16121f', px: 50 });
    else lines.push({ t: '🏆 ' + fmt(d.req) + ' Wins', c: '#ffd028', s: '#16121f', px: 48 });
    return lines;
}
function buildPedestal(d, pos, face) {
    box(7.8, 0.5, 8.8, pos.x, pos.y + 0.25, pos.z, 0xeb8c1e, { decor: true });
    box(7, 1, 8, pos.x, pos.y + 0.6, pos.z, LC.pedestal);
    if (d.aura) {
        const ring = new T.Mesh(new T.CylinderGeometry(5.2, 5.2, 0.3, 32), mat(d.aura, { neon: true, opacity: 0.55 }));
        ring.position.set(pos.x, pos.y + 0.2, pos.z); scene.add(ring);
        const col = new T.Mesh(new T.CylinderGeometry(3.4, 3.4, 9, 24, 1, true), mat(d.aura, { neon: true, opacity: 0.18 }));
        col.position.set(pos.x, pos.y + 5.6, pos.z); scene.add(col);
    }
    const rig = buildRig(d);
    rig.position.set(pos.x, pos.y + 1.1, pos.z);
    rig.rotation.y = Math.atan2(face.x, face.z);
    scene.add(rig);
    const sp = billboard(pedestalLines(d), 9, 512, new V3(pos.x, pos.y + 10.5, pos.z));
    shopItems.push({ d, sp, sig: '' });
    prompts.push({
        pos: new V3(pos.x, pos.y + 3, pos.z), r: 9,
        label: () => S.equipped === d.id ? 'Equipped' : S.owned[d.id] ? 'Equip ' + d.name : d.pass ? 'Buy ' + d.name : S.wins >= d.req ? 'Unlock ' + d.name : 'Need ' + fmt(d.req) + ' Wins',
        act: () => actions.shop(d),
    });
    tickers.push((dt, t) => animRig(rig, t * 2 + pos.z, 0.08));
}

export function treadLocked(def) {
    if (def.pass) return !S.passes[def.pass];
    if (def.req) return S.wins < def.req;
    return false;
}
function treadLines(def) {
    const col = def.mult === 25 ? '#c28cff' : def.mult === 9 ? '#6fe0ff' : def.mult === 3 ? '#ffbe28' : '#ffffff';
    const lines = [{ t: 'x' + def.mult + ' Speed', c: col, s: '#16121f', px: 70 }];
    if (def.tag) lines.push({ t: def.tag, c: '#ff4a4a', s: '#16121f', px: 44 });
    if (treadLocked(def)) lines.push({ t: def.pass ? '🔒 R$' + PASSES[def.pass].price : '🔒 ' + def.req + ' Wins', c: '#ffd028', s: '#16121f', px: 48 });
    return lines;
}
export function refreshShop() {
    for (const it of shopItems) {
        const sig = S.equipped + (S.owned[it.d.id] ? 1 : 0);
        if (sig !== it.sig) { it.sig = sig; it.sp.userData.set(pedestalLines(it.d)); }
    }
    for (const t of treadItems) {
        const sig = treadLocked(t.def) ? 'l' : 'u';
        if (sig !== t.sig) { t.sig = sig; t.sp.userData.set(treadLines(t.def)); }
    }
}
function buildTreadmill(def, cx, top, cz) {
    const L = TREAD_GEO.len, W = TREAD_GEO.width;
    const accent = def.mult === 25 ? 0x965aff : def.mult === 9 ? 0x3cc8ff : def.mult === 3 ? 0xff961e : 0xa5a5af;
    const neon = def.mult > 1;
    const belt = new T.Mesh(UNIT, new T.MeshLambertMaterial({ map: beltTex, color: 0xffffff }));
    belt.scale.set(L, 0.6, W); belt.position.set(cx, top + 0.3, cz); belt.receiveShadow = true; scene.add(belt);
    const c = aabb(cx, top + 0.3, cz, L, 0.6, W); c.belt = new V3(-12, 0, 0); c.tread = def; solids.push(c);
    for (const s of [-1, 1]) {
        box(L, 0.9, 0.6, cx, top + 0.45, cz + s * (W / 2 + 0.3), accent, { neon });
        box(0.6, 5, 0.6, cx + L / 2 - 0.5, top + 2.5, cz + s * (W / 2), 0x464650, { decor: true });
    }
    box(0.6, 0.6, W + 0.6, cx + L / 2 - 0.5, top + 4.2, cz, 0x464650, { decor: true });
    box(1, 2.4, W - 0.4, cx + L / 2, top + 5.8, cz, 0x23232a, { decor: true });
    textPlane([{ t: 'x' + def.mult, c: neon ? hexCss(accent) : '#ffffff', px: 90 }], 4, 256, new V3(cx + L / 2 - 0.55, top + 5.8, cz), new V3(cx - 10, top + 5.8, cz));
    const sp = billboard(treadLines(def), 10, 512, new V3(cx - 2, top + 11, cz));
    treadItems.push({ def, sp, sig: '' });
    if (def.mult > 1) {
        const at = new V3(cx, top + 0.7, cz);
        let acc = Math.random();
        tickers.push((dt) => { acc += dt * 14; while (acc > 1) { acc -= 1; emitTread(at, def.mult, L, W); } });
    }
}

function buildLobby() {
    const rng = rngFrom(7);
    const half = CFG.courseWidth / 2;
    box(HX * 2, 2, HZ * 2, 0, -1, 0, LC.floor, { studs: true });
    box(CFG.courseWidth, 0.1, 38, 0, 0.05, HZ - 19, LC.green, { studs: true, decor: true });
    box(28, 0.1, 76, -44, 0.05, 0, LC.green, { studs: true, decor: true });
    box(28, 0.1, 96, 48, 0.05, 0, LC.green, { studs: true, decor: true });

    const wall = (sx, sz, x, z, lower) => {
        box(sx, LOWER, sz, x, LOWER / 2, z, lower || LC.pink);
        box(sx + 0.6, WALLH - LOWER, sz + 0.6, x, LOWER + (WALLH - LOWER) / 2, z, LC.brick);
    };
    const seg = HX - half;
    wall(seg, 2, -(half + seg / 2), HZ + 1);
    wall(seg, 2, half + seg / 2, HZ + 1);
    wall(HX * 2 + 4, 2, 0, -HZ - 1, LC.brick);
    wall(2, HZ * 2, -HX - 1, 0);
    wall(2, HZ * 2, HX + 1, 0);
    for (let x = -72; x <= 72; x += 24) {
        if (Math.abs(x) > half + 4) {
            box(4, LOWER, 2.4, x, LOWER / 2, HZ - 1.2, LC.pillar);
            if (Math.abs(x + 12) > half + 6 && x + 12 < HX - 6) {
                box(11, 20, 0.4, x + 12, 10, HZ - 0.2, LC.frame, { decor: true });
                box(8, 17.5, 0.5, x + 12, 8.75, HZ - 0.3, LC.frameInner, { decor: true });
            }
        }
    }
    for (let z = -60; z <= 60; z += 20) {
        box(2.4, LOWER, 4, -HX + 1.2, LOWER / 2, z, LC.pillar);
        box(2.4, LOWER, 4, HX - 1.2, LOWER / 2, z, LC.pillar);
        if (z < 60) {
            box(0.4, 20, 11, -HX + 0.2, 10, z + 10, LC.frame, { decor: true });
            box(0.5, 17.5, 8, -HX + 0.3, 8.75, z + 10, LC.frameInner, { decor: true });
        }
    }
    box(HX * 2 + 6, 4, HZ * 2 + 6, 0, WALLH + 2, 0, LC.ceiling, { decor: true });
    for (const x of [-50, 0, 50]) for (const z of [-40, 0, 40]) box(9, 0.4, 9, x, WALLH - 0.2, z, 0xffffff, { neon: true, decor: true });
    for (let x = -70; x <= 70; x += 28) { vine(rng, x, HZ - 3); vine(rng, x + 10, -HZ + 3); }
    for (let z = -56; z <= 56; z += 28) { vine(rng, -HX + 3, z); vine(rng, HX - 3, z + 10); }

    // Stage 1 gate arch
    const arch = 0x9687a8, gz = HZ + 1;
    for (const s of [-1, 1]) {
        box(6, WALLH, 7, s * (half + 3), WALLH / 2, gz, arch);
        box(6, 5, 7, s * (half - 3), 33.5, gz, arch, { decor: true });
        box(5, 4, 7, s * (half - 8.5), 35, gz, arch, { decor: true });
    }
    box(CFG.courseWidth + 12, WALLH - 37, 7, 0, (WALLH + 37) / 2, gz, arch, { decor: true });
    for (const x of [-14, -4, 8, 16]) vine(rng, x, HZ - 3.5);

    // Spawn pad: white square with a black star
    box(14, 0.3, 14, SPAWN.x, 0.15, SPAWN.z, 0xf6f6fa, { decor: true });
    for (let i = 0; i < 8; i++) {
        const a = i * Math.PI / 4, len = i % 2 ? 4.5 : 6.5;
        const m = box(i % 2 ? 0.5 : 0.7, 0.06, len, 0, 0.32, 0, 0x141418, { decor: true });
        m.position.set(SPAWN.x + Math.sin(a) * len / 2, 0.32, SPAWN.z + Math.cos(a) * len / 2); m.rotation.y = a; m.updateMatrix();
    }
    const ring = new T.Mesh(new T.RingGeometry(1.5, 2, 32), mat(0x141418));
    ring.rotation.x = -Math.PI / 2; ring.position.set(SPAWN.x, 0.34, SPAWN.z); scene.add(ring);

    // Soccer player shop (west): cheap players in front, expensive ones on the raised back row
    box(14, 5, 72, -HX + 7, 2.5, 0, LC.platform, { studs: true });
    box(12, 1.5, 72, -HX + 20, 0.75, 0, LC.platform, { studs: true });
    const rows = { 1: [], 2: [] };
    for (const d of SOCCER) if (!d.special) rows[d.row].push(d);
    const rowX = { 1: -HX + 20, 2: -HX + 7 }, rowY = { 1: 1.5, 2: 5 };
    for (const r of [1, 2]) rows[r].forEach((d, i) => {
        const z = (i - (rows[r].length - 1) / 2) * 13.5;
        buildPedestal(d, new V3(rowX[r], rowY[r], z), new V3(1, 0, 0));
    });
    signBoard(new V3(-HX + 0.3, 37, 0), new V3(1, 0, 0), 46, 11, [{ t: 'BUY SOCCER', c: '#ffffff', s: '#16121f', px: 120 }, { t: 'PLAYERS', c: '#ffffff', s: '#16121f', px: 120 }], LC.shopSign);
    for (const d of SOCCER) if (d.special) {
        const p = d.id === 'PrimeMessi' ? new V3(-14, 0, -HZ + 22) : new V3(44, 0, -34);
        buildPedestal(d, p, new V3(-p.x, 0, -p.z).normalize());
    }

    // Treadmills (east)
    const bc = document.createElement('canvas'); bc.width = 64; bc.height = 64;
    const bx = bc.getContext('2d');
    bx.fillStyle = '#2d2d34'; bx.fillRect(0, 0, 64, 64);
    bx.fillStyle = '#3d3d46'; for (let i = 0; i < 4; i++) bx.fillRect(i * 16, 0, 6, 64);
    beltTex = texFrom(bc); beltTex.wrapS = beltTex.wrapT = T.RepeatWrapping; beltTex.repeat.set(4, 1);
    const top = TREAD_GEO.top;
    box(22, top, 96, HX - 11, top / 2, 0, LC.platform, { studs: true });
    box(3, 0.3, 96, HX - 23.5, 0.15, 0, LC.lavender, { neon: true, decor: true });
    TREADMILLS.forEach((def, i) => buildTreadmill(def, TREAD_GEO.cx, top, TREAD_GEO.z0 + i * TREAD_GEO.step));
    signBoard(new V3(HX - 0.3, 37, 0), new V3(-1, 0, 0), 44, 10, [{ t: 'TREADMILLS', c: '#ffffff', s: '#16121f', px: 130 }], LC.treadSign);
    textPlane([{ t: 'TREADMILLS', c: '#ffffff', s: '#16121f', px: 110 }, { t: 'Automatically increases your speed!', c: '#ffd228', s: '#16121f', px: 56 }], 30, 1024, new V3(HX - 4, 28, 0), new V3(0, 28, 0));

    // Stage portals (south wall)
    const lt = 1.5;
    box(100, lt, 12, 0, lt / 2, -HZ + 6, LC.platform, { studs: true });
    PORTALS.forEach((p, i) => {
        const x = (i - 2) * 20, wz = -HZ + 0.6;
        box(10, 13, 1, x, lt + 6.5, wz, LC.portal, { neon: true, decor: true });
        const archM = new T.Mesh(new T.CylinderGeometry(5, 5, 1, 24, 1, false, 0, Math.PI), mat(LC.portal, { neon: true }));
        archM.rotation.set(Math.PI / 2, 0, Math.PI / 2, 'ZYX'); archM.position.set(x, lt + 13, wz); scene.add(archM);
        box(12, 1, 1.4, x, lt + 0.5, wz + 0.5, 0xc8a01e, { decor: true });
        billboard([{ t: 'Stage ' + p.stage, c: '#ffffff', s: '#16121f', px: 72 }, { t: '🏆 ' + fmt(p.req) + ' Wins', c: '#ffd028', s: '#16121f', px: 54 }], 9, 512, new V3(x, lt + 20, wz + 2));
        const tr = aabb(x, lt + 8, wz + 2.5, 10, 16, 4);
        tr.enter = () => actions.portal(p);
        triggers.push(tr);
    });

    // Gold statue on the speed boost pad
    const bp = new V3(22, 0, -HZ + 20);
    const pad = new T.Mesh(new T.CylinderGeometry(6, 6, 0.4, 32), mat(0xffd028, { neon: true }));
    pad.position.set(bp.x, 0.2, bp.z); scene.add(pad);
    const statue = buildRig(GOLD); statue.position.set(bp.x, 0.4, bp.z);
    statue.rotation.y = Math.atan2(-bp.x, -bp.z); statue.scale.setScalar(1.3); armsUp(statue); scene.add(statue);
    billboard([{ t: 'SPEED BOOST', c: '#ffd028', s: '#16121f', px: 76 }, { t: 'x2 Speed for 15 min', c: '#ffffff', s: '#16121f', px: 48 }, { t: 'R$' + PRODUCTS.SpeedBoost.price, c: '#7dff6b', s: '#16121f', px: 52 }], 14, 512, new V3(bp.x, 13, bp.z));
    const btr = aabb(bp.x, 3.5, bp.z, 12, 7, 12);
    btr.enter = () => actions.buy('product', 'SpeedBoost');
    triggers.push(btr);

    // Leaderboards either side of the Stage 1 gate
    boards.speed = leaderboard(new V3(-36, 0, HZ - 18), 'Top Speed', 0x286ee6);
    boards.wins = leaderboard(new V3(36, 0, HZ - 18), 'Top Wins', 0xff8c1e);

    goalWithKeeper(new V3(-62, 0, HZ - 8), new V3(0.6, 0, -1).normalize(), LOBBY_KEEPER);
    goalWithKeeper(new V3(-62, 0, -HZ + 9), new V3(0.6, 0, 1).normalize(), LOBBY_KEEPER);
    stadiumLight(new V3(-48, 0, HZ - 4), 24);
    stadiumLight(new V3(-48, 0, -HZ + 5), 24);
    stadiumLight(new V3(26, 0, HZ - 4), 24);
}

// =====================================================================================
// Course (src/Server/MapBuilder.lua)
// =====================================================================================
const SPIKE_GEO = new T.ConeGeometry(1.5, 4, 8);
function spike(x, y, z) {
    const m = new T.Mesh(SPIKE_GEO, mat(CC.spike));
    m.position.set(x, y + 2, z); m.castShadow = true; scene.add(m);
    const k = aabb(x, y + 1.5, z, 2, 3, 2); k.active = true; kills.push(k);
}
function texturedBox(sx, sy, sz, x, y, z, material) {
    const m = new T.Mesh(UNIT, material);
    m.scale.set(sx, sy, sz); m.position.set(x, y, z);
    m.matrixAutoUpdate = false; m.updateMatrix();
    scene.add(m);
    return m;
}
function lavaPillar(x, z, h) {
    const sy = h + 10;
    texturedBox(3.5, sy, 3.5, x, -10 + sy / 2 - 6, z, lavaMaterial(1, sy / 6));
    const k = aabb(x, -10 + sy / 2 - 6, z, 3.5, sy, 3.5); k.active = true; kills.push(k);
}
function lavaPit(z0, z1) {
    const len = z1 - z0;
    texturedBox(CFG.courseWidth, 1, len, 0, -6.5, z0 + len / 2, lavaMaterial(CFG.courseWidth / 14, len / 14));
    const k = aabb(0, -22, z0 + len / 2, CFG.courseWidth, 34, len); k.active = true; kills.push(k);
}
function addPickup(stageIdx, x, y, z, amount) {
    const g = new T.Group();
    const body = new T.Mesh(UNIT, mat(0x2d8cff)); body.scale.set(1.6, 1, 2.8); body.position.y = 0.3; g.add(body);
    const sole = new T.Mesh(UNIT, mat(0xffffff)); sole.scale.set(1.75, 0.35, 3); sole.position.y = -0.3; g.add(sole);
    const ankle = new T.Mesh(UNIT, mat(0x2d8cff)); ankle.scale.set(1.5, 1, 1.2); ankle.position.set(0, 1, -0.8); g.add(ankle);
    const swoosh = new T.Mesh(UNIT, mat(0xffffff, { neon: true })); swoosh.scale.set(1.62, 0.2, 1.6); swoosh.position.set(0, 0.35, 0.1); g.add(swoosh);
    const glow = new T.Mesh(new T.CylinderGeometry(1.8, 1.8, 0.1, 20), mat(0x6fe0ff, { neon: true, opacity: 0.45 })); glow.position.y = -1.3; g.add(glow);
    g.position.set(x, y + 1.8, z);
    scene.add(g);
    const id = stageIdx + ':' + pickups.filter((p) => p.stage === stageIdx).length;
    pickups.push({ id, stage: stageIdx, g, base: y + 1.8, amount, respawnAt: 0, phase: Math.random() * 6 });
}
function chevrons(z0, count) {
    for (let i = 0; i < count; i++) {
        textPlane([{ t: '^', c: '#ffffff', px: 180 }], 6, 256, new V3(0, 0.06, z0 + i * 8), new V3(0, 10, z0 + i * 8)).rotation.set(-Math.PI / 2, 0, Math.PI);
    }
}
function stageSigns(s) {
    textPlane([{ t: s.name, c: '#ffffff', s: '#16121f', px: 150 }, { t: s.sub, c: s.subColor, s: '#16121f', px: 120 }], 30, 1024, new V3(0, 28, s.zS + 3), new V3(0, 28, s.zS - 10));
    const pz = s.zS + 22;
    box(0.4, 5, 12, -CFG.courseWidth / 2 + 0.2, 8, pz, CC.plaque, { decor: true });
    textPlane([{ t: 'Recommended :', c: '#ffffff', s: '#16121f', px: 60 }, { t: 'Lvl : ' + s.rec, c: '#ffd028', s: '#16121f', px: 70 }], 10, 512, new V3(-CFG.courseWidth / 2 + 0.5, 8, pz), new V3(10, 8, pz));
}
function returnPad(stageIdx, x, z, wins, finish) {
    const pad = new T.Mesh(new T.CylinderGeometry(5, 5, 0.4, 32), mat(finish ? CC.purple : CC.yellow, { neon: true }));
    pad.position.set(x, 0.2, z); scene.add(pad);
    billboard([{ t: '+' + wins + ' Wins', c: '#ffd028', s: '#16121f', px: 80 }, { t: finish ? 'FINISH!' : 'Return to lobby', c: '#ffffff', s: '#16121f', px: 46 }], 10, 512, new V3(x, 8, z));
    const tr = aabb(x, 3, z, 10, 6, 10);
    tr.enter = () => actions.pad(stageIdx);
    triggers.push(tr);
}
function doubleWinsPad(x, z) {
    const pad = new T.Mesh(new T.CylinderGeometry(4, 4, 0.4, 32), mat(CC.purple, { neon: true }));
    pad.position.set(x, 0.2, z); scene.add(pad);
    billboard([{ t: 'x2 Wins', c: '#e27bff', s: '#16121f', px: 80 }, { t: 'R$' + PASSES.DoubleWins.price, c: '#7dff6b', s: '#16121f', px: 50 }], 8, 512, new V3(x, 7, z));
    const tr = aabb(x, 3, z, 8, 6, 8);
    tr.enter = () => actions.buy('pass', 'DoubleWins');
    triggers.push(tr);
}

function buildLavaPath(i, s, rng, z0, z1) {
    const pw = s.pw, len = z1 - z0, mid = z0 + len / 2;
    lavaPit(z0, z1);
    box(pw, 2, len, 0, -1, mid, CC.floor, { studs: true });
    for (const sx of [-1, 1]) {
        box(0.8, 0.1, len, sx * (pw / 2 - 0.4), 0.05, mid, CC.red, { decor: true });
        box(4, 2, len, sx * (CFG.courseWidth / 2 - 2), -1, mid, CC.sidewalk, { studs: true });
    }
    for (let z = z0 + 24; z < z1 - 10; z += 22) {
        const n = 1 + Math.floor(rng() * 2);
        for (let k = 0; k < n; k++) spike((rng() * 2 - 1) * (pw / 2 - 2.5), 0, z + rng() * 8);
    }
    for (let z = z0 + 30; z < z1; z += 40) for (const sx of [-1, 1]) lavaPillar(sx * (pw / 2 + 3.5), z + rng() * 10, 4 + rng() * 10);
    for (let k = 0; k < 8; k++) addPickup(i, (rng() * 2 - 1) * (pw / 2 - 2), 0, z0 + 20 + (len - 30) * k / 7, s.pickup);
}
function buildFallingWalls(i, s, rng, z0, z1) {
    const len = z1 - z0, W = CFG.courseWidth;
    box(W, 2, len, 0, -1, z0 + len / 2, CC.floor, { studs: true });
    let k = 0;
    for (let z = z0 + 26; z < z1 - 14; z += 34, k++) {
        box(W, 0.1, 8, 0, 0.05, z, CC.red, { decor: true });
        const m = new T.Mesh(UNIT, mat(CC.falling)); m.scale.set(W, 30, 8); m.castShadow = true; scene.add(m);
        const c = aabb(0, 31, z, W, 30, 8); solids.push(c);
        slabs.push({ m, c, z, phase: k * 1.1 });
    }
    for (let n = 0; n < 8; n++) addPickup(i, (rng() * 2 - 1) * 16, 0, z0 + 24 + (len - 24) * n / 7, s.pickup);
}
function buildObby(i, s, rng, z0, z1) {
    lavaPit(z0, z1);
    let z = z0, x = 0, y = 0, k = 0;
    const tops = [];
    for (;;) {
        const gap = 3.5 + rng() * 3;
        const beam = rng() < 0.25;
        const sx = beam ? 3.5 : 7 + rng() * 6, sz = beam ? 14 : 7 + rng() * 5;
        const nz = z + gap;
        if (nz + sz > z1 - 12) break;
        x = clamp(x + (rng() * 2 - 1) * 5, -14, 14);
        y = clamp(y + [0, 0, 2, -2, 3, -3][Math.floor(rng() * 6)], 0, 9);
        box(sx, 2, sz, x, y - 1, nz + sz / 2, k % 2 ? 0xffb51c : CC.floor, { studs: true });
        tops.push({ x, y, z: nz + sz / 2 });
        z = nz + sz; k++;
    }
    const bz = z + 4;
    box(CFG.courseWidth, 2, z1 - bz, 0, -1, bz + (z1 - bz) / 2, CC.floor, { studs: true });
    for (let pz = z0 + 20; pz < z1; pz += 36) for (const sx of [-1, 1]) lavaPillar(sx * 19, pz + rng() * 8, 6 + rng() * 14);
    const step = Math.max(1, Math.floor(tops.length / 9));
    for (let n = 1; n < tops.length; n += step) addPickup(i, tops[n].x, tops[n].y, tops[n].z, s.pickup);
}
function buildChase(i, s, rng, z0, z1) {
    const len = z1 - z0, W = CFG.courseWidth;
    box(W, 2, len, 0, -1, z0 + len / 2, CC.chase, { studs: true });
    for (let z = z0 + 30; z < z1 - 10; z += 28) {
        if (rng() < 0.5) box(12 + rng() * 8, 2.6, 2, (rng() * 2 - 1) * 10, 1.3, z, CC.red);
        else for (let n = 0; n < 2; n++) box(5, WALLH, 5, (rng() * 2 - 1) * 15, WALLH / 2, z + n * 10, CC.ledge);
    }
    for (let n = 0; n < 9; n++) addPickup(i, (rng() * 2 - 1) * 16, 0, z0 + 20 + (len - 30) * n / 8, s.pickup);
    // The red wall that chases this player (local only; each player gets their own)
    const m = new T.Mesh(UNIT, mat(CC.red, { neon: true, opacity: 0.85 }));
    m.scale.set(W, WALLH, 4); m.visible = false; scene.add(m);
    const k = aabb(0, WALLH / 2, s.zS - 6, W, WALLH, 4); k.active = false; kills.push(k);
    s.chaseMesh = m; s.chaseKill = k;
}
function buildPlatforms(i, s, rng, z0, z1) {
    lavaPit(z0, z1);
    const xs = [-10, 6, -4, 10, 0, -12, 8];
    let z = z0, k = 0;
    const tops = [];
    while (z + 5 + 16 < z1 - 8) {
        z += 5;
        const x = xs[k % xs.length];
        box(16, 2, 16, x, -1, z + 8, CC.floor, { studs: true });
        if (k % 3 !== 2) {
            const side = k % 2 ? 1 : -1;
            spike(x + side * 5, 0, z + 5); spike(x + side * 5, 0, z + 11);
        }
        tops.push({ x: x - (k % 2 ? 1 : -1) * 4, z: z + 8 });
        z += 16; k++;
    }
    box(CFG.courseWidth, 2, z1 - z - 5, 0, -1, z + 5 + (z1 - z - 5) / 2, CC.floor, { studs: true });
    for (let pz = z0 + 14; pz < z1; pz += 30) for (const sx of [-1, 1]) lavaPillar(sx * 19.5, pz, 4 + rng() * 12);
    const step = Math.max(1, Math.floor(tops.length / 10));
    for (let n = 0; n < tops.length; n += step) addPickup(i, tops[n].x, 0, tops[n].z, s.pickup);
}

function buildCourse() {
    const W = CFG.courseWidth;
    STAGES.forEach((s, idx) => {
        const rng = rngFrom(100 + idx * 17);
        const mid = s.zS + s.len / 2;
        for (const sx of [-1, 1]) {
            texturedBox(2, 86, s.len, sx * (W / 2 + 1), 3, mid, brickMaterial(CC.wall, s.len / 12, 86 / 6));
            solids.push(aabb(sx * (W / 2 + 1), 3, mid, 2, 86, s.len));
            for (let z = s.zS + 20; z < s.zE - 5; z += 40) {
                box(2.4, WALLH, 2.4, sx * (W / 2 + 0.3), WALLH / 2, z, CC.pillar, { decor: true });
                box(3, 1.2, 3, sx * (W / 2 + 0.3), WALLH - 0.6, z, 0xc2560a, { decor: true });
                box(0.4, 2, 5, sx * (W / 2 - 0.1), 20, z + 20, 0xffe7a8, { neon: true, decor: true });
                const banner = new T.Mesh(new T.PlaneGeometry(5, 12.5), bannerMaterial((z / 40) % 2 ? ['#d71e2d', '#8c0f1a'] : ['#1e46c8', '#0f2470'], (z / 40) % 2 ? 'GOAL' : 'RUN!'));
                banner.position.set(sx * (W / 2 - 0.05), 30, z + 10);
                banner.rotation.y = -sx * Math.PI / 2;
                scene.add(banner);
            }
        }
        box(W + 4, 2, s.len, 0, WALLH + 1, mid, CC.ceiling, { decor: true });
        box(W, 2, 16, 0, -1, s.zS + 8, CC.floor, { studs: true });
        chevrons(s.zS + 4, 2);
        const z0 = s.zS + 16, z1 = s.cE;
        if (s.type === 'LavaPath') buildLavaPath(idx, s, rng, z0, z1);
        else if (s.type === 'FallingWalls') buildFallingWalls(idx, s, rng, z0, z1);
        else if (s.type === 'Obby') buildObby(idx, s, rng, z0, z1);
        else if (s.type === 'Chase') buildChase(idx, s, rng, z0, z1);
        else buildPlatforms(idx, s, rng, z0, z1);
        box(W, 2, CFG.endZone, 0, -1, s.cE + CFG.endZone / 2, CC.floor, { studs: true });
        const finish = idx === STAGES.length - 1;
        returnPad(idx, -10, s.cE + 22, s.wins, finish);
        doubleWinsPad(10, s.cE + 22);
        goalWithKeeper(new V3(W / 2 - 4, 0, s.cE + 38), new V3(-1, 0, 0), KEEPER);
        stageSigns(s);
        const tr = aabb(0, 20, s.zS + 3, W, 60, 2);
        tr.enter = () => actions.enterStage(idx);
        triggers.push(tr);
        if (finish) {
            texturedBox(W + 4, 90, 2, 0, 2, s.zE + 1, brickMaterial(CC.wall, 4, 15));
            solids.push(aabb(0, 2, s.zE + 1, W + 4, 90, 2));
            textPlane([{ t: 'YOU ESCAPED!', c: '#ffd028', s: '#16121f', px: 150 }, { t: 'More stages coming soon', c: '#ffffff', s: '#16121f', px: 70 }], 34, 1024, new V3(0, 24, s.zE - 0.2), new V3(0, 24, s.zE - 20));
        }
    });
}

// Falling walls run on the server clock so every player sees the same timing.
// Returns true when a slab crushes the player box at (x, y, z).
export function updateSlabs(t, hitsPlayer) {
    const F = CFG.fall, cyc = F.raised + F.warn + F.fall + F.down + F.rise;
    let crushed = false;
    for (const s of slabs) {
        const k = ((t + s.phase) % cyc + cyc) % cyc;
        let bottom = 16, warn = false, crushing = false;
        if (k < F.raised) bottom = 16;
        else if (k < F.raised + F.warn) { warn = true; bottom = 16 + Math.sin(k * 60) * 0.25; }
        else if (k < F.raised + F.warn + F.fall) { crushing = true; bottom = 16 * (1 - (k - F.raised - F.warn) / F.fall); }
        else if (k < F.raised + F.warn + F.fall + F.down) { bottom = 0; crushing = true; }
        else bottom = 16 * ((k - F.raised - F.warn - F.fall - F.down) / F.rise);
        s.m.position.set(0, bottom + 15, s.z);
        s.m.material = warn ? mat(CC.red) : mat(CC.falling);
        s.c.min.y = bottom; s.c.max.y = bottom + 30;
        if (crushing && hitsPlayer && hitsPlayer(s)) crushed = true;
    }
    return crushed;
}

export function buildWorld() {
    buildLobby();
    buildCourse();
    refreshShop();
}
