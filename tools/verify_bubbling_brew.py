#!/usr/bin/env python3
"""Verification for Bubbling Brew aura return logic."""

from __future__ import annotations

import sys

INTERVAL = 3


def returns_to_bag(ingredients_added_before: int) -> bool:
    return (ingredients_added_before + 1) % INTERVAL == 0


def countdown(ingredients_added: int) -> int:
    remainder = ingredients_added % INTERVAL
    if remainder == 0:
        return INTERVAL
    return INTERVAL - remainder


def simulate_brew(plays: int) -> tuple[list[bool], int, int]:
    added = 0
    cauldron_size = 0
    returned: list[bool] = []
    for _ in range(plays):
        if returns_to_bag(added):
            returned.append(True)
        else:
            returned.append(False)
            cauldron_size += 1
        added += 1
    return returned, cauldron_size, added


def main() -> int:
    assert returns_to_bag(2)
    assert not returns_to_bag(1)
    assert returns_to_bag(5)
    assert countdown(0) == 3
    assert countdown(2) == 1
    assert countdown(3) == 3

    returned, cauldron_size, added = simulate_brew(6)
    assert returned == [False, False, True, False, False, True]
    assert cauldron_size == 4
    assert added == 6

    returned, cauldron_size, added = simulate_brew(4)
    assert returned == [False, False, True, False]
    assert cauldron_size == 3
    assert added == 4

    print("PASS: bubbling brew verification checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())