# Factory Blocks — Horizon port

A port of [Factory Blocks](https://github.com/matthewperiut/factory_blocks) by
slaincow for Horizon: 49 industrial decorative blocks — factory panels, grating,
vents, pipes, hazard stripes, riveted plates and machinery faces.

- Craft them from the mod's own recipes and build with them; every block is a
  full cube with the upstream textures and models.
- The OptiFine CTM (connected-texture) data is carried, so connected-texture
  resource packs shade them like the original.

This is a data-tier carry: no block entity and no behaviour hooks. MIT — the
mod's own loader metadata declares MIT, its Modrinth page lists CC0-1.0, and the
discrepancy is recorded in the port repository's LICENSE and LICENSE-NOTICE.md;
original copyright and licence notices are kept there.

**Original:** [Factory Blocks](https://github.com/matthewperiut/factory_blocks) 1.4.2 by
slaincow, **MIT**. The original
copyright and licence notices are kept in [LICENSE](LICENSE), and
[LICENSE-NOTICE.md](LICENSE-NOTICE.md) records where each was read from.

**Horizon:** a port for [Horizon](https://github.com/horizon-rust/horizon), Minecraft:
Java Edition 26.3 rewritten in Rust. The exact Horizon and horizon-mixins
revisions this port builds against are pinned in `compatibility.json`.

## Install

1. Take `factory_blocks.hmod` from this repository (or build it below).
2. Put it in the game folder's `horizon-mods` folder — the game folder is the one
   holding `options.txt`.
3. Mods are off by default: enable this one in the game's mod list.

To try it without installing, start the game with
`--dev-mod factory_blocks.hmod`.

## Build

This is a content-only mod: `content/horizon-mod.toml` plus `assets/` and
`data/`.

```sh
cd content && cargo horizon-mod build    # packs content/ into the .hmod and checks it
```

`cargo-horizon-mod` comes from the Horizon repository
(`cargo install --git https://github.com/horizon-rust/horizon cargo-horizon-mod`).
`tools/e2e.sh` is the in-game harness and expects a campaign checkout
(`$CAMPAIGN_ROOT`) with the prepared 26.3 resources (`$HORIZON_RES`, default
`.local/horizon-client/26.3`).

## Layout

`content/` is the 49-block data tier (`data/factory_blocks/horizon/block/`) plus the carried assets; `tools/gen_content.py` regenerates the declarations.

This is an unofficial port: Horizon is not affiliated with the original author.
The licence above is the original's and travels with every copy; see
[LICENSE](LICENSE) and [LICENSE-NOTICE.md](LICENSE-NOTICE.md).
