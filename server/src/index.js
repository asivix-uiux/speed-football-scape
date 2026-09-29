import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import config, { listen } from '@colyseus/tools';
import { defineRoom } from 'colyseus';
import express from 'express';
import { SpeedRoom } from './SpeedRoom.js';

// Serves the built client (client/dist) and the game room on the same port,
// so one Node host is enough to run the whole game.
const CLIENT_DIST = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'client', 'dist');

const app = config({
    rooms: {
        speed: defineRoom(SpeedRoom),
    },
    initializeExpress: (expressApp) => {
        expressApp.get('/health', (req, res) => res.json({ ok: true }));
        if (fs.existsSync(CLIENT_DIST)) expressApp.use(express.static(CLIENT_DIST));
    },
});

listen(app, Number(process.env.PORT) || 2567);
