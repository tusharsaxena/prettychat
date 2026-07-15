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
