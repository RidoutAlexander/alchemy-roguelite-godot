#!/usr/bin/env python3
"""Verification for Jar of Froglegs end-of-level return rules."""

from __future__ import annotations

import sys


def return_entries(played: list[str], master: list[str]) -> list[dict]:
    seen: set[str] = set()
    entries: list[dict] = []
    restores_remaining = 0
    for chip in played:
        if chip in seen:
            continue
        seen.add(chip)
        needs_restore = chip not in master
        if needs_restore:
            restores_remaining += 1
        entries.append(
            {
                "needs_restore": needs_restore,
                "played_chip": chip,
            }
        )
    return entries, restores_remaining


def restore_to_master(
    master: list[str],
    played_chip: str | None,
    restores_remaining: int,
) -> tuple[list[str], int]:
    if restores_remaining <= 0:
        return master, restores_remaining
    if played_chip is not None and played_chip in master:
        return master, restores_remaining
    restores_remaining -= 1
    return master + ["frog_leg_restored"], restores_remaining


def consume_return_entries(
    played: list[str],
    master: list[str],
    consumed: bool,
    has_trinket: bool,
) -> tuple[list[dict], int, bool]:
    if consumed or not has_trinket:
        return [], 0, consumed
    entries, restores_remaining = return_entries(played, master)
    return entries, restores_remaining, True


def main() -> int:
    entries, restores = return_entries(["frog_a", "frog_b"], ["frog_b", "rat_a"])
    assert len(entries) == 2
    assert entries[0] == {"needs_restore": True, "played_chip": "frog_a"}
    assert entries[1] == {"needs_restore": False, "played_chip": "frog_b"}
    assert restores == 1

    assert return_entries([], ["frog_a"]) == ([], 0)
    assert return_entries(["frog_a", "frog_a"], ["frog_a"]) == (
        [{"needs_restore": False, "played_chip": "frog_a"}],
        0,
    )

    consumed = False
    first, restores, consumed = consume_return_entries(
        ["frog_a", "frog_b"],
        [],
        consumed,
        True,
    )
    second, _, consumed = consume_return_entries(
        ["frog_a", "frog_b"],
        [],
        consumed,
        True,
    )
    assert len(first) == 2
    assert restores == 2
    assert second == []
    assert consumed

    no_trinket, _, consumed = consume_return_entries(["frog_a"], [], False, False)
    assert no_trinket == []
    assert not consumed

    # Single bought frog leg played but still in master: visual return only.
    single_buy, restores = return_entries(["frog_a"], ["frog_a"])
    assert single_buy == [{"needs_restore": False, "played_chip": "frog_a"}]
    assert restores == 0

    # Escaped frog leg: one restore budget even if finalize reruns animations.
    escaped, restores = return_entries(["frog_a"], [])
    assert restores == 1
    master: list[str] = []
    for entry in escaped:
        if entry["needs_restore"]:
            master, restores = restore_to_master(
                master,
                entry["played_chip"],
                restores,
            )
    assert master == ["frog_leg_restored"]
    assert restores == 0

    # Extra animation entries cannot exceed the restore budget.
    escaped, restores = return_entries(["frog_a"], [])
    master = []
    for _ in range(3):
        for entry in escaped:
            if entry["needs_restore"]:
                master, restores = restore_to_master(
                    master,
                    entry["played_chip"],
                    restores,
                )
    assert master == ["frog_leg_restored"]

    print("PASS: jar of froglegs verification checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())