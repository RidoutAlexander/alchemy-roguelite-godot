#!/usr/bin/env python3
"""Verification for Bubbling Brew aura return logic."""

from __future__ import annotations

import sys

INTERVAL = 11
BAT_WING_ID = "bat_wing"


def bubbling_brew_hand_slots(
    hand_slots: list[str | None],
    ingredients_added_before_hand: int,
) -> list[int]:
    bubbling_slots: list[int] = []
    ingredients_added = ingredients_added_before_hand
    for slot_index, ingredient_id in enumerate(hand_slots):
        if ingredient_id is None:
            continue
        if returns_to_bag(ingredients_added):
            bubbling_slots.append(slot_index)
        ingredients_added += 1
    return bubbling_slots


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
    assert returns_to_bag(10)
    assert not returns_to_bag(9)
    assert returns_to_bag(21)
    assert countdown(0) == 11
    assert countdown(10) == 1
    assert countdown(11) == 11

    # Banner countdown should tick down one per ingredient added.
    for added in range(12):
        assert countdown(added) == (11 if added % 11 == 0 else 11 - (added % 11))

    returned, cauldron_size, added = simulate_brew(12)
    assert returned.count(True) == 1
    assert returned[10]
    assert not returned[11]
    assert cauldron_size == 11
    assert added == 12

    returned, cauldron_size, added = simulate_brew(22)
    assert returned.count(True) == 2
    assert returned[10]
    assert returned[21]
    assert cauldron_size == 20
    assert added == 22

    # Bat wing counts as a cauldron add for bubbling brew interval.
    slots = bubbling_brew_hand_slots([BAT_WING_ID, "b", None, None, None], 10)
    assert slots == [0], slots

    print("PASS: bubbling brew verification checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())