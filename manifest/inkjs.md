# O0 manifest: inkjs

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
