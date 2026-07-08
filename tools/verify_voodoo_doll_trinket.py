#!/usr/bin/env python3
"""Verification for Voodoo Doll trinket shop price and rarity overrides."""

from __future__ import annotations

import sys

VOODOO_DOLL_ID = "voodoo_doll"
VOODOO_DOLL_TRINKET_ID = "voodoo_doll_trinket"
VOODOO_DOLL_TRINKET_SHOP_COST = 6

RARITY_COMMON = 0
RARITY_EPIC = 3

SHOP_RARITY_WEIGHTS = [5, 4, 3, 2, 1]


def has_voodoo_doll_trinket(trinket_ids: list[str]) -> bool:
    return VOODOO_DOLL_TRINKET_ID in trinket_ids


def shop_price_for_ingredient(ingredient_id: str, base_cost: int, trinket_ids: list[str]) -> int:
    if has_voodoo_doll_trinket(trinket_ids) and ingredient_id == VOODOO_DOLL_ID:
        return VOODOO_DOLL_TRINKET_SHOP_COST
    return base_cost


def shop_rarity_for_ingredient(ingredient_id: str, base_rarity: int, trinket_ids: list[str]) -> int:
    if has_voodoo_doll_trinket(trinket_ids) and ingredient_id == VOODOO_DOLL_ID:
        return RARITY_COMMON
    return base_rarity


def rarity_weight(ingredient_id: str, base_rarity: int, trinket_ids: list[str]) -> int:
    rarity = shop_rarity_for_ingredient(ingredient_id, base_rarity, trinket_ids)
    return SHOP_RARITY_WEIGHTS[rarity]


def main() -> int:
    without: list[str] = []
    with_trinket = [VOODOO_DOLL_TRINKET_ID]

    assert shop_price_for_ingredient(VOODOO_DOLL_ID, 12, without) == 12
    assert shop_price_for_ingredient(VOODOO_DOLL_ID, 12, with_trinket) == 6
    assert shop_price_for_ingredient("frog_leg", 8, with_trinket) == 8

    assert shop_rarity_for_ingredient(VOODOO_DOLL_ID, RARITY_EPIC, without) == RARITY_EPIC
    assert shop_rarity_for_ingredient(VOODOO_DOLL_ID, RARITY_EPIC, with_trinket) == RARITY_COMMON
    assert shop_rarity_for_ingredient("frog_leg", RARITY_EPIC, with_trinket) == RARITY_EPIC

    assert rarity_weight(VOODOO_DOLL_ID, RARITY_EPIC, without) == SHOP_RARITY_WEIGHTS[RARITY_EPIC]
    assert rarity_weight(VOODOO_DOLL_ID, RARITY_EPIC, with_trinket) == SHOP_RARITY_WEIGHTS[RARITY_COMMON]

    assert shop_price_for_ingredient(VOODOO_DOLL_ID, 12, with_trinket) <= 10

    print("PASS: voodoo doll trinket verification checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())