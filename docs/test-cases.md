# Test Cases

_Generated — do not hand-edit. Regenerate with `lua tests/run.lua --list > docs/test-cases.md`._

### test_schema.lua (7)

- resolves known setting paths and returns nil for unknown ones
- resolves categories case-insensitively and by prefix
- master toggle round-trips through the single write path
- Set on a format pushes the override to _G via ApplyStrings
- re-setting a format to its default auto-clears the stored override
- Set on an unknown path is a no-op returning false
- load-time schema path validation resolved every path

### test_render.lua (5)

- renders basic %s + %d and collapses %% escapes
- positional %n$s formats degrade gracefully under stock Lua
- empty or nil format returns nil
- malformed conversion surfaces as nil + error string
- a real Blizzard-style default renders without error

### test_apply.lua (6)

- override is applied by default when all three layers are on
- master toggle off restores original, back on reapplies
- category toggle off restores original, back on reapplies
- per-string toggle off restores original, back on reapplies
- ResetString clears both the custom format and the per-string disable
- cross-registered global resolves to the last CATEGORY_ORDER registrant, stably

### test_database.lua (5)

- ns.Database and the db.global namespace exist
- a fresh DB is stamped at the current schema version
- re-running migrations is idempotent
- RunMigrations tolerates a db without a .global namespace
- an older DB is upgraded to the current version

### test_debuglog.lua (10)

- FONT_MONO points at the vendored JetBrainsMono TTF
- pure line formatters render plain and coloured lines
- /pc debug on|off drives the session flag through the SetEnabled seam
- colour-coded chat ack: ON green, OFF red, via [PC]
- enable emits the [Init] session summary after the bracket
- bare /pc debug toggles the window without changing the flag
- header toggle click flips state through the same seam
- ns.Debug is a no-op when off and appends one line when on
- Schema.Set emits one [Set] line with no separate [Apply] echo
- ResetAll emits one [Reset] summary carrying apply counts

### test_slash.lua (4)

- Schema.FormatValue formats bools and doubles pipes in strings
- /pc version prints the tagged version line
- /pc get echoes the gold-key/white-value FormatKV line
- /pc list prints the green header and azure category groups

## Totals

| Suite | Cases |
|-------|------:|
| test_schema.lua | 7 |
| test_render.lua | 5 |
| test_apply.lua | 6 |
| test_database.lua | 5 |
| test_debuglog.lua | 10 |
| test_slash.lua | 4 |
| **Total** | **37** |
