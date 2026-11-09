// Factory Blocks for Horizon — the block census, state space and recipe (pure).
//
// Ported from Factory Blocks 1.4.2 (matthewperiut/factory_blocks, tag
// `26.3-1.4.2`) for Minecraft Java 26.3. Upstream source was read for
// behaviour only; this is a clean-room Rust rewrite. This is a data-tier
// port: the 49 blocks and items are declared in ../content, and this module
// is the single place their ids, kinds, template choices, state counts and
// the one crafting recipe are spelled out (`RegisterBlocks.register`,
// `BaseFanBlock`, `RedstoneFanBlock`, `MediumFanBlock`).

#[cfg(test)]
mod tests {
    /// A block whose only behaviour is `BaseFactoryBlock`: a full cube.
    pub const BASE_BLOCKS: [&str; 42] = [
        "factory",
        "rust",
        "vrust",
        "srust",
        "wireframe",
        "pwireframe",
        "hazard",
        "hazardo",
        "circuit",
        "metalbox",
        "gcircuit",
        "pgcircuit",
        "grinder",
        "old_vents",
        "rust_plates",
        "bcircuit",
        "ice",
        "mosaic",
        "bwireframe",
        "rusty_scaffold",
        "caution",
        "large_pipes",
        "small_pipes",
        "vent",
        "gvent",
        "insulation",
        "gears",
        "cables",
        "rust_bplates",
        "grate",
        "rgrate",
        "hex",
        "wgpanel",
        "wopanel",
        "sturdy",
        "megacell",
        "exhaust",
        "engineer",
        "scaffold",
        "piping",
        "large_plating",
        "fan_side",
    ];

    /// `BaseFanBlock` with no redstone: a full cube with a horizontal facing.
    pub const ALWAYS_ON_FANS: [&str; 3] = ["fan_on", "fan_four_on", "fan_malfunction_on"];

    /// `RedstoneFanBlock`: a horizontal facing plus upstream's `on` boolean.
    pub const REDSTONE_FANS: [&str; 3] = ["fan", "fan_four", "fan_malfunction"];

    /// `MediumFanBlock`: a horizontal facing and upstream's 2x2 outline.
    pub const MEDIUM_FANS: [&str; 1] = ["medium_fan"];

    /// The vanilla template a full-cube block copies (`ofFullCopy(IRON_BLOCK)`).
    pub const IRON_TEMPLATE: &str = "minecraft:iron_block";

    /// The vanilla template a fan copies: a full cube whose placement rule
    /// sets `facing` opposite the player's horizontal look (`GlazedTerracottaBlock`).
    pub const FACING_TEMPLATE: &str = "minecraft:white_glazed_terracotta";

    /// The four horizontal facings upstream's `HORIZONTAL_FACING` accepts.
    pub const FACINGS: [&str; 4] = ["north", "south", "east", "west"];

    /// Upstream's recipe pattern `ISI / S S / ISI`: five iron ingots.
    pub const RECIPE_IRON_INGOTS: u32 = 5;

    /// Upstream's recipe pattern `ISI / S S / ISI`: four stone.
    pub const RECIPE_STONE: u32 = 4;

    /// What the recipe yields.
    pub const RECIPE_OUTPUT: u32 = 32;

    /// Every block id in upstream registration order.
    pub fn all_blocks() -> Vec<&'static str> {
        let mut blocks = Vec::with_capacity(49);
        blocks.extend(BASE_BLOCKS);
        blocks.extend(ALWAYS_ON_FANS);
        blocks.extend(REDSTONE_FANS);
        blocks.extend(MEDIUM_FANS);
        blocks
    }

    /// States one block declares: 1, 4, 8 or 4.
    pub fn state_count(name: &str) -> usize {
        if BASE_BLOCKS.contains(&name) {
            1
        } else if ALWAYS_ON_FANS.contains(&name) || MEDIUM_FANS.contains(&name) {
            FACINGS.len()
        } else if REDSTONE_FANS.contains(&name) {
            2 * FACINGS.len()
        } else {
            0
        }
    }

    /// The vanilla template a block copies.
    pub fn template(name: &str) -> &'static str {
        if BASE_BLOCKS.contains(&name) {
            IRON_TEMPLATE
        } else if ALWAYS_ON_FANS.contains(&name)
            || REDSTONE_FANS.contains(&name)
            || MEDIUM_FANS.contains(&name)
        {
            FACING_TEMPLATE
        } else {
            ""
        }
    }

    /// Whether a block declares its own `on` state.
    pub fn declares_on(name: &str) -> bool {
        REDSTONE_FANS.contains(&name)
    }

    /// A block's box in block units for `facing`, as upstream's `getShape`
    /// returns it (a `MediumFanBlock` is 2x2 blocks wide/tall).
    pub fn shape(name: &str, facing: &str) -> Option<[f64; 6]> {
        if !MEDIUM_FANS.contains(&name) {
            return None;
        }
        match facing {
            "north" | "south" => Some([0.0, 0.0, 0.0, 2.0, 2.0, 1.0]),
            "east" | "west" => Some([0.0, 0.0, 0.0, 1.0, 2.0, 2.0]),
            _ => None,
        }
    }

    /// Whether a block is listed in upstream's `factory_blocks:factory` tag.
    pub fn in_factory_tag(name: &str) -> bool {
        name != "medium_fan" && all_blocks().contains(&name)
    }

    #[test]
    fn census_has_forty_nine_unique_blocks() {
        let blocks = all_blocks();
        assert_eq!(blocks.len(), 49, "upstream registers 49 blocks");
        let mut sorted = blocks.clone();
        sorted.sort_unstable();
        sorted.dedup();
        assert_eq!(sorted.len(), 49, "two blocks share an id");
        for name in blocks {
            assert_eq!(name, name.to_lowercase(), "{name} is not lower case");
            assert!(
                name.bytes()
                    .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'_'),
                "{name} is not an id path"
            );
        }
    }

    #[test]
    fn census_is_forty_two_plain_and_seven_fans() {
        assert_eq!(BASE_BLOCKS.len(), 42, "42 plain BaseFactoryBlocks");
        assert_eq!(ALWAYS_ON_FANS.len(), 3, "three BaseFanBlocks");
        assert_eq!(REDSTONE_FANS.len(), 3, "three RedstoneFanBlocks");
        assert_eq!(MEDIUM_FANS.len(), 1, "one MediumFanBlock");
        assert_eq!(
            BASE_BLOCKS.len() + ALWAYS_ON_FANS.len() + REDSTONE_FANS.len() + MEDIUM_FANS.len(),
            49
        );
    }

    #[test]
    fn state_counts_are_one_four_eight_and_four() {
        for name in BASE_BLOCKS {
            assert_eq!(state_count(name), 1, "{name} has no states");
        }
        for name in ALWAYS_ON_FANS {
            assert_eq!(state_count(name), FACINGS.len(), "{name} is facing only");
        }
        for name in REDSTONE_FANS {
            assert_eq!(
                state_count(name),
                2 * FACINGS.len(),
                "{name} is facing x on"
            );
        }
        for name in MEDIUM_FANS {
            assert_eq!(state_count(name), FACINGS.len(), "{name} is facing only");
        }
        assert_eq!(FACINGS.len(), 4);
    }

    #[test]
    fn the_total_state_space_is_eighty_two() {
        let total: usize = all_blocks().iter().map(|name| state_count(name)).sum();
        assert_eq!(total, 42 + 3 * 4 + 3 * 8 + 4);
        assert_eq!(total, 82);
    }

    #[test]
    fn templates_are_iron_block_and_glazed_terracotta() {
        assert_eq!(IRON_TEMPLATE, "minecraft:iron_block");
        assert_eq!(FACING_TEMPLATE, "minecraft:white_glazed_terracotta");
        for name in BASE_BLOCKS {
            assert_eq!(template(name), IRON_TEMPLATE, "{name}");
        }
        for name in ALWAYS_ON_FANS
            .iter()
            .chain(REDSTONE_FANS.iter())
            .chain(MEDIUM_FANS.iter())
        {
            assert_eq!(template(name), FACING_TEMPLATE, "{name}");
        }
    }

    #[test]
    fn only_the_redstone_fans_declare_on() {
        for name in REDSTONE_FANS {
            assert!(declares_on(name), "{name} declares upstream's `on`");
        }
        for name in BASE_BLOCKS
            .iter()
            .chain(ALWAYS_ON_FANS.iter())
            .chain(MEDIUM_FANS.iter())
        {
            assert!(!declares_on(name), "{name} has no `on`");
        }
    }

    #[test]
    fn every_medium_fan_faces_all_four_ways_and_is_two_by_two() {
        for name in MEDIUM_FANS {
            for facing in FACINGS {
                let box_ = shape(name, facing).unwrap_or_else(|| panic!("{name}/{facing}"));
                assert!(box_[0] <= box_[3] && box_[1] <= box_[4] && box_[2] <= box_[5]);
            }
        }
        // Upstream's MediumFanBlock: NORTH/SOUTH span 2 in x and y, EAST/WEST
        // span 2 in y and z (Blockbench's 32x32x16 and 16x32x32 model).
        assert_eq!(
            shape("medium_fan", "north"),
            Some([0.0, 0.0, 0.0, 2.0, 2.0, 1.0])
        );
        assert_eq!(
            shape("medium_fan", "south"),
            Some([0.0, 0.0, 0.0, 2.0, 2.0, 1.0])
        );
        assert_eq!(
            shape("medium_fan", "east"),
            Some([0.0, 0.0, 0.0, 1.0, 2.0, 2.0])
        );
        assert_eq!(
            shape("medium_fan", "west"),
            Some([0.0, 0.0, 0.0, 1.0, 2.0, 2.0])
        );
        for name in BASE_BLOCKS
            .iter()
            .chain(ALWAYS_ON_FANS.iter())
            .chain(REDSTONE_FANS.iter())
        {
            assert_eq!(shape(name, "north"), None, "{name} is a full cube");
        }
    }

    #[test]
    fn the_recipe_is_five_iron_and_four_stone_for_thirty_two() {
        assert_eq!(RECIPE_IRON_INGOTS, 5);
        assert_eq!(RECIPE_STONE, 4);
        assert_eq!(RECIPE_OUTPUT, 32);
        assert_eq!(RECIPE_IRON_INGOTS + RECIPE_STONE, 9);
    }

    #[test]
    fn every_block_is_in_the_factory_tag_except_the_medium_fan() {
        for name in all_blocks() {
            assert_eq!(
                in_factory_tag(name),
                name != "medium_fan",
                "{name} in the factory tag"
            );
        }
        assert!(!in_factory_tag("unknown"), "unknown ids are not in the tag");
    }
}
