# World of ClaudeCraft: server architecture notes (input to the shared-world server pick)

- Donor: world-of-claudecraft @ `f46f30f5849989e44d7aa1bf62b3b14e435bc2fe`. Paths are relative to the donor root. Line numbers are at that commit.
- Author: analyst-claudecraft, 2026-10-06. These notes are factual only; the lead writes the recommendation.

## Shape at a glance

| Concern | What ClaudeCraft does | Where |
|---|---|---|
| Process model | **One Node process per realm**: `REALM_NAME` per deployment, all realms sharing one Postgres. Characters, friends, guilds and presence are scoped by realm. | `server/realm.ts:1-20` (`resolveRealm`, `REALM`) |
| Server build and run | esbuild bundle of `server/` to `dist-server/server.cjs`; it serves the built client from `dist/` | `package.json` scripts `build:server`, `server`; `server/CLAUDE.md:8-9` |
| Sim sharing | "One sim, three hosts": the same `src/sim/` runs offline in the browser, on the server, and headless for RL | `CLAUDE.md:116-118` |
| Transport | `ws` 8.x `WebSocketServer({ noServer: true, maxPayload: 16 KiB })` on the HTTP server's `/ws` upgrade. JSON text frames. | `server/main.ts:3801`, `:563` (`WS_MAX_PAYLOAD_BYTES = 16 * 1024`); upgrade wiring `server/ws_auth.ts` `attachUpgrade` (`main.ts:3826`) |
| Tick | `TICK_RATE = 20` (`DT = 1/20`). A `setInterval(…, 50)` accumulator loop runs `while (acc >= DT) sim.tick()`, dt is clamped to 0.5 s, and the whole body is wrapped in `runGuarded` so a throw costs one pass rather than the loop. | `src/sim/types.ts:32-33`; `server/game.ts:2540-2662` (clamp `:2559`, `sim.tick()` `:2593`, interval `:2662`) |
| Rooms / zones | **No rooms.** One `Sim` per realm holds every zone, and dungeons and raids run as instances inside that same Sim (`src/sim/instances/*`). Sharding is by realm process. | `server/realm.ts`, `src/sim/instances/` |
| State sync | After each loop pass, `broadcastSnapshots()` sends each client one `{"t":"snap","tick","time",…}` frame scoped to its interest radius. One padded spatial-grid query is made per occupied cell and shared by every viewer in that cell. Per-entity wire caches mean unchanged fields are not re-serialized, and event frames are serialized once and sent raw. | `server/game.ts:2635` (call), `:7910-7935` (head build); `server/interest_policy.ts:18-50` (radii: NPC 120/130, BG 300/320); `server/interest_candidates.ts:1-20`; `server/entity_wire_cache.ts`, `server/event_frame.ts` |
| Client input | Movement intent streams about every 50 ms plus a changed-only rAF flush (60-64/s measured, hard cap about 82.5/s). Commands are `{cmd}` frames. A `seq` is folded into an ack high-water mark that the self snapshot echoes. | `server/msg_rate_limit.ts:11-20` (cadence analysis); `server/input_seq.ts:36` |
| Command authority | "Trust nothing from the client": `dispatchMessage` type-checks every field before calling a `sim.*` method, and every outcome resolves inside the Sim. A non-object frame is dropped and still costs a command-lane token. | `server/CLAUDE.md:77-80`; `server/game.ts:6080-6100` |
| Auth verification | Opaque bearer token (32 random bytes, hex), looked up in Postgres `auth_tokens` with `expires_at` and scope (`full`/`read`). Passwords use scrypt N=16384, r=8, with `timingSafeEqual`. The WS handshake takes the token in the **first frame**, which must be `ONLINE_WORLD_AUTH_TYPE`, and must finish within a 10 s auth timeout. Moderation and character checks follow, then the lease, then `game.join`. | `server/auth.ts:1-41`; `server/db.ts:407-415`, `:1770-1774`; `server/ws_auth.ts:81`, `:271`, `:482`, `:659-661` |
| Single-login enforcement | A per-character **load lease** row in Postgres: one process may hold it, with a fresh nonce per join. A stale release cannot delete a newer lease. A same-account reclaim rotates the nonce so the displaced session's fenced writes fail. Heartbeats ride the autosave, and crash recovery is expiry-based. | `server/db.ts:694-720` (DDL rationale); `server/character_lease_db.ts:40-53` |
| Reconnect | A pure `planJoin` decides resume / reject / join, with a 5-minute link-dead grace. The client classifies "character already in world" (up to 8 retries) and "authentication timed out" (up to 20) as transient, with jittered backoff. | `server/linkdead.ts:17`, `:54`; `server/game.ts:3237`; `src/net/reconnect_policy.ts:54-72`; `src/net/backoff.ts:11` |
| Rate limiting (WS) | Three layers: (1) a gate that runs **before** `JSON.parse`, with a frame bucket of 120/s (burst 180), a byte bucket of 64 KiB/s (burst 128 KiB), and an abuse window that kicks after 5 abusive seconds in 10 (an abusive second has ≥30 drops); (2) per-class lanes after parsing: movement 90/120, command 30/60, chat 4/8, name-screen 2/5; (3) a list-readout meter. | `server/msg_rate_limit.ts:41-59`, `:114`; gate call `server/game.ts:5933-5944`; `server/msg_lanes.ts:43-79`, `:120`, `:138`; `server/list_read_guard.ts` |
| Rate limiting (HTTP) | Per-IP sliding 60 s window over a bounded 10k-IP table. The client IP comes from XFF only when the peer is loopback or private (the reverse proxy), or from a pinned `TRUSTED_PROXY_IPS`. An optional Postgres tier-2 store backs it. Auth routes allow 20/min. | `server/ratelimit.ts:1-25`, `:69`, `:149-212` |
| Admission caps | A per-IP hard WS cap, and a realm cap (`MAX_PLAYERS_PER_REALM`, default 5000) counted with an **in-flight admission counter** so racing handshakes cannot exceed it. Every refusal sends an `{t:'error'}` frame before closing. | `server/ws_auth.ts:132-136`, `:182-183`, `:440-450`; `server/CLAUDE.md:36` |
| Liveness | A 30 s ping sweep. A sweep delayed by an event-loop stall re-arms sessions instead of terminating them, and a 10-minute hard silence deadline reaps black-holed sockets. Outbound: a session is terminated when `ws.bufferedAmount` exceeds 8 MiB. | `server/keepalive_sweep.ts:16-80`; `server/game.ts:2780-2798`; `server/ws_backpressure.ts:15-19`; `server/game.ts:9792-9796` |
| Persistence | Postgres via `pg`, with the character stored as a JSON blob. The autosave runs every 30 s, fire-and-forget inside the tick, with each write listed exactly once. Per-resource **serial writer** FIFOs keep an older snapshot from committing after a newer one. Save transactions are bounded (statement 60 s, transaction 65 s) and fenced on the lease. A timeout ladder runs connect < statement < heavy < driver backstop. | `server/game.ts:518`; `server/periodic_save_flush.ts:1-30`, `:77`, `:114`; `server/serial_writer.ts:1-10`, `:20`; `server/character_save_transaction.ts:17-36`; `server/CLAUDE.md:42` |
| Outbox / ledger | Bank ledger outbox: capacity is reserved **before** the sim is mutated, then immutable rows are committed. A save captures an exact prefix and acknowledges it only after state and ledger rows commit in the **same transaction**. The cap is 2,048 rows, and per-account guards admit a 121-row burst plus 4 rows/s. | `server/bank_ledger_outbox.ts:1-20` |
| Compensation | `pg_rollback_proof.ts` classifies a thrown pg error by whether the rollback is proven. Compensating actions (restoring an item) run only on proof; an ambiguous result parks the item. | `server/pg_rollback_proof.ts:1-10`; `server/CLAUDE.md:51` (escrow section) |
| Anti-cheat | The server is authoritative, with field-typed dispatch. Bot detection is a pluggable `BotDetector` seam (a private clone, with only a no-op stub in this copy) fed protocol anomalies (`invalid_json`, `non_object`, `unknown_type`, `unknown_command`) and timing. There is a power-neutral "cheater mark" aura and a non-cryptographic client challenge hash. | `server/bot_detector/contract.ts:4-15`; `tsconfig.json` paths `#bot-detector`; `server/game.ts:5946-5955`; `server/cheater_mark_runtime.ts:1-10`; `src/sim/client_challenge.ts:1-6` |
| Observability | Tick profiler (per-phase laps), achieved tick-rate meter, prom-client metrics, and `/livez` stamped from the loop start. | `server/tick_profiler.ts`, `server/tick_rate_meter.ts`; `server/game.ts:2546`, `:2633-2634` |
| Code structure rule | "Module-first": pure decision logic goes in host-agnostic modules a Vitest imports directly, and I/O sits behind injected deps bags (`createWsAuth`). `game.ts` (9,811 LOC) and `main.ts` (4,363) are monoliths under a ratchet. | `server/CLAUDE.md:11-26`, `:35` |

## Hardening patterns worth adopting (each is pure and has a 1-file closure unless noted)

1. **Gate before parse:** apply token buckets on frames and bytes before `JSON.parse`, and kick on whole abusive seconds rather than raw drop counts, so a TCP stall-then-flush burst from a legitimate client never kicks it. (`server/msg_rate_limit.ts`, 156 LOC)
2. **Per-class lanes after parse,** so chat spam cannot starve movement and garbage still costs a token. (`server/msg_lanes.ts`, 176 LOC)
3. **Small `maxPayload`** (16 KiB) on the WebSocketServer. The `ws` default is about 100 MiB. (`server/main.ts:563`, `:3801`)
4. **Outbound backpressure kill** on `bufferedAmount`. (`server/ws_backpressure.ts`, 25 LOC)
5. **Stall-aware keepalive:** a late sweep re-arms instead of mass-disconnecting, and a separate hard silence deadline remains. (`server/keepalive_sweep.ts`, 81 LOC)
6. **First-frame auth with a deadline** and an error frame before every close, so the client can classify the refusal instead of retry-looping. (pattern from `server/ws_auth.ts`; the file itself drags in the sim)
7. **Admission cap with an in-flight counter,** to close the race between concurrent handshakes. (`server/ws_auth.ts:440-450`)
8. **Character lease plus nonce fencing** for single-login across processes and deploy overlap. (`server/character_lease_db.ts`)
9. **Pure `planJoin`** for resume / reject / join, with a link-dead grace. (`server/linkdead.ts`, 84 LOC)
10. **Serial-writer FIFO plus read-snapshot-inside-thunk** so the last commit always holds the freshest state. (`server/serial_writer.ts`, 316 LOC)
11. **Reserve-then-mutate outbox, with the ledger prefix committed in the same transaction as state** (pattern from `server/bank_ledger_outbox.ts`, which drags in sim types).
12. **Compensate only on proven rollback.** (`server/pg_rollback_proof.ts`, 41 LOC)
13. **Guarded tick body** plus a dt clamp, so one throw or stall cannot kill or spiral the loop. (`server/game.ts:2547-2559`)
14. **Non-finite pose guard** at the sim boundary. (`src/sim/finite_pose_guard.ts`, 142 LOC)
15. **Trusted-proxy-only XFF** for per-IP limits. (`server/ratelimit.ts:12-20`, `:149-212`)

## Patterns to avoid or differ on

- `auth_tokens.token` is stored in **plaintext** as the primary key (`server/db.ts:407-412`), while email-change and password-reset tokens are hashed (`token_hash`, `:603`, `:622`). Bearer tokens should be hashed at rest.
- The token travels in the WS first frame. That avoids URL leakage, but it means the socket is open before it is authenticated, which is what the 10 s timeout and per-IP cap exist to bound.
- A single-process realm with one Sim caps a world at one Node event loop. Scale-out is more realms, not zone handoff.
- Snapshots are JSON text rebuilt every pass (50 ms). Bandwidth is managed with interest radius and wire caches, not a binary or delta protocol.
- The monolith `game.ts` (9,811 LOC) mixes loop, dispatch and broadcast. Upstream itself treats it as debt (`server/CLAUDE.md:35`).
