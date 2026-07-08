#!/usr/bin/env python3
"""Verification for unified hand play preview resolution order."""

from __future__ import annotations

import sys

HAND_SLOT_COUNT = 5
HONEY_ID = "honey"
BAT_WING_ID = "bat_wing"
IN_RHYTHM_INTERVAL = 3
BUBBLING_INTERVAL = 11


def honey_skipped_slots(hand_slots: list[str | None]) -> set[int]:
    skipped: set[int] = set()
    for slot_index in range(1, HAND_SLOT_COUNT):
        if slot_index >= len(hand_slots):
            continue
        if hand_slots[slot_index] != HONEY_ID:
            continue
        if hand_slots[slot_index - 1] is not None:
            skipped.add(slot_index - 1)
    return skipped


def stays_in_hand(cauldron_count_before: int, stays_consumed: int = 0) -> bool:
    effective = cauldron_count_before + stays_consumed
    return (effective + 1) % BUBBLING_INTERVAL == 0


def compute_gecko_stay_slots(
    hand_slots: list[str | None],
    honey_skipped: set[int],
    interval_before: int,
) -> set[int]:
    stayed: set[int] = set()
    cauldron_count = interval_before
    gecko_stays_consumed = 0
    for slot_index in range(HAND_SLOT_COUNT):
        if slot_index in honey_skipped:
            continue
        if slot_index >= len(hand_slots) or hand_slots[slot_index] is None:
            continue
        if hand_slots[slot_index] == BAT_WING_ID:
            continue
        if stays_in_hand(cauldron_count, gecko_stays_consumed):
            stayed.add(slot_index)
            gecko_stays_consumed += 1
        else:
            cauldron_count += 1
    return stayed


def compute_steps(
    hand_slots: list[str | None],
    cauldron_size: int,
    ingredients_added: int,
) -> list[dict]:
    steps: list[dict] = []
    honey_skipped = honey_skipped_slots(hand_slots)
    gecko_stayed = compute_gecko_stay_slots(hand_slots, honey_skipped, ingredients_added)
    sim_cauldron = cauldron_size
    sim_ingredients_added = ingredients_added

    for slot_index in range(HAND_SLOT_COUNT):
        if slot_index in honey_skipped:
            continue
        if slot_index >= len(hand_slots) or hand_slots[slot_index] is None:
            continue
        ingredient_id = hand_slots[slot_index]
        if slot_index in gecko_stayed:
            steps.append(
                {
                    "slot_index": slot_index,
                    "ingredient_id": ingredient_id,
                    "plays_to_cauldron": False,
                    "gecko_stays": True,
                }
            )
            continue

        cauldron_count_before = sim_cauldron
        ingredients_added_before = sim_ingredients_added
        counts_for_added = ingredient_id != BAT_WING_ID
        bubbling_returns = (
            counts_for_added
            and (ingredients_added_before + 1) % BUBBLING_INTERVAL == 0
        )
        in_rhythm_doubles = (cauldron_count_before + 1) % IN_RHYTHM_INTERVAL == 0

        sim_cauldron += 1
        if bubbling_returns:
            sim_cauldron -= 1
        if counts_for_added:
            sim_ingredients_added += 1

        steps.append(
            {
                "slot_index": slot_index,
                "ingredient_id": ingredient_id,
                "plays_to_cauldron": True,
                "ingredients_added_before": ingredients_added_before,
                "in_rhythm_doubles": in_rhythm_doubles,
                "bubbling_returns": bubbling_returns,
            }
        )

    return steps


def playing_slots(steps: list[dict]) -> list[int]:
    return [
        int(step["slot_index"])
        for step in steps
        if step.get("plays_to_cauldron")
    ]


def main() -> int:
    # Honey keeps the left card in hand: only honey and cards to its right resolve.
    steps = compute_steps(["a", "honey", "c", None, None], 0, 0)
    assert playing_slots(steps) == [1, 2], playing_slots(steps)

    # Gecko stay removes a slot from cauldron play order.
    steps = compute_steps(["a", "b", None, None, None], 0, 9)
    assert any(step.get("gecko_stays") for step in steps), steps
    assert playing_slots(steps) == [0], playing_slots(steps)

    # Bat wing plays but should not advance bubbling interval for the next card.
    steps = compute_steps([BAT_WING_ID, "b", None, None, None], 0, 9)
    assert playing_slots(steps) == [0, 1], playing_slots(steps)
    b_step = next(
        step
        for step in steps
        if step.get("ingredient_id") == "b" and step.get("plays_to_cauldron")
    )
    assert b_step.get("ingredients_added_before", -1) == 9, b_step
    assert not b_step.get("bubbling_returns"), b_step

    # In Rhythm should follow actual cauldron adds, not raw slot positions.
    steps = compute_steps(["a", "b", "c", None, None], 2, 0)
    in_rhythm_slots = [
        int(step["slot_index"])
        for step in steps
        if step.get("plays_to_cauldron") and step.get("in_rhythm_doubles")
    ]
    assert in_rhythm_slots == [0], in_rhythm_slots

    print("PASS: hand play preview verification checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())