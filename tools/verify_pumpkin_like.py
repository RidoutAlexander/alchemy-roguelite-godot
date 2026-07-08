#!/usr/bin/env python3
"""Verification for pumpkin-like ingredient grouping (pumpkin + jack-o-lantern)."""

from __future__ import annotations

PUMPKIN_ID = "pumpkin"
JACK_O_LANTERN_ID = "jackolantern"
PUMPKIN_TRINKET_STREAK_CAP = 3


def is_pumpkin_like_id(ingredient_id: str) -> bool:
    normalized = ingredient_id.lower()
    return normalized == PUMPKIN_ID or normalized == JACK_O_LANTERN_ID


def count_trailing_pumpkin_streak(
    cauldron_ids: list[str],
    exclude_last_entry: bool = False,
) -> int:
    streak = 0
    last_index = len(cauldron_ids) - 1
    if exclude_last_entry:
        last_index -= 1
    for entry_id in reversed(cauldron_ids[: last_index + 1]):
        if is_pumpkin_like_id(entry_id):
            streak += 1
        else:
            break
    return streak


def count_pumpkin_like(cauldron_ids: list[str]) -> int:
    return sum(1 for entry_id in cauldron_ids if is_pumpkin_like_id(entry_id))


def pumpkin_trinket_bonus_score(
    cauldron_ids: list[str],
    exclude_last_entry: bool,
) -> int:
    return min(
        PUMPKIN_TRINKET_STREAK_CAP,
        count_trailing_pumpkin_streak(cauldron_ids, exclude_last_entry),
    )


def red_mushroom_bonus(cauldron_ids: list[str], base_point_value: int = 1) -> int:
    max_pre_double = 4
    total_before_doubles = min(
        max_pre_double,
        base_point_value + count_pumpkin_like(cauldron_ids),
    )
    return total_before_doubles - base_point_value


def main() -> int:
    assert is_pumpkin_like_id("pumpkin")
    assert is_pumpkin_like_id("jackolantern")
    assert is_pumpkin_like_id("JackOlantern")
    assert not is_pumpkin_like_id("rat")
    assert not is_pumpkin_like_id("pumpkin_trinket")

    mixed_streak = ["rat", "pumpkin", "jackolantern", "jackolantern"]
    assert count_trailing_pumpkin_streak(mixed_streak, False) == 3
    assert count_trailing_pumpkin_streak(mixed_streak, True) == 2
    assert pumpkin_trinket_bonus_score(mixed_streak, True) == 2

    jack_only = ["jackolantern", "jackolantern", "jackolantern"]
    assert pumpkin_trinket_bonus_score(jack_only, False) == 3

    mushroom_cauldron = ["pumpkin", "jackolantern", "rat"]
    assert count_pumpkin_like(mushroom_cauldron) == 2
    assert red_mushroom_bonus(mushroom_cauldron) == 2

    print("PASS: pumpkin-like verification checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())