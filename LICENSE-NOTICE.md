# Licence notice — Factory Blocks

This port carries the original mod's assets and data, and rewrites its behaviour
in Rust (or, for a data-tier port, declares its blocks from the same data). The
original licence and copyright notices are reproduced verbatim in
[LICENSE](LICENSE).

## Where the licence was read

- The pack jar `factory_blocks-neoforge-1.4.0+mc1.21.1.jar` (kept at
  `licence-cache/`) declares `license="MIT"` in `META-INF/neoforge.mods.toml`.
- Upstream, `fabric/src/main/resources/fabric.mod.json:17` and
  `neoforge/src/main/resources/META-INF/neoforge.mods.toml:3` also say MIT, and
  the repository has **no LICENSE file**. Modrinth's project page lists
  **CC0-1.0**. Both are permissive; this file carries the MIT text the mod's own
  metadata declares, and the registry entry names `MIT`.

## The port

- Original: Factory Blocks 1.4.2 by slaincow — MIT (loader metadata); CC0-1.0 on Modrinth.
- Licence: **MIT**
- Port to Horizon by AdLf0208: the Rust runtime, the Horizon declarations and the
  build/verification tooling in this repository.
- No Mojang file is included. The carried files are the mod's own assets and
  data; `data/minecraft/tags/…` files only add this mod's ids to vanilla tags.
