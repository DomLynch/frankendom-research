# O0 donor manifest — Frankendom: Origins

Assembled 2026-10-06 by Lead Dev (Expansion) from the analysts' fragments below (one per donor, unedited).
Pins: `donors/PINS.md`. Frankendom baseline: `DomLynch/RPG-game` docs/specs/origins/frankendom-baseline.md.

**Ruling 8 columns (every system):** spec author (the analyst who read the source) · implementer (a different agent, given the
spec only) · implementer saw source = **no** · audit rounds (logged in `audits/README.md`). GPL donors (OpenMW, ModernUO, EQEmu)
are clean-room only: decisions are reimplement / reference / reject, never reuse. MIT donors (ClaudeCraft, inkjs) may be reused
with notices, but no ClaudeCraft media or content (its CREDITS.md excludes most media from MIT).

**Finished specs** (crossed into RPG-game `docs/specs/origins/`, first round, goldens hand-derived, not yet engine-captured):
openmw-{quest-journal, dialogue-conditions, factions-disposition, levelling-skills} · gothic-{routines, guilds-attitudes,
progression, dialogue, zenkit-reference} · modernuo-{bank, secure-trade, crafting, virtues, champion-spawns, quests,
skill-stat-gain} · eqemu-{loot, experience, faction, inventory}.

**Implementers:** none assigned yet (O1 schemas first, then the three O2 proofs: inventory transfer, quest journal, staged boss event).


---

## O0 manifest: World of ClaudeCraft

- Donor: World of ClaudeCraft (Levy Street), TypeScript, MIT for source code (`LICENSE`, "Copyright (c) 2026 Levy Street").
- Commit: `f46f30f5849989e44d7aa1bf62b3b14e435bc2fe`. The VPS copy at `/opt/frankendom-shadow/work/expansion-donors/world-of-claudecraft` has had its `.git` removed, so the pin rests on this record.
- Spec author: analyst-claudecraft, 2026-10-06. Read-only survey: grep, sed and a stdin-fed node import walker, with no install, build or VPS write.
- Licence posture: MIT source may be reused directly as long as the notice is kept. **Media is not MIT** (see "Licence and provenance" below). "Implementer saw source" is `n/a` throughout because MIT reuse is allowed.

## How the closure numbers were measured

A node walker resolved every relative `import` / `export … from` / `import()` transitively from each root. Comments were stripped before parsing so that prose containing the word "import" was not miscounted. Two modes:

- **runtime**: skips `import type` and `import { type … }`. This is what ends up in a bundle.
- **all**: includes type-only edges. This is what has to come along if the files are copied verbatim and type-checked.

Category key:
- `sim`: other `src/sim` logic.
- `world-catalogue`: `src/sim/data.ts`, `src/sim/content/*`, `*_layout.ts`, `world_*`, generated files.
- `UI`: `src/ui`.
- `render`: `src/render`.
- `client-game`: `src/game`.
- `net-client`: `src/net`.
- `server`: `server/`.
- `platform`: wallet, capacitor, electron and native code.

**Extraction gate:** a unit fails if its closure reaches UI, render, client-game, platform or the world catalogue.

**Structural finding (it drives almost every decision below):** `src/sim/types.ts` is a hub.
- At type level it reaches the **entire sim**: 1,018 files / 322,280 LOC, including 189 world-catalogue files.
- At runtime it reaches **248 files / 105,759 LOC**, including 90 world-catalogue files / 57,727 LOC. This comes from its runtime imports of `cloneLootQuality` and `cloneMaterialPayload`, which lead through the material taxonomy into content and colliders.
- `src/sim/data.ts` (the `ITEMS` table) costs 8 files / 9,942 LOC at runtime: `content/items.ts` 4,184, `content/zone2.ts` 2,410, `fenbridge_layout.ts` 1,076, and others.
- `src/sim/material_ids.ts` (`isMaterialItemId`) costs 257 files / 109,587 LOC at runtime: `colliders.ts`, building and battleground layouts, professions content.

So almost every `src/sim` module fails the gate as-is. Only a few dependency-free leaves pass. The sim itself is clean of DOM, Three, UI and net code (enforced upstream by `tests/architecture.test.ts`), so the gate fails on **world catalogue**, not on UI.

## Manifest

| system | donor | commit | source files | behaviour | dependencies (runtime closure files/LOC; notable drags) | licence | decision | destination | tests (donor) | spec author | implementer | implementer saw source | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Container move (O2 transfer proof unit)** | ClaudeCraft | f46f30f5 | `src/sim/bank.ts:282-416` (`moveBetweenContainers`, `MoveResult`, `MoveRefusal`, `NoFitCause`) | All-or-nothing move of one source slot into a destination container against a pooled slot budget. A fungible stack can be partly moved. An instanced slot moves as one unit. Refusals are typed `invalid` or `no_fit` (`space` / `instanced_units`). The two arrays are mutated only on success. | As-is, via bank.ts: **656 / 240,959** (131 world-catalogue files). As cut (see O2 section): **7 donor files, about 735 LOC of spans, 0 npm, 0 catalogue** | MIT | **adapt** (cut the seams named below) | economy | `tests/bank.test.ts:883-1356` (39 `moveBetweenContainers` refs), `:2411-2481` | analyst-claudecraft | TBD | n/a (MIT reuse allowed) | spec ready |
| Stack fit and grant | ClaudeCraft | f46f30f5 | `src/sim/bags.ts:90-105` (`stackSizeOf`), `:194-238` (`countFit`), `:359-401` (`addStacked`) | Counts how many copies fit (top-up of matching stacks plus free slots × stack size) and grants them deterministically, deep-cloning instance payloads. | bags.ts as-is: 271 / 114,168 (94 world-catalogue). Cut: part of the O2 unit | MIT | **adapt**: drop the material arm and inject a def lookup | economy | `tests/bags.test.ts` (78 cases, catalogue-fixtured) | analyst-claudecraft | TBD | n/a | spec ready |
| Two-pool capacity | ClaudeCraft | f46f30f5 | `src/sim/bag_pools.ts` (132) | General pool plus a materials-only pool, with a deterministic "materials first" packing rule. Over-capacity is tolerated and never repaired. Container-agnostic. | 9 / 10,075 (`ITEMS` only, so 7 catalogue files) | MIT | **reuse** after replacing `ITEMS[id]` with an injected `defOf(id)` | economy | `tests/bag_pools.test.ts` (28 cases, imports `data.ts` fixtures) | analyst-claudecraft | TBD | n/a | spec ready |
| Instance-payload merge rules | ClaudeCraft | f46f30f5 | `src/sim/item_instance_merge.ts` (102) | Byte-equal payload comparison, which payloads may be merged, and charge-bearing payloads kept one per slot. | **1 / 103** | MIT | **reuse** | economy | `tests/item_instance_merge.test.ts` (17) | analyst-claudecraft | TBD | n/a | spec ready |
| Per-copy transfer lock | ClaudeCraft | f46f30f5 | `src/sim/transfer_lock.ts` (22) | `isTransferLockedInstance`: a copy marked bind-on-trade or bound cannot ride anonymous pipes. | **1 / 23** | MIT | **reuse** | economy | `tests/transfer_lock.test.ts` (5) | analyst-claudecraft | TBD | n/a | spec ready |
| Player item-lock flag | ClaudeCraft | f46f30f5 | `src/sim/item_lock_flag.ts` (18) | Owner's own "do not sell/salvage" flag predicate. | **1 / 19** | MIT | reuse (optional) | economy | item_lock suites | analyst-claudecraft | TBD | n/a | candidate |
| Item instances (payload, clone, load sanitizer) | ClaudeCraft | f46f30f5 | `src/sim/types.ts:1619-1830` (`ItemInstancePayload`, `cloneItemInstancePayload`, `InvSlot`, `cloneInvSlot`); `item_instance_load.ts`; `item_instance_stats.ts` | Per-copy identity (signer, rolled stats, enchant, charges, binding), plus a total clone over malformed data. | types.ts: 248 / 105,759 at runtime and 1,018 / 322,280 at type level. `item_instance_load` reaches the content tree | MIT | **adapt**: copy only the type and clone spans, and trim fields to Frankendom's needs (no rift, partyTrade or perfecting) | economy | `tests/item_instance*.test.ts` | analyst-claudecraft | TBD | n/a | spec ready |
| Manual bag order | ClaudeCraft | f46f30f5 | `src/sim/inventory_order.ts` (108) | Dense array plus per-stack `slot` hint resolved into a fixed grid. Total over malformed hints. | **1 / 109** | MIT | reuse | client (inventory view model) | `tests/inventory_order.test.ts` (16) | analyst-claudecraft | TBD | n/a | candidate |
| Inventory grant / extract / sort / consumption | ClaudeCraft | f46f30f5 | `src/sim/inventory_grant.ts`, `inventory_extract.ts`, `inventory_sort.ts`, `inventory_consumption.ts` | Grant receipts, extraction for escrow, sort, and reagent consumption. | 272 / 114,223; 253 / 106,193; 265 / 112,138; **657 / 241,124** (catalogue via types/material/ITEMS) | MIT | reference | economy | own suites | analyst-claudecraft | TBD | n/a | reference only |
| Personal bank (commands, slot purchase, persistence sanitizer) | ClaudeCraft | f46f30f5 | `src/sim/bank.ts` (983) excluding the move span | Banker-proximity gate, purchased slot ladder, server-stamped bonus slots, and a tamper-tolerant `sanitizeBankState`. | 656 / 240,959 (deeds, storage SKUs, rift progression, SimContext) | MIT | **reference** (load-sanitizer pattern worth copying: tolerate, never destroy) | economy | `tests/bank.test.ts` (104) | analyst-claudecraft | TBD | n/a | reference only |
| Vault / materials vault / guild bank | ClaudeCraft | f46f30f5 | `src/sim/vault_slot_ops.ts`, `materials_vault.ts`, `guild_bank*.ts` | Shared containers with escrow-merge save. | 656 / 240,959 | MIT | reject for O2; reference later | economy | many | analyst-claudecraft | TBD | n/a | rejected (scope) |
| Material stacks and provenance | ClaudeCraft | f46f30f5 | `src/sim/material_*.ts` (~25 files) | Source-signed material units with provenance packing. | `material_ids` 257 / 109,587 (colliders, layouts, professions content) | MIT | **reject** | n/a | many | analyst-claudecraft | n/a | n/a | rejected |
| Seeded RNG | ClaudeCraft | f46f30f5 | `src/sim/rng.ts` (97) | Deterministic seeded PRNG with a draw observer for parity tests. | **1 / 98** | MIT | reuse if the economy needs a seeded roll; otherwise keep Frankendom's own | economy | `tests/rng_draw_compensation.test.ts` | analyst-claudecraft | TBD | n/a | candidate |
| Weighted loot group | ClaudeCraft | f46f30f5 | `src/sim/loot/weighted_loot_group.ts` (34) | Turns relative weights into one guaranteed partition, keeping reserved absolute-odds entries. | **1 / 35** | MIT | reuse | economy | `tests/weighted_loot_group.test.ts` | analyst-claudecraft | TBD | n/a | candidate |
| Loot FFA timeout / master loot | ClaudeCraft | f46f30f5 | `src/sim/loot/loot_ffa.ts` (65), `src/sim/loot_master.ts` (41) | Tap lock that opens to everyone after a delay; master-loot threshold decision. | **1 / 66**, **1 / 42** | MIT | reference (MMO party rules, little fit for a duel game) | economy | `tests/loot_ffa*.test.ts`, `tests/loot_master*.test.ts` | analyst-claudecraft | TBD | n/a | reference only |
| Loot roll (need/greed) / kill participation | ClaudeCraft | f46f30f5 | `src/sim/loot/loot_roll.ts` (1,161), `kill_participation.ts` (82) | Group roll windows; credit eligibility. | 656 / 240,959; 249 / 105,842 | MIT | reject (catalogue) | n/a | `tests/loot_roll*.test.ts` | analyst-claudecraft | n/a | n/a | rejected |
| Crafting | ClaudeCraft | f46f30f5 | `src/sim/professions/crafting.ts` (1,723), `craft_reagent_plan.ts` (74) | Recipes, reagent plans, masterwork procs. | 656 / 240,959 each | MIT | **reimplement** (design reference only) | economy | `tests/crafting*.test.ts` | analyst-claudecraft | TBD | n/a | reference only |
| Collections | ClaudeCraft | f46f30f5 | `src/sim/professions/collection_manual.ts` (21), `src/sim/combat/crafted_collection_effects.ts` (247) | Validates a multi-recipe manual before granting; crafted-collection bonuses. | **1 / 22**; 248 / 105,759 | MIT | reference (the manual leaf is a good "validate the whole group before consuming" shape) | economy | `tests/crafted_collection_effects.test.ts` | analyst-claudecraft | TBD | n/a | reference only |
| Quests (credit, commands) | ClaudeCraft | f46f30f5 | `src/sim/quests/quest_credit.ts` (210), `quest_commands.ts` (507) | Objective credit, accept/turn-in commands. | 656 / 240,959 each | MIT | **reimplement** (OpenMW/Gothic specs own quest design; see `docs/origins/specs/`) | story | `tests/quest_*.test.ts` | analyst-claudecraft | TBD | n/a | reference only |
| NPC role / mob AI | ClaudeCraft | f46f30f5 | `src/sim/npc_role.ts` (132), `src/sim/mob/{lifecycle,targeting,social_aggro,flee_rules}.ts`, `threat.ts` (148), `pathfind.ts` (349) | MMO aggro, threat table, social pull, flee, grid pathfinding. | 251 / 108,792; 659 / 241,410; 250 / 106,144; 249 / 105,849; 9 / 9,967; 248 / 105,759; 248 / 105,759 | MIT | reject (duel AI is already Frankendom's own; catalogue drag) | n/a | `tests/*aggro*`, `tests/threat*` | analyst-claudecraft | n/a | n/a | rejected |
| Mail / post office | ClaudeCraft | f46f30f5 | `src/sim/mail/post_office.ts` (1,633) | Parcel custody with attachments. | 661 / 243,180 | MIT | reject for now | economy | `tests/mail*` | analyst-claudecraft | n/a | n/a | rejected (scope) |
| Inbound WS flood gate | ClaudeCraft | f46f30f5 | `server/msg_rate_limit.ts` (155) | Checks every frame before parsing: a frame token bucket (120/s, burst 180), a byte bucket (64 KiB/s, burst 128 KiB), and a whole-second abuse window (5 abusive seconds in 10 kicks). It is pure and takes `nowSec` as an input. | **1 / 156** | MIT | **reuse** (retune the constants to Frankendom's input cadence) | net | `tests/msg_rate_limit.test.ts` | analyst-claudecraft | TBD | n/a | candidate |
| Per-class message lanes | ClaudeCraft | f46f30f5 | `server/msg_lanes.ts` (175) | After parsing, separate buckets for movement (90/120), commands (30/60), chat (4/8) and name screens (2/5). | **1 / 176** | MIT | **reuse** | net | `tests/msg_lanes.test.ts` | analyst-claudecraft | TBD | n/a | candidate |
| Outbound backpressure kill | ClaudeCraft | f46f30f5 | `server/ws_backpressure.ts` (24) | Terminates a session when `bufferedAmount` exceeds 8 MiB. | **1 / 25** | MIT | **reuse** | net | `tests/ws_backpressure.test.ts` | analyst-claudecraft | TBD | n/a | candidate |
| Pre-auth handshake buffer | ClaudeCraft | f46f30f5 | `server/ws_buffer.ts` (47) | Bounded buffering of frames that arrive during async auth. | **1 / 48** | MIT | reuse | net | `tests/ws_buffer.test.ts` | analyst-claudecraft | TBD | n/a | candidate |
| Link-dead resume / join planning | ClaudeCraft | f46f30f5 | `server/linkdead.ts` (83) | Pure `planJoin` (resume / reject / join) with a 5-minute grace. | **1 / 84** | MIT | **reuse** | net | `tests/linkdead.test.ts` | analyst-claudecraft | TBD | n/a | candidate |
| Keepalive sweep | ClaudeCraft | f46f30f5 | `server/keepalive_sweep.ts` (80) | 30 s ping sweep. If the sweep itself was delayed by an event-loop stall, it re-arms sessions instead of mass-kicking. A hard 10-minute silence deadline reaps black-holed sockets. | **1 / 81** | MIT | **reuse** | net | `tests/server/keepalive_sweep.test.ts` | analyst-claudecraft | TBD | n/a | candidate |
| Input seq fold | ClaudeCraft | f46f30f5 | `server/input_seq.ts` (48) | Folds client input `seq` into an ack high-water mark plus gap accounting. | 2 / 205 (server-only) | MIT | adapt | net | `tests/input_seq_fold.test.ts` | analyst-claudecraft | TBD | n/a | candidate |
| HTTP rate limiter | ClaudeCraft | f46f30f5 | `server/ratelimit.ts` (1,199) | Per-IP sliding minute window with a bounded IP table, trusted-proxy XFF resolution, and an optional Postgres tier-2 store. | 2 / 1,261 (`node:net`) | MIT | adapt (trim to tier 1 plus proxy-IP logic) | net | `tests/ratelimit*.test.ts` | analyst-claudecraft | TBD | n/a | candidate |
| WS auth handshake | ClaudeCraft | f46f30f5 | `server/ws_auth.ts` (746) | Strict first-frame auth type, a 10 s auth timeout, a per-IP hard cap, a realm admission cap with an in-flight counter, a character lease, and an error frame before every close. | **668 / 245,857** (imports the sim via game types) | MIT | **reference** (copy the pattern, not the file) | net | `tests/ws_auth*.test.ts` | analyst-claudecraft | TBD | n/a | reference only |
| Password hashing / tokens | ClaudeCraft | f46f30f5 | `server/auth.ts` (441) | scrypt N=16384 r=8 p=1, `timingSafeEqual`, 32-byte random tokens; `obscenity` name filter. | 1 / 442 (`node:crypto`, `obscenity`) | MIT | reference. **Do not adopt token storage**: `auth_tokens.token` is a plaintext primary key (`server/db.ts:407-412`) | net | `tests/auth_utils.test.ts` | analyst-claudecraft | TBD | n/a | reference only |
| Auth-guard verdict core | ClaudeCraft | f46f30f5 | `server/auth_guard_core.ts` (178) | Pure token scope/expiry verdict plus a moderation ladder over raw rows. | **1 / 179** | MIT | adapt | net | `tests/server/auth_guard*.test.ts` | analyst-claudecraft | TBD | n/a | candidate |
| Save FIFO / periodic flush | ClaudeCraft | f46f30f5 | `server/serial_writer.ts` (315), `server/periodic_save_flush.ts` (138) | Per-resource FIFO so an older snapshot can never commit after a newer one; a fire-and-forget 30 s autosave with each write listed exactly once. | **1 / 316**, **1 / 139** | MIT | **reuse** | net | `tests/serial_writer.test.ts`, `tests/server/periodic_save_flush.test.ts` | analyst-claudecraft | TBD | n/a | candidate |
| Rollback-proof classifier | ClaudeCraft | f46f30f5 | `server/pg_rollback_proof.ts` (40) | Classifies a thrown pg error by whether the transaction provably rolled back. Compensate only when it did. | **1 / 41** | MIT | reuse | net | own suite | analyst-claudecraft | TBD | n/a | candidate |
| Ledger outbox | ClaudeCraft | f46f30f5 | `server/bank_ledger_outbox.ts` (981) | Reserve capacity before mutating, then commit immutable rows. The save acknowledges a prefix in the same transaction as state. | 273 / 115,769 (sim guild-bank and material types) | MIT | **reference** (pattern for the O-economy ledger) | economy / net | `tests/server/bank_ledger_outbox.test.ts` | analyst-claudecraft | TBD | n/a | reference only |
| Character save transaction | ClaudeCraft | f46f30f5 | `server/character_save_transaction.ts` (64) | Statement and transaction timeouts (60 s / 65 s) around a fenced save. | 284 / 120,204 | MIT | reference | net | `tests/character_save*.test.ts` | analyst-claudecraft | TBD | n/a | reference only |
| Cached read | ClaudeCraft | f46f30f5 | `server/cached_read.ts` (317) | Single-flight TTL cache with stale-on-error and a bust that refuses joiners. | **1 / 318** | MIT | reuse (leaderboards) | net | `tests/server/cached_read*.test.ts` | analyst-claudecraft | TBD | n/a | candidate |
| Bounded body / guarded iteration | ClaudeCraft | f46f30f5 | `server/bounded_body.ts` (33), `server/guarded_iter.ts` (34) | HTTP body size cap; per-item error isolation in loops. | **1 / 34**, **1 / 35** | MIT | reuse | net | own suites | analyst-claudecraft | TBD | n/a | candidate |
| Non-finite pose guard | ClaudeCraft | f46f30f5 | `src/sim/finite_pose_guard.ts` (141) | Keeps the last finite pose so a NaN cannot freeze interest scope or the camera. | **1 / 142** | MIT | **reuse** (input validation) | net / client | `tests/finite_pose_guard.test.ts` | analyst-claudecraft | TBD | n/a | candidate |
| Client challenge hash | ClaudeCraft | f46f30f5 | `src/sim/client_challenge.ts` (34), `fingerprint128.ts` (72) | cyrb53 challenge/answer. Not cryptographic. | **1 / 35**, **1 / 73** | MIT | reject as anti-cheat (obfuscation only); fingerprint128 is reference | n/a | own suites | analyst-claudecraft | n/a | n/a | rejected |
| Reconnect policy / backoff (client) | ClaudeCraft | f46f30f5 | `src/net/reconnect_policy.ts` (74), `src/net/backoff.ts` (19) | Bounded transient-rejection retries ("character already in world" ×8, auth timeout ×20); jittered backoff. | **1 / 75**, **1 / 20** | MIT | **reuse** | client | `tests/reconnect_policy*.test.ts` | analyst-claudecraft | TBD | n/a | candidate |
| Client send backpressure / input cadence / interp | ClaudeCraft | f46f30f5 | `src/net/send_backpressure.ts` (40), `input_send_cadence.ts` (39), `interp_math.ts` (21) | Client-side send throttle on `bufferedAmount`; input-send gating; snapshot interpolation math. | **1 / 41**, **1 / 40**, **1 / 22** | MIT | reuse | client | own suites | analyst-claudecraft | TBD | n/a | candidate |
| Mobile graphics: dynamic resolution | ClaudeCraft | f46f30f5 | `src/render/dynamic_resolution_core.ts` (114), `src/render/dpr_watch.ts` (63) | Render-scale controller with a floor of 0.68; DPR change watcher. | **1 / 115**, **1 / 64** | MIT | reuse | client | own suites | analyst-claudecraft | TBD | n/a | candidate |
| Mobile graphics: budgets and cadence | ClaudeCraft | f46f30f5 | `src/render/post_pixel_budget_core.ts` (126), `shadow_cadence_core.ts` (129), `point_light_budget.ts` (162), `perceptual_lod_core.ts` (242), `crowd_lod.ts` (312), `foliage_lod.ts` (310), `foliage_impostor_core.ts` (407), `adaptive_link_budget_core.ts` (379) | Pure policy cores for post-processing pixel budget, shadow-map update cadence, light count caps, crowd-adaptive animation/shadow LOD, and impostor selection. | each **1 file** (`point_light_budget`, `perceptual_lod_core` 2 files), 0 three.js | MIT | reuse the `*_core` policies; the three.js shells are reference only | client | own suites | analyst-claudecraft | TBD | n/a | candidate |
| Mobile graphics: device tier and frame cadence | ClaudeCraft | f46f30f5 | `src/device_memory_hint.ts` (136), `src/game/ui_tier_knobs.ts` (257), `frame_cadence_core.ts` (144), `perf_frame_health_core.ts` (56), `startup_graphics_safety.ts` (21) | iOS memory-hint cache (no `navigator.deviceMemory` in WKWebView), frame cadence and health, safe first-boot tier. | **1 file each** | MIT | adapt (the memory hint assumes a Capacitor native shell) | client | own suites | analyst-claudecraft | TBD | n/a | candidate |
| Mobile graphics: GFX profile / render budget shells | ClaudeCraft | f46f30f5 | `src/render/gfx.ts` (2,426), `render_budget.ts` (1,064), `instanced_dither_fade.ts`, `preview_pixel_ratio.ts`, `character_cull_core.ts`, `blob_shadow_core.ts`, `mobile_stations*.ts` | Module-load graphics profile and the renderer's budget wiring. | 280-712 files (three, sim types, catalogue, runtime, client_origin) | MIT | reference only | client | n/a | analyst-claudecraft | n/a | n/a | fails gate |

## O2 inventory-transfer proof: the smallest extractable unit

**Unit:** `moveBetweenContainers` plus the fungible and instanced fit/grant path it calls, with the material arm cut out and the item catalogue injected.

| # | Donor span | LOC | Role |
|---|---|---|---|
| 1 | `src/sim/bank.ts:282-416` | 135 | `MoveRefusal`, `NoFitCause`, `MoveResult`, `moveBetweenContainers`. Delete the material branch (the `isMaterialItemId` → `moveMaterialBetweenContainers` arm). |
| 2 | `src/sim/bags.ts:90-105`, `:194-238`, `:359-401` | 104 | `DEFAULT_STACK`, `UNSTACKED_KINDS`, `stackSizeOf`, `countFit`, `addStacked`. Delete the `isMaterialOperation` arms and swap `ITEMS[itemId]` for an injected `defOf`. |
| 3 | `src/sim/bag_pools.ts` (whole) | 132 | `PoolCapacity`, `poolCapacityOf`, `poolOccupancyOf`, `freePoolSlots`, `totalPoolCapacity`, `generalOnlyPools`. Swap the `ITEMS` import for `defOf`. The material predicate is already injected. |
| 4 | `src/sim/item_instance_merge.ts` (whole) | 102 | `canStackInstancePayloads`, `isMergeableInstancePayload`, `isChargeBearingPayload`, `itemInstancePayloadsEqual` |
| 5 | `src/sim/transfer_lock.ts` (whole) | 22 | `isTransferLockedInstance`, the gate a transfer pipe checks first |
| 6 | `src/sim/types.ts:1619-1830` (spans) | ~206 | `ItemInstancePayload`, `cloneItemInstancePayload`, `InvSlot`, `cloneInvSlot`. Trim the rift, partyTrade, perfecting and materialSources fields. |
| 7 | `src/sim/loot_quality/types.ts` | 34 | `cloneLootQuality`. Drop it if the payload loses `lootQuality`. |
| | **Total** | **~735 LOC across 7 donor files** | 0 npm packages, 0 UI/render/net/server/platform/crypto, 0 world catalogue |

**Closure if extracted as-is instead (fails the gate):** `bank.ts` runtime closure is 656 files / 240,959 LOC (521 sim, 131 world-catalogue); its type-level closure is 1,018 files / 322,280 LOC. Rerooting at `bags.ts` alone is still 271 / 114,168.

**The three seams to cut, and what each costs if kept:**
1. `ITEMS` from `src/sim/data.ts`: 8 files / 9,942 LOC of catalogue (items, zone2, fenbridge layout). Replace with `defOf(id): { kind; stackSize?; bagSlots?; materialsOnly? } | undefined`.
2. `isMaterialItemId` from `src/sim/material_ids.ts`: 257 files / 109,587 LOC (colliders, layouts, professions content). Replace with an injected `isMaterial(id) => false` for O2.
3. The `types.ts` runtime import hub: 248 files / 105,759 LOC. Copy only the four declarations listed above.

**Behaviours the proof should pin (all present in the donor tests):**
- All-or-nothing; source and destination are untouched on refusal.
- Partial fungible moves decrement the source, and whole-stack moves splice it out.
- An instanced slot moves as one unit and is deep-cloned, never aliased.
- `craftedRecipeId` is threaded through both fit and grant, so a round trip cannot launder provenance.
- `no_fit` is `space` unless the payload is non-mergeable and a free slot exists, in which case it is `instanced_units`.
- Over-capacity is tolerated, never repaired.
- Conservation: a seed sweep finds no item created or lost.

**Test port:** start from `tests/bank.test.ts:883-1356` (the `moveBetweenContainers` describe block), `:1357-1453` (conservation seed sweeps), `:2411-2481` (crafted-marker round), `tests/bag_pools.test.ts` (28 cases) and `tests/item_instance_merge.test.ts` (17). Every one of these imports `src/sim/data.ts` fixtures, so they must be re-fixtured against a 3-5 item synthetic catalogue.

**Notice:** keep the MIT notice ("Copyright (c) 2026 Levy Street" plus the permission text from `LICENSE`) in a header on each copied file, or in a `THIRD_PARTY_NOTICES` entry the files point to.

## Licence and provenance

- **Source code:** MIT, `LICENSE` (21 lines), "Copyright (c) 2026 Levy Street". `CREDITS.md:15-16` says "everything not carved out here is MIT" for code. No code carve-outs were found: there are no `@license` or `SPDX` headers in `src/` or `server/`, and `private/` (the bot detector) is empty in this copy, with `server/bot_detector/stub.ts` standing in for it.
- **Media:** `CREDITS.md` (515 lines) is "the operative licence record" and states that the MIT licence does **not** cover art, audio, fonts or other media. Assets missing from the register are "unrecorded rather than free". **Not covered by MIT:**
  - CraftPix class ability icons under `public/ui/skills/<class>/*.webp`: a licence purchased by Levy Street, non-transferable (`CREDITS.md:37-46`).
  - Project-owned commercial and prestige art, rights reserved (`:47-58`): class rework icons, Season 1 Armory weapons and renders, the Claudium set, Book of Deeds icons, the Professions 2.0 set, item-art replacements, map markers, the dragon emblem.
  - Art used with permission (`:59-64`): the Collective Reversal and Hourglass of Suspension icons, the `fireball_form` and `counterspell` artwork, and the `temporal_clock` SFX.
  - @jamiecypher SFX: CC BY-NC 4.0, so non-commercial use only (`:66-70`).
  - Assets marked "With the project only": generated props, creatures, backdrops and UI sounds (`:81-85`, `## Generated prop and creature models` at `:286`). These may not be extracted.
  - Brand marks (Twitch, X, Kick, YouTube, Discord, Steam, Solana, USDC) (`:226`).
  - CC0 packs (KayKit, Quaternius, Kenney, ambientCG, Poly Haven) are free, but should be pulled from their original sources rather than from this repo.
- **Third-party runtime notices:** `THIRD_PARTY_NOTICES.md` (251 lines). It covers the Reown AppKit Community License (non-OSI, `third_party/licenses/reown-community-license.md`), the WalletConnect community licence, @noble, @solana/web3.js, bs58, TweetNaCl and buffer. None of these sit in any recommended unit's closure.
- **Content IP:** `ip-refactor/` records a locked rename map (`ip-refactor/NAME-MAP.md`) that moved names and content off a classic-MMO parody. This is a further reason not to copy any `src/sim/content/*` catalogue. Names and data are rejected regardless of the licence.
- **Media decision:** reuse **no** ClaudeCraft media.

## Rejected list

| Item | Reason |
|---|---|
| `src/sim/content/*`, `src/sim/data.ts` (catalogue) | Fails the gate by definition. It is world catalogue with IP-pivot history (`ip-refactor/`), and Frankendom owns its own content. |
| Material stacks and provenance (`src/sim/material_*.ts`) | `material_ids` closure is 257 / 109,587 and reaches colliders and layouts; the design is out of scope. |
| Vault, guild bank, mail, market, $WOC exchange (`server/woc_market*`) | Scope, plus crypto and wallet platform code (Solana, Reown, tweetnacl). |
| Loot roll, kill participation, MMO aggro / threat / pathfind / NPC role | Catalogue drag (248-659 files); MMO group mechanics do not fit a duel game. |
| Crafting and quest command modules (as code) | Each is 656 / 240,959 at runtime. Reimplement from specs; quest design is owned by the OpenMW/Gothic specs. |
| `ws_auth.ts`, `game.ts`, `main.ts` (as code) | Monolith (game.ts 9,811 LOC, main.ts 4,363) and sim-coupled (ws_auth 668 / 245,857). Use as a pattern reference only. |
| `client_challenge.ts` as anti-cheat | Non-cryptographic cyrb53 hash; obfuscation, not authority. |
| Token storage scheme | `auth_tokens.token` is stored in plaintext as the PK (`server/db.ts:407-412`). Frankendom should hash bearer tokens at rest. |
| `src/render/gfx.ts`, `render_budget.ts`, three.js shells | 280+ file closures pulling in the sim and catalogue via `runtime.ts`; only the pure `*_core` policies pass. |
| All media under `public/` | Not MIT (see above). |
| Wallet, Capacitor, Electron, Steam, Epic and Discord code | Platform code; fails the gate. |

---

## O0 manifest: inkjs

- Donor: inkjs 2.4.0 (inkle's ink runtime and compiler in TypeScript). MIT: `LICENSE.md`, "Copyright (c) 2017 inkle Ltd." and "Copyright (c) 2017 inkjs contributors (see AUTHORS)".
- Commit: `6b1153410ab1c4bcfd9ef04eb2f0107f36be7778`, at `/opt/frankendom-shadow/work/expansion-donors/inkjs`.
- Spec author: analyst-claudecraft, 2026-10-06. Read-only survey with no install or build. `dist/` is absent, so bundle bytes are **not measured** and should be measured at O2 from the published npm `inkjs/dist/ink.min.js`.

## Size

- **Engine (runtime):** `src/engine/`, 40 files, 9,615 LOC TS, 291,913 bytes of source including comments. The import closure of `src/engine/Story.ts` is **39 files / 9,648 LOC**, with **0 npm dependencies** (`package.json` has an empty `dependencies`) and no reach into the compiler.
- **Compiler:** `src/compiler/`, 10,881 LOC. It is only needed to compile `.ink` to JSON at build time, so it should not ship.
- **Package exports:** `inkjs` gives the engine only (`dist/ink.mjs` / `dist/ink.js`). `inkjs/full` adds the compiler (`rollup.config.js:26-102`). Use the engine-only entry.
- **Ink version gates:** `Story.inkVersionCurrent = 21`, minimum compatible 18 (`src/engine/Story.ts:53-55`). Save format `kInkSaveStateVersion = 10`, minimum loadable 8 (`src/engine/StoryState.ts:31-32`).

## API surface (src/engine/Story.ts unless noted)

| Need | API |
|---|---|
| Load a story | `new Story(json)` (`:147-150`), from compiled JSON |
| Advance text | `Continue()` `:336`, `ContinueMaximally()` `:607`, `canContinue` `:341`, `currentTags` `:78`, `globalTags` `:2171`, `TagsForContentAtPath` `:2175` |
| Choices | `currentChoices` `:57`, `ChooseChoiceIndex(i)` `:1726`, `ChoosePathString(path, …)` `:1677` |
| Variables | `variablesState` `:111` (get and set by name), `ObserveVariable` `:2070`, `ObserveVariables` `:2092`, `RemoveVariableObserver` `:2101` |
| External functions | `BindExternalFunction(name, fn, lookaheadSafe=false)` `:1958`, `BindExternalFunctionGeneral` `:1934`, `UnbindExternalFunction` `:1983`, `allowExternalFunctionFallbacks` `:1837`, `EvaluateFunction` `:1757` |
| Save state | `story.state.ToJson()` / `story.state.LoadJson(json)` (`StoryState.ts:37`, `:46`), `ResetState()` `:276`, `SwitchFlow(name)` `:316` (parallel flows) |
| Hooks | `onError` `:123`, `onDidContinue` `:125`, `onChoosePathString` `:136` |

**Determinism note:** the story seed defaults to wall-clock time (`StoryState.ts:443-444`, `new Date().getTime()` → PRNG). Ink `RANDOM` and shuffles are only reproducible if `SEED_RANDOM()` is called or `state.storySeed` is set after creating the story. `StopWatch.ts` also reads `Date`. Neither uses `eval` or `new Function`, so the engine is CSP-safe.

**Authority note:** external functions run synchronously inside `Continue` with arbitrary JS (`func.apply`, `:1978`). With `lookaheadSafe=false`, ink may call them during lookahead. The rule for Frankendom: bound functions may **read** economy and quest state and may **emit intents**, but must never mutate authoritative state. The server stays the economy authority, and ink variables are a presentation copy only.

## Manifest

| system | donor | commit | source files | behaviour | dependencies (closure size: files/LOC + notable drags) | licence | decision | destination | tests | spec author | implementer | implementer saw source | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Ink runtime (dialogue) | inkjs | 6b115341 | `src/engine/*` (as the npm package `inkjs` engine entry) | Runs compiled ink: text, choices, tags, variables, observers, external functions, JSON save/load, flows | 39 files / 9,648 LOC; 0 npm; no UI, platform or crypto | MIT (keep the `LICENSE.md` notice) | **reuse as a pinned npm dependency** (engine entry only), dialogue and presentation only | story / client | upstream `src/tests` (39 files, 311 `it(` cases); Frankendom adds a save round-trip, seeded-RANDOM determinism, and a test that external functions are read-only | analyst-claudecraft | TBD | n/a (MIT reuse allowed) | spec ready |
| Ink compiler | inkjs | 6b115341 | `src/compiler/*` | `.ink` → JSON | 10,881 LOC | MIT | **build-time only** (or inklecate); never shipped to the client | story (tooling) | upstream | analyst-claudecraft | TBD | n/a | candidate |

## Rejected

| Item | Reason |
|---|---|
| Ink as economy or quest authority (ink variables holding gold, items or flags that the server trusts) | The client runs it, the seed comes from the wall clock, and external functions can be called on lookahead. Authority stays server-side (see `claudecraft-server.md`). |
| `inkjs/full` in the client bundle | It ships the compiler (about 10.9k LOC) for no runtime benefit. |

---

## Origins donor manifest fragment: ModernUO

Donor ModernUO, GPLv3, commit `261ea01ab4b7c49a043dfabc7f44703b648883f8` (read-only on the VPS at `/opt/frankendom-shadow/work/expansion-donors/ModernUO`). Clean-room only: specs in `docs/origins/specs/modernuo-*.md`; implementers work from the spec and never see the source. Source paths below are relative to `Projects/`.

| system | donor | commit | source files | behaviour (one line) | dependencies (engine pieces it leans on) | licence | decision | destination | tests (parity golden cases planned) | spec author | implementer | implementer saw source | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Skill gain and stat gain | ModernUO | 261ea01a | UOContent/Skills/SkillCheck.cs; UOContent/Skills/AntiMacroSystem.cs; Server/Skills.cs; Distribution/Data/skills.json | Use-based skill gain: chance from task difficulty, distance to skill and total caps, success bonus; 700.0 total cap enforced by Down-locked skill atrophy; stats rise from skill use with per-stat cooldown, caps and atrophy | Mobile skill table and locks, stat locks, region gain veto, shared RNG, loop clock | GPL-3.0 | reimplement | progression | G1–G19 in spec (chance short-circuits, gain-chance values, floor/pet, low-skill burst, atrophy order, soft total-cap overshoot, Pub45 stat pick, stat atrophy tie-break, cooldown) | analyst-modernuo | TBD | no | spec written |
| Crafting | ModernUO | 261ea01a | UOContent/Engines/Craft/Core/CraftSystem.cs; Core/CraftItem.cs; Core/CraftRes.cs; Core/CraftSubRes*.cs; DefBlacksmithy.cs (+ other Def*.cs for constants) | Recipes with resources and skill ranges; linear success chance from chanceAtMin; three exceptional-chance variants; independent quality and success rolls; full or half resource loss on failure by era; tool wear; 1.25 s craft | Skill check (above), backpack resource search with hue grouping, tools/stations, timers, item factory | GPL-3.0 | reimplement | economy | C1–C14 in spec (chance and exceptional values per ECA, era-dependent failure loss, useAllRes, material skill gate, timing, roll independence) | analyst-modernuo | TBD | no | spec written |
| Bank | ModernUO | 261ea01a | Server/Items/Containers.cs (BankBox); Server/Items/Container.cs; UOContent/Mobiles/Townfolk/Banker.cs; UOContent/Items/Misc/Gold.cs; UOContent/Items/Misc/BankCheck.cs; UOContent/Accounting/Account.cs; Server/IAccount.cs | Private item-limited (125) unlimited-weight storage; gold piles ≤ 60k and checks 5k–1M; all-or-nothing and partial deposits with capacity pre-check; withdraw piles before checks; optional account-gold ledger | Container capacity rules, item totals, banker NPC speech, account object | GPL-3.0 | reimplement | economy | B1–B18 in spec (deposit splitting, top-ups, capacity refusal, partial deposit, withdraw order, command limits, check cash-out, ledger no-carry) | analyst-modernuo | TBD | no | spec written |
| Secure trade | ModernUO | 261ea01a | Server/SecureTrade.cs; Server/Items/SecureTradeContainer.cs; Server/Items/VirtualCheck.cs; Server/Network/NetState/NetState.cs (trade list, validation); Server/Mobiles/Mobile.cs (OpenTrade, OnDragDrop); UOContent/Mobiles/PlayerMobile.cs (CheckTrade); UOContent/Network/Packets/IncomingMobilePackets.cs | Two-sided offer windows; any offer change clears both accepts; on double accept: per-item veto and currency affordability, then simultaneous swap; cancel on distance > 2, map change, death, disconnect | Backpack capacity rule, per-connection trade list, movement/death hooks, account ledger | GPL-3.0 | reimplement | economy | T1–T12 in spec (accept/reset sequences, veto keeps window open, capacity refusals, cancel triggers, currency transfer order) | analyst-modernuo | TBD | no | spec written |
| Virtues | ModernUO | 261ea01a | UOContent/Engines/Virtues/VirtueSystem.cs; VirtueContext.cs; Valor.cs; Sacrifice.cs; Compassion.cs; Justice.cs; Honor.cs; HonorContext.cs; gain call sites in PlayerMobile.cs, BaseChampion.cs, ChampionSpawn.cs, BaseEscortable.cs | Eight independent capped tracks (20k–22k) with tier thresholds 4k/10k/20k; deed-based gains (formula for justice and honor); weekly decay on four tracks; abilities that spend points | Kill/damage events, fame, timers, champion spawn, escort NPCs | GPL-3.0 | reimplement (mechanics only; rename tracks) | story | V1–V17 in spec (tiers, clamp and path flag, decay, justice and honor formulas, embrace cost, compassion window, valor spend) | analyst-modernuo | TBD | no | spec written |
| Champion spawns | ModernUO | 261ea01a | UOContent/Engines/CannedEvil/ChampionSpawn.cs; ChampionSpawnInfo.cs; CannedEvilTimer.cs; LLChampionSpawn.cs; DungeonChampionSpawn.cs; UOContent/Mobiles/Special/BaseChampion.cs; UOContent/Mobiles/BaseCreature.cs (GetLootingRights) | Escalating wave encounter: kills per level 256/128/64/32/16, roster tier every 4 levels, population 250→130, 16–18 levels then a boss; 30-min decay; looting-rights and damage-weighted rewards | Region enter/exit, mobile spawning and leashing, 1 s timer, map rules, rewards (scrolls, artifacts) | GPL-3.0 | reimplement | world | S1–S18 in spec (level-up thresholds, sub-level off-by-one, run length 1,924–1,956 kills, decay outcomes, valor per kill, looting rights, scroll levels, artifact weighting incl. infinite-loop case) | analyst-modernuo | TBD | no | spec written |
| ML quests (data-driven) | ModernUO | 261ea01a | UOContent/Engines/ML Quests/MLQuest.cs; MLQuestEntry.cs; MLQuestContext.cs; MLQuestSystem.cs; Objectives/*.cs | Up to 10 concurrent quests; kill/collect/deliver/escort/gain-skill objectives, All/Any; timed failure; hand-in then all-or-nothing rewards; one-time, restart delay (default 30–150 s) and chains | Kill events, inventory marking, NPC interaction, timers | GPL-3.0 | reimplement | story | Q1–Q11, Q15 in spec (kill routing across quests, Any claim, restart timing, chain blocking, full-pack reward rollback, timed fail, collect consumption) | analyst-modernuo | TBD | no | spec written |
| Classic quest system | ModernUO | 261ea01a | UOContent/Engines/Quests/Core/QuestSystem.cs; QuestObjective.cs; QuestRestartInfo.cs | Single scripted quest slot; objective progress/max; restart record rules (finite delay only on completion; never-repeat also on cancel) | Hand-written quest subclasses, gumps | GPL-3.0 | reference | story | Q12–Q14 in spec (restart record semantics) | analyst-modernuo | TBD | no | spec written (reference only) |

## Rejected / not worth taking

- **Anti-macro system as shipped** (UOContent/Skills/AntiMacroSystem.cs): disabled by default, keyed on map cells; Frankendom should key repetition on opponent id inside the progression design instead. Reference only (described in the skill spec).
- **Pre-AOS stat-to-skill influence** (Server/Skills.cs NonRacialValue stat offset): dead in AOS+ eras and the shipped data appears double-scaled; design fresh if wanted.
- **Account-gold / platinum ledger** (Account.cs, AccountGold): no carry from gold to platinum, 32-bit overflow risk, platinum ignored on withdraw; Frankendom should use a single 64-bit currency integer. The physical gold/check model is also only worth taking if Frankendom has physical inventory.
- **Champion roster/boss tables, power scrolls, scrolls of transcendence, statuettes, artifact lists** (ChampionSpawnInfo.cs, BaseChampion lists): UO content and UO-specific reward items; replace with Frankendom opponents and rewards.
- **Faction and Felucca/Trammel map rules, young-player protection, Justice protector link**: tied to UO's PvP ruleset and maps.
- **Quest content definitions** (Engines/ML Quests/Definitions/*, Engines/Quests/* scripted quests, ~18k lines): UO story content; not to be copied in any form.
- **Talisman craft bonuses, faction imbuing, maker's mark gumps, T2A craft menus**: UO-specific item systems and UI.
- **All gumps, packets, NetState plumbing, serialization/migration code**: engine plumbing, replaced by Frankendom's own UI and persistence.

## Surprises worth a design decision

1. Crafting failure in every modern era consumes the **full** resource amount (half only before UOTD), despite the "some materials lost" message.
2. Crafting quality (exceptional) and success are two independent rolls taken at different times; over-skilled crafts raise exceptional odds but teach nothing.
3. Skill total cap is soft: a gain is applied whenever `total < cap`, so totals can overshoot by up to the gain size (4 tenths, more with acceleration).
4. Champion spawn kill-count tiers change at level 4/8/12 but rosters change one level later (≤ vs ≥ boundary).
5. Champion artifact award loops forever if the only eligible player dealt exactly 1 damage.
6. New virtue gains on decaying tracks are hit by the first decay within 5 minutes (last-loss timestamp starts at the epoch).
7. The Valor ability on a spawn whose champion is already up prints a refusal but still spends and advances.

---

## Donor manifest fragment: EQEmu

Donor EQEmu, licence GPLv3, pinned commit `4aceae18b94ffaafc08e2b17bc41cd72c77f795d` (VPS: `/opt/frankendom-shadow/work/expansion-donors/EQEmu`, read-only). Clean-room process: specs in `docs/origins/specs/eqemu-*.md` hold behaviour, formulas and constants only. No donor source was copied.

| system | donor | commit | source files | behaviour (one line) | dependencies | licence | decision | destination | tests (planned goldens) | spec author | implementer | implementer saw source | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| loot tables | EQEmu | 4aceae18 | zone/loot.cpp, zone/zone_loot.cpp, zone/global_loot_manager.{h,cpp}, common/loot.h, zone/attack.cpp (death/corpse), common/ruletypes.h, common/random.h | At spawn: coin roll, loottable entries gated by probability × multiplier, lootdrops picked independently (no limit) or weighted with droplimit/mindrop; global loot by level/race/class/body/rare/raid filters; at death items the killer is over/under-level for are removed | NPC level and flags, item catalogue, RNG with injectable draw list; feeds inventory | GPLv3 | clean-room reimplement | economy | G-L1 … G-L14 (coin split, avg-coin branch, probability gate, Mode A, Mode B distribution 0.28125/0.359375/0.1797/0.1797, mindrop, bypass, bonus copies, NPC level gate, trivial filter, global filters, equip upgrade); statistical check via donor sidecar `/api/v1/loot-simulate` | analyst-eqemu | TBD | no | spec ready |
| experience and levelling | EQEmu | 4aceae18 | zone/exp.cpp, zone/attack.cpp (NPC::Death, Client::Death), zone/mob_ai.cpp (GetLevelCon), zone/hate_list.cpp, zone/groups.cpp, zone/raids.cpp, common/features.h, common/ruletypes.h | Kill XP = level²·262.5 × npc mod × 0.5 × con colour (gray 0 … red 1.5); group bonus/split with level-gap and per-member cap; raid ×0.8 split; cubic level table with band multipliers in float32; death loss L·(L/18)·12000 with de-level | consider colour, group/raid membership, damage-top attribution; no RNG | GPLv3 | clean-room reimplement | progression | G-X1 … G-X19 (base XP, solo by colour, gray zero, hot zone, duo/full group, level gap, low-member cap, raid, XP table values, multi-level, death loss and de-level, res return, per-kill cap) | analyst-eqemu | TBD | no | spec ready |
| faction | EQEmu | 4aceae18 | common/faction.{h,cpp}, zone/client.cpp (faction functions), zone/zone_npc_factions.cpp, zone/zonedb.cpp (faction data), zone/hate_list.cpp, zone/npc.cpp, zone/mob.cpp, zone/aggro.cpp, common/features.h, common/ruletypes.h | Personal standing ±2000 (bounded per faction) + base + race/class/deity mods → nine attitudes at 1100/750/500/100/0/−100/−500/−750; kill applies a hit list (or direct hit + association spread) to every player on the hate list; Scowls aggro, Threatening 32 % aggro roll | XP-recipient attribution, hate list, consider colour (level gate), RNG (HeroicCHA, aggro roll) | GPLv3 | clean-room reimplement | story | G-F1 … G-F14 (thresholds, totals, bounds, clamp, repair, HeroicCHA, associations with min-1 and +1 on zero mod, hate-list recipients, merchant floor, engaged override, aggro gates, NPC vs NPC, temp factions) | analyst-eqemu | TBD | no | spec ready |
| inventory / item instance model | EQEmu | 4aceae18 | common/item_data.h, common/item_instance.{h,cpp}, common/inventory_profile.{h,cpp}, common/emu_constants.h, common/patches/rof2_limits.h, zone/inventory.cpp | Static item definition vs owned instance (charges, attuned, serial, contents); worn/general/cursor/bank slots with 200-slot bag ranges; stacking to StackSize, lore uniqueness, no-drop recursion, charge consumption | item catalogue; loot | GPLv3 | reference | economy | concept checks G-I1 … G-I5 only; no server goldens planned | analyst-eqemu | TBD | no | reference spec |

## Rejected (not carried into Frankendom)

- EverQuest client slot numbering, packets and patch translation layers: tied to a proprietary client; no value for a browser game.
- Legacy consider system (UseOldConSystem table) and legacy race/class XP penalties: off by default and era-specific; one modern con rule is enough.
- AA (alternate advancement) XP split, normalized AA and modern AA scaling: a second post-cap currency conflicts with the one-career proposal; revisit only if Frankendom adds a post-cap track.
- Group/raid leadership XP: needs a squad-leader system Frankendom does not have.
- Hot zones, per-level and per-character zone XP mod tables, quest-script overrides (Lua/Perl hooks): server-operator tuning knobs, not game rules.
- Faction HeroicCHA random doubling and race-equality helpers: stat Frankendom does not have; helpers unused on the core path.
- Content/expansion filtering on loot rows: operator era gating; replace with Frankendom's own content flags if needed.
- Bazaar, trader, shared bank, tribute, evolving items, ornamentation: out of scope for Origins.

---

## Manifest fragment: OpenMW (analyst-openmw)

Donor: OpenMW, GPLv3, pinned `71fc0a4a2904ed9c315050194f51857ed598a8d1` (read-only at `/opt/frankendom-shadow/work/expansion-donors/openmw` on the VPS). Clean-room process (ruling 8): specs only. No donor code is copied. Implementers must not read the donor source.

| system | donor | commit | source files | behaviour | dependencies | licence | decision | destination | tests (planned goldens) | spec author | implementer | implementer saw source | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Quest journal | OpenMW | 71fc0a4a | apps/openmw/mwdialogue/{journalimp,quest,journalentry,topic}.cpp; apps/openmw/mwscript/dialogueextensions.cpp; components/esm3/{loaddial,loadinfo,infoorder,queststate,journalentry}.hpp | Per-quest stage index (only rises through entries; SetJournalIndex can lower it), finished flag from Finished/Restart stages, restart clears finished on same-named quests, dated chronological journal, per-topic reply log deduped by info, save and load drop entries whose content vanished | Content model (dialogue + ordered infos); text-token substitution; date provider; dialogue conditions (Journal function) | GPLv3 donor; spec-only, our implementation under the Frankendom licence | clean-room reimplement | story | J1-J14 in docs/origins/specs/openmw-quest-journal.md | analyst-openmw | TBD | no | spec written |
| Dialogue conditions | OpenMW | 71fc0a4a | apps/openmw/mwdialogue/{filter,selectwrapper,dialoguemanagerimp}.cpp; components/esm3/dialoguecondition.{hpp,cpp}; components/esm3/loadinfo.*; apps/openmw/mwworld/store.cpp | First-match info selection in priority order: speaker filters (id, race, class, faction, rank, gender), player filters (faction, rank, cell prefix), up to 6 typed conditions (74 functions plus global/local/journal/item/dead/not-*), 6 comparison operators, min disposition with Info Refusal fallback, inverted check for service refusal, greetings by sorted dialogue id, choices, topic learning | Quest journal; factions and disposition; player stats; inventory counts; a condition schema (keep the numeric function ids) | GPLv3 donor; spec-only | clean-room reimplement | story | D1-D18 in docs/origins/specs/openmw-dialogue-conditions.md | analyst-openmw | TBD | no | spec written |
| Factions and disposition | OpenMW | 71fc0a4a | apps/openmw/mwmechanics/{npcstats,mechanicsmanagerimp,creaturestats}.cpp; apps/openmw/mwscript/statsextensions.cpp; apps/openmw/mwdialogue/dialoguemanagerimp.cpp; apps/openmw/mwclass/npc.cpp; components/esm3/loadfact.hpp; apps/opencs/model/world/defaultgmsts.cpp | Ranks 0-9 snapping to named ranks, join/raise/lower/expel, faction and global reputation, top-3-skill plus 2-attribute plus reputation rank requirements, directional faction reactions with runtime overrides, derived disposition formula, persuasion (admire, intimidate, taunt, bribe) with temporary and permanent split, barter offer, crime bounty and expulsion | Player stats (attributes, skills, level, fatigue); seeded RNG; quest/dialogue layer for promotion | GPLv3 donor; spec-only | clean-room reimplement | story (factions); economy (barter, bribe) | F1-F16 in docs/origins/specs/openmw-factions-disposition.md | analyst-openmw | TBD | no | spec written |
| Levelling and skill progression | OpenMW | 71fc0a4a | files/data-mw/scripts/omw/playerskillhandlers.lua; files/data/scripts/omw/skillhandlers.lua; apps/openmw/mwmechanics/{npcstats,mechanicsmanagerimp}.cpp; apps/openmw/mwgui/{levelupdialog,trainingwindow,waitdialog}.cpp; components/esm3/{loadclas,loadskil}.hpp; apps/opencs/model/world/defaultgmsts.cpp | Use-based skill XP: req = (base+1) × major/minor/misc factor × specialization factor. Major and minor increases fill a 10-point level bar. Level-up on sleep with 3 attributes × multiplier from governed-skill increases (1→×2 … 10→×5). Health += 0.1 × END. Creation bonuses. Training price base × 10 through barter. Jail skill drift. | Class and skill tables; barter offer (factions spec); time/rest hook | GPLv3 donor; spec-only | clean-room reimplement (as input to the ONE progression proposal; Frankendom tunes values) | progression | L1-L16 in docs/origins/specs/openmw-levelling-skills.md | analyst-openmw | TBD | no | spec written |

## Rejected / not taken (from the same donor)

- MWScript interpreter and compiler (result scripts, `fixDefinesDialog` token engine). Too large and engine-specific. Replace with a data-driven effect list plus our own token substitution.
- ESM/ESP binary formats, RefId, `InfoOrder` loader mechanics and save-game record framing (REC_QUES/REC_JOUR/REC_DIAS). Keep only the logical shapes described in the specs.
- Lua scripting VM and handler-chain plumbing (`openmw.interfaces`, engine events). Keep the "source" enum and the override hook idea only.
- Crime witness, alarm and AI-reaction system (alarm radius, guards, pursuit), and the AI fight/flee side effects of intimidate and taunt. Out of scope for a duel game unless Origins adds crime.
- Magic-effect-driven terms (Charm, diseases, Corprus, vampirism, werewolf) and weather conditions. Keep them as generic modifiers or flags only if Origins needs them.
- GUI (dialogue window, keyword hypertext search, level-up coins widget, training window, journal book UI) and sound/subtitles.
- Morrowind content values (SKIL use values, real GMSTs, quests). We have no Morrowind data and will not obtain it. The GMST numbers cited come from OpenMW-CS editor defaults and are reference only.

---

## Manifest fragment: Gothic donors (OpenGothic, ZenKit)

Clean-room per Dom's ruling 8: specs written by analyst-gothic from donor source; implementers work from the spec only.
Licences verified on the VPS checkout: OpenGothic `LICENSE` = MIT ("Copyright (c) 2019 Try"); ZenKit `license.md` = MIT ("Copyright 2021-2024 GothicKit Contributors"). Both require the copyright + permission notice in copies of substantial portions; clean-room reimplementation copies none, but credit both in our third-party notices anyway.
Gothic II game data and Daedalus scripts are proprietary (Piranha Bytes / THQ Nordic): not obtained, not used. All XP/LP/crime/guild-join numbers live there and are out of scope.

| system | donor | commit | source files | behaviour | dependencies | licence | decision | destination | tests | spec author | implementer | implementer saw source | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| NPC daily routines, AI states, perception, world clock | OpenGothic | 801f6ed5da1d29c316e1b2d18d3e001a84b9ebf1 | common/world/objects/npc.cpp (routine, state, perception), npc.h, game/gamesession.cpp, game/gametime.h, world/world.cpp, world/worldobjects.cpp, world/waymatrix.cpp, world/fplock.cpp, game/gamescript.cpp (externals) | 14.5:1 clock; time-windowed schedule entries with wrap and gap fallback; state init/loop/end lifecycle on the perception period; AI queue pre-empts routine; continue-routine; schedule swap; teleport-to-schedule on time skip; active/passive perceptions with ranges and view cone; free-point locking | waypoint graph, our raycast, our NPC state machine, a game clock service | MIT | adapt (reimplement from spec) | world | 21 golden cases in spec 10; pure-function unit tests + fake-clock NPC fixture | analyst-gothic | TBD | no | spec ready (docs/origins/specs/gothic-routines.md) |
| Guilds and attitudes, crime perception, knock-out rule | OpenGothic | 801f6ed5da1d29c316e1b2d18d3e001a84b9ebf1 | common/game/gamescript.cpp (table, attitude, externals), game/constants.h, world/objects/npc.cpp (guild, KO/death, perception emitters), world/world.cpp (rooms), game/movealgo.cpp, world/objects/interactive.cpp | guild x guild attitude table (default hostile), per-NPC permanent attitude to player overrides table, temp attitude stored but unused, true guild vs worn guild, room ownership, ownership tests, engine-emitted crime perceptions, unconscious-instead-of-dead when attacker not hostile | perception bus (routines), combat damage hook, zone ids | MIT | adapt (reimplement from spec; crime/witness/fine design is ours) | world / story | 14 golden cases in spec 10 | analyst-gothic | TBD | no | spec ready (docs/origins/specs/gothic-guilds-attitudes.md) |
| Levelling, XP, learning points, talents | OpenGothic | 801f6ed5da1d29c316e1b2d18d3e001a84b9ebf1 | common/world/objects/npc.cpp (fields, talents, attributes, regen), game/damagecalculator.cpp/.h, game/constants.h, ui/gamemenu.cpp; ZenKit include/zenkit/addon/daedalus.hh (INpc) | engine = storage (level, exp, exp_next, lp, talent tier/value, hitchance) + consequences (tier overlays, G2 skill-roll damage with MinDamage 5, ranged hit/crit, attribute clamps, regen); XP curve, LP award and teacher pricing are SCRIPT and absent | progression proposal (mentor/teacher model), dialogue evaluator for teacher gating, combat damage | MIT | reference (data model + combat consequence) / reimplement economy ourselves | progression | 15 golden cases in spec 10 (RNG-injected) | analyst-gothic | TBD | no | spec ready (docs/origins/specs/gothic-progression.md) |
| Dialogue / info selection | OpenGothic + ZenKit | 801f6ed5da1d29c316e1b2d18d3e001a84b9ebf1 / ddf27decd5eeb48ec715e6e66e5f5072c51d88ee | common/game/gamescript.cpp (dialogChoices, updateDialog, exec, sort, told-set, externals), common/ui/dialogmenu.cpp; ZenKit include/zenkit/addon/daedalus.hh (IInfo), src/addon/daedalus.cc (add_choice) | per-NPC info pool; condition predicates; important-first pass; told-set keyed by listener; permanent vs one-shot; sort by (nr, id); sub-choices newest-first and one-shot; trade flag | content format chosen by story lane (inkjs or other) | MIT | adapt (selection rules only) / compare with OpenMW, inkjs | story | 7 golden cases in spec 9 | analyst-gothic | TBD | no | spec ready (docs/origins/specs/gothic-dialogue.md) |
| ZenKit format parsers | ZenKit | ddf27decd5eeb48ec715e6e66e5f5072c51d88ee | include/zenkit/*.hh, src/*, docs/engine/formats/*.md | parsers for VDF, ZEN, Daedalus DAT, SAV, CSL, meshes, models, animations, textures, fonts | none for us (no Gothic data) | MIT (vendored submodules empty in checkout; upstream libsquish and doctest are MIT) | reference | tooling | none | analyst-gothic | n/a | no | reference page (docs/origins/specs/gothic-zenkit-reference.md) |

## Rejected
- Daedalus VM / script execution (ZenKit `DaedalusVm`, OpenGothic `GameScript` VM glue): we will not run Gothic scripts; logic becomes TS.
- All proprietary-asset parsers (VDF, ZEN worlds, MDL/MDH/MDM/MMB/MRM/MSH/MAN/MDS, TEX, FNT, CSL/OU, SAV): no data, no use.
- Retail XP/LP/teacher/crime/guild-join numbers and any `GIL_ATTITUDES` contents: script data, proprietary, not obtained; Frankendom designs its own.
- OpenGothic Far/Far2 AI LOD heuristics and the "TOT" dead-point removal hack: engine-specific workarounds.
- G1 branches (G1 guild ids, G1 crit formula, G1 party-member aivar index): reference only in specs, not to implement.
- `Npc_IsDetectedMobOwnedByGuild` and `Npc_PerceiveAll`: unimplemented stubs in donor.
- Temp attitude resolution: donor stores but ignores it; if wanted, it is our own extension (guild spec 5.3).
- Rendering, physics, sound, animation solver, UI menus, Bink video, DirectMusic: out of scope.
