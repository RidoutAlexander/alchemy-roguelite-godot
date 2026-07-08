#!/usr/bin/env python3
"""Verification for Time Turner hand redraw exclusion rules."""

from __future__ import annotations

import sys


def draw_excluding_instances(
    working: list[str],
    excluded: list[str],
    count: int,
) -> list[str] | None:
    pool = [chip for chip in working if chip not in excluded]
    if len(pool) < count:
        return None
    picked: list[str] = []
    for _ in range(count):
        chosen = pool.pop(0)
        picked.append(chosen)
        working.remove(chosen)
    return picked


def main() -> int:
    working = ["rat_a", "rat_b", "pumpkin_a", "mushroom_a", "bat_a"]
    hand = ["rat_a", "pumpkin_a"]
    working_after_return = working + hand
    redraw = draw_excluding_instances(
        working_after_return.copy(),
        hand,
        len(hand),
    )
    assert redraw is not None
    assert "rat_a" not in redraw
    assert "pumpkin_a" not in redraw
    assert redraw == ["rat_b", "mushroom_a"]

    short_bag = ["rat_a", "pumpkin_a"]
    failed = draw_excluding_instances(short_bag, hand, len(hand))
    assert failed is None

    print("PASS: time turner verification checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())