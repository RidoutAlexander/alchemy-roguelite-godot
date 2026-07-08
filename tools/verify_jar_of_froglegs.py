#!/usr/bin/env python3
"""Verification for Jar of Froglegs end-of-level return rules."""

from __future__ import annotations

import sys


def return_entries(played: list[str], master: list[str]) -> list[dict]:
    seen: set[str] = set()
    entries: list[dict] = []
    for chip in played:
        if chip in seen:
            continue
        seen.add(chip)
        entries.append({"needs_restore": chip not in master})
    return entries


def main() -> int:
    entries = return_entries(["frog_a", "frog_b"], ["frog_b", "rat_a"])
    assert len(entries) == 2
    assert entries[0] == {"needs_restore": True}
    assert entries[1] == {"needs_restore": False}

    assert return_entries([], ["frog_a"]) == []
    assert return_entries(["frog_a", "frog_a"], ["frog_a"]) == [
        {"needs_restore": False}
    ]

    print("PASS: jar of froglegs verification checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())