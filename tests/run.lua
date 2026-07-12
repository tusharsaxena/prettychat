-- tests/run.lua
--
-- Headless test runner for Ka0s Pretty Chat. Loads the addon sources
-- into a mock WoW environment (see wow_mock.lua / loader.lua) and runs
-- the characterization + behaviour suites. Exits non-zero if any check
-- fails, so it can gate commits (audit §14A).
--
-- Run from the repo root:  lua tests/run.lua

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

local ctx = { t = t, loadAddon = loadAddon, mock = mock, root = root }

-- ---- Suites ----------------------------------------------------------
local SUITES = {
    "test_schema",
    "test_render",
    "test_apply",
    "test_database",
}

for _, name in ipairs(SUITES) do
    current = name
    local path = root .. "/tests/" .. name .. ".lua"
    local fh = io.open(path, "r")
    if fh then
        fh:close()
        -- dofile runs the chunk and returns the suite function it exports.
        local loaded, runner = pcall(dofile, path)
        if not loaded then
            record(false, "SUITE LOAD ERROR: " .. tostring(runner))
        else
            local ok, err = pcall(runner, ctx)
            if not ok then record(false, "SUITE ERROR: " .. tostring(err)) end
        end
    end
end

-- ---- Report ----------------------------------------------------------
print(("PrettyChat tests: %d passed, %d failed"):format(results.pass, results.fail))
for _, m in ipairs(results.msgs) do print("  FAIL: " .. m) end
os.exit(results.fail == 0 and 0 or 1)
