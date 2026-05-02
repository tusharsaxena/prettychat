# Ka0s Pretty Chat

![wow](https://img.shields.io/badge/WoW-Midnight_12.0.5-orange)
![CurseForge Version](https://img.shields.io/curseforge/v/919766)
![license](https://img.shields.io/badge/license-MIT-green)

![alt text](https://media.forgecdn.net/attachments/1659/647/prettychat-logo-v2-jpg.jpg)

PrettyChat is a lightweight, single-folder WoW addon that reformats system chat messages — loot, currency, money, reputation, experience, honor, tradeskill, and a handful of misc events — into a color-coded, pipe-delimited layout that's easier to scan in a busy chat window.

Rather than parsing chat events, PrettyChat overrides Blizzard's `GlobalStrings.lua` format strings directly. That means it works with the default Blizzard chat frame and any UI replacement (ElvUI, Glass, etc.) without configuration, and never has to inspect or rewrite messages at runtime.

Everything is configurable through the standard Blizzard Settings panel and through the `/pc` slash command — every per-string toggle and editable format string in the panel is also addressable from chat by dot path.

## Screenshots

**_Without Pretty Chat_**

![Without Pretty Chat](https://media.forgecdn.net/attachments/738/967/before.png)

**_With Pretty Chat_**

![With Pretty Chat](https://media.forgecdn.net/attachments/738/969/after.png)

## Usage

### Slash commands

`/pc` and `/prettychat` are aliases for the same dispatcher. All chat output from the addon is prefixed with a cyan `[PC]` tag.

| Command | Effect |
|---------|--------|
| `/pc` / `/pc help` | Show the slash-command help in chat |
| `/pc config` | Open the settings panel (refuses during combat — Blizzard's category-switch is protected) |
| `/pc list` | List every setting (long; ~170 rows). Pass a category name to filter, e.g. `/pc list Loot` |
| `/pc get <path>` | Print one setting's current value (e.g. `/pc get Loot.LOOT_ITEM_SELF.enabled`) |
| `/pc set <path> <value>` | Set one setting (e.g. `/pc set Loot.enabled false`). Bools accept `true/false/on/off/yes/no/1/0` |
| `/pc reset <Category>` | Reset one category to defaults |
| `/pc resetall` | Reset every category to defaults |
| `/pc test` | Print a sample of every format string to chat. Preview ignores enable toggles, so it works even when the addon is disabled |

### Settings panel

PrettyChat appears in the Blizzard Settings panel under **Ka0s Pretty Chat**. The parent page hosts only a description; nine sub-pages hold the actionable controls. Each sub-page is a sibling row in the addon list, so each gets the full right-pane width to itself — no tab strip.

*   **General** — addon-wide controls. **Enable PrettyChat** master toggle (when off, every Blizzard original is restored regardless of per-category state), a **Test** button (prints a sample of every format string to chat so you can see what each looks like), and the **Reset All to Defaults** button.
*   **Loot** — 19 strings covering item pickups, self/group loot, bonus rolls, and currency drops via loot.
*   **Currency** — 4 strings for currency gains and losses (including loss-from-death).
*   **Money** — 8 strings for gold/silver/copper pickups, loot-money splits, guild bank deposits, generic gains, and quest reward money.
*   **Reputation** — 14 strings for faction standing changes (increases, decreases, threshold transitions).
*   **Experience** — 20 strings covering all `COMBATLOG_XPGAIN_*` variants (rested, group, raid, …).
*   **Honor** — 6 strings for honor and combat-log honor awards.
*   **Tradeskill** — 8 strings for crafted-item creation and lock opening.
*   **Misc** — 2 catch-all strings (quest reward XP, zone exploration).

Each category sub-page lists every format string it owns. A row contains: an **Enable** checkbox, the GlobalString key name (e.g. `LOOT_ITEM_SELF`), a side-by-side pair of edit boxes showing the original Blizzard format string and the editable PrettyChat replacement, and a full-width preview that renders the current format with sample arguments substituted in. Disabled strings revert to Blizzard's original at runtime.

## Notes

A few user-facing behaviors worth knowing. Implementation details live in [ARCHITECTURE.md](ARCHITECTURE.md).

- **The master toggle wins.** `General → Enable PrettyChat` (or `/pc set General.enabled false`) restores every Blizzard original regardless of per-category and per-string state. Your customizations stay in the database, just unapplied.
- **Three enable layers**, checked in this order: master → category → per-string. A string only renders with your format if all three are on.
- **Edit format strings from the panel.** It shows raw escape codes (`|cAARRGGBB...|r`) and renders a live preview as you type. Editing from chat is supported but you must double `|` → `||` (WoW's chat input interprets `|c…|r` as inline color escapes the moment you press Enter).
- **Format specifiers must match Blizzard's.** Each Blizzard string has a fixed signature (`%s`, `%d`, `%.1f`, `%2$s`, etc.). Drop or reorder a `%`-conversion and the line errors at `string.format`. Copy from the panel's left (Original) edit box and only modify the surrounding text and color escapes.
- **Reset paths.** Whole category: `/pc reset <Category>`. One string back to Blizzard's original: `/pc set <Category>.<GLOBALNAME>.enabled false`. One string back to PrettyChat's default: set the format to its default value — the schema clears overrides that match the default automatically.

## FAQ

| Question | Answer |
|----------|--------|
| Does this work with ElvUI / Glass / other chat replacements? | Yes. PrettyChat overrides Blizzard's `GlobalStrings.lua` format strings before any chat frame sees them. Any UI that consumes Blizzard's chat events gets the formatted output for free — no hooks, no per-message rewriting. |
| Why do some lines still look like Blizzard's defaults? | Three layers may be off: the master toggle (`/pc get General.enabled`), the category (`/pc get <Category>.enabled`), or that specific string (`/pc get <Category>.<GLOBALNAME>.enabled`). Disabled strings are restored to Blizzard's original at runtime — by design. `/pc list <Category>` shows every toggle in one place. |
| I edited a format string and now it shows raw `%s` markers or errors. | The replacement consumes wrong / missing `%`-conversions. Reset one string: disable it (`/pc set <Category>.<GLOBALNAME>.enabled false`) or copy Blizzard's exact format from the panel's left edit box. Reset a whole category: `/pc reset <Category>`. |
| Where are settings stored? Per-character? | In `PrettyChatDB` via AceDB, on a single shared **Default** profile — every character on the account uses the same configuration. Per-character / per-class / per-realm profile scoping is not exposed in the panel today; if you want it, file an issue. |

## Troubleshooting

| Symptom | Diagnosis & fix |
|---------|-----------------|
| Chat looks unchanged after installing | Check in order: `/pc get General.enabled` → must be `true`; `/pc get <Category>.enabled` → must be `true`; `/pc get <Category>.<GLOBALNAME>.enabled` → must be `true`. Run `/pc test` — if test output is formatted but real chat lines aren't, another addon is overriding the same `_G[GLOBALNAME]` later in load order. |
| An edited format string breaks the line / errors | The replacement's `%`-conversions don't match Blizzard's signature. Reset the whole category (`/pc reset <Category>`), or copy Blizzard's exact string from the panel's left (Original) edit box. |
| Settings panel won't open from chat | `/pc config` needs the addon fully loaded — try again after the load screen completes. It also refuses during combat (Blizzard's category-switch is protected). If the parent page opens but a sub-category doesn't, click the sub-row in the addon list. |
| Want a clean slate | One category: `/pc reset <Category>` (e.g. `/pc reset Loot`). Everything including the master toggle: `/pc resetall` (or General → **Reset All to Defaults**). |

## Issues and feature requests

All bugs, feature requests, and outstanding work are tracked at [https://github.com/tusharsaxena/prettychat/issues](https://github.com/tusharsaxena/prettychat/issues). Please file new reports there rather than as comments — the issue tracker is the single source of truth for the project's backlog.

## Version History

| Version | Changes |
|---------|---------|
| **1.2.0** | New General sub-page (master Enable toggle, Test button, Reset All); schema-driven slash commands (`/pc list/get/set/reset/resetall/test`) sharing one write path with the panel; settings restructured into Blizzard sub-pages (one per category, no tab strip) with side-by-side Original/New edit boxes per string. |
| **1.1.0** | Full configuration UI via `/pc` / `/prettychat`: per-string customization with live preview, per-category and per-string enable toggles (disabled strings revert to Blizzard defaults), reset-to-defaults, and AceDB profile storage. |
| **1.0.0** | Initial release … yay! |
