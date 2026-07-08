#!/usr/bin/env python3
"""Verification for Pristine Feather trinket double-play logic."""

from __future__ import annotations

import sys

PRISTINE_FEATHER_ID = "pristine_feather"
PHOENIX_FEATHER_ID = "pheonix_feather"


def is_feather_ingredient_id(ingredient_id: str) -> bool:
    normalized = ingredient_id.lower()
    if normalized == "feather":
        return True
    return normalized.startswith("feather_") or "_feather" in normalized


def feather_plays_twice(ingredient_id: str, trinket_ids: list[str]) -> bool:
    return (
        is_feather_ingredient_id(ingredient_id)
        and PRISTINE_FEATHER_ID in trinket_ids
    )


def should_schedule_repeat(
    ingredient_id: str,
    trinket_ids: list[str],
    exploded: bool,
    in_progress: bool,
) -> bool:
    if not feather_plays_twice(ingredient_id, trinket_ids) or not in_progress:
        return False
    if not exploded:
        return True
    return ingredient_id == PHOENIX_FEATHER_ID


def resolve_phoenix_save(exploded: bool, ingredient_id: str) -> bool:
    return exploded and ingredient_id == PHOENIX_FEATHER_ID


def simulate_first_play_resolution(
    ingredient_id: str,
    trinket_ids: list[str],
    explosiveness: int,
    explosion_limit: int,
    explosive_value: int = 1,
) -> dict:
    exploded = explosiveness + explosive_value >= explosion_limit
    if resolve_phoenix_save(exploded, ingredient_id):
        explosiveness = 0
        exploded = explosiveness >= explosion_limit
    repeat_scheduled = should_schedule_repeat(
        ingredient_id,
        trinket_ids,
        exploded,
        True,
    )
    return {
        "explosiveness": explosiveness,
        "exploded": exploded,
        "repeat_scheduled": repeat_scheduled,
    }


def main() -> int:
    with_trinket = [PRISTINE_FEATHER_ID]
    without: list[str] = []

    assert is_feather_ingredient_id("feather")
    assert is_feather_ingredient_id("pheonix_feather")
    assert is_feather_ingredient_id("golden_feather_charm")
    assert is_feather_ingredient_id("feather_fan")
    assert not is_feather_ingredient_id("rat")
    assert not is_feather_ingredient_id("featherless_stone")

    assert feather_plays_twice("feather", with_trinket)
    assert feather_plays_twice("pheonix_feather", with_trinket)
    assert feather_plays_twice("storm_feather", with_trinket)
    assert not feather_plays_twice("feather", without)
    assert not feather_plays_twice("rat", with_trinket)

    assert should_schedule_repeat("pheonix_feather", with_trinket, False, True)
    assert should_schedule_repeat("pheonix_feather", with_trinket, True, True)
    assert not should_schedule_repeat("feather", with_trinket, True, True)
    assert not should_schedule_repeat("feather", without, False, True)

    phoenix_first_play = simulate_first_play_resolution(
        PHOENIX_FEATHER_ID,
        with_trinket,
        explosiveness=9,
        explosion_limit=10,
    )
    assert phoenix_first_play["explosiveness"] == 0
    assert not phoenix_first_play["exploded"]
    assert phoenix_first_play["repeat_scheduled"]

    phoenix_repeat_play = simulate_first_play_resolution(
        PHOENIX_FEATHER_ID,
        with_trinket,
        explosiveness=9,
        explosion_limit=10,
    )
    assert phoenix_repeat_play["explosiveness"] == 0
    assert not phoenix_repeat_play["exploded"]

    print("PASS: pristine feather verification checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())