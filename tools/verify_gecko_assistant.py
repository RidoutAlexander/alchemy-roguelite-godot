#!/usr/bin/env python3
"""Verification for Gecko Assistant trinket stay-in-hand logic."""

from __future__ import annotations

import sys

INTERVAL = 11
HAND_SLOT_COUNT = 5
BAT_WING_ID = "bat_wing"


def skips_hand_stay_interval_counter(ingredient_id: str | None) -> bool:
    return ingredient_id == BAT_WING_ID


def stays_in_hand(
    cauldron_count_before: int,
    stays_consumed_this_hand: int = 0,
) -> bool:
    effective = cauldron_count_before + stays_consumed_this_hand
    return (effective + 1) % INTERVAL == 0


def countdown(cauldron_count: int) -> int:
    remainder = cauldron_count % INTERVAL
    if remainder == 0:
        return INTERVAL
    return INTERVAL - remainder


def compute_gecko_stay_slots(
    hand_slots: list[str | None],
    honey_skipped: set[int],
    cauldron_before: int,
) -> set[int]:
    stayed: set[int] = set()
    cauldron_count = cauldron_before
    gecko_stays_consumed = 0
    for slot_index in range(HAND_SLOT_COUNT):
        if slot_index in honey_skipped:
            continue
        if slot_index >= len(hand_slots) or hand_slots[slot_index] is None:
            continue
        if skips_hand_stay_interval_counter(hand_slots[slot_index]):
            continue
        if stays_in_hand(cauldron_count, gecko_stays_consumed):
            stayed.add(slot_index)
            gecko_stays_consumed += 1
        else:
            cauldron_count += 1
    return stayed


def simulate_locked_hand_play(
    hand_slots: list[str | None],
    honey_skipped: set[int],
    cauldron_before: int,
    cauldron_after_chain_draws: int,
) -> tuple[set[int], list[str | None]]:
    stayed_slots = compute_gecko_stay_slots(hand_slots, honey_skipped, cauldron_before)
    slots = hand_slots.copy()
    live_count = cauldron_after_chain_draws
    for slot_index in range(HAND_SLOT_COUNT):
        if slot_index in honey_skipped:
            continue
        if slots[slot_index] is None:
            continue
        if slot_index in stayed_slots:
            continue
        slots[slot_index] = None
        live_count += 1
    return stayed_slots, slots


def main() -> int:
    assert stays_in_hand(10)
    assert not stays_in_hand(9)
    assert stays_in_hand(21)
    assert not stays_in_hand(10, stays_consumed_this_hand=1)
    assert countdown(0) == 11
    assert countdown(10) == 1
    assert countdown(11) == 11

    stayed = compute_gecko_stay_slots(
        ["a", "b", None, None, None],
        set(),
        10,
    )
    assert stayed == {0}
    assert 1 not in stayed

    stayed = compute_gecko_stay_slots(
        ["a", "b", None, None, None],
        set(),
        9,
    )
    assert stayed == {1}

    stayed_slots, slots_after = simulate_locked_hand_play(
        ["chain", "gecko", None, None, None],
        set(),
        9,
        10,
    )
    assert stayed_slots == {1}
    assert slots_after[1] == "gecko"
    assert slots_after[0] is None

    # Bat wing should not advance the gecko interval; the next real card triggers stay.
    stayed = compute_gecko_stay_slots(
        [BAT_WING_ID, "b", None, None, None],
        set(),
        10,
    )
    assert stayed == {1}, stayed

    print("PASS: gecko assistant verification checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())