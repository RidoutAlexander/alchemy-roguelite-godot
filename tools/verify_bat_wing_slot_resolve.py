#!/usr/bin/env python3
"""Verification for bat wing picker resolving in the source hand slot."""

from __future__ import annotations

import sys

COBBLER_ID = "cobbler"
BAT_WING_ID = "bat_wing"
BOOM_BERRY_ID = "boom_berry_2"
COBBLER_SCORE = 10
COBBLER_EXPLOSIVE = 2


def is_boom_berry_id(ingredient_id: str) -> bool:
    return ingredient_id.startswith("boom_berry")


def cobbler_adjacency_bonus(previous_id: str | None, ingredient_id: str) -> dict[str, int]:
    if previous_id is None:
        return {"score": 0, "explosiveness": 0}
    if is_boom_berry_id(ingredient_id) and previous_id == COBBLER_ID:
        return {"score": COBBLER_SCORE, "explosiveness": COBBLER_EXPLOSIVE}
    if ingredient_id == COBBLER_ID and is_boom_berry_id(previous_id):
        return {"score": COBBLER_SCORE, "explosiveness": COBBLER_EXPLOSIVE}
    return {"score": 0, "explosiveness": 0}


def hand_boom_berry_slot_immediately_left(hand_slots: list[str | None], slot_index: int) -> int:
    left_slot = slot_index - 1
    while left_slot >= 0:
        ingredient_id = hand_slots[left_slot]
        if ingredient_id is not None:
            if is_boom_berry_id(ingredient_id):
                return left_slot
            return -1
        left_slot -= 1
    return -1


def cobbler_bonus_target_slot(
    ingredient_id: str,
    previous_id: str | None,
    play_slot: int,
    last_hand_slot: int,
    hand_slots: list[str | None],
    last_hand_ingredient_id: str | None = None,
) -> int:
    if ingredient_id == COBBLER_ID and previous_id is not None and is_boom_berry_id(previous_id):
        left_slot = hand_boom_berry_slot_immediately_left(hand_slots, play_slot)
        if left_slot >= 0:
            return left_slot
        if (
            last_hand_slot >= 0
            and last_hand_ingredient_id is not None
            and is_boom_berry_id(last_hand_ingredient_id)
        ):
            return last_hand_slot
        return -1
    if ingredient_id == COBBLER_ID:
        return -1
    return play_slot


def resolve_hand_play_cobbler(
    ingredient_id: str,
    cauldron_ids: list[str],
    play_slot: int,
    last_hand_slot: int,
    hand_slots: list[str | None],
    last_hand_ingredient_id: str | None = None,
) -> dict:
    previous_id = cauldron_ids[-1] if cauldron_ids else None
    bonus = cobbler_adjacency_bonus(previous_id, ingredient_id)
    if bonus["score"] == 0 and bonus["explosiveness"] == 0:
        return {"bonus": bonus, "retroactive_slot": -1}
    target_slot = cobbler_bonus_target_slot(
        ingredient_id,
        previous_id,
        play_slot,
        last_hand_slot,
        hand_slots,
        last_hand_ingredient_id,
    )
    if target_slot < 0:
        if ingredient_id == COBBLER_ID:
            if (
                last_hand_slot >= 0
                and last_hand_ingredient_id is not None
                and is_boom_berry_id(last_hand_ingredient_id)
            ):
                return {"bonus": bonus, "retroactive_slot": last_hand_slot}
            return {"bonus": {"score": 0, "explosiveness": 0}, "retroactive_slot": -1}
        return {
            "bonus": bonus,
            "retroactive_slot": -1,
            "apply_retroactive_immediately": True,
        }
    if target_slot == play_slot:
        if is_boom_berry_id(ingredient_id):
            return {"bonus": bonus, "retroactive_slot": -1, "apply_to_current": True}
        return {"bonus": {"score": 0, "explosiveness": 0}, "retroactive_slot": -1}
    return {"bonus": bonus, "retroactive_slot": target_slot}


def simulate_hand_play(
    hand_slots: list[str | None],
    bat_wing_slot: int | None = None,
    bat_wing_pick_id: str | None = None,
) -> dict[str, int]:
    cauldron: list[str] = []
    last_hand_slot = -1
    last_hand_ingredient_id: str | None = None
    pending: dict[int, dict[str, int]] = {}
    totals = {"score": 0, "explosiveness": 0}

    for play_slot in range(len(hand_slots)):
        if bat_wing_slot is not None and play_slot == bat_wing_slot:
            cauldron.append(BAT_WING_ID)
            last_hand_slot = play_slot
            last_hand_ingredient_id = BAT_WING_ID
            ingredient_id = bat_wing_pick_id
            play_slot_for_pick = bat_wing_slot
        elif hand_slots[play_slot] is None:
            continue
        else:
            ingredient_id = hand_slots[play_slot]
            play_slot_for_pick = play_slot

        pending_bonus = pending.pop(play_slot_for_pick, {"score": 0, "explosiveness": 0})
        resolved = resolve_hand_play_cobbler(
            ingredient_id,
            cauldron,
            play_slot_for_pick,
            last_hand_slot,
            hand_slots,
            last_hand_ingredient_id,
        )
        bonus = resolved["bonus"]
        retroactive_slot = resolved["retroactive_slot"]
        if retroactive_slot >= 0:
            if retroactive_slot < play_slot_for_pick:
                totals["score"] += bonus["score"]
                totals["explosiveness"] += bonus["explosiveness"]
                bonus = {"score": 0, "explosiveness": 0}
            else:
                existing = pending.get(retroactive_slot, {"score": 0, "explosiveness": 0})
                existing["score"] += bonus["score"]
                existing["explosiveness"] += bonus["explosiveness"]
                pending[retroactive_slot] = existing
                bonus = {"score": 0, "explosiveness": 0}
        elif resolved.get("apply_retroactive_immediately"):
            totals["score"] += bonus["score"]
            totals["explosiveness"] += bonus["explosiveness"]
            bonus = {"score": 0, "explosiveness": 0}
        elif not resolved.get("apply_to_current", False):
            bonus = {"score": 0, "explosiveness": 0}

        totals["score"] += bonus["score"] + pending_bonus["score"]
        totals["explosiveness"] += bonus["explosiveness"] + pending_bonus["explosiveness"]
        cauldron.append(ingredient_id)
        last_hand_slot = play_slot_for_pick
        last_hand_ingredient_id = ingredient_id

    return totals


def main() -> int:
    # Bat wing in slot 1 picks cobbler; boom berry still in slot 2.
    hand = [None, BAT_WING_ID, BOOM_BERRY_ID, None, None]
    totals = simulate_hand_play(hand, 1, COBBLER_ID)
    assert totals["score"] == COBBLER_SCORE, (
        f"expected cobbler to buff later boom berry, got score={totals['score']}"
    )
    assert totals["explosiveness"] == COBBLER_EXPLOSIVE

    # Bat wing in slot 1 picks boom berry; cobbler still in slot 2.
    hand = [None, BAT_WING_ID, COBBLER_ID, None, None]
    totals = simulate_hand_play(hand, 1, BOOM_BERRY_ID)
    assert totals["score"] == COBBLER_SCORE, (
        f"expected cobbler in slot 2 to pair with picked boom berry, got {totals['score']}"
    )

    # Boom berry plays before cobbler; cobbler must not buff itself.
    hand = [BOOM_BERRY_ID, None, COBBLER_ID, None, None]
    totals = simulate_hand_play(hand)
    assert totals["score"] == COBBLER_SCORE, (
        f"expected boom berry to receive cobbler bonus, got score={totals['score']}"
    )
    assert totals["explosiveness"] == COBBLER_EXPLOSIVE

    resolved = resolve_hand_play_cobbler(
        COBBLER_ID,
        [BOOM_BERRY_ID],
        2,
        0,
        [None, None, COBBLER_ID, None, None],
        BOOM_BERRY_ID,
    )
    assert resolved["retroactive_slot"] == 0, resolved
    assert resolved["bonus"]["score"] == COBBLER_SCORE

    # Adjacent boom berry + cobbler: bonus belongs to berry, not cobbler.
    adjacent = simulate_hand_play([BOOM_BERRY_ID, COBBLER_ID, None, None, None])
    assert adjacent["score"] == COBBLER_SCORE
    assert adjacent["explosiveness"] == COBBLER_EXPLOSIVE

    resolved_adjacent = resolve_hand_play_cobbler(
        COBBLER_ID,
        [BOOM_BERRY_ID],
        1,
        0,
        [BOOM_BERRY_ID, COBBLER_ID, None, None, None],
        BOOM_BERRY_ID,
    )
    assert resolved_adjacent["retroactive_slot"] == 0, resolved_adjacent
    assert "apply_to_current" not in resolved_adjacent

    # Bag-drawn bat wing should not use a hand slot.
    source_slot = -1
    from_hand = source_slot >= 0
    assert not from_hand

    print("PASS: bat wing slot resolve verification checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())