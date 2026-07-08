#!/usr/bin/env python3
"""Verification for Headless Chicken trinket draw blocking."""

from __future__ import annotations

import sys

HEADLESS_CHICKEN_ID = "headless_chicken"
CHICKEN_ID = "chicken"
BLOCKED_HANDS = 2


def blocks_chicken_draws(hands_drawn: int, has_trinket: bool) -> bool:
    return has_trinket and hands_drawn < BLOCKED_HANDS


def turns_remaining(hands_drawn: int, has_trinket: bool) -> int:
    if not has_trinket:
        return 0
    return max(0, BLOCKED_HANDS - hands_drawn)


def try_draw_excluding_ids(deck: list[str], excluded_ids: list[str]) -> str | None:
    excluded = {ingredient_id for ingredient_id in excluded_ids if ingredient_id}
    for index, ingredient_id in enumerate(deck):
        if ingredient_id not in excluded:
            return deck.pop(index)
    if deck:
        return deck.pop(0)
    return None


def main() -> int:
    assert blocks_chicken_draws(0, True)
    assert blocks_chicken_draws(1, True)
    assert not blocks_chicken_draws(2, True)
    assert not blocks_chicken_draws(0, False)

    assert turns_remaining(0, True) == 2
    assert turns_remaining(1, True) == 1
    assert turns_remaining(2, True) == 0

    deck = ["chicken", "rat", "chicken"]
    drawn = try_draw_excluding_ids(deck, [CHICKEN_ID])
    assert drawn == "rat", drawn
    assert deck == ["chicken", "chicken"]

    deck = ["chicken", "chicken"]
    drawn = try_draw_excluding_ids(deck, [CHICKEN_ID])
    assert drawn == "chicken"
    assert deck == ["chicken"]

    print("PASS: headless chicken verification checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())