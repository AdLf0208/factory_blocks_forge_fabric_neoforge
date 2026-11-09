#!/usr/bin/env python3
"""Craft Factory Blocks' one recipe in a real crafting table.

Upstream 1.4.2 ships exactly one crafting recipe
(`data/factory_blocks/recipe/factory.json`):

    I S I        I = minecraft:iron_ingot (5)
    S   S        S = minecraft:stone      (4)
    I S I        -> 32 x factory_blocks:factory

Called by tools/e2e.sh with the open game's control socket. Uses the
harness's crafting grid (`ctl screen`: slots 100-108 row-major, result 200),
gives the ingredients and asserts:

1. the pattern crafts 32 `factory_blocks:factory`, and the stack reaches the
   inventory;
2. the same pattern with cobblestone instead of stone stays empty (wrong
   ingredient control);
3. one missing stone (three stones) stays empty (the pattern needs all four);
4. an extra stick in the centre stays empty (the centre must be empty);
5. nine stone stays empty (no stone-only recipe).

The table is replaced before every case, so a failed/untaken result cannot
leak into the next grid. Exits 1 with the observed result on the first
mismatch.
"""
import json
import subprocess
import sys

# 3x3 grid: row-major slots 100..108, result 200.
IRON_SLOTS = [100, 102, 106, 108]
STONE_SLOTS = [101, 103, 105, 107]
CENTRE = 104
ALL_NINE = [100, 101, 102, 103, 104, 105, 106, 107, 108]


def main():
    sock, ctl, x, y, z = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]

    def run(*args):
        out = subprocess.run([ctl, "--socket", sock, *args], text=True, capture_output=True)
        try:
            return json.loads(out.stdout)
        except json.JSONDecodeError:
            raise SystemExit(f"ctl {' '.join(args)}: {out.stdout}{out.stderr}")

    def wait(ticks=4):
        run("wait", str(ticks))

    def slots():
        screen = run("screen")
        if "slots" not in screen:
            raise SystemExit(f"no menu is open: {screen}")
        return screen["slots"]

    def find(item):
        for slot in slots():
            if slot.get("item") == item:
                return slot["slot"]
        raise SystemExit(f"missing ingredient {item} in the inventory")

    def open_table():
        wait()
        print("debug interact:", run("interact", x, y, z))
        wait(5)

    def result():
        stack = [s for s in slots() if s["slot"] == 200]
        if not stack or not stack[0].get("item"):
            return None
        return stack[0]

    def place(item, targets):
        slot = find(item)
        run("click-slot", str(slot))
        wait(1)
        for target in targets:
            # One item per cell: a right click splits the held stack.
            run("click-slot", str(target), "right")
            wait(1)
        run("click-slot", str(slot))
        wait(2)

    def setup(items):
        try:
            run("close")
        except SystemExit:
            pass
        wait(5)
        # A fresh table means a fresh crafting grid for every case.
        run("setblock", x, y, z, "minecraft:air")
        run("setblock", x, y, z, "minecraft:crafting_table")
        wait(2)
        print("debug tp:", run("command", f"tp @s {float(x) - 0.5} {y} {float(z) + 0.5}"))
        wait(3)
        run("command", "clear @s")
        for item, count in items:
            run("give", item, str(count))
        wait(3)
        open_table()

    failures = []

    def check(label, items, placements, want_item, want_count):
        setup(items)
        for item, targets in placements:
            place(item, targets)
        got = result()
        print(f"{label} ->", json.dumps(got))
        if not got or got.get("item") != want_item or got.get("count") != want_count:
            failures.append(f"{label}: expected {want_count} {want_item}, got {got}")
            return None
        return got

    def empty_control(label, items, placements):
        setup(items)
        for item, targets in placements:
            place(item, targets)
        got = result()
        print(f"{label} ->", json.dumps(got))
        if got is not None:
            failures.append(f"{label}: control crafted {got['item']} x{got['count']}")

    pattern = [
        ("minecraft:iron_ingot", IRON_SLOTS),
        ("minecraft:stone", STONE_SLOTS),
    ]

    # 1. The real recipe: 5 iron + 4 stone -> 32 Factory Blocks.
    setup([("minecraft:iron_ingot", 5), ("minecraft:stone", 4)])
    for item, targets in pattern:
        place(item, targets)
    got = result()
    print("5 iron + 4 stone ->", json.dumps(got))
    if not got or got.get("item") != "factory_blocks:factory" or got.get("count") != 32:
        failures.append("the factory recipe did not yield 32 factory_blocks:factory")
    else:
        run("click-slot", "200")
        wait(5)
        run("click-slot", "9")
        wait(3)
        made = run("inventory")["counts"].get("factory_blocks:factory", 0)
        if made < 32:
            failures.append(f"the crafted factory blocks reached the inventory as {made}, not 32")

    # 2. The wrong ingredient: cobblestone in stone's cells.
    empty_control(
        "5 iron + 4 cobblestone",
        [("minecraft:iron_ingot", 5), ("minecraft:cobblestone", 4)],
        [("minecraft:iron_ingot", IRON_SLOTS), ("minecraft:cobblestone", STONE_SLOTS)],
    )

    # 3. One stone missing: the shaped pattern needs all four.
    empty_control(
        "5 iron + 3 stone",
        [("minecraft:iron_ingot", 5), ("minecraft:stone", 3)],
        [("minecraft:iron_ingot", IRON_SLOTS), ("minecraft:stone", STONE_SLOTS[:3])],
    )

    # 4. An extra item in the centre: the centre must be empty.
    empty_control(
        "5 iron + 4 stone + stick in the centre",
        [("minecraft:iron_ingot", 5), ("minecraft:stone", 4), ("minecraft:stick", 1)],
        [
            ("minecraft:iron_ingot", IRON_SLOTS),
            ("minecraft:stone", STONE_SLOTS),
            ("minecraft:stick", [CENTRE]),
        ],
    )

    # 5. Nine stone: no stone-only recipe.
    empty_control("9 stone", [("minecraft:stone", 9)], [("minecraft:stone", ALL_NINE)])

    run("close")
    wait(3)
    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        raise SystemExit(1)
    print(
        "recipe PASS: 5 iron + 4 stone -> 32 factory blocks; cobblestone, "
        "missing-stone, centre-stick and all-stone controls stay empty"
    )


if __name__ == "__main__":
    main()
