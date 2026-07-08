#!/usr/bin/env python3
"""Headless verification for bat wing reroll logic and picker card cleanup."""

from __future__ import annotations

import random
import sys
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Set


BAT_WING_PICK_COUNT = 3
JAR_OF_FLIES_ID = "jar_of_flies"


@dataclass
class Ingredient:
    id: str
    instance: int

    def __hash__(self) -> int:
        return id(self)

    def __eq__(self, other: object) -> bool:
        return self is other


def make_bag(ids: List[str]) -> List[Ingredient]:
    counts: Dict[str, int] = {}
    bag: List[Ingredient] = []
    for ingredient_id in ids:
        counts[ingredient_id] = counts.get(ingredient_id, 0) + 1
        bag.append(Ingredient(ingredient_id, counts[ingredient_id]))
    return bag


class BagModel:
    def __init__(self, chips: List[Ingredient]) -> None:
        self._working = chips[:]

    def remaining_count(self) -> int:
        return len(self._working)

    def take_random(self, count: int) -> List[Ingredient]:
        picked: List[Ingredient] = []
        for _ in range(min(count, len(self._working))):
            index = random.randrange(len(self._working))
            picked.append(self._working.pop(index))
        return picked

    def count_drawable_excluding_instances(self, excluded: List[Ingredient]) -> int:
        excluded_set = set(excluded)
        return sum(1 for chip in self._working if chip not in excluded_set)

    def take_random_excluding_instances(
        self, excluded_instances: List[Ingredient], count: int
    ) -> List[Ingredient]:
        excluded = set(excluded_instances)
        pool = [chip for chip in self._working if chip not in excluded]
        picked: List[Ingredient] = []
        for _ in range(min(count, len(pool))):
            index = random.randrange(len(pool))
            chosen = pool.pop(index)
            self._working.remove(chosen)
            picked.append(chosen)
        return picked

    def return_to_bag(self, ingredients: List[Ingredient]) -> None:
        self._working.extend(ingredients)

    def remove_instances(self, ingredients: List[Ingredient]) -> None:
        for ingredient in ingredients:
            if ingredient in self._working:
                self._working.remove(ingredient)


class BrewSessionReroll:
    def __init__(self, bag: BagModel, trinkets: List[str]) -> None:
        self.bag = bag
        self.owned_trinket_ids = trinkets
        self._bat_wing_choices: List[Ingredient] = []
        self._bat_wing_reroll_used = False

    def draw_bat_wing_choices(self) -> None:
        self._bat_wing_choices = self.bag.take_random(BAT_WING_PICK_COUNT)
        self._bat_wing_reroll_used = False

    def can_reroll(self) -> bool:
        if (
            self._bat_wing_reroll_used
            or len(self._bat_wing_choices) < BAT_WING_PICK_COUNT
            or self.bag is None
        ):
            return False
        if JAR_OF_FLIES_ID not in self.owned_trinket_ids:
            return False
        return (
            self.bag.count_drawable_excluding_instances(self._bat_wing_choices)
            >= BAT_WING_PICK_COUNT
        )

    def try_reroll(self) -> bool:
        if not self.can_reroll():
            return False
        held_out = self._bat_wing_choices[:]
        self.bag.return_to_bag(held_out)
        rerolled = self.bag.take_random_excluding_instances(
            held_out, BAT_WING_PICK_COUNT
        )
        if len(rerolled) < BAT_WING_PICK_COUNT:
            self.bag.return_to_bag(rerolled)
            self.bag.remove_instances(held_out)
            self._bat_wing_choices = held_out
            return False
        self._bat_wing_choices = rerolled
        self._bat_wing_reroll_used = True
        return True

    def complete_picker(self, selected: Ingredient) -> None:
        unselected = [c for c in self._bat_wing_choices if c is not selected]
        self.bag.return_to_bag(unselected)
        self._bat_wing_choices.clear()
        self._bat_wing_reroll_used = False


@dataclass
class PickerCard:
    ingredient: Optional[Ingredient] = None
    picker_mode: bool = False
    disabled: bool = True
    mouse_filter_stop: bool = False
    queued_for_deletion: bool = False

    def sync_picker_input(self) -> None:
        if not self.picker_mode:
            return
        self.disabled = False
        self.mouse_filter_stop = True

    def bind_picker_card(self, ingredient: Ingredient, in_tree: bool) -> None:
        self.picker_mode = True
        if in_tree:
            self._apply_bind(ingredient)
        else:
            self._deferred_bind = ingredient

    def place_in_tree(self) -> None:
        self._run_ready_empty_state()
        if self._deferred_bind is not None:
            self._apply_bind(self._deferred_bind)
            self._deferred_bind = None

    def _run_ready_empty_state(self) -> None:
        self.picker_mode = False
        self.disabled = True
        self.mouse_filter_stop = False

    def _apply_bind(self, ingredient: Ingredient) -> None:
        self.ingredient = ingredient
        if self.picker_mode:
            self.sync_picker_input()
        else:
            self.disabled = True
            self.mouse_filter_stop = False

    _deferred_bind: Optional[Ingredient] = field(default=None, repr=False)


@dataclass
class Slot:
    card: Optional[Ingredient] = None
    queued_for_deletion: bool = False

    def get_card_old_bug(self) -> Optional[Ingredient]:
        return self.card

    def get_card_fixed(self) -> Optional[Ingredient]:
        if self.card is not None and self.queued_for_deletion:
            return None
        return self.card

    def clear_hosted_card_fixed(self) -> None:
        if self.get_card_fixed() is None:
            return
        self.card = None
        self.queued_for_deletion = False

    def clear_cards_old_bug(self) -> None:
        if self.card is not None:
            self.queued_for_deletion = True

class PickerOverlay:
    def __init__(self, slots: List[Slot], use_fixed_clear: bool) -> None:
        self.slots = slots
        self.use_fixed_clear = use_fixed_clear

    def _occupant(self, slot: Slot) -> Optional[Ingredient]:
        if self.use_fixed_clear:
            return slot.get_card_fixed()
        return slot.get_card_old_bug()

    def populate(self, ingredients: List[Ingredient]) -> None:
        if self.use_fixed_clear:
            for slot in self.slots:
                slot.clear_hosted_card_fixed()
        else:
            for slot in self.slots:
                slot.clear_cards_old_bug()
        for i, ingredient in enumerate(ingredients):
            slot = self.slots[i]
            occupant = self._occupant(slot)
            if occupant is not None:
                raise RuntimeError(
                    f"slot still occupied by {occupant.id} when placing {ingredient.id}"
                )
            slot.card = ingredient
            slot.queued_for_deletion = False

    def reroll_refresh(self, ingredients: List[Ingredient]) -> None:
        self.populate(ingredients)


def assert_true(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def test_reroll_preserves_chip_count() -> None:
    random.seed(7)
    bag = BagModel(make_bag(["a", "b", "c", "d", "e", "f", "g", "h", "i"]))
    session = BrewSessionReroll(bag, [JAR_OF_FLIES_ID])
    total_before = bag.remaining_count()
    session.draw_bat_wing_choices()
    held = session._bat_wing_choices[:]
    total_after_draw = bag.remaining_count() + len(held)
    assert_true(total_after_draw == total_before, "draw should conserve chips")
    assert_true(session.can_reroll(), "reroll should be available with jar of flies")
    assert_true(session.try_reroll(), "reroll should succeed")
    total_after_reroll = bag.remaining_count() + len(session._bat_wing_choices)
    assert_true(
        total_after_reroll == total_before,
        f"reroll leaked chips: before={total_before}, after={total_after_reroll}",
    )
    assert_true(not session.can_reroll(), "only one reroll allowed")
    selected = session._bat_wing_choices[0]
    session.complete_picker(selected)
    assert_true(
        bag.remaining_count() == total_before - 1,
        "completing picker should return unselected chips and consume the pick",
    )


def test_reroll_fails_when_bag_too_small() -> None:
    random.seed(1)
    bag = BagModel(make_bag(["a", "b", "c", "d", "e"]))
    session = BrewSessionReroll(bag, [JAR_OF_FLIES_ID])
    session.draw_bat_wing_choices()
    assert_true(not session.try_reroll(), "only 2 chips left; reroll must fail")
    assert_true(len(session._bat_wing_choices) == 3, "choices unchanged on failed reroll")


def test_reroll_allows_same_id_different_instance() -> None:
    random.seed(3)
    bag = BagModel(make_bag(["a", "a", "a", "b", "c", "d", "e", "f"]))
    session = BrewSessionReroll(bag, [JAR_OF_FLIES_ID])
    session.draw_bat_wing_choices()
    assert_true(session.try_reroll(), "reroll should work with duplicate ids in bag")
    ids = [chip.id for chip in session._bat_wing_choices]
    assert_true(len(ids) == 3, "reroll should still offer 3 choices")


def test_old_clear_cards_causes_occupant_collision() -> None:
    slots = [Slot(), Slot(), Slot()]
    overlay = PickerOverlay(slots, use_fixed_clear=False)
    first = make_bag(["a", "b", "c"])
    overlay.populate(first)
    second = make_bag(["d", "e", "f"])
    try:
        overlay.reroll_refresh(second)
        raise AssertionError("old clear_cards bug should leave occupied slots")
    except RuntimeError:
        pass


def test_fixed_clear_cards_allows_reroll_refresh() -> None:
    slots = [Slot(), Slot(), Slot()]
    overlay = PickerOverlay(slots, use_fixed_clear=True)
    first = make_bag(["a", "b", "c"])
    overlay.populate(first)
    second = make_bag(["d", "e", "f"])
    overlay.reroll_refresh(second)
    shown = [slot.get_card_fixed().id for slot in slots]
    assert_true(shown == ["d", "e", "f"], f"expected refreshed choices, got {shown}")


def test_bind_before_place_disables_picker_input() -> None:
    card = PickerCard()
    ingredient = Ingredient("a", 1)
    card.bind_picker_card(ingredient, in_tree=False)
    card.place_in_tree()
    assert_true(card.disabled, "bind-before-place should leave card disabled after ready")
    assert_true(not card.mouse_filter_stop, "bind-before-place should ignore picker clicks")


def test_place_before_bind_keeps_picker_input() -> None:
    card = PickerCard()
    ingredient = Ingredient("a", 1)
    card.place_in_tree()
    card.bind_picker_card(ingredient, in_tree=True)
    assert_true(not card.disabled, "place-before-bind should keep card interactive")
    assert_true(card.mouse_filter_stop, "place-before-bind should accept picker clicks")


def test_double_reroll_refresh_stable() -> None:
    slots = [Slot(), Slot(), Slot()]
    overlay = PickerOverlay(slots, use_fixed_clear=True)
    for batch in (["a", "b", "c"], ["d", "e", "f"], ["g", "h", "i"]):
        overlay.reroll_refresh(make_bag(batch))
        shown = [slot.get_card_fixed().id for slot in slots]
        assert_true(shown == batch, f"refresh mismatch: expected {batch}, got {shown}")


def main() -> int:
    tests = [
        test_reroll_preserves_chip_count,
        test_reroll_fails_when_bag_too_small,
        test_reroll_allows_same_id_different_instance,
        test_old_clear_cards_causes_occupant_collision,
        test_fixed_clear_cards_allows_reroll_refresh,
        test_bind_before_place_disables_picker_input,
        test_place_before_bind_keeps_picker_input,
        test_double_reroll_refresh_stable,
    ]
    passed = 0
    for test in tests:
        test()
        passed += 1
        print(f"PASS: {test.__name__}")
    print(f"\nAll {passed} verification checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())