#!/usr/bin/env python3
"""Verification for Holy Grail explosion limit bonus ordering."""

from __future__ import annotations

import sys


def limit_bonus_for_played(ingredient_id: str, cauldron_ids: list[str]) -> int:
    if ingredient_id == "holy_grail":
        return 1
    if ingredient_id == "garlic":
        return 1 if cauldron_ids.count("garlic") <= 1 else 0
    return 0


def apply_play(
    explosiveness: int,
    explosion_limit: int,
    ingredient_id: str,
    explosive_add: int,
    cauldron_ids: list[str],
) -> tuple[int, int, bool]:
    cauldron_after = cauldron_ids + [ingredient_id]
    limit_bonus = limit_bonus_for_played(ingredient_id, cauldron_after)
    explosion_limit += limit_bonus
    explosiveness += explosive_add
    exploded = explosiveness >= explosion_limit
    return explosiveness, explosion_limit, exploded


def main() -> int:
    # Holy grail with cobbler adjacency bonus (+2 explosive) at 6/8 should end at 8/9, not explode.
    exp, limit, exploded = apply_play(6, 8, "holy_grail", 2, ["cobbler"])
    assert limit == 9, limit
    assert exp == 8, exp
    assert not exploded

    # Playing limit bonus before explosiveness lets a later card use the raised cap.
    exp, limit, exploded = apply_play(6, 8, "holy_grail", 0, [])
    assert limit == 9 and exp == 6 and not exploded
    exp, limit, exploded = apply_play(exp, limit, "boom_berry_red", 2, ["holy_grail"])
    assert exp == 8 and limit == 9 and not exploded

    print("PASS: holy grail verification checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())