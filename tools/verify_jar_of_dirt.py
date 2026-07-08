#!/usr/bin/env python3
"""Verification for Jar of Dirt use limit and break behavior."""

from __future__ import annotations

import sys

MAX_USES = 5


def uses_remaining(chip_uses: int | None) -> int:
    if chip_uses is not None and chip_uses >= 0:
        return chip_uses
    return MAX_USES


def consume_use(chip_uses: int | None) -> tuple[int | None, bool]:
    remaining = uses_remaining(chip_uses)
    remaining -= 1
    broke = remaining <= 0
    return (0 if broke else remaining, broke)


def main() -> int:
    assert uses_remaining(None) == 5
    assert uses_remaining(3) == 3

    uses = None
    for play in range(1, 6):
        uses, broke = consume_use(uses)
        if play < 5:
            assert not broke
            assert uses == MAX_USES - play
        else:
            assert broke
            assert uses == 0

    print("PASS: jar of dirt verification checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())