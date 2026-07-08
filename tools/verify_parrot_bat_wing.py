#!/usr/bin/env python3
"""Parrot + Bat Wing should run two full picker sequences, not one silent replay."""

from __future__ import annotations

import sys

BAT_WING_ID = "bat_wing"
PARROT_ID = "parrot"
PICKED_ID = "boom_berry_2"


class Session:
    def __init__(self) -> None:
        self.cauldron: list[str] = []
        self.parrot_repeat_pending = False
        self.parrot_repeat_ingredient: str | None = None
        self.parrot_repeat_from_hand = False
        self.parrot_repeat_hand_slot = -1
        self.bat_wing_choices: list[str] = []
        self.bat_wing_source_slot = -1
        self.needs_picker = False
        self.events: list[str] = []

    def play_bat_wing(self, from_hand: bool, slot_index: int, parrot_doubled: bool) -> None:
        self.cauldron.append(BAT_WING_ID)
        self.bat_wing_choices = ["a", "b", "c"]
        self.bat_wing_source_slot = slot_index if from_hand else -1
        self.needs_picker = True
        self.events.append(f"bat_wing_play:{slot_index}")
        if parrot_doubled:
            self.parrot_repeat_pending = True
            self.parrot_repeat_ingredient = BAT_WING_ID
            self.parrot_repeat_from_hand = from_hand
            self.parrot_repeat_hand_slot = slot_index

    def complete_picker(self, picked: str) -> None:
        self.cauldron.append(picked)
        self.bat_wing_choices = []
        self.needs_picker = False
        self.events.append(f"pick:{picked}")

    def try_parrot_repeat(self) -> bool:
        if not self.parrot_repeat_pending:
            return False
        ingredient = self.parrot_repeat_ingredient
        from_hand = self.parrot_repeat_from_hand
        slot_index = self.parrot_repeat_hand_slot
        self.parrot_repeat_pending = False
        self.parrot_repeat_ingredient = None
        if ingredient != BAT_WING_ID:
            self.cauldron.append(ingredient or "")
            self.events.append(f"parrot_repeat:{ingredient}")
            return True
        self.play_bat_wing(from_hand, slot_index, parrot_doubled=False)
        return True


def simulate_parrot_bat_wing() -> Session:
    session = Session()
    session.play_bat_wing(from_hand=True, slot_index=2, parrot_doubled=True)
    assert session.needs_picker
    session.complete_picker(PICKED_ID)
    assert session.try_parrot_repeat()
    assert session.needs_picker, "second bat wing must reopen picker"
    session.complete_picker(PICKED_ID)
    assert not session.try_parrot_repeat()
    return session


def main() -> int:
    session = simulate_parrot_bat_wing()
    assert session.cauldron == [
        BAT_WING_ID,
        PICKED_ID,
        BAT_WING_ID,
        PICKED_ID,
    ], session.cauldron
    assert session.events == [
        "bat_wing_play:2",
        f"pick:{PICKED_ID}",
        "bat_wing_play:2",
        f"pick:{PICKED_ID}",
    ], session.events

    print("PASS: parrot bat wing verification checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())