#!/usr/bin/env python3
"""Verification for Beating Heart trinket acquire effects."""

from __future__ import annotations

import sys

BEATING_HEART_ID = "beating_heart"
BOOM_BERRY_3_ID = "boom_berry_3"
STARTING_LIVES = 3
MAX_LIVES = 4


def apply_beating_heart_acquire(
    lives: int,
    bag_ids: list[str],
    owned: list[str],
    has_berry_template: bool = True,
) -> tuple[int, list[str], list[str]]:
    if BEATING_HEART_ID in owned:
        return lives, bag_ids, owned
    owned = owned + [BEATING_HEART_ID]
    lives = min(MAX_LIVES, lives + 1)
    if has_berry_template:
        bag_ids = bag_ids + [BOOM_BERRY_3_ID]
    return lives, bag_ids, owned


def slots_to_show(remaining_lives: int, max_lives: int = MAX_LIVES) -> int:
    return max(STARTING_LIVES, min(remaining_lives, max_lives))


def main() -> int:
    lives, bag, owned = apply_beating_heart_acquire(STARTING_LIVES, [], [])
    assert lives == 4
    assert bag == [BOOM_BERRY_3_ID]
    assert owned == [BEATING_HEART_ID]

    lives, bag, owned = apply_beating_heart_acquire(STARTING_LIVES, [], owned)
    assert lives == STARTING_LIVES
    assert bag == []
    assert owned == [BEATING_HEART_ID]

    assert slots_to_show(3) == 3
    assert slots_to_show(4) == 4
    assert slots_to_show(2) == 3

    print("PASS: beating heart verification checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())