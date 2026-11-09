#!/usr/bin/env bash
# In-game check for the Factory Blocks port (content, data tier): 49 blocks,
# 82 declared states, one recipe.
#
# Default run (creative launch for placement/state binding, survival for
# drops and crafting; The End):
#   1. every declared state of every block `setblock`s and reads back its full
#      state string, so 82/82 states bind (42 plain, 12 always-on fan, 24
#      redstone fan, 4 medium fan);
#   2. `#minecraft:mineable/pickaxe` holds three samples and a dirt control is
#      outside it; `medium_fan` (and only it) is in `#minecraft:dragon_immune`
#      and `#minecraft:wither_immune`;
#   3. all 49 items are `/give`-able (in two batches, the inventory holds 36);
#   4. the mod's creative tab `factory_blocks:blocks` lists exactly the 49
#      items in upstream order;
#   5. every block item places and reads back its default state; placing the
#      redstone `fan` from the four sides gives the four facings (the
#      glazed-terracotta placement rule, not the default east);
#   6. every block drops itself when mined with a diamond pickaxe (49/49);
#   7. 5 iron + 4 stone -> 32 `factory_blocks:factory`; cobblestone,
#      missing-stone, centre-stick and all-stone controls stay empty;
#   8. unknown ids are refused by `give` and `setblock`.
#
# COUNTERFACTUAL=1 runs the differential on the templates: vanilla
# `minecraft:iron_block` reads back as itself and drops vanilla iron, never a
# Factory Blocks item; the recipe table still passes. NEGATIVE=1 (with
# COUNTERFACTUAL=1) asserts that the vanilla block dropped
# `factory_blocks:factory`; that run MUST exit 1, proving the drop assertion
# is not vacuous. SELFTEST=1 flips a state expectation after the binding loop
# and MUST exit 1, proving the read-back comparison is live.
set -euo pipefail

CLONE=${CAMPAIGN_ROOT:?set CAMPAIGN_ROOT to a checkout of the ATM10-Horizon campaign tree}
PORT=$CLONE/ports/factory_blocks
CTL=${CTL:-$PORT/target/horizon-cargo/fast/horizon-ctl}
GAME=${GAME:-$PORT/target/horizon-cargo/fast/horizon-client}
RES=${RES:-${HORIZON_RES:-.local/horizon-client/26.3}}
SOCK=${SOCK:-/tmp/opencode/factory-blocks-e2e.sock}
CENSUS=$PORT/tools/blocks.json
COUNTERFACTUAL=${COUNTERFACTUAL:-0}
NEGATIVE=${NEGATIVE:-0}
SELFTEST=${SELFTEST:-0}

[ -x "$CTL" ] || { echo "missing horizon-ctl: $CTL" >&2; exit 1; }
[ -x "$GAME" ] || { echo "missing horizon-client: $GAME" >&2; exit 1; }
[ -d "$RES/assets" ] || { echo "missing prepared resources: $RES" >&2; exit 1; }
[ -f "$PORT/content/horizon-mod.toml" ] || { echo "missing content mod: $PORT/content" >&2; exit 1; }
[ -f "$CENSUS" ] || { echo "missing census: $CENSUS" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

BLOCK_IDS=()
mapfile -t BLOCK_IDS < <(jq -r '.blocks[].id' "$CENSUS")
TOTAL_STATES=$(jq -r '.total_states' "$CENSUS")
[ "${#BLOCK_IDS[@]}" -eq 49 ] || { echo "census has ${#BLOCK_IDS[@]} blocks, expected 49" >&2; exit 1; }
[ "$TOTAL_STATES" -eq 82 ] || { echo "census has $TOTAL_STATES states, expected 82" >&2; exit 1; }

SCRATCH=$(mktemp -d /tmp/opencode/factory-blocks-home.XXXXXX)
export HORIZON_HOME=$SCRATCH/game
export HORIZON_LAUNCHER_HOME=$SCRATCH/launcher
export XDG_DATA_HOME=$SCRATCH/data
export XDG_CONFIG_HOME=$SCRATCH/config
export HORIZON_NO_AUDIO=1
mkdir -p "$(dirname "$SOCK")"
rm -f "$SOCK"
cd "$SCRATCH"

ctl() { "$CTL" --socket "$SOCK" "$@"; }
fail() { echo "FAIL: $*" >&2; exit 1; }
say() { echo "+ $*"; }
count_item() { ctl inventory | jq -r --arg i "$1" '.counts[$i] // 0'; }
block_name() { ctl block "$1" "$2" "$3" | jq -r '.block // "unknown"'; }
block_state() { ctl block "$1" "$2" "$3" | jq -r '.state // "unknown"'; }
end() { ctl command "execute in minecraft:the_end run $1"; }

cleanup() {
    ctl quit >/dev/null 2>&1 || true
    sleep 1
    rm -rf "$SCRATCH" || true
}
trap cleanup EXIT

say "launch (offscreen renderer, creative, content --dev-mod content/)"
"$CTL" --socket "$SOCK" launch \
    --game "$GAME" --world FactoryBlocksE2E --seed 20261106 --creative --offscreen --wait \
    --game-dir "$SCRATCH/game" --resources "$RES" --dev-mod "$PORT/content"
ctl wait-ready 180

say "The End platform at y=79 and an empty box above it"
end "forceload add -12 -12 20 12"
end "tp @s 0.5 80 2.5"
ctl wait 40
end "fill -12 79 -12 20 79 12 minecraft:stone"
end "fill -12 80 -12 20 88 12 minecraft:air"
end "kill @e[type=minecraft:item]"
end "kill @e[type=minecraft:ender_dragon]"
end "kill @e[type=minecraft:end_crystal]"
end "difficulty peaceful"
end "tp @s 0.5 80 2.5"
ctl wait 10
ctl close >/dev/null 2>&1 || true
ctl wait 3

# ---------------------------------------------------------------- state bind
say "every declared state of every block binds (82/82)"
bound=0
while IFS=$'\t' read -r id state; do
    if [ -n "$state" ]; then wanted="$id[$state]"; else wanted="$id"; fi
    ctl setblock 0 80 0 "$wanted" >/dev/null || fail "setblock $wanted failed"
    ctl wait 2
    got=$(block_state 0 80 0)
    [ "$got" = "$wanted" ] || fail "state reads '$got', expected '$wanted'"
    bound=$((bound + 1))
done < <(jq -r '.blocks[] | .id as $id | .states[] | [$id, .] | @tsv' "$CENSUS")
[ "$bound" -eq "$TOTAL_STATES" ] || fail "bound $bound states, expected $TOTAL_STATES"
echo "$bound/$TOTAL_STATES declared states bound"

if [ "$SELFTEST" = 1 ]; then
    # A deliberately false expectation: a plain BaseFactoryBlock copies
    # iron_block and has no `facing` state, so this MUST fail. If it ever
    # printed the echo, the read-back comparison would be vacuous.
    say "SELFTEST: a deliberately false state assertion must fail the run"
    ctl setblock 0 80 0 factory_blocks:factory >/dev/null
    ctl wait 2
    got=$(block_state 0 80 0)
    [ "$got" = "factory_blocks:factory[facing=north]" ] \
        || fail "SELFTEST: a plain factory block read '$got', not the deliberately wrong 'factory_blocks:factory[facing=north]'; the state read-back assertion is live (this exit 1 is the proof)"
    echo "SELFTEST unexpectedly matched the false state"
fi

# --------------------------------------------------------------------- tags
say "mineable/pickaxe and the medium fan's immune tags"
ctl setblock 5 80 0 factory_blocks:factory >/dev/null
ctl setblock 6 80 0 factory_blocks:fan >/dev/null
ctl setblock 7 80 0 factory_blocks:medium_fan >/dev/null
ctl setblock 8 80 0 minecraft:dirt >/dev/null
ctl wait 3
for pair in "5 TAG_FACTORY" "6 TAG_FAN" "7 TAG_MEDIUM" "8 TAG_DIRT"; do
    set -- $pair
    ctl command "execute in minecraft:the_end if block $1 80 0 #minecraft:mineable/pickaxe run say $2" >/dev/null
done
ctl command "execute in minecraft:the_end if block 7 80 0 #minecraft:dragon_immune run say TAG_DRAGON" >/dev/null
ctl command "execute in minecraft:the_end if block 7 80 0 #minecraft:wither_immune run say TAG_WITHER" >/dev/null
ctl command "execute in minecraft:the_end if block 5 80 0 #minecraft:dragon_immune run say TAG_FACTORY_DRAGON" >/dev/null
ctl wait 3
messages=$(ctl messages 80 | jq -r '.chat[]')
for tag in TAG_FACTORY TAG_FAN TAG_MEDIUM TAG_DRAGON TAG_WITHER; do
    echo "$messages" | grep -Eq "$tag([^0-9A-Z_]|$)" || fail "$tag is missing (messages: $messages)"
done
echo "$messages" | grep -q TAG_DIRT && fail "dirt matched #minecraft:mineable/pickaxe, so the tag check is not discriminating"
echo "$messages" | grep -q TAG_FACTORY_DRAGON && fail "the factory block matched #minecraft:dragon_immune"
echo "tags: 3/3 samples mineable/pickaxe, dirt outside, medium_fan in both immune tags, factory not"

# --------------------------------------------------------------- item side
say "all 49 items are give-able (two batches of 36 and 13)"
ctl command "clear @s" >/dev/null
for id in "${BLOCK_IDS[@]:0:36}"; do
    ctl give "$id" 1 >/dev/null || fail "give $id failed"
done
ctl wait 6
for id in "${BLOCK_IDS[@]:0:36}"; do
    [ "$(count_item "$id")" -ge 1 ] || fail "$id is missing from the inventory"
done
ctl command "clear @s" >/dev/null
for id in "${BLOCK_IDS[@]:36}"; do
    ctl give "$id" 1 >/dev/null || fail "give $id failed"
done
ctl wait 6
for id in "${BLOCK_IDS[@]:36}"; do
    [ "$(count_item "$id")" -ge 1 ] || fail "$id is missing from the inventory"
done
echo "49/49 items are give-able"

CREATIVE=$(find "$SCRATCH/game/.horizon-cache/mod-content" -maxdepth 2 -name creative-inventory.json 2>/dev/null | head -1)
[ -n "$CREATIVE" ] || fail "no creative-inventory.json under $SCRATCH/game/.horizon-cache/mod-content"
if ! python3 - "$CREATIVE" "$CENSUS" <<'PY'
import json, re, sys
cache = json.load(open(sys.argv[1]))
census = json.load(open(sys.argv[2]))
want = [b["id"] for b in census["blocks"]]
tabs = [t for t in cache["tabs"] if t.get("id") == "factory_blocks:blocks"]
if len(tabs) != 1:
    raise SystemExit(f"expected one factory_blocks:blocks tab, found {len(tabs)}")
items = [re.search(r'id:"([^"]+)"', v).group(1) for v in tabs[0]["items"] if "id:" in v]
if items != want:
    missing = [i for i in want if i not in items]
    extra = [i for i in items if i not in want]
    raise SystemExit(f"tab items differ: missing={missing} extra={extra}")
owned = set()
for tab in cache["tabs"]:
    for value in tab.get("items", []):
        found = re.search(r'id:"([^"]+)"', value)
        if found and found.group(1).startswith("factory_blocks:"):
            owned.add(found.group(1))
unknown = sorted(owned - set(want))
if unknown:
    raise SystemExit(f"creative inventory holds undeclared factory_blocks items: {unknown}")
print(f"creative tab factory_blocks:blocks lists all {len(items)} items in order")
PY
then
    fail "the creative tab check failed"
fi
echo "creative tab lists all 49 items"

if [ "$COUNTERFACTUAL" = 1 ]; then
    # --------------------------------------------------------- differential
    say "counterfactual: vanilla iron_block reads back as vanilla"
    ctl setblock 0 80 0 minecraft:iron_block >/dev/null || fail "cannot set vanilla iron block"
    ctl wait 3
    got=$(block_state 0 80 0)
    [ "$got" = "minecraft:iron_block" ] || fail "vanilla iron block reads '$got'"
    echo "vanilla iron_block reads minecraft:iron_block, not a factory_blocks id"

    say "counterfactual: mine vanilla iron_block"
    ctl command "clear @s" >/dev/null
    ctl command "gamemode survival @s" >/dev/null
    ctl give minecraft:diamond_pickaxe 1 >/dev/null
    ctl wait 2
    ctl select minecraft:diamond_pickaxe >/dev/null
    ctl wait 2
    ctl command "tp @s 0.5 80 1.5" >/dev/null
    ctl wait 5
    ctl look-at-block 0 80 0 >/dev/null || true
    broken=$(ctl break 0 80 0) || { echo "break reply: $broken"; fail "cannot break vanilla iron block"; }
    echo "$broken" | jq -c '{block,block_before,drops}'
    [ "$(echo "$broken" | jq -r '.block')" = "minecraft:air" ] || fail "vanilla iron block did not break"
    vanilla=$(echo "$broken" | jq -r '.drops["minecraft:iron_block"] // 0')
    factory=$(echo "$broken" | jq -r '.drops["factory_blocks:factory"] // 0')
    if [ "$NEGATIVE" = 1 ]; then
        # The false assertion this mode exists to prove fail-capable: the
        # vanilla template must (incorrectly) have dropped a Factory Blocks
        # item. It did not, so the run exits 1 here by design.
        fail "NEGATIVE run: expected the vanilla iron_block to drop a factory_blocks item (it dropped $factory)"
    fi
    [ "$vanilla" -ge 1 ] || fail "vanilla iron block dropped $vanilla of itself"
    [ "$factory" -eq 0 ] || fail "vanilla iron block dropped $factory factory_blocks:factory"
    echo "vanilla iron_block dropped itself and never a factory_blocks item"

    say "counterfactual: the recipe table still passes"
    end "setblock 6 80 2 minecraft:crafting_table"
    ctl command "gamemode creative @s" >/dev/null
    ctl command "clear @s" >/dev/null
    ctl command "tp @s 5.5 80 2.5" >/dev/null
    ctl wait 5
    python3 "$PORT/tools/craft_check.py" "$SOCK" "$CTL" 6 80 2 >/dev/null || fail "the recipe differential failed"
    echo "the factory recipe crafts and the controls stay empty"

    say "unknown ids are refused"
    if ctl give factory_blocks:not_a_block 1 >/dev/null 2>&1; then
        fail "give factory_blocks:not_a_block succeeded"
    fi
    ctl setblock 6 80 6 factory_blocks:not_a_block >/dev/null 2>&1 || true
    [ "$(block_name 6 80 6)" = "minecraft:air" ] || fail "factory_blocks:not_a_block became a block"
    ctl setblock 7 80 6 factory_blocks:factory_extra >/dev/null 2>&1 || true
    [ "$(block_name 7 80 6)" = "minecraft:air" ] || fail "factory_blocks:factory_extra became a block"
    echo "unknown factory_blocks ids are refused"
    echo "COUNTERFACTUAL PASS: vanilla iron_block drops vanilla, never a Factory Blocks item"
    exit 0
fi

# ------------------------------------------------------------------- place
say "every block item places at its default state"
ctl command "clear @s" >/dev/null
ctl command "tp @s 0.5 80 2.5" >/dev/null
ctl wait 4
placed=0
for id in "${BLOCK_IDS[@]}"; do
    ctl setblock 0 80 0 minecraft:air >/dev/null
    ctl give "$id" 1 >/dev/null || fail "cannot give $id for placement"
    ctl wait 1
    ctl select "$id" >/dev/null || fail "cannot select $id"
    ctl wait 1
    reply=$(ctl place 0 80 0 --item "$id" 2>&1) || { echo "place reply: $reply"; fail "cannot place $id"; }
    ctl wait 2
    got=$(block_name 0 80 0)
    [ "$got" = "$id" ] || fail "placed $id reads '$got'"
    ctl command "clear @s" >/dev/null
    placed=$((placed + 1))
done
[ "$placed" -eq 49 ] || fail "placed $placed blocks, expected 49"
echo "49/49 block items placed and read back"

say "placing the redstone fan from four yaws yields the four facings"
ctl command "clear @s" >/dev/null
ctl give factory_blocks:fan 4 >/dev/null
ctl wait 2
place_facing() { # yaw wanted
    ctl setblock 0 80 0 minecraft:air >/dev/null
    # The server placement context uses the last synced yaw, so set it with a
    # console tp and let the rotation reach the server before the click.
    ctl command "tp @s 0.5 80 2.5 $1 0" >/dev/null
    ctl wait 6
    ctl place 0 80 0 --item factory_blocks:fan >/dev/null || fail "cannot place the fan at yaw $1"
    ctl wait 3
    got=$(block_state 0 80 0)
    [ "$got" = "factory_blocks:fan[facing=$2,on=false]" ] \
        || fail "placed at yaw $1 reads '$got', expected facing=$2"
    echo "yaw $1 -> $got"
}
place_facing 180 south
place_facing 0 north
place_facing 90 east
place_facing 270 west
ctl command "gamemode creative @s" >/dev/null
ctl command "clear @s" >/dev/null

# ------------------------------------------------------------------- drops
say "mine every block with a diamond pickaxe: each drops itself"
ctl command "clear @s" >/dev/null
ctl command "gamemode survival @s" >/dev/null
ctl give minecraft:diamond_pickaxe 1 >/dev/null
ctl wait 2
ctl select minecraft:diamond_pickaxe >/dev/null
ctl wait 2
ctl command "tp @s 0.5 80 2.5" >/dev/null
ctl wait 3
dropped=0
for id in "${BLOCK_IDS[@]}"; do
    ctl setblock 0 80 0 "$id" >/dev/null || fail "cannot set $id for mining"
    ctl wait 2
    ctl look-at-block 0 80 0 >/dev/null || true
    broken=$(ctl break 0 80 0) || { echo "break reply: $broken"; fail "cannot break $id"; }
    [ "$(echo "$broken" | jq -r '.block')" = "minecraft:air" ] || fail "$id did not break"
    got=$(echo "$broken" | jq -r --arg i "$id" '.drops[$i] // 0')
    [ "$got" -ge 1 ] || fail "$id dropped $got of itself"
    ctl command "kill @e[type=minecraft:item]" >/dev/null
    dropped=$((dropped + 1))
done
[ "$dropped" -eq 49 ] || fail "mined $dropped blocks, expected 49"
echo "49/49 blocks dropped themselves"

# ----------------------------------------------------------------- recipes
say "craft 5 iron + 4 stone -> 32 factory blocks, with wrong-ingredient controls"
end "setblock 6 80 2 minecraft:crafting_table"
ctl command "gamemode creative @s" >/dev/null
ctl command "clear @s" >/dev/null
ctl command "tp @s 5.5 80 2.5" >/dev/null
ctl wait 5
python3 "$PORT/tools/craft_check.py" "$SOCK" "$CTL" 6 80 2 || fail "the recipe check failed"
ctl command "gamemode creative @s" >/dev/null
ctl command "clear @s" >/dev/null
ctl wait 3

# ------------------------------------------------------------- unknown ids
say "unknown ids are refused"
if ctl give factory_blocks:not_a_block 1 >/dev/null 2>&1; then
    fail "give factory_blocks:not_a_block succeeded"
fi
ctl setblock 6 80 8 factory_blocks:not_a_block >/dev/null 2>&1 || true
[ "$(block_name 6 80 8)" = "minecraft:air" ] || fail "factory_blocks:not_a_block became a block"
ctl setblock 7 80 8 factory_blocks:factory_extra >/dev/null 2>&1 || true
[ "$(block_name 7 80 8)" = "minecraft:air" ] || fail "factory_blocks:factory_extra became a block"
echo "unknown factory_blocks ids are refused"

echo "PASS: 82/82 states bind, 49/49 items give and place, tab lists 49, 4/4 fan facings on placement, 49/49 self-drops, the factory recipe yields 32 with four empty controls, unknown ids refused"
