# GlobalStrings Sub-Addon

LoadOnDemand sub-addon containing a searchable copy of Blizzard's GlobalStrings, split into 10 chunk files.

## Files

- `GlobalStrings.lua` — Full Blizzard reference (~1.57 MB, source file, not loaded by any TOC)
- `GlobalStrings_001.lua` ... `GlobalStrings_010.lua` — Chunk files split by first letter of key
- `GlobalStrings.toc` — Sub-addon TOC (`LoadOnDemand: 1`)
- `split_globalstrings.py` — Python script to regenerate chunk files from `GlobalStrings.lua`

## split_globalstrings.py

Parses `GlobalStrings.lua` for `KEY = "value";` entries (ignoring `_G["KEY"]` entries), then splits them into 10 roughly-equal chunk files by first letter of the key.

### Usage

From the project root:

```
python3 GlobalStrings/split_globalstrings.py
```

### What it does

1. Prints letter distribution and target entries per chunk
2. Computes 10 balanced groups of consecutive letters using a greedy algorithm
3. Writes chunk files as `PrettyChatGlobalStrings["KEY"] = "value"` assignments
4. Cleans up old `GlobalStrings_*.lua` files before writing new ones
5. Updates `GlobalStrings.toc` with the new file list

### When to re-run

Re-run this script whenever `GlobalStrings.lua` is updated (e.g., after a new WoW patch). You can get the latest GlobalStrings.lua [here](https://www.townlong-yak.com/framexml/live/Helix/GlobalStrings.lua).
