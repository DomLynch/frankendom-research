# O0 manifest: World of ClaudeCraft

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
