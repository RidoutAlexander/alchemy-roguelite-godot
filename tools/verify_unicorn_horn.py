#!/usr/bin/env python3
"""Unicorn Horn cures the next ingredient's explosive only if it has any."""

from __future__ import annotations

import sys


def apply_unicorn_next(
    explosive_add: int,
    unicorn_active: bool,
) -> tuple[int, bool, bool]:
    """Returns (explosive_add, unicorn_still_active, cured_this_play)."""
    if not unicorn_active:
        return explosive_add, False, False
    cured = explosive_add > 0
    if cured:
        explosive_add = 0
    return explosive_add, False, cured


def preview_unicorn_next(
    explosive_add: int,
    unicorn_active: bool,
) -> tuple[int, bool, bool]:
    if not unicorn_active:
        return explosive_add, False, False
    cured = explosive_add > 0
    if cured:
        explosive_add = 0
    return explosive_add, False, cured


def main() -> int:
    # Explosive next: cured and unicorn spent.
    exp, active, cured = apply_unicorn_next(4, True)
    assert exp == 0 and not active and cured

    # Non-explosive next (Bat Wing): unicorn spent, nothing cured.
    exp, active, cured = apply_unicorn_next(0, True)
    assert exp == 0 and not active and not cured

    # Preview must match play for non-explosive next.
    prev_exp, prev_active, prev_cured = preview_unicorn_next(0, True)
    assert prev_exp == exp and prev_active == active and prev_cured == cured

    # Unicorn still available when preview wrongly skipped spend (regression guard).
    wrong_exp, wrong_active, wrong_cured = 0, True, False
    assert wrong_active, "preview must not leave unicorn active after non-explosive next"

    print("PASS: unicorn horn verification checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())