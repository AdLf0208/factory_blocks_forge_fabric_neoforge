#!/usr/bin/env bash
# Prove the built content package (content/factory_blocks.hmod) loads on a real
# game: the shared, unmodded 1d63e0a5 game with `--dev-mod <the .hmod>` must
# register representative blocks and items. A second launch WITHOUT --dev-mod
# is the negative control: the same ids must be unknown there, so the check
# cannot pass vacuously.
set -euo pipefail
export LC_ALL=C

CLONE=${CAMPAIGN_ROOT:?set CAMPAIGN_ROOT to a checkout of the ATM10-Horizon campaign tree}
PIN_BIN=$CLONE/ports/_shared/bin/horizon-1d63e0a5
CTL=${CTL:-$PIN_BIN/horizon-ctl}
GAME=${GAME:-$PIN_BIN/horizon-client}
HMOD=${HMOD:-$CLONE/ports/factory_blocks/content/factory_blocks.hmod}
RES=${RES:-${HORIZON_RES:-.local/horizon-client/26.3}}
SOCK=${SOCK:-/tmp/opencode/factory_blocks-hmod-load.sock}

[ -x "$CTL" ] || { echo "missing horizon-ctl: $CTL" >&2; exit 1; }
[ -x "$GAME" ] || { echo "missing horizon-client: $GAME" >&2; exit 1; }
[ -f "$HMOD" ] || { echo "missing package: $HMOD" >&2; exit 1; }
[ -d "$RES/assets" ] || { echo "missing prepared resources: $RES" >&2; exit 1; }

SCRATCH=$(mktemp -d /tmp/opencode/factory_blocks-hmod-home.XXXXXX)
export HORIZON_HOME=$SCRATCH/game
export HORIZON_LAUNCHER_HOME=$SCRATCH/launcher
export XDG_DATA_HOME=$SCRATCH/data
export XDG_CONFIG_HOME=$SCRATCH/config
export HORIZON_NO_AUDIO=1
mkdir -p "$(dirname "$SOCK")" "$XDG_CONFIG_HOME"
rm -f "$SOCK"
cd "$SCRATCH"

ctl() { "$CTL" --socket "$SOCK" "$@"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

cleanup() {
    ctl quit >/dev/null 2>&1 || true
    sleep 1
    rm -rf "$SCRATCH" 2>/dev/null || true
}
trap cleanup EXIT

launch() { # world [extra args...]
    local world=$1; shift
    rm -f "$SOCK"
    "$CTL" --socket "$SOCK" launch \
        --game "$GAME" --world "$world" --seed 20261106 --creative --headless --wait \
        --game-dir "$SCRATCH/game" --resources "$RES" "$@" >/dev/null
    ctl wait-ready 120
    ctl command "execute in minecraft:the_end run tp @s 0.5 80 2.5" >/dev/null
    ctl wait 20
}

CASES=(
    "0 80 0 factory_blocks:factory factory_blocks:factory"
    "2 80 0 factory_blocks:fan factory_blocks:fan[facing=east,on=false]"
    "4 80 0 factory_blocks:medium_fan factory_blocks:medium_fan[facing=east]"
)

echo "== launch WITH the package (--dev-mod $HMOD) =="
launch FactoryBlocksHmod --dev-mod "$HMOD"
ctl command "execute in minecraft:the_end run fill -4 79 -4 8 79 8 minecraft:stone" >/dev/null
ctl command "execute in minecraft:the_end run fill -4 80 -4 8 88 8 minecraft:air" >/dev/null
ctl wait 4
for case_ in "${CASES[@]}"; do
    set -- $case_
    ctl command "execute in minecraft:the_end run setblock $1 $2 $3 $4" >/dev/null
    ctl wait 2
    got=$(ctl block "$1" "$2" "$3" | jq -r '.state // .block // .name // "unknown"')
    echo "block $1,$2,$3 = $got"
    [ "$got" = "$5" ] || fail "the package did not register $4 as $5 (read '$got')"
done
ctl give factory_blocks:factory 1 >/dev/null
ctl wait 4
ctl inventory | jq -e '[.counts["factory_blocks:factory"] // 0] | .[0] >= 1' >/dev/null \
    || fail "the package did not register the factory block item"
echo "item factory_blocks:factory = $(ctl inventory | jq -r '.counts["factory_blocks:factory"] // 0')"
ctl quit >/dev/null 2>&1 || true
sleep 2

echo "== negative control: the SAME ids without --dev-mod =="
launch FactoryBlocksHmodControl
ctl command "execute in minecraft:the_end run fill -4 79 -4 8 79 8 minecraft:stone" >/dev/null
ctl command "execute in minecraft:the_end run fill -4 80 -4 8 88 8 minecraft:air" >/dev/null
ctl wait 4
for case_ in "${CASES[@]}"; do
    set -- $case_
    ctl command "execute in minecraft:the_end run setblock $1 $2 $3 $4" >/dev/null 2>&1 || true
    ctl wait 2
    got=$(ctl block "$1" "$2" "$3" | jq -r '.state // .block // .name // "unknown"')
    echo "control block $1,$2,$3 = $got"
    [ "$got" = "minecraft:air" ] || fail "$4 became '$got' without the package, so the load check is not discriminating"
done
if ctl give factory_blocks:factory 1 >/dev/null 2>&1; then
    fail "give factory_blocks:factory succeeded without the package"
fi
echo "control: all three ids are unknown without the package"

echo "PASS: the .hmod registers factory/fan/medium_fan and the factory item; without it the same ids are refused"
