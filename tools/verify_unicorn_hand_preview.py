#!/usr/bin/env python3
"""Verify unicorn horn hand preview targets the next played explosive card."""

from __future__ import annotations

import sys

HAND_SLOT_COUNT = 5
HONEY_ID = "honey"
BAT_WING_ID = "bat_wing"
UNICORN_HORN_ID = "unicorn_horn"
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
        counts_for_added = ingredient_id is not None
        bubbling_returns = (
            counts_for_added
            and (ingredients_added_before + 1) % BUBBLING_INTERVAL == 0
        )

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
            }
        )

    return steps


def explosive_values(hand_slots: list[str | None]) -> dict[int, int]:
    values: dict[int, int] = {}
    for slot_index, ingredient_id in enumerate(hand_slots):
        if ingredient_id is None:
            continue
        if ingredient_id.startswith("boom"):
            values[slot_index] = 1
        else:
            values[slot_index] = 0
    return values


def compute_unicorn_cured_slots(
    hand_slots: list[str | None],
    unicorn_cures_next: bool = False,
) -> list[int]:
    cured: list[int] = []
    unicorn_active = unicorn_cures_next
    explosive_by_slot = explosive_values(hand_slots)

    for step in compute_steps(hand_slots, 0, 0):
        if not step.get("plays_to_cauldron"):
            continue
        slot_index = int(step["slot_index"])
        ingredient_id = str(step["ingredient_id"])
        explosive_add = explosive_by_slot.get(slot_index, 0)

        if unicorn_active and explosive_add > 0:
            cured.append(slot_index)
            unicorn_active = False

        if ingredient_id == UNICORN_HORN_ID:
            unicorn_active = True

    return cured


def main() -> int:
    # Honey skips the left card; unicorn cures the next played boom in order.
    hand = ["boom_1", HONEY_ID, UNICORN_HORN_ID, "boom_2", None]
    cured = compute_unicorn_cured_slots(hand)
    assert cured == [3], cured
    assert cured != [4], cured

    # Skip a zero-explosive card and cure the following boom in play order.
    hand = ["boom_1", HONEY_ID, UNICORN_HORN_ID, "safe", "boom_2"]
    cured = compute_unicorn_cured_slots(hand)
    assert cured == [4], cured

    # Cauldron unicorn buff should apply to the first played boom in the hand.
    hand = [UNICORN_HORN_ID, "safe", "boom_1", None, None]
    cured = compute_unicorn_cured_slots(hand, unicorn_cures_next=True)
    assert cured == [2], cured

    print("PASS: unicorn hand preview verification checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())