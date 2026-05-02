#!/usr/bin/env python3
"""
Split GlobalStrings.lua into manageable chunk files for GlobalStrings.

Reads GlobalStrings.lua, parses KEY = "value"; entries (ignoring _G["KEY"] entries),
then splits them into 10 roughly-equal chunks by first letter of the key.

Usage:
    python GlobalStrings/split_globalstrings.py
"""

import collections
import glob
import os
import re
import sys

NUM_CHUNKS = 10

# Pattern for KEY = "value"; format (ignores _G["KEY"] = "value"; entries)
RE_SIMPLE = re.compile(r'^([A-Z_][A-Z0-9_]*)\s*=\s*"(.*)"\s*;\s*$')

# Canonical sort order for first characters
# Non-alpha chars go last so they merge into the final chunk
LETTER_ORDER = list("ABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789")


def parse_globalstrings(filepath):
    """Parse GlobalStrings.lua and return list of (key, value) tuples."""
    entries = []
    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n\r")
            m = RE_SIMPLE.match(line)
            if m:
                entries.append((m.group(1), m.group(2)))
    return entries


def compute_chunks(entries, num_chunks):
    """Group entries into num_chunks balanced groups by first letter of key.

    Uses a greedy algorithm: iterate through letters in order, accumulating
    into the current chunk. Start a new chunk when adding the next letter
    group would make the current chunk further from the target than not adding it.
    """
    # Count entries per first character
    counts = collections.Counter()
    for key, _ in entries:
        counts[key[0].upper()] += 1

    # Get sorted list of (letter, count) for letters that actually appear
    letter_counts = []
    seen = set()
    for ch in LETTER_ORDER:
        if ch in counts and ch not in seen:
            letter_counts.append((ch, counts[ch]))
            seen.add(ch)
    # Catch any characters not in LETTER_ORDER
    for ch in sorted(counts):
        if ch not in seen:
            letter_counts.append((ch, counts[ch]))

    total = sum(c for _, c in letter_counts)
    target = total / num_chunks

    # Greedy grouping
    groups = []
    current_letters = []
    current_count = 0

    for i, (letter, count) in enumerate(letter_counts):
        remaining_groups = num_chunks - len(groups)
        remaining_letters = len(letter_counts) - i

        # If remaining letters exactly match remaining groups, give each its own.
        # But never exceed num_chunks — merge excess into the last group.
        if remaining_letters <= remaining_groups and len(groups) < num_chunks - 1:
            if current_letters:
                groups.append((current_letters, current_count))
                current_letters = []
                current_count = 0
            groups.append(([letter], count))
            continue

        # If current chunk is empty, always add
        if not current_letters:
            current_letters.append(letter)
            current_count += count
            continue

        # Would adding this letter overshoot the target?
        if current_count + count > target and remaining_groups > 1:
            # Close current chunk if it's closer to target without this letter
            if abs(current_count - target) <= abs(current_count + count - target):
                groups.append((current_letters, current_count))
                current_letters = [letter]
                current_count = count
                continue

        current_letters.append(letter)
        current_count += count

    # Flush remaining
    if current_letters:
        groups.append((current_letters, current_count))

    return groups


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    input_path = os.path.join(script_dir, "GlobalStrings.lua")
    output_dir = script_dir
    toc_path = os.path.join(script_dir, "GlobalStrings.toc")

    if not os.path.exists(input_path):
        print(f"Error: {input_path} not found", file=sys.stderr)
        sys.exit(1)

    # Clean up old chunk files
    for old_file in glob.glob(os.path.join(output_dir, "GlobalStrings_*.lua")):
        os.remove(old_file)
        print(f"  Removed {os.path.basename(old_file)}")

    print(f"Parsing {input_path}...")
    entries = parse_globalstrings(input_path)
    print(f"Total entries parsed: {len(entries)}")

    # Print letter distribution
    letter_counts = collections.Counter()
    for key, _ in entries:
        letter_counts[key[0].upper()] += 1
    print(f"\nLetter distribution:")
    for ch in LETTER_ORDER:
        if ch in letter_counts:
            print(f"  {ch}: {letter_counts[ch]}")
    for ch in sorted(letter_counts):
        if ch not in LETTER_ORDER:
            print(f"  {ch}: {letter_counts[ch]}")
    print(f"  Target per chunk ({NUM_CHUNKS}): {len(entries) // NUM_CHUNKS}")

    # Compute balanced chunk groups
    groups = compute_chunks(entries, NUM_CHUNKS)

    # Build a lookup: first char -> chunk index
    char_to_chunk = {}
    for i, (letters, _) in enumerate(groups):
        for letter in letters:
            char_to_chunk[letter] = i

    # Distribute entries into chunks
    chunk_entries = [[] for _ in groups]
    for key, value in entries:
        first = key[0].upper()
        idx = char_to_chunk.get(first, len(groups) - 1)
        chunk_entries[idx].append((key, value))

    # Write chunk files
    print()
    total_written = 0
    chunk_filenames = []
    for i, (letters, _) in enumerate(groups):
        filename = f"GlobalStrings_{i + 1:03d}.lua"
        filepath = os.path.join(output_dir, filename)
        items = chunk_entries[i]
        letter_range = "".join(letters)

        with open(filepath, "w", encoding="utf-8", newline="\n") as f:
            f.write("PrettyChatGlobalStrings = PrettyChatGlobalStrings or {}\n")
            for key, value in items:
                f.write(f'PrettyChatGlobalStrings["{key}"] = "{value}"\n')

        print(f"  {filename} [{letter_range}]: {len(items)} entries")
        chunk_filenames.append(filename)
        total_written += len(items)

    # Update TOC file
    if os.path.exists(toc_path):
        with open(toc_path, "r", encoding="utf-8") as f:
            lines = f.readlines()

        # Keep header lines (## directives and blank lines before file list)
        header = []
        for line in lines:
            stripped = line.strip()
            if stripped.startswith("##") or stripped == "":
                header.append(line)
            else:
                break

        with open(toc_path, "w", encoding="utf-8", newline="\n") as f:
            for line in header:
                f.write(line)
            for filename in chunk_filenames:
                f.write(filename + "\n")

        print(f"\nUpdated {os.path.basename(toc_path)} with {len(chunk_filenames)} chunk files")

    print(f"\nTotal entries written: {total_written}")
    if total_written != len(entries):
        print("WARNING: Entry count mismatch!", file=sys.stderr)
        sys.exit(1)
    print("Done!")


if __name__ == "__main__":
    main()
