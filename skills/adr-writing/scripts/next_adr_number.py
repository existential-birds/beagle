#!/usr/bin/env python3
"""Get the next ADR sequence number.

Scans docs/adrs/ for existing ADRs and returns the next available number.

Usage:
    python scripts/next_adr_number.py
    python scripts/next_adr_number.py --dir /path/to/docs/adrs
    python scripts/next_adr_number.py --count 3  # Pre-allocate 3 numbers for parallel writes
"""

import argparse
import re
import sys
from pathlib import Path


def find_adr_directory() -> Path:
    """Find the ADR directory by searching up from cwd."""
    candidates = [
        Path("docs/adrs"),
        Path("docs/adr"),
        Path("adr"),
        Path("adrs"),
        Path("doc/adr"),
        Path("doc/adrs"),
    ]

    # Search from current directory
    cwd = Path.cwd()
    for candidate in candidates:
        if (cwd / candidate).is_dir():
            return cwd / candidate

    # Search up to git root
    git_root = cwd
    while git_root != git_root.parent:
        if (git_root / ".git").exists():
            break
        git_root = git_root.parent

    for candidate in candidates:
        if (git_root / candidate).is_dir():
            return git_root / candidate

    return cwd / "docs/adrs"


def get_existing_numbers(adr_dir: Path) -> list[int]:
    """Extract ADR numbers from filenames in the directory."""
    pattern = re.compile(r"^(\d{4})-.*\.md$")
    numbers = []

    if not adr_dir.exists():
        return numbers

    for file in adr_dir.iterdir():
        if file.is_file():
            match = pattern.match(file.name)
            if match:
                numbers.append(int(match.group(1)))

    return sorted(numbers)


def next_number(existing: list[int]) -> int:
    """Calculate the next ADR number."""
    if not existing:
        return 1
    return max(existing) + 1


def format_number(num: int) -> str:
    """Format number as zero-padded 4-digit string."""
    return f"{num:04d}"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Get the next ADR sequence number"
    )
    parser.add_argument(
        "--dir",
        type=Path,
        help="ADR directory (auto-detected if not specified)",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List existing ADR numbers",
    )
    parser.add_argument(
        "--count",
        type=int,
        default=1,
        help="Number of sequential ADR numbers to allocate (for parallel writes)",
    )
    args = parser.parse_args()

    adr_dir = args.dir or find_adr_directory()
    existing = get_existing_numbers(adr_dir)

    if args.list:
        if existing:
            print(f"ADR directory: {adr_dir}")
            print(f"Existing ADRs: {[format_number(n) for n in existing]}")
        else:
            print(f"No ADRs found in {adr_dir}")
        return 0

    next_num = next_number(existing)

    if args.count == 1:
        print(format_number(next_num))
    else:
        # Output multiple numbers, one per line, for parallel allocation
        allocated = [format_number(next_num + i) for i in range(args.count)]
        print("\n".join(allocated))

    return 0


if __name__ == "__main__":
    sys.exit(main())
