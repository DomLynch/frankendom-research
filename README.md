# frankendom-research — the clean room's dirty side

Research material for **Frankendom: Origins** (Dom's ruling 8, 2026-10-06). This repo is where donor game code is read.
It holds donor pins, analysts' working notes, the O0 donor manifest, completeness-audit rounds and the item/loot/storage scorecard.
No secrets, keys, tokens or player data ever go in here.

## The clean-room rule

1. **Analysts** read the real donor source (OpenMW, OpenGothic/ZenKit, ModernUO, EQEmu; ClaudeCraft and inkjs are MIT)
   and write behaviour specs: every formula and constant with file:line, data structures, order of operations, edge cases.
   Specs contain prose and maths, never donor code.
2. **Finished specs cross the wall** into the game repo (`DomLynch/RPG-game`, `docs/specs/origins/`). Nothing else does.
3. **Implementers** are different agents. They are given only the finished specs and the game repo. They are never given this
   repository, its paths, the donor checkouts or analysts' notes. They modernise freely and list every deliberate divergence.
   Their code is wholly Frankendom's, with no inherited GPL, and may run on the server or in the browser.
4. **Parity tests** come from golden cases, captured from the donor emulators on the VPS where possible.
5. **Auditors** (analyst side, never an implementer) compare the finished build against the original source and the spec.
   Findings go back only as written spec amendments (no code, no snippets). Implementers update from the amended spec.
   Repeat until an audit round finds nothing material. Every round is logged in `audits/`.

## Who may read this repo
Analysts, auditors, the Expansion lead and Strategy. **Not** implementer agents.
The Expansion lead coordinates but does not read GPL donor source itself, so it can brief implementers from specs alone.

## Layout
- `donors/` — `PINS.md` (repo, commit, licence) and `fetch.sh`. The donor trees themselves live on the VPS
  (`/opt/frankendom-shadow/work/expansion-donors`, ~3.6 GB), never on the Mac and never in git.
- `manifest/` — the O0 donor manifest (`donor-manifest.md`) and per-donor fragments.
- `notes/` — analysts' working notes.
- `audits/` — completeness-audit rounds (system / round / findings / amended).
- `scorecard/` — the item, loot and storage scorecard (ClaudeCraft vs EQEmu vs ModernUO).
