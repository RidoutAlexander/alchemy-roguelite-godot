#!/usr/bin/env python3
"""Verification for Pristine Feather trinket double-play logic."""

from __future__ import annotations

import sys

FEATHER_ID = "feather"
PHOENIX_FEATHER_ID = "pheonix_feather"
PRISTINE_FEATHER_ID = "pristine_feather"


def feather_plays_twice(ingredient_id: str, trinket_ids: list[str]) -> bool:
    return (
        ingredient_id == FEATHER_ID
        and PRISTINE_FEATHER_ID in trinket_ids
    )


def should_schedule_repeat(
    ingredient_id: str,
    trinket_ids: list[str],
    exploded: bool,
    in_progress: bool,
) -> bool:
    return (
        feather_plays_twice(ingredient_id, trinket_ids)
        and in_progress
        and not exploded
    )


def main() -> int:
    with_trinket = [PRISTINE_FEATHER_ID]
    without: list[str] = []

    assert feather_plays_twice(FEATHER_ID, with_trinket)
    assert not feather_plays_twice(FEATHER_ID, without)
    assert not feather_plays_twice(PHOENIX_FEATHER_ID, with_trinket)
    assert not feather_plays_twice("rat", with_trinket)

    assert should_schedule_repeat(FEATHER_ID, with_trinket, False, True)
    assert not should_schedule_repeat(FEATHER_ID, with_trinket, True, True)
    assert not should_schedule_repeat(FEATHER_ID, without, False, True)

    print("PASS: pristine feather verification checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())