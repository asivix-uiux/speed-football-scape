// Game data shared by the client and the Colyseus server.
// Ported from the Roblox build (src/Shared/Config.lua and Catalog.lua).

export const CFG = {
    maxLevel: 30,
    minWalk: 16,
    gainInterval: 0.5,
    staminaMax: 12,
    staminaDrain: 3,
    staminaRegen: 2,
    staminaDelay: 1,
    sprintMult: 1.35,
    courseWidth: 44,
    wallHeight: 46,
    voidY: -40,
    endZone: 50,
    pickupRespawn: 10,
    ballLifetime: 16,
    ballKnockback: 70,
    fall: { raised: 2.5, warn: 0.8, fall: 0.25, down: 1.5, rise: 0.6 },
    boostMult: 2,
    boostMinutes: 15,
    reviveTimeout: 10,
    shieldTime: 3,
    starterPackDuration: 15 * 60,
    offerRotate: 45,
    rebirthStep: 0.5,
    maxPlayers: 24,
};

export const xpFor = (L) => Math.floor(15 * Math.pow(1.12, L - 1));
export const maxSpeedFor = (L, R) => Math.max(CFG.minWalk, 12 + 2 * L + 20 * (R || 0));

export const LOBBY = { halfX: 85, halfZ: 70, lower: 30, wallHeight: 46, spawn: { x: 0, y: 0.5, z: -14 } };

export const STAGES = [
    { name: 'Stage 1', sub: 'ESCAPE', subColor: '#28c8ff', type: 'LavaPath', len: 420, pw: 20, pickup: 5, wins: 1, rec: 1, bi: 4, bs: 34 },
    { name: 'Stage 2', sub: 'Falling Walls', subColor: '#ff5a1e', type: 'FallingWalls', len: 420, pickup: 5, wins: 3, rec: 5, bi: 5, bs: 38 },
    { name: 'Stage 3', sub: 'Obby', subColor: '#cdaf19', type: 'Obby', len: 440, pickup: 9, wins: 8, rec: 15, bi: 6, bs: 40 },
    { name: 'Stage 4', sub: 'RUN!', subColor: '#28e628', type: 'Chase', len: 460, chaseSpeed: 48, chaseWait: 4, pickup: 9, wins: 20, rec: 35, bi: 7, bs: 40 },
    { name: 'Stage 5', sub: 'Ball', subColor: '#28c8ff', type: 'LavaPath', len: 460, pw: 22, pickup: 12, wins: 50, rec: 50, bi: 1.8, bs: 46, bmin: 10, bmax: 16 },
    { name: 'Stage 6', sub: 'PLATFORMS', subColor: '#8c28ff', type: 'Platforms', len: 480, pickup: 15, wins: 100, rec: 60, bi: 4, bs: 42 },
];
{
    let z = 70;
    for (const s of STAGES) {
        s.zS = z;
        s.zE = z + s.len;
        s.cE = s.zE - CFG.endZone;
        // Stages whose floor is a continuous lane get rolling balls
        s.ballLane = s.type === 'LavaPath' ? s.pw / 2 : s.type === 'FallingWalls' || s.type === 'Chase' ? CFG.courseWidth / 2 - 1 : 0;
        z = s.zE;
    }
}
export function stageAt(z) {
    for (let i = 0; i < STAGES.length; i++) if (z >= STAGES[i].zS && z < STAGES[i].zE) return i;
    return -1;
}

// Lobby order matches the reference: X25, X9, X3, four x1, X3
export const TREADMILLS = [
    { mult: 25, pass: 'RunArea25x', tag: '*SUPER OP*' },
    { mult: 9, pass: 'RunArea9x' },
    { mult: 3, req: 5 },
    { mult: 1 }, { mult: 1 }, { mult: 1 }, { mult: 1 },
    { mult: 3, req: 5 },
];
// Belt geometry (also used by the server to know who is on a treadmill)
export const TREAD_GEO = { cx: LOBBY.halfX - 12, top: 1.5, len: 16, width: 8, z0: -42, step: 12 };
export function treadmillAt(x, y, z) {
    const g = TREAD_GEO;
    if (Math.abs(x - g.cx) > g.len / 2 + 1 || y > g.top + 3 || y < g.top - 0.5) return null;
    for (let i = 0; i < TREADMILLS.length; i++) {
        if (Math.abs(z - (g.z0 + i * g.step)) <= g.width / 2 + 0.5) return TREADMILLS[i];
    }
    return null;
}

export const PORTALS = [
    { stage: 3, req: 10 }, { stage: 6, req: 100 }, { stage: 9, req: 1000 }, { stage: 12, req: 10000 }, { stage: 15, req: 200000 },
];

export const PRODUCTS = {
    Speed10K: { name: '+10K Speed', price: 29, speed: 10000 },
    Speed100K: { name: '+100K Speed', price: 79, speed: 100000 },
    Speed1M: { name: '+1M Speed', price: 149, speed: 1000000 },
    StarterPack: { name: 'OP Starter Pack', price: 19, speed: 50000, wins: 10 },
    Revive: { name: 'Revive', price: 9 },
    SpeedBoost: { name: 'x2 Speed Boost (15 min)', price: 49 },
};
export const PASSES = {
    DoubleSpeed: { name: '2x Speed', price: 3, ic: '⚡', desc: 'Double all Speed you earn' },
    DoubleWins: { name: 'x2 Wins', price: 139, ic: '🏆', desc: 'Double Wins from every stage' },
    RunArea9x: { name: '9x Run Area', price: 279, ic: '🏃', desc: 'Unlocks the x9 treadmill' },
    RunArea25x: { name: '25x Run Area', price: 399, ic: '🚀', desc: 'Unlocks the x25 treadmill' },
    PrimeMessi: { name: 'Prime Messi', price: 200, ic: '🐐', desc: '+10K Speed per step' },
    PrimeRonaldo: { name: 'Prime Ronaldo', price: 299, ic: '👑', desc: '+25K Speed per step' },
    RainbowAura: { name: 'Rainbow Aura', price: 99, ic: '🌈', desc: 'x5 Speed aura' },
};
// Bloxity Bux SKUs: create these in the game's IAP catalog on bloxity.io (prices live there)
export const SKUS = {
    product: {
        Speed10K: 'speed_10k', Speed100K: 'speed_100k', Speed1M: 'speed_1m',
        StarterPack: 'starter_pack', Revive: 'revive', SpeedBoost: 'speed_boost',
    },
    pass: {
        DoubleSpeed: 'pass_double_speed', DoubleWins: 'pass_double_wins',
        RunArea9x: 'pass_run_area_9x', RunArea25x: 'pass_run_area_25x',
        PrimeMessi: 'pass_prime_messi', PrimeRonaldo: 'pass_prime_ronaldo', RainbowAura: 'pass_rainbow_aura',
    },
};
// Bux price label for 3D text (DOM uses the coin icon instead)
export const buxText = (n) => fmt(n) + ' Bux';
export function skuLookup(sku) {
    for (const kind of ['product', 'pass']) for (const [key, s] of Object.entries(SKUS[kind])) if (s === sku) return { kind, key };
    return null;
}

export const OFFERS = [
    { title: 'OP STARTER PACK', ic: '🎁', kind: 'product', key: 'StarterPack' },
    { title: '1M Speed', ic: '👟', kind: 'product', key: 'Speed1M' },
    { title: 'Prime Ronaldo', ic: '👑', kind: 'pass', key: 'PrimeRonaldo' },
    { title: '9x Run Area', ic: '🏃', kind: 'pass', key: 'RunArea9x' },
];

const P_ = (id, name, bonus, req, num, row, shirt, shorts, socks, skin, hair, numC, extra) =>
    Object.assign({ id, name, bonus, req, num, row, shirt, shorts, socks, skin, hair, numC }, extra || {});
export const SOCCER = [
    P_('Yamal', 'LAMINE YAMAL', 3, 0, 19, 1, 0xd71923, 0x19236e, 0x19236e, 0xc88c5f, 0x2d1e14, '#ffcd28'),
    P_('Saka', 'SAKA', 2, 3, 7, 1, 0xf2f2f2, 0x19235a, 0xf2f2f2, 0x5f3c28, 0x140f0a, '#19235a'),
    P_('Dembele', 'DEMBELE', 5, 15, 11, 1, 0x2346c8, 0xf2f2f2, 0xd71e2d, 0x5a3723, 0x140f0a, '#ffffff'),
    P_('Ramos', 'RAMOS', 25, 50, 93, 1, 0x1e8250, 0x14141e, 0x14141e, 0xd7a578, 0x231914, '#ffffff'),
    P_('Palmer', 'PALMER', 50, 100, 20, 1, 0xf2f2f2, 0xf2f2f2, 0xd71e2d, 0xebbe96, 0xbe783c, '#d71e2d', { stripes: 0xd71e2d }),
    P_('Lewandowski', 'LEWANDOWSKI', 100, 1000, 9, 2, 0xa51437, 0x192364, 0x192364, 0xe1b48c, 0x281e19, '#ffcd28', { stripes: 0x19288c }),
    P_('Neymar', 'NEYMAR JR.', 250, 5000, 10, 2, 0xfadc28, 0x1e46c8, 0xf2f2f2, 0xbe875f, 0xe6c878, '#14783c'),
    P_('Mbappe', 'MBAPPE', 500, 10000, 10, 2, 0xf5f5f5, 0xf5f5f5, 0xf5f5f5, 0x6e462d, 0x140f0a, '#28283c'),
    P_('Messi', 'MESSI', 1000, 20000, 10, 2, 0xf5aac8, 0xf5aac8, 0xf5aac8, 0xe1af87, 0x462d19, '#14141e'),
    P_('Ronaldo', 'RONALDO', 2000, 50000, 7, 2, 0xfad728, 0x1e3caa, 0xfad728, 0xd7a578, 0x19140f, '#1e3caa'),
    P_('PrimeMessi', 'Prime Messi', 10000, 0, 10, 0, 0xf5f5fa, 0x14141e, 0xf5f5fa, 0xe1af87, 0x462d19, '#14141e', { pass: 'PrimeMessi', special: true, tagline: '*X10 VALUE*', aura: 0x288cff, stripes: 0x78bef0 }),
    P_('PrimeRonaldo', 'Prime Ronaldo', 25000, 0, 7, 0, 0xd2141e, 0xf5f5f5, 0x141419, 0xd7a578, 0x19140f, '#ffffff', { pass: 'PrimeRonaldo', special: true, tagline: '*INSANE VALUE*', aura: 0xff323c }),
];
// Stylised looks: hair style, beard, boot colour, signature celebration pose, rarity
const LOOKS = {
    Yamal: { hairStyle: 'curly', shoes: 0xff3fa0, pose: 'airplane', rarity: 'common', label: 'YAMAL' },
    Saka: { hairStyle: 'buzz', shoes: 0xffd028, pose: 'armsUp', rarity: 'common' },
    Dembele: { hairStyle: 'curly', beard: true, shoes: 0x28c8ff, pose: 'hips', rarity: 'common' },
    Ramos: { hairStyle: 'slick', beard: true, shoes: 0xf5f5f5, pose: 'flex', rarity: 'rare' },
    Palmer: { hairStyle: 'crop', shoes: 0x46ec50, pose: 'cold', rarity: 'rare' },
    Lewandowski: { hairStyle: 'fade', shoes: 0xff6e14, pose: 'hips', rarity: 'epic', label: 'LEWANDOWSKI' },
    Neymar: { hairStyle: 'mohawk', beard: true, shoes: 0xffd028, pose: 'wave', rarity: 'epic', label: 'NEYMAR JR' },
    Mbappe: { hairStyle: 'buzz', shoes: 0xf5f5f5, pose: 'crossed', rarity: 'legendary' },
    Messi: { hairStyle: 'short', beard: true, shoes: 0xff3fa0, pose: 'sky', rarity: 'legendary' },
    Ronaldo: { hairStyle: 'quiff', shoes: 0x28c8ff, pose: 'siu', rarity: 'legendary' },
    PrimeMessi: { hairStyle: 'long', shoes: 0xffd028, pose: 'sky', rarity: 'mythic', label: 'MESSI' },
    PrimeRonaldo: { hairStyle: 'quiff', shoes: 0xf5f5f5, pose: 'siu', rarity: 'mythic', label: 'RONALDO' },
};
for (const p of SOCCER) Object.assign(p, { label: p.name.toUpperCase() }, LOOKS[p.id] || {});
export const RARITY = {
    common: { name: 'COMMON', color: 0x6fe0ff },
    rare: { name: 'RARE', color: 0x46ec50 },
    epic: { name: 'EPIC', color: 0xc428ff },
    legendary: { name: 'LEGENDARY', color: 0xffd028 },
    mythic: { name: 'MYTHIC', color: 0xff3c50 },
};
export const soccerById = Object.fromEntries(SOCCER.map((p) => [p.id, p]));

export const AURAS = [
    { id: 'Sparkle', name: 'Sparkle', req: 10, mult: 1.1, color: 0xffffff, ic: '✨' },
    { id: 'BlueFlame', name: 'Blue Flame', req: 50, mult: 1.25, color: 0x288cff, ic: '🔵' },
    { id: 'Inferno', name: 'Inferno', req: 250, mult: 1.5, color: 0xff6e14, ic: '🔥' },
    { id: 'Lightning', name: 'Lightning', req: 1000, mult: 2, color: 0x5ae6ff, ic: '⚡' },
    { id: 'Galaxy', name: 'Galaxy', req: 5000, mult: 3, color: 0xaa46ff, ic: '🌌' },
    { id: 'Rainbow', name: 'Rainbow', pass: 'RainbowAura', mult: 5, color: 0xff50c8, ic: '🌈' },
];
export const auraById = Object.fromEntries(AURAS.map((a) => [a.id, a]));

// Session playtime rewards (minutes since joining)
export const FREE = [
    { min: 2, speed: 500 }, { min: 5, wins: 2 }, { min: 10, speed: 5000 },
    { min: 15, wins: 5 }, { min: 25, speed: 25000 }, { min: 40, wins: 15 },
];

// Player kits cycle by join order so players look different from each other
export const KITS = [
    { shirt: 0x2f7bff, shorts: 0xf5f5f5, socks: 0x2f7bff },
    { shirt: 0xe82434, shorts: 0x14141e, socks: 0xe82434 },
    { shirt: 0x28c43c, shorts: 0xf5f5f5, socks: 0x28c43c },
    { shirt: 0xffb51c, shorts: 0x1e3caa, socks: 0xffb51c },
    { shirt: 0x8a1cff, shorts: 0xf5f5f5, socks: 0x8a1cff },
    { shirt: 0xf5f5f5, shorts: 0x14141e, socks: 0xf5f5f5 },
    { shirt: 0xff3fa0, shorts: 0xf5f5f5, socks: 0xff3fa0 },
    { shirt: 0x14141e, shorts: 0x14141e, socks: 0xffd028 },
];
export const SKINS = [0xe1af87, 0xc88c5f, 0x8c5a3c, 0x5f3c28, 0xf0c8a0];

// Combined multiplier for earned Speed: rebirths, aura, 2x pass, timed boost
export function speedMult(p, now) {
    let m = 1 + (p.rebirths || 0) * CFG.rebirthStep;
    const a = auraById[p.aura];
    if (a) m *= a.mult;
    if (p.passes && p.passes.DoubleSpeed) m *= 2;
    if ((now || Date.now()) < (p.boostUntil || 0)) m *= CFG.boostMult;
    return m;
}

const SUF = ['K', 'M', 'B', 'T', 'Qa', 'Qi'];
// 2700 -> "2.7K", 1000000 -> "1M", 950 -> "950"
export function fmt(v) {
    v = Math.floor(v || 0);
    if (v < 1000) return String(v);
    let i = -1, s = v;
    while (s >= 1000 && i < SUF.length - 1) { s /= 1000; i++; }
    const t = s >= 100 ? String(Math.floor(s)) : (Math.floor(s * 10) / 10).toFixed(1).replace(/\.0$/, '');
    return t + SUF[i];
}
// Leaderboard style: 6700000 -> "6.7e+6"
export function sci(v) {
    v = Math.floor(v || 0);
    if (v < 100000) return fmt(v);
    const e = Math.floor(Math.log10(v));
    return (Math.floor(v / Math.pow(10, e) * 10) / 10).toFixed(1) + 'e+' + e;
}
export function clock(s) {
    s = Math.max(0, Math.floor(s));
    return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');
}
export const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
export function rngFrom(seed) {
    let a = seed >>> 0;
    return () => {
        a = (a + 0x6D2B79F5) >>> 0;
        let t = a;
        t = Math.imul(t ^ (t >>> 15), t | 1);
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}
