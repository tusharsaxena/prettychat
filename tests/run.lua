-- tests/run.lua
--
-- Headless test runner for Ka0s Pretty Chat. Loads the addon sources
-- into a mock WoW environment (see wow_mock.lua / loader.lua) and runs
-- the characterization + behaviour suites. Exits non-zero if any check
-- fails, so it can gate commits (audit §14A).
--
-- Each suite registers named cases via ctx.test(name, fn); a case passes
-- when its body neither errors nor trips a failed assertion. The pass
-- count is over cases, and the generated inventory (docs/test-cases.md,
-- testing-§5) enumerates them.
--
-- Run from the repo root:
--   lua tests/run.lua          -- run all suites (non-zero exit on failure)
--   lua tests/run.lua --list   -- print docs/test-cases.md's body; run nothing

-- Resolve the repo root from arg[0] regardless of the caller's cwd.
local root = (function()
    local p   = ((arg and arg[0]) or "tests/run.lua"):gsub("\\", "/")
    local dir = p:match("^(.*)/[^/]*$") or "."          -- .../tests
    return dir:match("^(.*)/[^/]*$") or "."             -- repo root
end)()

local mock      = dofile(root .. "/tests/wow_mock.lua")
local loadAddon = dofile(root .. "/tests/loader.lua")(root, mock)

-- ---- Micro test framework -------------------------------------------
local results = { pass = 0, fail = 0, msgs = {} }
local current = "?"

local function record(cond, msg)
    if cond then
        results.pass = results.pass + 1
    else
        results.fail = results.fail + 1
        results.msgs[#results.msgs + 1] = ("[%s] %s"):format(current, msg or "assertion failed")
    end
end

local t = {}
function t.eq(got, want, msg)
    record(got == want,
        ("%s (expected %q, got %q)"):format(msg or "eq", tostring(want), tostring(got)))
end
function t.neq(got, other, msg)
    record(got ~= other, ("%s (both %q)"):format(msg or "neq", tostring(got)))
end
function t.truthy(v, msg) record(v and true or false, msg or "expected truthy") end
function t.falsy(v, msg)  record(not v, msg or "expected falsy") end
function t.nilv(v, msg)   record(v == nil, (msg or "expected nil") .. " (got " .. tostring(v) .. ")") end

-- ---- Test-case registry ---------------------------------------------
-- Suites call ctx.test(name, fn) to register a case. currentSuite is
-- snapshotted around each dofile so every case is stamped with the
-- suite file it was declared in; cases run in registration order.
local cases = {}
local currentSuite = "?"
local function test(name, fn)
    cases[#cases + 1] = { name = name, suite = currentSuite, fn = fn }
end

local ctx = { t = t, test = test, loadAddon = loadAddon, mock = mock, root = root }

-- ---- Suites ----------------------------------------------------------
-- Order is load-order-sensitive; keep it stable.
local SUITES = {
    "test_schema",
    "test_render",
    "test_apply",
    "test_database",
    "test_debuglog",
    "test_slash",
    "test_util",
}

-- Register every suite. Calling the suite chunk runs its top-level setup
-- and registers its cases via ctx.test, but runs no assertions yet.
for _, name in ipairs(SUITES) do
    currentSuite = name
    local path = root .. "/tests/" .. name .. ".lua"
    local fh = io.open(path, "r")
    if fh then
        fh:close()
        -- dofile runs the chunk and returns the suite function it exports.
        local loaded, runner = pcall(dofile, path)
        if not loaded then
            local err = runner
            test("SUITE LOAD ERROR", function() error(tostring(err), 0) end)
        else
            local ok, err = pcall(runner, ctx)
            if not ok then
                test("SUITE REGISTRATION ERROR", function() error(tostring(err), 0) end)
            end
        end
    end
end

-- ---- --list mode: print the generated inventory and exit -------------
local function listMode()
    for _, a in ipairs(arg or {}) do
        if a == "--list" then return true end
    end
    return false
end

if listMode() then
    local out = {}
    local function line(s) out[#out + 1] = s or "" end

    line("# Test Cases")
    line()
    line("_Generated — do not hand-edit. Regenerate with `lua tests/run.lua --list > docs/test-cases.md`._")
    line()

    local bySuite = {}
    for _, c in ipairs(cases) do
        bySuite[c.suite] = bySuite[c.suite] or {}
        bySuite[c.suite][#bySuite[c.suite] + 1] = c.name
    end

    for _, suite in ipairs(SUITES) do
        local names = bySuite[suite] or {}
        line(("### %s.lua (%d)"):format(suite, #names))
        line()
        for _, nm in ipairs(names) do line("- " .. nm) end
        line()
    end

    line("## Totals")
    line()
    line("| Suite | Cases |")
    line("|-------|------:|")
    local total = 0
    for _, suite in ipairs(SUITES) do
        local n = bySuite[suite] and #bySuite[suite] or 0
        total = total + n
        line(("| %s.lua | %d |"):format(suite, n))
    end
    line(("| **Total** | **%d** |"):format(total))

    print(table.concat(out, "\n"))
    os.exit(0)
end

-- ---- Run -------------------------------------------------------------
local testsPassed, testsFailed = 0, 0
for _, c in ipairs(cases) do
    current = c.suite .. " / " .. c.name
    local failBefore = results.fail
    local ok, err = pcall(c.fn)
    if not ok then
        record(false, "errored: " .. tostring(err))
    end
    if ok and results.fail == failBefore then
        testsPassed = testsPassed + 1
    else
        testsFailed = testsFailed + 1
    end
end

-- ---- Report ----------------------------------------------------------
print(("PrettyChat tests: %d passed, %d failed"):format(testsPassed, testsFailed))
for _, m in ipairs(results.msgs) do print("  FAIL: " .. m) end
os.exit(testsFailed == 0 and 0 or 1)
