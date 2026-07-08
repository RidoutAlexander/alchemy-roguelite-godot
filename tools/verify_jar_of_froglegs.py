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


def consume_return_entries(
    played: list[str],
    master: list[str],
    consumed: bool,
    has_trinket: bool,
) -> tuple[list[dict], bool]:
    if consumed or not has_trinket:
        return [], consumed
    return return_entries(played, master), True


def main() -> int:
    entries = return_entries(["frog_a", "frog_b"], ["frog_b", "rat_a"])
    assert len(entries) == 2
    assert entries[0] == {"needs_restore": True}
    assert entries[1] == {"needs_restore": False}

    assert return_entries([], ["frog_a"]) == []
    assert return_entries(["frog_a", "frog_a"], ["frog_a"]) == [
        {"needs_restore": False}
    ]

    consumed = False
    first, consumed = consume_return_entries(
        ["frog_a", "frog_b"],
        [],
        consumed,
        True,
    )
    second, consumed = consume_return_entries(
        ["frog_a", "frog_b"],
        [],
        consumed,
        True,
    )
    assert len(first) == 2
    assert second == []
    assert consumed

    no_trinket, consumed = consume_return_entries(["frog_a"], [], False, False)
    assert no_trinket == []
    assert not consumed

    print("PASS: jar of froglegs verification checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())