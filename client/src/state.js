// Local mirror of this player's progress. The server owns the real values:
// public stats arrive through the room state, private ones in "profile" messages.
export const S = {
    speed: 0, wins: 0, level: 1, xp: 0, rebirths: 0,
    owned: { Yamal: true }, equipped: 'Yamal', auras: {}, aura: '', passes: {},
    boostUntil: 0, customSpeed: 0, claimedPack: false, firstPlay: Date.now(),
    freeClaimed: {}, joinedAt: Date.now(), name: '',
};

// Game actions that world objects (pads, pedestals, portals) trigger; filled in by main.js
export const actions = {};

export const net = {
    room: null,
    offset: 0,
    send(type, msg) { if (this.room) this.room.send(type, msg || {}); },
    // Server clock in ms, so falling walls and balls line up for everyone
    now() { return Date.now() + this.offset; },
};
