-- tests/loader.lua
--
-- Loads the addon's Lua sources into a fresh mock environment in TOC
-- order and runs the AceAddon lifecycle (OnInitialize + OnEnable), so
-- each call returns a fully-booted, isolated addon instance:
--
--   { env = <mock _G>, ns = <addon namespace>, addon = <AceAddon obj> }
--
-- Before OnEnable, every schema-registered Blizzard global is seeded with
-- a recognisable pristine value ("ORIG:<NAME>") so the "restore on
-- disable" path in ApplyStrings is testable.

-- Source files in the same order PrettyChat.toc loads them (libs and the
-- GlobalStrings chunks are supplied by the mock / not needed headlessly).
local SOURCES = {
    "locales/enUS.lua",
    "core/Compat.lua",
    "core/Constants.lua",
    "core/Namespace.lua",
    "core/State.lua",
    "core/Util.lua",
    "core/Database.lua",
    "core/DebugLog.lua",
    "core/PrettyChat.lua",
    "defaults/Profile.lua",
    "defaults/Defaults.lua",
    "modules/Override.lua",
    "settings/Schema.lua",
    "settings/Slash.lua",
    "settings/Panel.lua",
}

-- Returns a loader closure bound to the repo root + mock module.
return function(root, mock)
    return function()
        local env = mock.newEnv()
        local ns  = {}
        local addonName = "PrettyChat"

        for _, rel in ipairs(SOURCES) do
            local path = root .. "/" .. rel
            local fh = io.open(path, "r")
            if fh then          -- optional modules may not exist yet
                fh:close()
                local chunk, err = loadfile(path)
                if not chunk then
                    error(("loadfile(%s) failed: %s"):format(rel, tostring(err)))
                end
                setfenv(chunk, env)
                chunk(addonName, ns)
            end
        end

        local addon = env.LibStub("AceAddon-3.0"):GetAddon("PrettyChat")
        if addon.OnInitialize then addon:OnInitialize() end

        -- Seed pristine Blizzard originals for every registered global so
        -- the snapshot in OnEnable captures them.
        if ns.Schema and ns.Schema.CATEGORY_ORDER then
            local seen = {}
            for _, cat in ipairs(ns.Schema.CATEGORY_ORDER) do
                for _, row in ipairs(ns.Schema.RowsByCategory(cat)) do
                    if row.globalName and not seen[row.globalName] then
                        seen[row.globalName] = true
                        env[row.globalName] = "ORIG:" .. row.globalName
                    end
                end
            end
        end

        if addon.OnEnable then addon:OnEnable() end

        return { env = env, ns = ns, addon = addon }
    end
end
