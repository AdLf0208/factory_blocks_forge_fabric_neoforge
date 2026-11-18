# Factory Blocks [Forge/Fabric/NeoForge] — a Horizon port

**Factory Blocks [Forge/Fabric/NeoForge]** is a Minecraft mod. This repository is a **port of it to [Horizon](https://github.com/horizon-rust/horizon)**, the Rust engine for Minecraft Java 26.3. It carries the complete source of the port plus the content files it ships, and installs as a single `.hmod` package.

Upstream: [matthewperiut/factory_blocks](https://github.com/matthewperiut/factory_blocks) — licence **MIT**.

| | |
|---|---|
| Upstream mod | Factory Blocks [Forge/Fabric/NeoForge] ([source](https://github.com/matthewperiut/factory_blocks)) |
| Ported to | Horizon 0b14f8a, Minecraft Java 26.3, mod API `0.2` |
| Package | `factory_blocks.hmod` (install it with the Horizon launcher) |
| Licence | **MIT** — the upstream mod's licence; see [Licence and credit](#licence-and-credit) |

## What this port implements

- full-cube shape, hardness 2.0, blast resistance 2.0, iron's metal sound,
- horizontal fan `facing`, default east, and the placement rule (proved in the
- the `on` state and all 82 state bindings.
- **Redstone fans do not switch.** `RedstoneFanBlock.neighborUpdate` is a
- **Per-item tooltips.** `TooltipBlockItem.appendHoverText` prints
- **The custom `factory_blocks:metal_sound` SoundType.** `properties.sounds`
- **The vanilla `minecraft:building_blocks` tab.** A content mod cannot append
- **Chipped/Chisel integration.** The two `chipped:*` recipes and the Chisel

## Not yet ported

- full-cube shape, hardness 2.0, blast resistance 2.0, iron's metal sound,
- horizontal fan `facing`, default east, and the placement rule (proved in the
- the `on` state and all 82 state bindings.
- **Redstone fans do not switch.** `RedstoneFanBlock.neighborUpdate` is a
- **Per-item tooltips.** `TooltipBlockItem.appendHoverText` prints
- **The custom `factory_blocks:metal_sound` SoundType.** `properties.sounds`
- **The vanilla `minecraft:building_blocks` tab.** A content mod cannot append
- **Chipped/Chisel integration.** The two `chipped:*` recipes and the Chisel

## Installing

1. Install the [Horizon launcher](https://github.com/horizon-rust/horizon/releases) (0.2.70 or newer).
2. Add `factory_blocks.hmod` to the instance's mods.
3. The package is pinned to a specific Horizon build; the launcher checks that pin.

## Licence and credit

Factory Blocks [Forge/Fabric/NeoForge] was created by its upstream authors; the code, models and assets in the original mod
remain theirs and are used here under **MIT**. The Rust in this repository is a clean-room
rewrite for Horizon, not a translation of the original source.

- `LICENSE` — the upstream licence text.
- `LICENSE-NOTICE.md` — what this port carries and where it came from.
- The upstream project: https://github.com/matthewperiut/factory_blocks

## Technical details

```
horizon-mod.toml   package manifest (id, version, api, [native] pin)
Cargo.toml         the crate; depends on `horizon-mod-api` from the fetched SDK
src/               lib.rs (the one `impl Hooks`), runtime.rs (pure logic + tests), glue
assets/ data/      the content the package ships
tools/             content generators and the e2e scenario
```

- Build: `cargo horizon-mod build` (packages; it does not compile against the game).
- Test: `cargo test`, `cargo clippy --all-targets -- -D warnings`.
- In-game: `ports/tools/launcher-game.sh run factory_blocks` in the campaign tree, or install the
  `.hmod` and play; the harness scenario is `tools/e2e.sh`.

This repository is generated from the campaign's port at `ports/factory_blocks/`; the port's own
`notes.md` is the full record (decisions, traps, evidence).
