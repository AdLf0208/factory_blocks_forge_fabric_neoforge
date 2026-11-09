#!/usr/bin/env python3
"""Generate the Factory Blocks content mod from the upstream 26.3 assets.

Reads the analysis clone at
`ports/_shared/upstream/factory_blocks/common/src/main/resources` (shallow,
git-ignored) and writes `content/`:

  assets/factory_blocks/blockstates/   upstream, minus the Athena CTM keys
  assets/factory_blocks/items/         upstream `items/<id>.json`
  assets/factory_blocks/models/        upstream block + item models
  assets/factory_blocks/textures/      upstream block textures (Athena CTM
                                       tiles dropped; OptiFine CTM carried)
  assets/factory_blocks/optifine/      upstream OptiFine CTM
  assets/factory_blocks/sounds.json    upstream custom metal sound (unreferenced)
  assets/factory_blocks/sounds/        upstream oggs
  assets/factory_blocks/lang/          upstream languages
  data/factory_blocks/horizon/block/   one declaration per block
  data/factory_blocks/horizon/creative_tab/blocks.json
  data/factory_blocks/loot_table/blocks/ upstream entries, 26.3 condition shape
  data/factory_blocks/recipe/factory.json upstream
  data/factory_blocks/tags/{block,item}/factory.json upstream
  data/minecraft/tags/block/           upstream additions
  tools/blocks.json                    the census the e2e reads

Upstream's blockstates carry `athena:loader`/`ctm_textures`, an Athena
loader extension. They are stripped so the 26.3 blockstate codec reads the
plain `variants`; the OptiFine `optifine/ctm/` assets are carried instead.

Everything is regenerated from scratch, so a rerun is deterministic.
"""
import json
import shutil
from pathlib import Path

PORT = Path(__file__).resolve().parents[1]
UPSTREAM = PORT.parent / "_shared" / "upstream" / "factory_blocks" / "common" / "src" / "main" / "resources"
CONTENT = PORT / "content"

# Upstream `RegisterBlocks.register` order (block/RegisterBlocks.java:65-105),
# with the kind that picks the declaration.
BASE = [
    "factory", "rust", "vrust", "srust", "wireframe", "pwireframe", "hazard",
    "hazardo", "circuit", "metalbox", "gcircuit", "pgcircuit", "grinder",
    "old_vents", "rust_plates", "bcircuit", "ice", "mosaic", "bwireframe",
    "rusty_scaffold", "caution", "large_pipes", "small_pipes", "vent", "gvent",
    "insulation", "gears", "cables", "rust_bplates", "grate", "rgrate", "hex",
    "wgpanel", "wopanel", "sturdy", "megacell", "exhaust", "engineer",
    "scaffold", "piping", "large_plating", "fan_side",
]
ALWAYS_ON = ["fan_on", "fan_four_on", "fan_malfunction_on"]
REDSTONE = ["fan", "fan_four", "fan_malfunction"]
MEDIUM = ["medium_fan"]
ORDER = BASE + ALWAYS_ON + REDSTONE + MEDIUM

FACINGS = ["north", "south", "east", "west"]

IRON_TEMPLATE = "minecraft:iron_block"
FACING_TEMPLATE = "minecraft:white_glazed_terracotta"

# `ofFullCopy(Blocks.IRON_BLOCK).strength(2.0f)` then a custom sound type.
# `strength(float)` sets hardness and explosion resistance together.
PROPERTIES = {
    "hardness": 2.0,
    "explosion_resistance": 2.0,
    # Upstream uses its own `factory_blocks:metal_sound` SoundType; a content
    # declaration may only name a vanilla block, so iron's metal sound stands in.
    "sounds": "minecraft:iron_block",
}

# Upstream's `MediumFanBlock.getShape` (block/fan/MediumFanBlock.java:20-33):
# north/south is 2x2x1, east/west is 1x2x2, both in block units.
MEDIUM_SHAPE = {
    "north": [[0.0, 0.0, 0.0, 2.0, 2.0, 1.0]],
    "south": [[0.0, 0.0, 0.0, 2.0, 2.0, 1.0]],
    "east": [[0.0, 0.0, 0.0, 1.0, 2.0, 2.0]],
    "west": [[0.0, 0.0, 0.0, 1.0, 2.0, 2.0]],
}

COPY_TREES = [
    ("assets/factory_blocks/sounds", ()),
    ("assets/factory_blocks/lang", ()),
    ("assets/factory_blocks/optifine", ()),
    ("data/factory_blocks/tags/block", ()),
    ("data/factory_blocks/tags/item", ()),
    ("data/minecraft/tags/block", ()),
]


def dump(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n")


def copy_tree(source_rel, dest_rel, skip_stems=()):
    source = UPSTREAM / source_rel
    dest = CONTENT / dest_rel
    for file in sorted(source.rglob("*")):
        if not file.is_file():
            continue
        if file.stem in skip_stems:
            continue
        target = dest / file.relative_to(source)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(file, target)


def write_loot_tables():
    """Carry the 49 self-drop tables in 26.3's pool-condition shape.

    Upstream (and NeoForge 1.21.1/26.1 datagen) writes

        "conditions": [{"condition": "minecraft:survives_explosion"}]

    whose element has no `type`, so Horizon's loot evaluator
    (`horizon-items/src/items.rs::LootContext::condition`) reads an empty kind,
    returns false and drops nothing. 26.3 spells a pool's condition as one
    typed object under the singular key:

        "condition": {"type": "minecraft:survives_explosion"}

    The entry list and rolls are upstream's; only the condition key changes.
    """
    source = UPSTREAM / "data/factory_blocks/loot_table/blocks"
    for name in ORDER:
        upstream = json.loads((source / f"{name}.json").read_text())
        pools = []
        for pool in upstream["pools"]:
            conditions = pool.get("conditions", [])
            if conditions != [{"condition": "minecraft:survives_explosion"}]:
                raise SystemExit(f"{name}: unexpected upstream pool conditions {conditions}")
            pools.append(
                {
                    "condition": {"type": "minecraft:survives_explosion"},
                    "entries": pool["entries"],
                    "rolls": pool["rolls"],
                }
            )
        dump(
            CONTENT / f"data/factory_blocks/loot_table/blocks/{name}.json",
            {"type": upstream["type"], "pools": pools},
        )


def main():
    if not UPSTREAM.is_dir():
        raise SystemExit(f"missing upstream analysis clone: {UPSTREAM}")
    if (CONTENT / "assets").exists():
        shutil.rmtree(CONTENT / "assets")
    if (CONTENT / "data").exists():
        shutil.rmtree(CONTENT / "data")

    # ------------------------------------------------------------ assets
    for name in ORDER:
        state = json.loads((UPSTREAM / f"assets/factory_blocks/blockstates/{name}.json").read_text())
        # Keep the variants; Athena's CTM keys are not part of a 26.3
        # blockstate definition.
        dump(CONTENT / f"assets/factory_blocks/blockstates/{name}.json", {"variants": state["variants"]})
        shutil.copy2(
            UPSTREAM / f"assets/factory_blocks/items/{name}.json",
            _ensure(CONTENT / f"assets/factory_blocks/items/{name}.json"),
        )
    copy_tree("assets/factory_blocks/models", "assets/factory_blocks/models", ("engineer1", "engineer2", "engineer3", "oldfan"))

    # Block textures. `textures/block/ctm/` holds the tiles the weighted
    # multi-model blockstates (piping, rust_bplates, wgpanel, wopanel) reference,
    # so they are carried even though the Athena blockstate keys are stripped.
    for file in sorted((UPSTREAM / "assets/factory_blocks/textures/block").rglob("*")):
        if not file.is_file():
            continue
        rel = file.relative_to(UPSTREAM / "assets/factory_blocks/textures/block")
        target = CONTENT / "assets/factory_blocks/textures/block" / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(file, target)

    shutil.copy2(UPSTREAM / "assets/factory_blocks/sounds.json", _ensure(CONTENT / "assets/factory_blocks/sounds.json"))
    for rel, skip in COPY_TREES:
        copy_tree(rel, rel, skip)
    copy_tree("data/factory_blocks/recipe", "data/factory_blocks/recipe", skip_stems=("mason_table", "mason_table_old"))
    write_loot_tables()

    # ------------------------------------------------------- declarations
    census = []
    for name in ORDER:
        if name in BASE:
            decl = {"template": IRON_TEMPLATE, "properties": dict(PROPERTIES)}
            states = [""]
        elif name in MEDIUM:
            decl = {
                "template": FACING_TEMPLATE,
                "properties": dict(PROPERTIES),
                "default_state": {"facing": "east"},
                "shapes": {"property": "facing", "values": MEDIUM_SHAPE},
            }
            states = [f"facing={facing}" for facing in FACINGS]
        elif name in ALWAYS_ON:
            decl = {
                "template": FACING_TEMPLATE,
                "properties": dict(PROPERTIES),
                "default_state": {"facing": "east"},
            }
            states = [f"facing={facing}" for facing in FACINGS]
        else:
            decl = {
                "template": FACING_TEMPLATE,
                "properties": dict(PROPERTIES),
                "state_properties": {"on": {"type": "boolean"}},
                "default_state": {"facing": "east"},
            }
            states = [f"facing={facing},on={on}" for facing in FACINGS for on in ("false", "true")]
        dump(CONTENT / f"data/factory_blocks/horizon/block/{name}.json", decl)
        census.append(
            {
                "id": f"factory_blocks:{name}",
                "kind": "base" if name in BASE else "medium" if name in MEDIUM else "fan" if name in ALWAYS_ON else "redstone_fan",
                "template": decl["template"],
                "states": states,
                "in_factory_tag": name != "medium_fan",
            }
        )

    dump(
        CONTENT / "data/factory_blocks/horizon/creative_tab/blocks.json",
        {"title": "Factory Blocks", "icon": "factory_blocks:factory", "items": [entry["id"] for entry in census]},
    )
    dump(
        PORT / "tools/blocks.json",
        {
            "source": "matthewperiut/factory_blocks@ecdb3591647cf2ff7a306e1e972d335966b119e5 (26.3-1.4.2)",
            "facings": FACINGS,
            "blocks": census,
            "total_states": sum(len(entry["states"]) for entry in census),
        },
    )
    print(f"census: {len(census)} blocks, {sum(len(e['states']) for e in census)} states")


def _ensure(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    return path


if __name__ == "__main__":
    main()
