#!/usr/bin/env python3
"""Hand-preview check: unicorn-cured boom berries keep cobbler score only."""

from __future__ import annotations

import sys

COBBLER_SCORE = 10
COBBLER_EXPLOSIVE = 2


def apply_retroactive_cobbler_bonus_to_slot(
    target_slot: int,
    cobbler_bonus: dict[str, int],
    pre_double_stats: list,
    display_stats: list,
    unicorn_cured_slots: set[int],
) -> None:
    if target_slot < 0 or target_slot >= len(pre_double_stats):
        return
    prior_stats = pre_double_stats[target_slot]
    if prior_stats is None:
        return
    bonus_score = cobbler_bonus["score"]
    bonus_explosive = cobbler_bonus["explosiveness"]
    if target_slot in unicorn_cured_slots:
        bonus_explosive = 0
    if bonus_score == 0 and bonus_explosive == 0:
        return
    old_prior_pv = prior_stats["point_value"]
    old_prior_ev = prior_stats["explosive_value"]
    prior_stats["point_value"] = old_prior_pv + bonus_score
    prior_stats["explosive_value"] = old_prior_ev + bonus_explosive
    if target_slot >= len(display_stats):
        return
    display_entry = display_stats[target_slot]
    if display_entry is None:
        return
    display_pv = display_entry["point_value"]
    display_ev = display_entry["explosive_value"]
    if old_prior_pv > 0:
        display_entry["point_value"] = display_pv + round(
            bonus_score * display_pv / old_prior_pv
        )
    else:
        display_entry["point_value"] = display_pv + bonus_score
    if old_prior_ev > 0:
        display_entry["explosive_value"] = display_ev + round(
            bonus_explosive * display_ev / old_prior_ev
        )
    else:
        display_entry["explosive_value"] = display_ev + bonus_explosive


def main() -> int:
    pre_double = [{"point_value": 1, "explosive_value": 1}]
    display = [{"point_value": 1, "explosive_value": 0}]
    cured = {0}
    bonus = {"score": COBBLER_SCORE, "explosiveness": COBBLER_EXPLOSIVE}
    apply_retroactive_cobbler_bonus_to_slot(0, bonus, pre_double, display, cured)
    assert display[0]["point_value"] == 1 + COBBLER_SCORE, display
    assert display[0]["explosive_value"] == 0, display

    print("PASS: unicorn + cobbler preview verification checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())