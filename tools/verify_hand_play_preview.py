#!/usr/bin/env python3
"""Verification for unified hand play preview resolution order."""

from __future__ import annotations

import sys

HAND_SLOT_COUNT = 5
HONEY_ID = "honey"
BAT_WING_ID = "bat_wing"
PARROT_ID = "parrot"
FEATHER_ID = "feather_1"
IN_RHYTHM_INTERVAL = 3
BUBBLING_INTERVAL = 11
BAT_WING_PICK_PLACEHOLDER = "__bat_wing_pick_preview__"


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


def in_rhythm_doubles(cauldron_count_before: int) -> bool:
    return (cauldron_count_before + 1) % IN_RHYTHM_INTERVAL == 0


def bubbling_returns(ingredients_added_before: int) -> bool:
    return (ingredients_added_before + 1) % BUBBLING_INTERVAL == 0


def feather_plays_twice(ingredient_id: str | None, has_feather_trinket: bool) -> bool:
    return has_feather_trinket and ingredient_id is not None and ingredient_id.startswith("feather")


def generic_bat_wing_pick() -> str:
    return BAT_WING_PICK_PLACEHOLDER


def record_cauldron_play(
    steps: list[dict],
    slot_index: int,
    ingredient_id: str | None,
    sim_cauldron: int,
    sim_ingredients_added: int,
    extra_flags: dict | None = None,
) -> tuple[int, int]:
    extra_flags = extra_flags or {}
    cauldron_count_before = sim_cauldron
    ingredients_added_before = sim_ingredients_added
    counts_for_added = ingredient_id is not None
    returns = counts_for_added and bubbling_returns(ingredients_added_before)

    if ingredient_id is not None:
        sim_cauldron += 1
    if returns:
        sim_cauldron -= 1
    if counts_for_added:
        sim_ingredients_added += 1

    steps.append(
        {
            "slot_index": slot_index,
            "ingredient_id": ingredient_id,
            "plays_to_cauldron": True,
            "cauldron_count_before": cauldron_count_before,
            "ingredients_added_before": ingredients_added_before,
            "in_rhythm_doubles": in_rhythm_doubles(cauldron_count_before),
            "bubbling_returns": returns,
            **extra_flags,
        }
    )
    return sim_cauldron, sim_ingredients_added


def simulate_bat_wing_pick_chain(
    steps: list[dict],
    source_slot: int,
    sim_cauldron: int,
    sim_ingredients_added: int,
    bat_wing_pick_overrides: dict[int, str],
    use_pick_override: bool,
) -> tuple[int, int]:
    pick = generic_bat_wing_pick()
    if use_pick_override and source_slot in bat_wing_pick_overrides:
        pick = bat_wing_pick_overrides[source_slot]
    sim_cauldron, sim_ingredients_added = record_cauldron_play(
        steps,
        source_slot,
        pick,
        sim_cauldron,
        sim_ingredients_added,
        {"bat_wing_pick": True},
    )
    if pick == BAT_WING_ID:
        return simulate_bat_wing_pick_chain(
            steps,
            source_slot,
            sim_cauldron,
            sim_ingredients_added,
            bat_wing_pick_overrides,
            False,
        )
    return sim_cauldron, sim_ingredients_added


def record_hand_slot_play(
    steps: list[dict],
    slot_index: int,
    ingredient_id: str,
    sim_cauldron: int,
    sim_ingredients_added: int,
    bat_wing_pick_overrides: dict[int, str],
    parrot_repeat: bool = False,
    feather_repeat: bool = False,
) -> tuple[int, int]:
    sim_cauldron, sim_ingredients_added = record_cauldron_play(
        steps,
        slot_index,
        ingredient_id,
        sim_cauldron,
        sim_ingredients_added,
        {
            "parrot_repeat": parrot_repeat,
            "feather_repeat": feather_repeat,
        },
    )
    if ingredient_id == BAT_WING_ID:
        return simulate_bat_wing_pick_chain(
            steps,
            slot_index,
            sim_cauldron,
            sim_ingredients_added,
            bat_wing_pick_overrides,
            True,
        )
    return sim_cauldron, sim_ingredients_added


def compute_steps(
    hand_slots: list[str | None],
    cauldron_size: int,
    ingredients_added: int,
    *,
    parrot_doubles_next: bool = False,
    has_feather_trinket: bool = False,
    bat_wing_pick_overrides: dict[int, str] | None = None,
) -> list[dict]:
    steps: list[dict] = []
    honey_skipped = honey_skipped_slots(hand_slots)
    gecko_stayed = compute_gecko_stay_slots(hand_slots, honey_skipped, ingredients_added)
    sim_cauldron = cauldron_size
    sim_ingredients_added = ingredients_added
    parrot_repeats_next = parrot_doubles_next
    bat_wing_pick_overrides = bat_wing_pick_overrides or {}

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

        parrot_repeat_this = parrot_repeats_next
        parrot_repeats_next = False

        sim_cauldron, sim_ingredients_added = record_hand_slot_play(
            steps,
            slot_index,
            ingredient_id,
            sim_cauldron,
            sim_ingredients_added,
            bat_wing_pick_overrides,
        )
        if ingredient_id == PARROT_ID:
            parrot_repeats_next = True

        if parrot_repeat_this:
            sim_cauldron, sim_ingredients_added = record_hand_slot_play(
                steps,
                slot_index,
                ingredient_id,
                sim_cauldron,
                sim_ingredients_added,
                bat_wing_pick_overrides,
                parrot_repeat=True,
            )

        if feather_plays_twice(ingredient_id, has_feather_trinket):
            sim_cauldron, sim_ingredients_added = record_hand_slot_play(
                steps,
                slot_index,
                ingredient_id,
                sim_cauldron,
                sim_ingredients_added,
                bat_wing_pick_overrides,
                feather_repeat=True,
            )

    return steps


def playing_slots(steps: list[dict]) -> list[int]:
    return [
        int(step["slot_index"])
        for step in steps
        if step.get("plays_to_cauldron")
    ]


def in_rhythm_slots(steps: list[dict]) -> list[int]:
    return [
        int(step["slot_index"])
        for step in steps
        if step.get("plays_to_cauldron") and step.get("in_rhythm_doubles")
    ]


def bubbling_slots(steps: list[dict]) -> list[int]:
    return [
        int(step["slot_index"])
        for step in steps
        if step.get("plays_to_cauldron") and step.get("bubbling_returns")
    ]


def in_rhythm_countdown(cauldron_count: int) -> int:
    remainder = cauldron_count % IN_RHYTHM_INTERVAL
    if remainder == 0:
        return IN_RHYTHM_INTERVAL
    return IN_RHYTHM_INTERVAL - remainder


def bubbling_countdown(ingredients_added: int) -> int:
    remainder = ingredients_added % BUBBLING_INTERVAL
    if remainder == 0:
        return BUBBLING_INTERVAL
    return BUBBLING_INTERVAL - remainder


def countdown_to_in_rhythm(steps: list[dict], cauldron_count: int) -> int:
    plays_until = 0
    projected = cauldron_count
    for step in steps:
        if not step.get("plays_to_cauldron"):
            continue
        plays_until += 1
        if step.get("in_rhythm_doubles"):
            return plays_until
        projected += 1
    return in_rhythm_countdown(projected)


def countdown_to_bubbling(steps: list[dict], ingredients_added: int) -> int:
    adds_until = 0
    projected = ingredients_added
    for step in steps:
        if not step.get("plays_to_cauldron"):
            continue
        ingredient_id = step.get("ingredient_id")
        if ingredient_id is None:
            continue
        adds_until += 1
        if step.get("bubbling_returns"):
            return adds_until
        projected += 1
    return bubbling_countdown(projected)


def main() -> int:
    # Honey keeps the left card in hand: only honey and cards to its right resolve.
    steps = compute_steps(["a", HONEY_ID, "c", None, None], 0, 0)
    assert playing_slots(steps) == [1, 2], playing_slots(steps)

    # Gecko stay removes a slot from cauldron play order.
    steps = compute_steps(["a", "b", None, None, None], 0, 9)
    assert any(step.get("gecko_stays") for step in steps), steps
    assert playing_slots(steps) == [0], playing_slots(steps)

    # Bat wing counts as a cauldron add; its pick is the next add and can trigger bubbling.
    steps = compute_steps([BAT_WING_ID, "b", None, None, None], 0, 9)
    assert playing_slots(steps) == [0, 0, 1], playing_slots(steps)
    pick_step = next(
        step
        for step in steps
        if step.get("bat_wing_pick") and step.get("plays_to_cauldron")
    )
    assert pick_step.get("ingredients_added_before", -1) == 10, pick_step
    assert pick_step.get("bubbling_returns"), pick_step
    b_step = next(
        step
        for step in steps
        if step.get("ingredient_id") == "b" and step.get("plays_to_cauldron")
    )
    assert b_step.get("ingredients_added_before", -1) == 11, b_step
    assert not b_step.get("bubbling_returns"), b_step

    # In Rhythm should follow actual cauldron adds, not raw slot positions.
    steps = compute_steps(["a", "b", "c", None, None], 2, 0)
    assert in_rhythm_slots(steps) == [0], in_rhythm_slots(steps)

    # Parrot doubles the next card's cauldron adds.
    steps = compute_steps([PARROT_ID, "b", "c", None, None], 0, 0)
    assert playing_slots(steps).count(1) == 2, playing_slots(steps)
    assert in_rhythm_slots(steps) == [1], in_rhythm_slots(steps)

    # Pristine feather doubles feather plays for interval counting.
    steps = compute_steps([FEATHER_ID, "b", None, None, None], 0, 9, has_feather_trinket=True)
    assert playing_slots(steps).count(0) == 2, playing_slots(steps)
    assert bubbling_slots(steps) == [0], bubbling_slots(steps)

    # Bat wing counts; pick preview can be the bubbling trigger instead of the next hand card.
    steps = compute_steps(
        [BAT_WING_ID, "b", None, None, None],
        0,
        9,
        bat_wing_pick_overrides={0: "safe_pick"},
    )
    assert bubbling_slots(steps) == [0], bubbling_slots(steps)

    # Interval countdowns follow previewed play order.
    steps = compute_steps(["a", "b", "c", None, None], 2, 0)
    assert countdown_to_in_rhythm(steps, 2) == 1, countdown_to_in_rhythm(steps, 2)

    steps = compute_steps([PARROT_ID, "b", None, None, None], 1, 0)
    assert countdown_to_in_rhythm(steps, 1) == 2, countdown_to_in_rhythm(steps, 1)

    steps = compute_steps([BAT_WING_ID, "b", None, None, None], 0, 9)
    assert countdown_to_bubbling(steps, 9) == 2, countdown_to_bubbling(steps, 9)

    print("PASS: hand play preview verification checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())