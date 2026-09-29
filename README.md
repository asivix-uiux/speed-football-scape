# Speed Football Scape

A multiplayer "speed escape" football game for the browser, built with **Three.js** and **Colyseus**. It clones the Roblox game *[X1000] +1 Speed Football Scape* (see `reference/`).

## Project layout

| Folder | What it is |
|---|---|
| `client/` | Vite + Three.js game client (`src/main.js`, `world.js`, `engine.js`, `ui.js`) |
| `server/` | Colyseus 0.18 server: the `speed` room, player profiles, leaderboards |
| `shared/` | Game data and formulas used by both sides (`config.js`) |
| `web/` | Earlier single-file, single-player demo (kept for reference) |
| `src/` | Original Roblox/Rojo build (design reference only) |

## Run it locally

Needs Node 20 or newer.

```sh
npm install          # installs client and server too
npm run build        # builds the client into client/dist
npm start            # server + game on http://localhost:2567
```

For development, run `npm run dev:server` and `npm run dev:client` in two terminals, then open the Vite URL (http://localhost:5173). In dev the client connects to the server on port 2567; set `VITE_SERVER_URL` to point it somewhere else.

## How multiplayer works

- Everyone joins one shared `speed` room (up to 24 players), which covers the lobby and all six stages.
- **Client-side:** movement and physics. The client sends its position about 15 times a second, and other players are drawn with interpolation, name and Speed labels, followers and auras.
- **Server-side:** everything that changes progress.
  - Speed from running (every 0.5s while moving, including treadmill multipliers).
  - Shoe pickups and Wins pads, checked against the player's position.
  - Shop unlocks, auras, rebirths and FREE rewards.
  - Purchases.
- Falling walls and rolling balls run on the server clock, so all players see the same timing. Each player's Stage 4 chase wall is local.
- Leaderboards list real players and refresh every 10 seconds.
- Progress is saved per browser, keyed by a random id in localStorage.
  - The server stores it in `server/data/profiles.json`; set `DATA_DIR` to change the folder.
  - Replace `server/src/profiles.js` with the platform's auth and database when the game goes live on Bloxity.

## Purchases

Every Robux button is free in this demo. `SpeedRoom.onBuy` in `server/src/SpeedRoom.js` is where real payments hook in.

## Deploy

The server also serves the built client, so one Node host runs the whole game. Use Render, Railway, Colyseus Cloud or any VPS:

- Build command: `npm install && npm run build`
- Start command: `npm start` (it listens on `PORT`)

WebSockets must be allowed. On hosts with a temporary disk, point `DATA_DIR` at a persistent volume, or player progress resets on redeploy.

---

## Legacy: Roblox build

The original Roblox "speed escape" football game built with Rojo and Luau, modelled on `reference/gameplay.mp4`.

## Gameplay

- **Lobby** (built in `src/Server/LobbyBuilder.lua` to match `reference/lobby.mp4`):
  - North: the Stage 1 gate with the Top Speed and Top Wins boards.
  - East: eight treadmills (X25 and X9 are game passes, X3 needs Wins).
  - West: the soccer player shop, plus Prime Messi and Prime Ronaldo.
  - South: yellow stage portal doors that skip ahead once you have enough Wins, and the SPEED BOOST pad (a timed x2 boost).
- **Course** of six stages, as in the real game:
  - Stage 1 ESCAPE: a green path between lava channels.
  - Stage 2 Falling Walls.
  - Stage 3 Obby.
  - Stage 4 RUN!: a red wall chases you down the hall.
  - Stage 5 Ball: a lava path with giant, frequent balls.
  - Stage 6 PLATFORMS.
- Giant rolling footballs, spinning sweepers, spikes and lava. Shoe pickups give +5 / +9 Speed.
- Return pads at the end of each stage give Wins (+1 / +3 / +8 / +20 / +50 / +100) and send you back to the lobby.
- Dying shows a **Revive** popup (Robux) or sends you back to the lobby.
- Running earns Speed. XP is earned 1:1 with Speed, and max walk speed is `12 + 2 × Level + 20 × Rebirths`. The level cap is 30; at MAX the XP bar keeps filling.
- The HUD matches the reference: offer banner, Rebirth / Auras / FREE buttons, Starter Pack timer, Custom Speed, 2x Speed, level and stamina bars, and +10K / +100K / +1M Speed buttons. Hold Shift to sprint.

The map is built from code at runtime (`src/Server/MapBuilder.lua`), so there is nothing to place by hand in Studio.

## Monetization placeholders

Product and game pass IDs live in `src/Shared/Config.lua` (`Config.Products` and `Config.Passes`) and are all `0` for now.

- **In Studio**, a placeholder purchase is granted for free, so every button can be tested.
- **In a live server**, a placeholder shows "Coming soon!" instead.

To go live, replace each `0` with the real Developer Product or Game Pass ID.

## Setup

1. Start the sync server from the project root with `rojo serve`. Rojo 7.7.0 is pinned in `aftman.toml`.
2. In Roblox Studio, open the Rojo plugin and choose **Connect**.
3. Turn on **Game Settings → Security → Enable Studio Access to API Services** so DataStores and leaderboards work in Studio.
4. Press Play.

`Workspace.StreamingEnabled` is turned off in `default.project.json` so clients receive the whole generated map.

## Folder structure

```text
src/
  Shared/   Config (all tunables), Catalog (players/auras/rewards), RigBuilder, Remotes, Format
  Server/   Bootstrap, MapBuilder, LobbyBuilder, DataService, PlayerService,
            CourseService, ShopService, LeaderboardService, ProgressionService
  Client/   Bootstrap, ClientState, UI, HUDController, PanelController,
            EffectsController, FollowerController, InputController, CameraController
```

## Progression (Phase 2)

All values live in `src/Shared/Catalog.lua`.

- **Soccer players**: step on a pedestal in the lobby to equip a player. The player adds bonus Speed to every running step and follows you around. Players unlock with Wins; Prime Messi is a game pass.
- **Rebirth**: available at Level 30. Resets your Level to 1 and adds +50% to all Speed you earn. Speed and Wins are kept.
- **Auras**: unlock with Wins (or a game pass for Rainbow). Each aura is a visual effect plus a Speed multiplier.
- **FREE rewards**: playtime rewards that can be claimed once per session. The FREE button shows a "!" when one is ready.
