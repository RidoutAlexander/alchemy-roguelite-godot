#!/usr/bin/env python3
"""Hand display preview rules: bat wing isolation, played-twice vs doubled."""

from __future__ import annotations

import sys

BAT_WING_ID = "bat_wing"
PARROT_ID = "parrot"
COBBLER_ID = "cobbler"
BOOM_BERRY_ID = "boom_berry_1"
FEATHER_ID = "feather_1"
COBBLER_SCORE = 10
COBBLER_EXPLOSIVE = 2


def preview_slot(
    ingredient_id: str,
    *,
    parrot_pending: bool = False,
    cobbler_retro_score: int = 0,
    cobbler_retro_explosive: int = 0,
    in_rhythm: bool = False,
    feather_trinket: bool = False,
) -> dict[str, int]:
    if ingredient_id == BAT_WING_ID:
        point = 1
        explosive = 0
        if in_rhythm:
            point *= 2
        if parrot_pending:
            pass  # second full play, not 2x stats
        return {"point_value": point, "explosive_value": explosive}

    point = 1 if ingredient_id == BOOM_BERRY_ID else 2
    explosive = 1 if ingredient_id == BOOM_BERRY_ID else 0
    point += cobbler_retro_score
    explosive += cobbler_retro_explosive
    if in_rhythm:
        point *= 2
        explosive *= 2
    if parrot_pending:
        pass  # overlay only; numbers stay single-play
    if feather_trinket and ingredient_id.startswith("feather"):
        pass  # overlay only; no second play added to label
    return {"point_value": point, "explosive_value": explosive}


def main() -> int:
    bat_wing = preview_slot(BAT_WING_ID, cobbler_retro_score=COBBLER_SCORE)
    assert bat_wing == {"point_value": 1, "explosive_value": 0}, bat_wing

    berry_with_cobbler = preview_slot(
        BOOM_BERRY_ID,
        cobbler_retro_score=COBBLER_SCORE,
        cobbler_retro_explosive=COBBLER_EXPLOSIVE,
        in_rhythm=True,
    )
    assert berry_with_cobbler == {"point_value": 22, "explosive_value": 6}, berry_with_cobbler

    parrot_berry = preview_slot(BOOM_BERRY_ID, parrot_pending=True, in_rhythm=True)
    assert parrot_berry == {"point_value": 2, "explosive_value": 2}, parrot_berry

    feather = preview_slot(FEATHER_ID, feather_trinket=True, in_rhythm=True)
    assert feather == {"point_value": 4, "explosive_value": 0}, feather

    print("PASS: hand display preview verification checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())