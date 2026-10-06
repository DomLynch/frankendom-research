# Scorecard: items, loot and storage (Frankendom: Origins)

- Analyst: analyst-scorecard (clean-room analyst side), 2026-10-06. Read-only: grep/sed on the VPS donor trees, no builds, no VPS writes.
- Donors and pins:
  - **ClaudeCraft (CC)**, MIT, `f46f30f5` at `/opt/frankendom-shadow/work/expansion-donors/world-of-claudecraft`. Direct reuse is allowed if the MIT notice is kept. Its `src/sim/types.ts` hub drags 248 files / 105,759 LOC at runtime, and `bank.ts` drags 656 / 240,959 (`manifest/claudecraft.md`). Only leaves and the scoped O2 cut (~735 LOC) are cheap.
  - **EverQuest / EQEmu (EQ)**, GPLv3, `4aceae18`. Clean-room only: we reimplement from a spec.
  - **Ultima Online / ModernUO (MUO)**, GPLv3, `261ea01a`, with paths relative to `Projects/`. Clean-room only.
- Citations are `donor/path:line` at those pins. Frankendom citations are `src/...` at trunk `8a3cefb7`. Where a score is a judgement and not a code fact, the row says so.

## The fixed spine, and what it does to every layer

Donors plug in around these rules. None of them may change them.

1. **Stats are only Attack and RES.** They are resolved once before the fight from `(slot, tier)` and capped at 1.15 / 0.80 (`src/gear-stats.ts:36`, `:65-80`). Every number is a damage multiplier and none is a duration (`:14-17`). It follows that any donor feature that **rolls stats onto a copy** is rejected wherever it appears. That covers MUO `LootPack.Mutate` random properties (`ModernUO/Projects/UOContent/Misc/LootPack.cs:689-733`), CC `ItemInstancePayload.rolled.stats` / masterwork / perfecting (`world-of-claudecraft/src/sim/types.ts:1619` onward) and EQ augments. A copy carries a **tier**, and the existing `pointsFor(tier, slot)` scale prices it (`src/gear-stats.ts:72`).
2. **Identity today is the definition.** `LootId = <opponent>.<Slot>`, and a player holds at most one of each across all tiers (`src/loot.ts:26`, `:145-149`, `src/awards.ts:26`). The missing piece is `TierOf(piece)` (`src/gear-stats.ts:119`). Today "every kit resolves naked". Giving each copy an instance with a tier on it is what finally fills that hook.
3. **Awards are server-verified.** `scripts/verify-loot.mjs` replays the record and writes `awards` (baseline §3.3). Rule: **any donor roll runs in the verifier, never in the client.** Its seed comes from server state plus the `fight_hash`, so the result can be audited again later but cannot be predicted by grinding seeds.
4. **Take one piece.** One claim gives at most one award (`supabase/migrations/202609230001_server_awards.sql:20-21`, `src/awards.ts:5-7`).

Score key: **(a)** fit with the stat spine, **(b)** exploit and dupe safety at scale, **(c)** phone UI simplicity, **(d)** server cost (5 = cheapest), **(e)** size of what we would have to build (5 = least to build). Each score is 1–5.

---

## 1. Item identity and instances

What the layer has to give us: a unique serial per copy, exactly one location and custodian per copy, a custody transfer that cannot leave a copy in two places, and dupe safety.

| Donor | a | b | c | d | e | Total |
|---|---|---|---|---|---|---|
| ClaudeCraft | 3 | 3 | 4 | 3 | 3 | 16 |
| EverQuest | 4 | 3 | 2 | 3 | 3 | 15 |
| **Ultima Online** | **4** | **4** | **3** | **4** | **4** | **19** |

**ClaudeCraft**
- (a) 3. The payload carries `rolled.stats`, masterwork, enchant and perfecting (`src/sim/types.ts:1619-1700`). All of it must be cut, and nothing in it holds a tier. `boundTo`/`bindOnTrade` is usable as-is.
- (b) 3. **There is no per-copy serial.** `InvSlot` is `{itemId, count, instance?, slot?}` (`src/sim/types.ts:1791-1810`). A copy is addressed by index plus an "ordinal-plus-count" anchor (`src/sim/item_copy_anchor.ts:3-22`). The header of `src/sim/item_copy_ref.ts:13-16` says the copy-choice guess "has been patched three times without being fixed". The server side is strong: a cross-process lease is "the cross-process double-load dupe guard" (`server/character_lease_db.ts:12-17`).
- (c) 4. The anchor exists to solve a real phone problem. A lagging mirror plus a tap can destroy "the wrong copy … silently" (`src/sim/item_copy_anchor.ts:8-15`). A real serial on our side removes that problem outright.
- (d) 3. The character is a JSON blob in Postgres with a 30 s autosave (`notes/claudecraft-server.md`, `server/game.ts:518`). Custody lives inside the blob, not in rows.
- (e) 3. MIT, but the usable span is the ~206 LOC of type and clone code inside the 105k-LOC hub (`manifest/claudecraft.md` O2 row 6). We would still have to add the serial ourselves.

**EverQuest**
- (a) 4. The definition-versus-instance split is ours already (`ItemData` vs `ItemInstance`, `EQEmu/common/item_data.h:337-492`, `common/item_instance.h:336-370`). **Lore** (LoreGroup −1 means unique per item id, `item_data.h:372-373`) is exactly our "one `<opponent>.<Slot>` per player" rule, checked on loot, buy and trade (`zone/inventory.cpp:171-182`).
- (b) 3. The runtime serial is a process-local `int32` counter that wraps to 1 at INT32_MAX and exists "because the Bazaar relies on" it (`common/item_instance.cpp:28-54`). The persistent identity is a separate `guid uint64` column on inventory rows (`common/repositories/base/base_inventory_repository.h:55`). One copy therefore has two identities. There is visible dupe history in the shared bank: every shared-bank move is re-verified against the DB, and the log reads "was found exploiting the shared bank" (`zone/inventory.cpp:1819-1830`).
- (c) 2. Identity is tied to the RoF2 client slot numbering, with 200-slot bag ranges (`common/emu_constants.h:219-247`, `common/patches/rof2_limits.h`).
- (d) 3. Zone-process memory plus a MariaDB row per slot. Fine, but the authority is split between them, which is what the shared-bank guard is patching.
- (e) 3. Clean-room. We take only the concepts (definition/instance, lore, no-drop recursion), which are small. The spec is reference-only (`docs/specs/origins/eqemu-inventory.md`).

**Ultima Online**
- (a) 4. Neutral to stats: a serial plus a parent holds no numbers. `LootType` (Blessed/Newbied, `Server/Items/Item.cs:81`, `:313`) gives us "cannot be traded/dropped" flags with no stat meaning.
- (b) 4. **One global serial space** for every item, `0x40000000..0x7EEEEEEE` (`Server/World/World.cs:56-65`, `Server/Serial.cs:21-40`). It is never reused within a world.
  - **One parent by construction:** `AddItem` first detaches the item from its old parent, whether a mobile or a container (`Server/Items/Item.cs:3391-3440`). It also refuses self-adds and parent-into-child adds with logged warnings (`:3398-3423`).
  - An item on the cursor has a `Holding` owner and a `BounceInfo` that returns it home (`Server/Mobiles/Mobile.cs:548-576`, `Server/Items/Item.cs:104-143`). A disconnect drops what is held (`Mobile.cs:1351`).
  - The risk is inferred, not cited: persistence is a periodic whole-world snapshot (`Server/World/World.cs:661` ItemPersistence), so a crash between saves rolls trades back. That is the classic UO dupe class, and it is solved by storage, not by the rule. The GM `Dupe` command is logged staff tooling, not a hole (`UOContent/Commands/Dupe.cs:12-13`, `:106`).
- (c) 3. The layer is invisible to the player. It neither helps nor hurts.
- (d) 4. "A serial plus one custodian column plus one move" maps onto one Postgres row per copy with a single `UPDATE … WHERE custodian = $from`. That is cheap.
- (e) 4. The rule is small: serial, single parent, detach-then-attach, held item bounces home.

**Pick: Ultima Online's STRUCTURE with EverQuest's RULE.** UO's single serial and single custodian makes a dupe impossible to even express. EQ's lore rule keeps our one-per-player promise when trading arrives.
- **Hybrid:** the structure (instance row, global id, one custodian, move = atomic detach plus attach) comes from MUO. The uniqueness rule ("you may not receive an `<opponent>.<Slot>` you already hold anywhere, bank included") comes from EQ lore. Note that EQ exempts the shared bank (`eqemu-inventory.md` §4) and we should not. The server hardening patterns come from CC MIT: the lease and nonce fencing (`server/character_lease_db.ts`) and compensate-only-on-proven-rollback (`server/pg_rollback_proof.ts`).
- **Spine fit:** the instance carries `tier` and `provenance` (`claim_id`). `TierOf` becomes a lookup on the equipped instance, and the per-piece score is untouched.
- **Baseline collisions to fix first:**
  - `cleanLoot` silently drops anything that fails `isLootId`, so an older build would erase instance ids (`src/loot.ts:152-156`). Readers must tolerate instance ids before any writer emits them.
  - Two server CHECK regexes pin the old grammar (`202609230001:27`, `:59`).

---

## 2. Loot tables and drops

What the layer has to give us: probabilities, drop limits, named rares and anti-farm.

| Donor | a | b | c | d | e | Total |
|---|---|---|---|---|---|---|
| ClaudeCraft | 3 | 4 | 4 | 5 | 4 | 20 |
| **EverQuest** | **4** | **4** | **4** | **5** | **3** | **20** |
| Ultima Online | 2 | 3 | 4 | 5 | 3 | 17 |

**ClaudeCraft**
- (a) 3. The rules are MMO party rules: need/greed `loot_roll.ts` (1,161 LOC, catalogue-dragged), FFA timeout and master loot (`src/sim/loot/loot_ffa.ts`, `src/sim/loot_master.ts`), none of which fits a 1v1. `weightedLootGroup` fits our needs: a guaranteed partition plus "reserved" absolute-odds chase entries (`src/sim/loot/weighted_loot_group.ts:3-21`).
- (b) 4. A seeded mulberry32 `Rng` is the single source of randomness ("all sim randomness must flow through this", `src/sim/rng.ts:16-17`), so a roll replays exactly, which is what our verifier needs. `weightedLootGroup` throws on a non-finite or negative weight (`weighted_loot_group.ts:12-20`). Heroic rows replace Normal rows rather than stacking on them (`src/sim/loot/loot_difficulty_gate.ts:5-11`).
- (c) 4. No UI is needed beyond the existing take-one-piece screen.
- (d) 5. Pure functions.
- (e) 4. `weighted_loot_group` (35 LOC) and `rng.ts` (98 LOC) are 1-file MIT leaves (`manifest/claudecraft.md`).

**EverQuest**
- (a) 4. Two levels:
  - Each table entry is gated on probability × multiplier.
  - Each drop pool works in one of two modes: Mode A, where every entry rolls independently, or Mode B, a weighted pick limited by `droplimit`/`mindrop` (`zone/loot.cpp:31-140`, `:142-250`).
  - Mode B with `droplimit 1, mindrop 1` is exactly "one piece per win". Named rares come through global loot filtered on the `rare_spawn` flag (`zone/global_loot_manager.cpp:116-185`).
  - The weak spot is that loot is rolled **at spawn** (`zone/spawn2.cpp:299-302`). For us it must be rolled at verification.
- (b) 4. The only anti-farm rule is the trivial-killer filter at death: an over-levelled killer loses the tagged items (`zone/loot.cpp:742-780`). That maps one-to-one onto our dial floor `levelRefusal` (`src/awards.ts:33-37`). The RNG is OS-seeded mt19937 (`common/random.h:41`, `:107`), so it cannot be replayed. Clean-room fixes that, because we inject our seeded RNG and the spec already orders the draws (`eqemu-loot.md` §6).
- (c) 4. No UI.
- (d) 5. Pure selection.
- (e) 3. Clean-room reimplementation of about 300 lines. Fourteen hand-derived goldens are ready (G-L1…G-L14, `eqemu-loot.md` §9).

**Ultima Online**
- (a) 2. `LootPack` rolls per-entry chance out of 10,000 (`UOContent/Misc/LootPack.cs:116-148`) and then `Mutate` applies random magic properties scaled by luck (`:689-733`). That is rolled stats, which our spine forbids. Paragon variants exist (`UOContent/Mobiles/BaseCreature.cs:930`).
- (b) 3. Damage-weighted looting rights (`BaseCreature.cs:3344`) are group-kill logic. Luck is a stat-driven bias on the drop chance (`LootPack.cs:64-116`).
- (c) 4. No UI.
- (d) 5. Pure selection.
- (e) 3. Clean-room, with no spec written for LootPack yet.

**Pick: EverQuest's RULES on ClaudeCraft's STRUCTURE.** EQ's table shape (droplimit/mindrop, rare filter, trivial anti-farm) is the most complete drop design. CC's seeded RNG and weighted group are MIT leaves that replay exactly inside our verifier.
- **Hybrid:**
  - The rules are EQ's loottable → lootdrop with Mode A/B, `droplimit`/`mindrop`, the rare/named filter, and the trivial-killer filter (which becomes our dial floor).
  - The structure is CC's `Rng` and `weightedLootGroup` (reserved chase entries = named rares), called **once in `verify-loot.mjs`**, seeded from server state plus `fight_hash`.
  - The "pick" the player sees is still one piece. The table only decides which pieces are offered (today the opponent's six armour pieces, `kitAt`, `src/awards.ts:18-19`).
- **Reject:** MUO `Mutate` and every rolled-property path; EQ coin (gold is a separate economy decision); CC need/greed/FFA.

---

## 3. Backpack / inventory

What the layer has to give us: capacity, stacking, a choice between weight and slots, and a fit with the phone UI.

| Donor | a | b | c | d | e | Total |
|---|---|---|---|---|---|---|
| **ClaudeCraft** | **4** | **4** | **4** | **4** | **4** | **20** |
| EverQuest | 2 | 3 | 1 | 3 | 2 | 11 |
| Ultima Online | 2 | 3 | 1 | 3 | 2 | 11 |

**ClaudeCraft**
- (a) 4. Capacity is **slots, not weight**: a 16-slot backpack plus up to 4 bags, pooled (`src/sim/bags.ts:2-3`, `:83`). Gear kinds never stack (`UNSTACKED_KINDS`, `bags.ts:94`), which matches our one-copy pieces. Weight would be a hidden stat, and END/stamina belongs to the character layer (`src/gear-stats.ts:4-6`).
- (b) 4. `moveBetweenContainers` is all-or-nothing and leaves both arrays untouched on refusal (`src/sim/bank.ts:323`, plus the O2 behaviours in `manifest/claudecraft.md`). There are conservation seed sweeps. The add hub is deliberately never capacity-capped, so an award can never destroy an item. When an award does not fit, it stays claimable rather than being force-added or mailed (`src/sim/loot/awarded_loot_hold.ts:3-16`).
- (c) 4. Fixed grid with a manual order (`src/sim/inventory_order.ts`). Touch-tap opens the item menu, and destroy actions go through one confirm (`src/ui/bag_item_action_menu.ts:6-12`).
- (d) 4. Array operations inside the character save.
- (e) 4. MIT. The O2 cut is already scoped at ~735 LOC across 7 files with 0 catalogue (`manifest/claudecraft.md`, O2 section).

**EverQuest**
- (a) 2. Ten general slots plus bags with item Size ≤ BagSize, and a separate cursor slot (`eqemu-inventory.md` §3, `common/patches/rof2_limits.h`). Size is a second hidden attribute.
- (b) 3. The cursor is an unlimited-depth queue (`eqemu-inventory.md` §3), a classic dupe surface. Lore and no-drop recursion are good.
- (c) 1. Nested bags, a cursor and client slot numbers make this a PC interface.
- (d) 3. One row per slot.
- (e) 2. Clean-room, and the slot model would have to be redesigned anyway.

**Ultima Online**
- (a) 2. Weight plus count: backpack 125 items and 400 stones (`Server/Items/Container.cs:87-100`, `:141-179`), with gold weighed per coin (`UOContent/Items/Misc/Gold.cs:22`). Weight is a stat the spine does not have.
- (b) 3. The capacity check is recursive and correct (`Container.cs:230-281`). But a withdraw into a full pack force-drops it to the ground and overloads it (`modernuo-bank.md` §6).
- (c) 1. Free-form drag piles at x/y inside container gumps.
- (d) 3. Same cost class as EQ.
- (e) 2. Clean-room, and the UI would have to be built from scratch.

**Pick: ClaudeCraft.** Slot-based, never-stacking gear, an all-or-nothing move and touch menus already fit a phone. It is MIT, and the cut is already measured. This layer is not a hybrid. Frankendom's existing `Loot.pack` (`src/loot.ts:40`) becomes the instance list that CC's slot logic arranges.

---

## 4. Bank and storage

What the layer has to give us: personal storage, a shared account stash and guild storage.

| Donor | a | b | c | d | e | Total |
|---|---|---|---|---|---|---|
| **ClaudeCraft** | **4** | **5** | **4** | **3** | **3** | **19** |
| Ultima Online | 4 | 3 | 3 | 4 | 3 | 17 |
| EverQuest | 3 | 2 | 2 | 3 | 2 | 12 |

**ClaudeCraft**
- (a) 4. The personal bank has 24 base slots plus purchased 6-slot rungs (`src/sim/bank.ts:47-62`). Bonus slots are server-stamped and clamped (`:70`, `:88-90`). Nothing touches stats.
- (b) 5. This is the most hardened code of the three, and it carries the most visible dupe history:
  - "Every dupe this feature had moved value between a purse and a book, and not one of them was visible to scripts/bank_audit.mjs", fixed with a two-sided counterparty ledger (`server/guild_bank_counterparty.ts:5-13`).
  - `bank_ledger` is a keep-forever "anti-dupe audit trail" (`server/bank_ledger.ts:18-21`, `server/main.ts:3951-3972`).
  - The guild-bank incident metrics are labelled "dupe-sensitive paths" (`server/http/game_metrics.ts:227`).
  - `sanitizeBankState` tolerates bad data and never destroys it on load (`src/sim/bank.ts:764`).
- (c) 4. A grid of the same shape as the bags, with UI cores for the bank chrome and the rung purchase (`src/ui/bank_chrome_layout_core.ts`, `src/ui/bank_rung_purchase_core.ts`).
- (d) 3. The ledger outbox and the keep-forever table grow without bound, and there is a growth monitor for it (`server/bank_ledger_growth_monitor.ts`).
- (e) 3. `bank.ts` as-is is 656 files. The move function comes with the O2 cut. The rest is a reference for reimplementing.

**Ultima Online**
- (a) 4. The bank is per character: 125 items, unlimited weight (`Server/Items/Containers.cs:7-114`, `Container.cs:177`). The deposit is all-or-nothing and checks capacity before changing anything (`UOContent/Mobiles/Townfolk/Banker.cs:209-314`).
- (b) 3. The rules are clean, but the account-gold ledger has no carry and can overflow 32 bits (`UOContent/Accounting/Account.cs:523-604`, `modernuo-bank.md` §6). There is no shared account bank. Shared and guild storage is house "secure containers" with access levels Owner/CoOwners/Friends/Anyone/Guild (`UOContent/Multis/Houses/BaseHouse.cs:3911-3918`), which needs housing.
- (c) 3. The banker-proximity gate maps nicely onto a place in the world (it closes when you move, `Server/Mobiles/Mobile.cs:7360-7375`). The speech commands must go.
- (d) 4. A container of rows.
- (e) 3. Clean-room, with the spec ready (B1–B18).

**EverQuest**
- (a) 3. The personal bank has 24 slots, there is a 2-slot account **shared bank**, and there is a guild bank (`zone/guild_mgr.cpp:940-1210`).
- (b) 2. The shared bank was a dupe vector, and every move out of it is re-verified against the DB, with "found exploiting the shared bank" logged and the destination deleted (`zone/inventory.cpp:1819-1830`). That is a guard bolted on after the fact, not structural safety.
- (c) 2. Bank bags inside bank slots, numbered for the client.
- (d) 3. One row per slot, plus the verify round-trip.
- (e) 2. Clean-room of a design we would mostly redesign.

**Pick: ClaudeCraft's STRUCTURE with Ultima Online's RULE.** CC's bank is slot-based like the backpack, and its ledger and audit design is the only one that was hardened against real dupes. MUO adds the simple rules.
- **Hybrid:**
  - The structure is CC: the same slot grid and the same `moveBetweenContainers` for pack↔bank, purchased rungs if wanted later, and the tolerant loader.
  - The rules are MUO: an all-or-nothing deposit with a capacity pre-check, and access only at a place, i.e. a banker. The "Concord Exchange → bank front" greybox in commit `849313bd` is that place.
- **Shared account stash:** not needed at first. Frankendom has one fighter per account, so the personal bank *is* the account bank.
- **Guild storage:** later. When it comes, take CC's two-sided counterparty ledger pattern, not EQ's verify-after-move.

---

## 5. Trade and gifting

What the layer has to give us: a two-sided confirm, escrow, and a market later.

| Donor | a | b | c | d | e | Total |
|---|---|---|---|---|---|---|
| **ClaudeCraft** | **4** | **5** | **4** | **4** | **3** | **20** |
| Ultima Online | 4 | 3 | 4 | 5 | 3 | 19 |
| EverQuest | 4 | 3 | 3 | 4 | 3 | 17 |

**ClaudeCraft**
- (a) 4. A per-copy lock: `boundTo` is never offered, and `bindOnTrade` stamps the recipient's copy (`src/sim/social/trade.ts:55-66`, `src/sim/transfer_lock.ts`). This gives "Pit-won pieces can or cannot be traded" as a flag, not as a stat.
- (b) 5.
  - Any offer change clears both accepts (`trade.ts:387-388`).
  - The confirm re-validates per-copy pins and, on a stale offer, clears the accepts rather than swapping (`trade.ts:723-799`).
  - A **capacity check on the swap itself** (`fitsAfterSwap`, `trade.ts:477`) closes MUO's spill-on-full-pack hole.
  - The market has a recorded fix of "the item-dupe hole (return sweep mails the escrow home while the buyer can still pay)" (`server/woc_market.ts:3462-3474`).
- (c) 4. At most 6 offer lines, and the constant is shared with the UI so the client can never stage a line the server drops (`trade.ts:50-53`).
- (d) 4. In-memory session plus save. It needs both players online in one server process (`TRADE_RANGE = 10`, `trade.ts:48`).
- (e) 3. `trade.ts` (1,048 LOC) imports `ITEMS` and rift content, so the pattern gets reimplemented and the leaves (`transfer_lock`, `item_instance_merge`) are reused.

**Ultima Online**
- (a) 4. Items only, with a per-item veto hook (`Server/Items/Item.cs:1884-1889`).
- (b) 3. The state machine is textbook: any add or remove, nested ones included, clears both ticks (`Server/Items/SecureTradeContainer.cs:40-90`); the swap is simultaneous; it cancels on distance > 2, death, disconnect or map change (`Server/Network/NetState/NetState.cs:310-339`). The holes:
  - **No capacity check at completion**, so items spill to the ground (`Server/SecureTrade.cs:186-331`, `modernuo-secure-trade.md` §4.4 step 5).
  - Negative currency offers are not validated on entry (`Server/Items/VirtualCheck.cs:60-80`).
- (c) 4. Two panes and two ticks is the clearest phone picture.
- (d) 5. Synchronous and stateless after it closes.
- (e) 3. Clean-room, with the spec ready (T1–T12).

**EverQuest**
- (a) 4. A lore conflict cancels the trade (`zone/client_packet.cpp:15428-15450`, `CheckTradeLoreConflict` at `zone/trading.cpp:689`). That is our one-per-player rule enforced at trade time.
- (b) 3. Adding an item resets both sides to "trading" (`zone/trading.cpp:85-98`). No-drop is checked on both sides at accept (`trading.cpp:740`). The serials the Bazaar depends on are process-local (§1).
- (c) 3. A fixed 8-slot trade window plus the cursor.
- (d) 4. Comparable to MUO.
- (e) 3. Clean-room.

**Pick: ClaudeCraft's STRUCTURE with EverQuest's RULE.** It is the only trade of the three that checks capacity at the swap and pins the exact copy, and its market escrow carries real dupe fixes.
- **Hybrid:**
  - The structure is CC: a server state machine, reset-both-on-change, confirm-time re-pin by **our instance serial** (simpler than CC's ordinal anchor), and capacity at the swap.
  - The rule is EQ: refuse a trade that would give either side a second copy of an `<opponent>.<Slot>` (lore conflict).
  - MUO's T1–T12 goldens stay the conformance tests for the accept/cancel sequence.
- **Gifting** is a one-sided offer the recipient accepts, through the same machine.
- **Market later:** CC's escrow and settlement pattern (`server/woc_market*` minus the crypto and wallet code, which `manifest/claudecraft.md` rejects).
- **Phone note:** for players who are not in the same scene, prefer an asynchronous escrowed offer (CC mail-custody shape, `server/mail_custody_overlay.ts`) over a live window.

---

## 6. Crafting (later; scored lightly)

| Donor | a | b | c | d | e | Total |
|---|---|---|---|---|---|---|
| **EverQuest** | **4** | **3** | **2** | **5** | **3** | **17** |
| Ultima Online | 2 | 3 | 3 | 5 | 3 | 16 |
| ClaudeCraft | 2 | 4 | 4 | 4 | 2 | 16 |

- **EQ.**
  - (a) 4. A fixed recipe gives a fixed output, and success depends on skill against a trivial (`zone/tradeskills.cpp:1071-1073`). There is no quality variance, so the per-piece score holds.
  - (b) 3. (c) 2: the combine-container drag.
  - (d) 5. (e) 3.
- **MUO.**
  - (a) 2. An exceptional-quality roll independent of success (`modernuo-crafting.md`, `UOContent/Engines/Craft/Core/CraftItem.cs`), which means variance on the copy.
  - (b) 3. (c) 3. (d) 5.
  - (e) 3: spec C1–C14 is ready.
- **CC.**
  - (a) 2. Masterwork procs and rolled stats (`src/sim/professions/crafting.ts`, 1,723 LOC).
  - (b) 4. Plan-then-apply, and `craftedRecipeId` provenance survives round trips (`manifest/claudecraft.md` O2).
  - (c) 4. (d) 4.
  - (e) 2. A 656-file closure.

**Pick: EverQuest's RULE with ClaudeCraft's STRUCTURE, deferred.** Fixed outputs keep the stat spine honest.
- The rules are EQ's fixed recipe → fixed output.
- The structure is CC's "validate the whole recipe, then consume" shape (`src/sim/professions/collection_manual.ts`, 22 LOC).
- Design flag for Dom: crafting should probably **re-tier or repair a piece you already own** rather than mint new `<opponent>.<Slot>` copies, because minting would undercut "you took it from him".

---

## Summary of picks

| Layer | Pick | Rules from | Structure from |
|---|---|---|---|
| 1 Identity | Hybrid | EQ (lore: one per definition per player) | MUO (global serial, one parent, atomic detach plus attach) and CC server fencing |
| 2 Loot | Hybrid | EQ (droplimit/mindrop, named rares, trivial anti-farm) | CC (seeded `Rng`, `weightedLootGroup`) inside our verifier |
| 3 Backpack | ClaudeCraft | CC | CC (O2 cut, MIT) |
| 4 Bank | Hybrid | MUO (all-or-nothing deposit, banker-place access) | CC (slot grid, shared move, ledger pattern) |
| 5 Trade | Hybrid | EQ (lore conflict) and MUO T1–T12 conformance | CC (reset-on-change, re-pin, capacity at swap, escrow) |
| 6 Crafting | Hybrid, later | EQ (fixed output) | CC (validate-then-consume) |

## Exploit and dupe history seen in the code

- **CC**
  - The guild-bank purse↔book dupes, closed by the counterparty ledger (`server/guild_bank_counterparty.ts:5-13`).
  - The market return-sweep escrow dupe (`server/woc_market.ts:3462-3474`).
  - A mail-delivery dupe (`server/woc_market_delivery.ts:575`).
  - A cross-process double-load dupe, closed by the character lease (`server/character_lease_db.ts:12-17`).
  - A "Phase 3 QA dupe" in reconcile (`server/game.ts:4712`).
  - A non-finite stack clamp that "closes a dupe vector" (`src/sim/materials_vault.ts:1150`).
  - The copy-choice heuristic, patched three times (`src/sim/item_copy_ref.ts:13-16`).
- **EQ**
  - The shared-bank exploit guard (`zone/inventory.cpp:1819-1830`).
  - A serial-wrap note in the code itself: "Maybe we should call abort()" (`common/item_instance.cpp:42`).
  - A zone-state test asserting "no dupes" after a restore (`zone/cli/tests/cli_zone_state.cpp:548-575`).
- **MUO**
  - No dupe-fix comments in the item, trade or bank paths. The only "Dupe" hits are the logged GM command (`UOContent/Commands/Dupe.cs`).
  - Structural guards against self-parenting and parent-into-child (`Server/Items/Item.cs:3398-3423`).
  - The completion spill is a design gap, not a patched bug (`modernuo-secure-trade.md` §6).
