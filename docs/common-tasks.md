# Common tasks

Recipes for the routine modifications. For deeper context on any module, see [module-map.md](./module-map.md) and the per-topic docs.

## Add a new format string to an existing category

The single source of truth is `Defaults.lua` — Schema, Config, and slash UI all derive from it.

1. In `Defaults.lua`, add a new entry under the relevant category's `strings` table:
   ```lua
   YOUR_GLOBAL_NAME = {
       label = "Friendly Label (Self)",
       default = "|cffff0000Loot|cffffffff | |cff93c47dYou|cffffffff | |cffffffff+ %s|cffffffff",
   },
   ```
   - `label` is what the panel shows above the toggle (gold, large).
   - `default` is the PrettyChat format. Match Blizzard's `%`-conversion signature exactly — see [Fix a broken format string](#fix-a-broken-format-string) below for what happens if you don't.
2. `/reload` in-game. The schema rebuilds at file-load, so the new row appears in `/pc list <Category>`, in the panel sub-page, and the override pipeline starts targeting `_G[YOUR_GLOBAL_NAME]`.

No code changes needed. The Schema row, panel widgets, slash-set parsing, Test preview, and `/pc reset <Category>` cleanup all pick the new entry up automatically.

## Add a new category

Categories are top-level keys in `PrettyChatDefaults`. Adding one requires:

1. **`Defaults.lua`** — add a top-level entry:
   ```lua
   YourCategory = {
       enabled = true,
       strings = { /* one or more entries as above */ },
   },
   ```
2. **`Schema.lua`** — append the category name to `CATEGORY_ORDER` (controls display order in the panel left rail and `/pc list`):
   ```lua
   local CATEGORY_ORDER = {
       "General",
       "Loot", "Currency", "Money", "Reputation",
       "Experience", "Honor", "Tradeskill", "Misc",
       "YourCategory",   -- new
   }
   ```
3. (Optional) Add a category-color line to the [color palette](./settings-panel.md#color-palette) section of `docs/settings-panel.md` if you're introducing a new label color.
4. `/reload`. The category appears as a sibling sub-page beneath "Ka0s Pretty Chat" in the addon list, the schema picks up its rows, and `/pc list YourCategory` works.

No `Config.lua` edits — `BuildCategoryOptions` is generic and iterates whatever's in `PrettyChatDefaults[category].strings`.

## Fix a broken format string

A format string "breaks" when the panel-edited (or `/pc set`-edited) value's `%`-conversions don't match Blizzard's signature. Symptom: the chat line errors at `string.format` time, sometimes silently dropping the message, sometimes throwing a Lua error.

1. Open the panel sub-page for the category and read the **Original Format String** disabled input for the affected key. That's Blizzard's exact signature (live from `_G.PrettyChatGlobalStrings`).
2. Edit the **New Format String** input: keep every `%`-conversion (`%s`, `%d`, `%.1f`, `%2$s`, …) in the same order, but freely change surrounding text and `|cAARRGGBB...|r` color escapes.
3. The Preview row below renders the format with sample arguments substituted in (`buildSampleArgs` in `PrettyChat.lua`). If Preview shows a Blizzard-styled error, the conversions are still wrong.
4. To revert: either (a) set the format back to the PrettyChat default exactly — the auto-clear kicks in and removes the override (see [schema.md](./schema.md#auto-clear-on-default)); (b) disable the per-string toggle, which restores Blizzard's original via the snapshot path; or (c) `/pc reset <Category>` to clear every override in that category.

## Edit the PrettyChat default for a string

If you want the *shipped* default for a key to change (not just per-user overrides):

1. Edit the `default` field of the entry in `Defaults.lua`.
2. Existing users with a saved override won't see the change — their stored value still wins. The auto-clear on default match doesn't help retroactively (a value that was the *old* default isn't the *new* default).
3. If you want to force-reset existing users to the new default for that one string, there's no graceful path — they'd need to `/pc reset <Category>` (clears every override, not just yours) or set the format to the new default text exactly (which then auto-clears).
4. For most cases, prefer "ship the new default; existing overrides keep working" — that's the contract.

## Regenerate `GlobalStrings_*.lua` after a WoW patch

See [global-strings.md](./global-strings.md#regenerating-chunks-after-a-wow-patch). Short version:

1. Drop the new `GlobalStrings.lua` into `GlobalStrings/`.
2. `python3 GlobalStrings/split_globalstrings.py`.
3. `/reload` in-game; verify the panel's "Original Format String" inputs still resolve.
4. If Blizzard renamed any keys or changed signatures, update the corresponding entries in `Defaults.lua`.

## Add a new slash command

One row in the `COMMANDS` table at the top of `PrettyChat.lua`:

```lua
{"yourverb", "Description shown in /pc help",
    function(self, rest) yourFunctionBody(self, rest) end},
```

The dispatcher and the help printer iterate the same table — no other edits needed. If your command needs the schema, guard with `if not schemaReady() then return end` (the same pattern the existing schema-touching commands use).

## Adjust the per-string panel row layout

The 12-widget block lives in `Config.lua`'s `BuildStringEntry`. The widget order is encoded by the `i` / `i + 1` / … offsets — increment is 12, so adding a 13th widget means bumping the loop's `i = i + 12` to `i = i + 13` and adding the new widget at `i + 12`.

Width semantics gotcha: `width = N` is `N × 170 px` *absolute*; for a percentage of the row use `width = "relative", relWidth = N`. The Original / New side-by-side rows use `relWidth = 0.5`. See [settings-panel.md](./settings-panel.md#the-width-semantics-gotcha).

## Verify a behavior change in-game

There are no automated tests. Validation is manual:

1. Reload UI (`/reload`) so file-load-time builders re-run.
2. `/pc test` to dump a synthesized sample of every format string. Output ignores enable toggles, so this works even when the addon is disabled.
3. Trigger the real chat events (`/use` an item, gain XP, repair money, etc.) and read the actual chat lines.
4. For panel changes: open `/pc config`, walk to the affected category sub-page, exercise the toggles and edit boxes.

If you can only reason about the change from code and cannot test it in WoW, say so explicitly — don't claim it works.
