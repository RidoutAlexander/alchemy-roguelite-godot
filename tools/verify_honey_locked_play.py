#!/usr/bin/env python3
"""Verification that honey/gecko locked slots are fixed when play begins."""

from __future__ import annotations

HAND_SLOT_COUNT = 5
HONEY_ID = "honey"
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
        if stays_in_hand(cauldron_count, gecko_stays_consumed):
            stayed.add(slot_index)
            gecko_stays_consumed += 1
        else:
            cauldron_count += 1
    return stayed


def compute_hand_play_locks(
    hand_slots: list[str | None],
    interval_before: int,
) -> tuple[set[int], set[int], set[int]]:
    honey = honey_skipped_slots(hand_slots)
    gecko = compute_gecko_stay_slots(hand_slots, honey, interval_before)
    locked = set(honey)
    locked.update(gecko)
    return honey, gecko, locked


def play_order_from_locked(
    hand_slots: list[str | None],
    locked: set[int],
) -> list[int]:
    order: list[int] = []
    for slot_index in range(HAND_SLOT_COUNT):
        if slot_index in locked:
            continue
        if slot_index >= len(hand_slots) or hand_slots[slot_index] is None:
            continue
        order.append(slot_index)
    return order


def play_order_after_live_hand_changes(
    start_hand: list[str | None],
    locked: set[int],
) -> list[int]:
    live = start_hand.copy()
    order: list[int] = []
    for slot_index in range(HAND_SLOT_COUNT):
        if slot_index in locked:
            continue
        if live[slot_index] is None:
            continue
        order.append(slot_index)
        live[slot_index] = None
    return order


def honey_skip_after_honey_removed(start_hand: list[str | None]) -> set[int]:
    live = start_hand.copy()
    for slot_index, ingredient_id in enumerate(live):
        if ingredient_id == HONEY_ID:
            live[slot_index] = None
    return honey_skipped_slots(live)


def main() -> int:
    start = ["frog_leg", "boom_berry_1", HONEY_ID, None, None]
    honey, gecko, locked = compute_hand_play_locks(start, 0)
    assert honey == {1}
    assert locked == {1}

    assert play_order_from_locked(start, locked) == [0, 2]
    assert play_order_after_live_hand_changes(start, locked) == [0, 2]

    # Recomputing honey skip from a live hand after honey is removed would
    # incorrectly unfreeze the boom berry; locked slots must stay authoritative.
    assert honey_skip_after_honey_removed(start) == set()
    assert play_order_from_locked(start, locked) == [0, 2]

    print("PASS: honey locked play verification checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())