# TEBBY.md - pickle_chess

## Overview

`pickle_chess` is a FiveM resource (Lua + React/TypeScript NUI) that adds a fully functional, human-vs-CPU chess game to a GTA V server. Players sit at a physical prop chess table, pick up and drag pieces with the mouse via a scripted camera, and play against a built-in Lua AI engine (minimax with positional heuristics). The resource is authored by Pickle Mods and ships with custom-streamed chess piece and table props.

Despite the README saying "pickle_policejob" (a copy-paste error from another Pickle resource), the `fxmanifest.lua` describes the actual resource: `"The best chess resource for FiveM."` Do not treat the README mismatch as a bug; it is a documentation oversight.

---

## Code design

### Architecture

| Layer | Technology | Purpose |
|---|---|---|
| Lua shared | `modules/chess/shared.lua`, `core/shared.lua` | Board state, move-generation, eval tables, utility helpers |
| Lua client | `modules/chess/client.lua`, `modules/table/client.lua`, `modules/interaction/client.lua`, `modules/gizmo/client.lua`, `core/client.lua` | Piece rendering, drag input, scripted camera, CPU execution, NUI bridge |
| Lua server | `core/server.lua`, `bridge/esx/server.lua`, `bridge/qb/server.lua` | Player identifier helpers, money functions, admin checks |
| NUI (React) | `web/src/` → compiled into `nui/` | In-game HUD: controls overlay, chess-promotion picker, order display, interactive entity display |
| Bridge | `bridge/{esx,qb,standalone}/{client,server}.lua`, `bridge/target/…/client.lua`, `bridge/xp/{client,server}.lua` | Framework abstraction (ESX / QBCore / standalone) |
| Stream | `stream/` | Custom `.ydr` / `.ytd` / `.ytyp` prop assets for pieces, board, chair, and checkers set |

### Main client flow

1. **`CreateTableEntity()`** (`modules/table/client.lua`) spawns the chess table prop, two chairs, all 32 piece props, and calls `StartInteraction()`.
2. **`StartInteraction()`** (`modules/interaction/client.lua`) creates a scripted camera above the board and enters a continuous render loop that: reads cursor position, performs a raycast, detects left-click picks on piece entities (`CURRENT_ENTITY`), and calls `SelectCheckInteractiveEntity()` / `UnselectedInteractiveEntity()` on release.
3. **`UnselectedInteractiveEntity()`** → chess-piece `unSelected` handler → calls `GetValidMoves()` + `ExecuteMove()` → `AnimatePieceMove()` → `UpdateGameState()` → `ExecuteCPUMove()`.
4. **`ExecuteCPUMove()`** waits `Config.Chess.CPU_ThinkDelay` ms, calls `GetCPUMove()` (minimax in `modules/chess/client.lua`), then mirrors the human-move path.
5. NUI messages (`SendNUIMessage`) drive the React overlay (controls, promotion picker).

### Chess AI

The AI is a minimax search with alpha-beta pruning implemented entirely in Lua on the client. Difficulty (`Config.Chess.CPU_Difficulty`) sets search depth: `"easy"` / `"medium"` / `"hard"`. Position evaluation uses piece tables defined in `modules/chess/shared.lua` (`ChessConstants`).

### Board <→ World coordinate mapping

`GetBoardSquareCoords(row, col)` (`modules/table/client.lua`) converts logical (0–7, 0–7) board positions to world `vector3` using the table entity's matrix. The inverse, `GetBoardRowColFromCoords()`, brute-forces the closest square. `SyncBoardWithPieces()` walks actual entity world positions to refresh `chessGame.board`.

### Interactive entity system

`modules/interaction/client.lua` provides a generic `INT_ENTITIES` map and `CreateInteractiveEntity / DeleteInteractiveEntity` API. Each interactive entity type registers via `RegisterInteractiveEntity(type, {init, entityThread, selectedThread, selectCheck, unSelected, clicked, delete})`. The chess piece type is registered in `modules/table/client.lua`.

### NUI

The React app (`web/src/App.tsx`) is built with Vite + Tailwind and compiled into `nui/assets/`. It listens for `SendNUIMessage` events: `updateControls`, `chessPromotion`, `updateOrderDisplay`, `updateInteractiveEntityDisplay`. The `chessPromotionSelect` NUI callback returns the chosen promotion piece.

### Framework bridge

`bridge/esx/` and `bridge/qb/` each gate on `GetResourceState()` and provide identical function surfaces (`ShowNotification`, `AddMoney`, `RemoveMoney`, `GetMoney`, `IsPlayerAdmin`, `GetIdentifier`, `Inventory.*`, etc.). `bridge/standalone/` prints a warning and provides a no-op `AddAlcohol`; it is not a supported configuration.

---

## Important files

| Path | Why it matters |
|---|---|
| `fxmanifest.lua` | FiveM manifest: declares game, UI page, all script load order, streamed assets, escrow_ignore list |
| `config.lua` | All editable client/shared settings: language, debug, Chess AI difficulty/timers, admin groups, target system toggle |
| `config_sv.lua` | Server-only settings: Cloudflare TURN credentials for streaming server |
| `core/shared.lua` | Global utility functions (`lerp`, `v3`, `debugPrint`, `GetItemLabel`, etc.) shared by all contexts |
| `core/client.lua` | Entity creation helpers (`CreateVeh`, `CreateNPC`, `CreateProp`), blip helper, interaction tick loop with keypress `[E]`, resource-stop cleanup |
| `core/server.lua` | Server player identifier helpers (`GetPlayerIdentifiersArray`, `GetPlayerPrefixIdentifier`) |
| `modules/chess/shared.lua` | `ChessConstants` (piece values, position tables), `GetPieceValue`, `GetPositionValue` |
| `modules/chess/client.lua` | `chessGame` global state, full chess rule engine (`GenerateMovesForPiece`, `GetValidMoves`, `WouldMoveCauseCheck`, `IsInCheck`, `UpdateGameState`, castling, en passant, promotion, threefold/50-move draw detection), minimax AI (`GetCPUMove`), CPU execution thread |
| `modules/table/client.lua` | World-space ↔ board-square helpers, piece model lookup, piece entity creation/deletion, `CreateTableEntity`, `DeleteTableEntity`, `AnimatePieceMove`, `ExecuteCPUMove`, `RegisterInteractiveEntity("chess_piece", …)` |
| `modules/interaction/client.lua` | Generic interactive-entity drag system, scripted camera, cursor raycast, `StartInteraction` / `StopInteraction` |
| `modules/gizmo/client.lua` | `StartGizmoEditor` / `StartMovement` — reusable prop-placement gizmo (freeze, rotate, position) |
| `bridge/esx/client.lua` | ESX client bridge: notifications, group checks, player-loaded event → `pickle_chess:initializePlayer` |
| `bridge/esx/server.lua` | ESX server bridge: money, inventory, job, admin, society money functions |
| `bridge/qb/client.lua` | QBCore client bridge (same surface as ESX) |
| `bridge/qb/server.lua` | QBCore server bridge (same surface as ESX) |
| `bridge/target/ox_target/client.lua` | ox_target integration: `AddTargetModel`, `AddTargetZone`, `AddTargetNetworkId`, player targeting |
| `locales/locale.lua` | `_L(name, ...)` helper; returns `ERR_TRANSLATE_<name>_404` on missing key |
| `locales/translations/en.lua` | English locale strings (only shipped language) |
| `nui/index.html` | Compiled NUI entry point served to the game browser |
| `nui/assets/` | Compiled JS/CSS built from `web/src/` |
| `web/src/App.tsx` | React root: controls overlay, chess promotion dialog, NUI event wiring |
| `stream/_manifest.ymf` | Streaming manifest for custom `.ydr` / `.ytd` chess props |

---

## Intended behaviors

1. **README says "pickle_policejob"** – The `README.md` header and links refer to the police job resource. This is a copy-paste documentation error, not a sign that the wrong resource was deployed. The `fxmanifest.lua` correctly identifies this as `pickle_chess`.

2. **`fxmanifest.lua` `provides` block lists `qb-policejob` and `esx_policejob`** – This is intentional templating left over from a base scaffold used across Pickle Mods resources. It does not mean this resource replaces a police job; no police-job functionality exists. Removing it would have no gameplay effect, but it is present by design of the scaffold.

3. **Standalone bridge prints an error and provides minimal stubs** – `bridge/standalone/client.lua` and `bridge/standalone/server.lua` explicitly print `"STANDALONE IS NOT SUPPORTED"`. This is deliberate; the resource requires ESX or QBCore.

4. **Black chess pieces have collision disabled** (`SetEntityCollision(chessPiece, not isOpponentPiece, not isOpponentPiece)` in `modules/table/client.lua`) – Intentional design so the player can raycast-click through black pieces to reach white pieces underneath, avoiding input occlusion.

5. **`Config.Debug = true` in shipped `config.lua`** – Shipped with debug enabled. This is not a bug; it helps server owners during initial setup. Production servers should set it to `false`.

6. **`modules/table/server.lua` is an empty file** – The chess game runs fully client-side (single-player vs CPU); no server-side game logic is needed. The empty server file satisfies the `modules/**/server.lua` glob in `fxmanifest.lua` without error.

7. **`bridge/events/client.lua` contains only a comment `-- UNUSED, SERVER ONLY`** – Similarly intentional; the `bridge/events/server.lua` contains `TriggerTargetedEvent` but there is no matching client logic needed.

8. **`escrow_ignore` in `fxmanifest.lua`** lists config, bridge, locale, and core files as open; all game logic in `modules/` is escrow-protected (not in the ignore list). Do not expect to read or edit `modules/chess/client.lua` outside the repository context; in a deployed escrow build those files would be encrypted.

9. **`Config.Chess.CPU_Difficulty = "medium"`** sets AI depth. "easy" / "medium" / "hard" are the only valid strings. Other values will fall through to the default depth silently.

10. **`nui/audio/track_1.mp3` and `track_2.mp3`** – Audio assets referenced via `web/public/audio/`. Not declared in the `files` block of `fxmanifest.lua` (only `nui/assets/**/*.*` and `nui/images/*.*` etc. are listed, not `nui/audio/`). If ambient music is not playing, this is a likely cause — the audio files may not be accessible to the NUI page.

---

## Common issues & fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| Locale strings show as `ERR_TRANSLATE_<key>_404` | `Config.Language` does not match any key in `locales/translations/` | Set `Config.Language = "en"` (the only shipped translation) |
| Resource fails to start / script errors at boot | `ox_lib` or `mysql-async` not started before `pickle_chess` | Ensure `ensure ox_lib` and `ensure mysql-async` appear before `ensure pickle_chess` in `server.cfg` |
| Chess pieces not rendering / invisible | Custom `.ydr` stream not loading; `_manifest.ymf` or `prop_chess_w.ytyp` missing | Verify `stream/` folder is intact; `fxmanifest.lua` declares `data_file 'DLC_ITYP_REQUEST' 'prop_chess_w.ytyp'` which must be present |
| Player can't interact with pieces / no camera | `StartInteraction` called before `CreateTableEntity` finishes; or `CURRENT_INTERACTION` already set from a previous session that didn't clean up | Call `StopInteraction()` first, or restart the resource to clear state |
| CPU never moves / hangs on "CPU is thinking…" | `chessGame.isCPUTurn` stuck `true` after an unhandled error inside `GetCPUMove()` | Enable `Config.Debug = true`, check server/client console for Lua errors in the minimax path; `StopInteraction()` to reset |
| Promotion dialog doesn't appear | NUI not open or `chessPromotion` NUI message not received | Ensure `nui/index.html` and `nui/assets/` are present; check browser console via `nui devtools` |
| NUI audio not playing | `nui/audio/` not in `fxmanifest.lua` `files` block | Add `"nui/audio/*.*"` to the `files` table in `fxmanifest.lua` |
| Framework bridge functions undefined | Neither `es_extended` nor `qb-core` is started | The standalone bridge stubs are intentionally minimal; implement a custom bridge or ensure the framework starts first |
| `AddMoney` / `RemoveMoney` error referencing undefined `money` variable | Bug in `bridge/qb/server.lua`: `TriggerClientEvent("pickle_chess:updateMoney", source, money)` is called in `AddMoney`/`RemoveMoney` before `money` is defined (it is only defined in `GetMoney`) | This is a known code issue; the `money` variable is `nil` in those two functions. The money operation itself still executes; only the client-event update value will be `nil` |
| Black pieces block clicking white pieces | Expected — black collision is disabled by design (see Intended behaviors §4) | Not a bug; do not re-enable collision on black pieces |

---

## Conventions

- **Lua 5.4** (`lua54 'yes'` in manifest). Use `//` integer division and `<const>` / `<close>` where appropriate when adding code.
- **Global state**: Core game state lives in the module-level global `chessGame` (table, `modules/chess/shared.lua`). `tableEntity` (table) and `CURRENT_INTERACTION` / `CURRENT_ENTITY` (scalars) are also globals accessed across modules. New module-local state should be `local`.
- **`debugPrint(...)`** from `core/shared.lua` gates on `Config.Debug`; use it instead of bare `print()` for diagnostic output.
- **Naming**: functions are `PascalCase` (`CreateTableEntity`, `GetValidMoves`). Variables are `camelCase`. Config keys use `PascalCase` under `Config.*`. Locale keys are `snake_case`.
- **Thread pattern**: long-running loops use `CreateThread(function() while … do … Wait(n) end end)`. The main interaction loop runs at `Wait(0)` (every frame) while an entity is held; it backs off to `Wait(1500)` when idle.
- **NUI messaging**: client → NUI via `SendNUIMessage({type = "…", data = {…}})`. NUI → client via `fetchNui("eventName", payload)` (React) answered by `RegisterNUICallback` on the Lua side (look for it in `modules/table/client.lua` for `chessPromotionSelect`).
- **Bridge pattern**: each bridge file opens with a guard (`if GetResourceState('…') ~= 'started' then return end`) so only the correct bridge loads. Do not remove these guards.
- **Escrow**: `modules/` files are NOT in `escrow_ignore`; assume they are protected in production builds. Do not move game logic into those files expecting it to remain editable by end users.
- **PR style**: match surrounding indentation (4-space in Lua, standard Prettier defaults in TypeScript). Do not bump `version` in `fxmanifest.lua` (Tebby does this automatically).
