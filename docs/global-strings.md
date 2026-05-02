# GlobalStrings sub-tree

`GlobalStrings/` ships a searchable copy of Blizzard's `GlobalStrings.lua` (~22,879 entries), split into 10 chunk files by first letter of key. The chunks populate a single global table, `PrettyChatGlobalStrings`.

## Two TOCs reference these chunks

This is intentional, but worth flagging because the historical name "LoadOnDemand sub-addon" is misleading about runtime behavior.

- **`PrettyChat.toc`** loads `GlobalStrings_001.lua` … `GlobalStrings_010.lua` *eagerly at addon startup* (load order: after `Libs/`, before `Defaults.lua`). This populates `PrettyChatGlobalStrings` so `Config.lua`'s "Original Format String" disabled input can resolve every key without an explicit load step.
- **`GlobalStrings/GlobalStrings.toc`** is a separate `LoadOnDemand: 1` sub-addon (`PrettyChat - GlobalStrings`, version `1.1.0`) that *also* loads the same chunks. `GlobalStringSearch:EnsureLoaded()` calls `C_AddOns.LoadAddOn("GlobalStrings")`, but because the chunks are already loaded by the main TOC, the call is effectively idempotent (Blizzard returns the addon as already-loaded).

The redundant load path exists for historical reasons: the sub-addon was originally LoD-only, then the main TOC was given the chunks directly when the Settings panel started rendering originals at panel-open time. The LoD packaging now mostly serves as a guard for a future world where the eager load is removed (e.g. to cut startup memory).

## Files

| Path | Purpose |
|------|---------|
| `GlobalStrings/GlobalStrings.lua` | Full Blizzard reference (~1.6 MB, source file). **Not loaded by any TOC** — only used as input to `split_globalstrings.py`. |
| `GlobalStrings/GlobalStrings_001.lua` … `_010.lua` | Chunk files split by first letter of key. Each emits `PrettyChatGlobalStrings["KEY"] = "value"` assignments. |
| `GlobalStrings/GlobalStrings.toc` | LoadOnDemand sub-addon TOC. |
| `GlobalStrings/split_globalstrings.py` | Splitter script — re-run after a WoW patch. |
| `GlobalStrings/README.md` | Splitter usage instructions. |

## The `PrettyChatGlobalStrings` global

Populated eagerly at addon load. Keyed by Blizzard's `GLOBALNAME` constants, valued with the Blizzard-default format string (the same string `_G[GLOBALNAME]` would return at addon load time, *before* PrettyChat overrides anything).

This is the same data PrettyChat snapshots into `self.originalStrings` at `OnEnable` for the "restore on disable" path — but `originalStrings` only covers keys mentioned in `PrettyChatDefaults` (~81 entries), while `PrettyChatGlobalStrings` carries the full ~22,879. The extra entries support the panel's "Original Format String" display for any global key, even ones the user has added to `Defaults.lua` since the addon last shipped.

## The search API

`ns.GlobalStringSearch` (defined in `GlobalStringSearch.lua`) exposes:

```lua
ns.GlobalStringSearch:EnsureLoaded()                 -- C_AddOns.LoadAddOn("GlobalStrings"); idempotent
ns.GlobalStringSearch:FindByKey(pattern, limit?)     -- substring match against keys, case-insensitive
ns.GlobalStringSearch:FindByValue(pattern, limit?)   -- substring match against values
ns.GlobalStringSearch:Find(pattern, limit?)          -- both
```

Returns sorted `{ {key, value}, ... }` arrays. `limit` defaults to 50.

**Not consumed by any slash command or panel widget today** — it's available for future debug tooling. `Config.lua` reads `_G.PrettyChatGlobalStrings` directly rather than going through this API.

## Regenerating chunks after a WoW patch

When Blizzard ships a new client (TWW patch, Midnight feature drop, etc.) the `GlobalStrings.lua` reference may add / rename / remove entries. To resync:

1. Drop the new `GlobalStrings.lua` into `GlobalStrings/`. Source: [townlong-yak.com](https://www.townlong-yak.com/framexml/live/Helix/GlobalStrings.lua).
2. From the project root: `python3 GlobalStrings/split_globalstrings.py`.

The script:

1. Parses the source for `KEY = "value";` entries (ignoring `_G["KEY"]` forms).
2. Computes 10 balanced groups of consecutive letters using a greedy algorithm (so each chunk file is roughly the same size — keeps load times even).
3. Cleans up old `GlobalStrings_*.lua` files.
4. Writes the new chunk files as `PrettyChatGlobalStrings["KEY"] = "value"` assignments.
5. Updates `GlobalStrings/GlobalStrings.toc`'s file list to match.

The main `PrettyChat.toc` is **not** updated by the script — its `GlobalStrings\GlobalStrings_001.lua` … `_010.lua` lines are stable as long as the chunk count stays at 10. If the splitter is ever changed to produce a different number of chunks, update both TOCs.

After regenerating, `/reload` in-game and verify the panel's "Original Format String" inputs still resolve for every category. If a Blizzard format-string signature changed (e.g. `%s` → `%2$s`), the corresponding `PrettyChatDefaults` entry in `Defaults.lua` needs updating to match — see [common-tasks.md](./common-tasks.md#fix-a-broken-format-string). Run the full [smoke-test suite](./smoke-tests.md) — a client patch can shift behavior anywhere in the override pipeline, not just in the keys you re-split.

## Why split into chunks?

WoW will refuse to load a Lua file beyond a certain size threshold (the exact limit varies by client version; `GlobalStrings.lua` at ~1.6 MB has historically been over). The 10-chunk split keeps each file comfortably under the threshold while still letting the data load deterministically in a single pass.

The split-by-first-letter approach is arbitrary but stable — keys never move between chunks unless you change the splitter, so version-control diffs after a re-split stay readable.
