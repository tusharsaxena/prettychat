# Testing

Contributor-facing verification guide. (Player-facing docs live in the root [README](../README.md); this content was moved out of the README under the Ka0s Standard v2.1.0, which keeps the README player-only.)

## Headless harness

PrettyChat ships a headless test harness that runs under stock Lua 5.1 with no WoW client — it loads the addon sources into a mock WoW environment and exercises the schema, sample renderer, apply pipeline, migration runner, slash dispatcher, and debug console.

```sh
lua tests/run.lua          # run every suite (exits non-zero on failure)
lua tests/run.lua --list   # print the test-case inventory (runs nothing)
luacheck .                 # static analysis (config in .luacheckrc)
```

## The gate

Both `lua tests/run.lua` and `luacheck .` must be green before any commit. The suites register named `test(name, fn)` cases; the `Tests` badge in the README badge row shows the pass/total.

## Test-case inventory & badge sync (`testing-§5`)

The authoritative case count lives in the **generated** inventory [`test-cases.md`](./test-cases.md) — every case, grouped by suite, with per-suite and grand totals. It is produced by the runner's `--list` mode, never hand-edited:

```sh
lua tests/run.lua --list > docs/test-cases.md   # regenerate the inventory
# verify it's in sync (CR-agnostic, since docs are CRLF on disk):
diff --strip-trailing-cr <(lua tests/run.lua --list) docs/test-cases.md
```

Whenever the suite changes — a case added, removed, or renamed, or the pass count moves (i.e. whenever a failing test is resolved) — regenerate `docs/test-cases.md` and update the README `Tests` badge count **in the same change**, never as a follow-up.

## In-game validation

For behaviour stock Lua can't cover (panel rendering, live chat overrides, positional `%n$s` formats), follow the manual [smoke-test suite](./smoke-tests.md) — it lists which invariant each test guards, so a failure can be tied back to a specific area of the addon.
