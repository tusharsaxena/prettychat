# Slash commands

`/pc` and `/prettychat` are aliases for the same dispatcher (`PrettyChat:OnSlashCommand`). All chat output from the addon is prefixed with the cyan `[PC]` tag via `ns.Print`.

This doc covers: the dispatch shape, the full command reference, and the `||` ↔ `|` chat-input escape that bites users on `/pc set` for format strings.

## The `COMMANDS` table

`PrettyChat.lua` defines an ordered table at the top of the file:

```lua
local COMMANDS = {
    {"help",     "...", function(self) printHelp(self) end},
    {"config",   "...", function(self) ... end},
    {"list",     "...", function(self, rest) listSettings(self, rest) end},
    {"get",      "...", function(self, rest) getSetting(self, rest) end},
    {"set",      "...", function(self, rest) setSetting(self, rest) end},
    {"reset",    "...", function(self, rest) runReset(self, rest) end},
    {"resetall", "...", function(self) runResetAll(self) end},
    {"test",     "...", function(self) self:Test() end},
}
```

The table drives **both** dispatch (`OnSlashCommand` linear-searches it) **and** help (`printHelp` iterates the same table). Adding a command means adding one row — help text and dispatch never drift.

`OnSlashCommand(input)` parses `<command> <rest>`, lowercases the command name, and **preserves case in `rest`** — so dot paths like `Loot.LOOT_ITEM_SELF.format` survive intact through to `set` / `get`. Both `/pc` and `/prettychat` route to the same dispatcher.

Unknown commands and the empty input fall back to `printHelp`.

## Command reference

| Command | Effect |
|---------|--------|
| `/pc` / `/pc help` | Print the help index via `ns.Print`. Header line includes the addon version (`v<VERSION>`, read from TOC `## Version:` at file load via `C_AddOns.GetAddOnMetadata`). |
| `/pc config` | Open the Blizzard settings panel to the parent page. **Refuses during combat** (`InCombatLockdown()`) — Blizzard's category-switch is protected and would taint the panel. Prints a notice and stops if combat is active. |
| `/pc list` | List every setting and its current value, grouped by category (~170 lines). With ~170 rows the output is long, but it's the only way the slash UI reaches parity with the panel (which exposes a toggle and a format edit-box per string). |
| `/pc list <Category>` | Filter to one category. Case-insensitive (`/pc list loot` works). Prints the category toggle + every per-string `.enabled` and `.format` row. Unknown categories print the valid list. |
| `/pc get <path>` | Print one row's current value (e.g. `/pc get Loot.LOOT_ITEM_SELF.enabled` or `/pc get General.enabled`). |
| `/pc set <path> <value>` | Write one row through `ns.Schema.Set`. `bool` accepts `true/false/on/off/yes/no/1/0`; `string` consumes the rest of the line literally. For `string_format` rows, setting `<value>` to the row's PrettyChat default clears the override (see [schema.md](./schema.md#auto-clear-on-default)). |
| `/pc reset <Category>` | Clear all overrides for one category (case-insensitive name). For `General`, clears the addon-wide enabled override back to default (true). |
| `/pc resetall` | Clear every category's overrides AND the addon-wide enabled flag. |
| `/pc test` | Synthesize a sample chat line from every format string regardless of enable toggles (same action as the General page's Test button). See [settings-panel.md](./settings-panel.md#the-test-preview). |
| unknown command | Print the help index (with an "unknown command" warning first). |

Output is colored: yellow (`|cffffff00`) for command names via the local `cmd()` helper, white (`|cffffffff`) for explanatory notes via `note()`. The header line includes the version banner.

## Edit-box pipe escaping

WoW chat input interprets `|c…|r` as inline color escapes the moment the user presses Enter. To send a literal `|` through `/pc set`, the user must type `||`. So setting a format string from chat looks like:

```
/pc set Loot.LOOT_ITEM_SELF.format ||cffff0000Loot||r | ||cff93c47dYou||r | + %s
```

The settings panel's format input box wraps this internally — `Config.lua`'s edit-box `get` does `:gsub("|", "||")` and `set` does `:gsub("||", "|")`, so users see double-escaped strings while editing but `ns.Schema` always stores raw single-`|` format strings. `/pc set` users have to type `||` themselves; the slash command body does **no** un-escaping.

`/pc get` output renders with colors applied (single `|` is sent through `ns.Print` → `DEFAULT_CHAT_FRAME:AddMessage`, which interprets the escapes).

This is why the settings panel is the recommended editing surface for format strings — the `||` boundary is hostile to direct chat editing. `/pc set` is a power-user path.

## Per-command internals

Each command body is a small file-local function in `PrettyChat.lua`:

| Function | Responsibility |
|----------|----------------|
| `printHelp(self)` | Iterate `COMMANDS` and print one yellow-name + white-description line per row. Header includes the version banner. |
| `listSettings(self, rest)` | If `rest` is empty: print every row across every category in `CATEGORY_ORDER` order. Else: resolve `rest` via `ns.Schema.ResolveCategory` and print only that category. Format: `"  <path> = <value>"` with values quoted for strings, raw for bools. |
| `getSetting(self, rest)` | Parse `<path>`, look up via `ns.Schema.FindByPath`, print `"<path> = <value>"`. Errors with `"setting not found"` for unknowns. |
| `setSetting(self, rest)` | Parse `<path> <value>`, look up the row, parse the value to the row's declared type (`bool` accepts seven aliases, `string` consumes the rest of the line), then call `ns.Schema.Set(path, newVal)`. Echoes the new value back via `ns.Schema.Get`. |
| `runReset(self, rest)` | Resolve `<Category>` and call `PrettyChat:ResetCategory(matched)`. No in-chat confirmation — the command itself is the assertion. |
| `runResetAll(self)` | Call `PrettyChat:ResetAll()`. No in-chat confirmation. |

`schemaReady()` guards each schema-touching command — prints `"schema not ready yet"` if `ns.Schema` hasn't loaded (shouldn't happen in practice given the TOC load order, but cheap to check).

## Why no chat-side confirm popup for resets

The slash command itself is the assertion. The panel buttons gate Reset / Reset All behind AceConfig `confirm = true` popups because mis-clicks happen; chat reset commands take more typing and rarely fire by accident. If the asymmetry ever bites, add a `StaticPopupDialogs` confirmation in `runResetAll` — but don't add one mid-feature without a triggering complaint.

## What lives in the panel but NOT in the slash UI

Three things you can't reach via `/pc`:

- **Per-string Reset to PrettyChat default**. Indirect: `/pc set <Cat>.<NAME>.format <default value>` triggers the auto-clear, but you'd have to type the default exactly. The panel's per-category Reset is the practical path.
- **Live preview of an unsaved edit.** The panel's Preview row renders `ns.Schema.Get(formatPath)`, which reflects the saved value. Slash users get the same preview *after* `/pc set` lands, via `/pc test`.
- **Visual diff between Original and New.** The panel renders both side-by-side. Chat users would need `/pc get` against the format row plus an external GlobalStrings reference.

These gaps are by design — the panel is the editing surface, slash is for scripted / power-user workflows.
