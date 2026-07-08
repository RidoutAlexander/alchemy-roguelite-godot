#!/usr/bin/env python3
"""Verification for Pocket Watch trinket countdown and doubling logic."""

from __future__ import annotations

import sys

INTERVAL = 21


def doubles(cauldron_count_before: int) -> bool:
    return (cauldron_count_before + 1) % INTERVAL == 0


def countdown(cauldron_count: int) -> int:
    remainder = cauldron_count % INTERVAL
    if remainder == 0:
        return INTERVAL
    return INTERVAL - remainder


def main() -> int:
    assert doubles(20)
    assert not doubles(19)
    assert doubles(41)
    assert countdown(0) == 21
    assert countdown(20) == 1
    assert countdown(21) == 21
    assert countdown(40) == 2
    print("PASS: pocket watch verification checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())