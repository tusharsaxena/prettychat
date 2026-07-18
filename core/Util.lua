local addonName, ns = ...

-- ns.Util — tiny pure string helpers shared by the slash dispatcher (settings/Slash.lua)
-- and any other module. Kept here so the colour-wrap helpers have a single home instead
-- of being re-declared per file. Loads after Constants so ns.Const.Color exists.
ns.Util = ns.Util or {}
local Util  = ns.Util
local Color = ns.Const.Color

-- Trim leading/trailing whitespace; nil-safe.
function Util.trim(s)
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

-- note() — white body text (slash help descriptions, notices).
function Util.note(s)
    return Color.white .. s .. Color.reset
end

-- cmd() — gold command text (slash-commands-§4: `/pc <verb>` renders gold).
function Util.cmd(s)
    return Color.yellow .. s .. Color.reset
end

-- Secret-safe output helpers (events-frames-taint-§8). A Blizzard combat
-- "secret" raises when it hits a `..` concatenation or string.format, which
-- would break the shared chat printer (ns.Print) or the debug sink (ns.Debug).
-- IsConcatSafe probes concatenability with table.concat — NEVER `..`, which
-- would itself raise on a secret — so string/number pass and everything else
-- (including bools, which Lua also refuses to `..`) does not. SafeToString
-- returns a display string, substituting a visible placeholder for any value
-- the probe rejects so a protected value can never reach the output path.
function Util.IsConcatSafe(v)
    return (pcall(table.concat, { v })) and true or false
end

function Util.SafeToString(v)
    if v == nil then return "nil" end
    if type(v) == "boolean" then return tostring(v) end
    if Util.IsConcatSafe(v) then return tostring(v) end
    return "<secret>"
end
