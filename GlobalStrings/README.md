# GlobalStrings

A searchable copy of Blizzard's GlobalStrings (~22,879 entries), split into 10 chunk files. The chunks populate a single global table, `PrettyChatGlobalStrings`.

The chunks are loaded by **two** different TOCs — see `CLAUDE.md` → `## GlobalStrings Sub-Addon` for the dual-load story. In short:

- `PrettyChat.toc` loads `GlobalStrings_001.lua` … `GlobalStrings_010.lua` *eagerly at addon startup* so the Settings panel can show originals without an explicit load step.
- `GlobalStrings/GlobalStrings.toc` packages the same chunks as a separate `LoadOnDemand: 1` sub-addon (`PrettyChat - GlobalStrings`); `GlobalStringSearch.lua`'s `EnsureLoaded()` calls `LoadAddOn("GlobalStrings")` but the call is effectively idempotent given the eager load above.

## Files

- `GlobalStrings.lua` — Full Blizzard reference (~1.6 MB, source file, not loaded by any TOC; only used as input to `split_globalstrings.py`)
- `GlobalStrings_001.lua` ... `GlobalStrings_010.lua` — Chunk files split by first letter of key
- `GlobalStrings.toc` — LoadOnDemand sub-addon TOC
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
