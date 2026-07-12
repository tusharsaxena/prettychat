-- tests/wow_mock.lua
--
-- Builds a mock WoW global environment so the addon's Lua sources can be
-- loaded and exercised headlessly under stock Lua 5.1 (no WoW client).
--
-- Design notes:
--   * Frame/widget mocks are self-returning no-ops — enough that any
--     CreateFrame():SetPoint():Show() chain won't crash. They are NOT
--     asked to model layout behaviour; no test drives the panel.
--   * The DB and the _G global-string table ARE real Lua tables, so the
--     schema / apply / render logic is genuinely exercised (per the
--     harness design in audit/2026-07-12/04_TECHNICAL_DESIGN.md §A).
--   * `_G` is the env itself, so `_G[GLOBALNAME] = value` writes in
--     ApplyStrings land back in the same table the loader reads.

local M = {}

-- Metadata returned by C_AddOns.GetAddOnMetadata (tests may override).
M.metadata = {
    Version  = "1.3.0",
    Notes    = "Prettier chat messages",
    Title    = "Ka0s Pretty Chat",
    IconTexture = "2056011",
}

local function noop() end

-- Self-returning no-op frame/widget: every indexed method returns a
-- function that returns the receiver, so chained calls are inert.
local function newFrame()
    local f = {}
    return setmetatable(f, {
        __index = function()
            return function(self) return self end
        end,
    })
end
M.newFrame = newFrame

local function deepcopy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = deepcopy(v) end
    return o
end

function M.newEnv()
    local env = {}

    -- Standard Lua 5.1 library passthrough.
    local passthrough = {
        "assert", "error", "ipairs", "next", "pairs", "pcall", "print",
        "select", "setmetatable", "getmetatable", "tonumber", "tostring",
        "type", "unpack", "rawget", "rawset", "rawequal", "xpcall",
        "collectgarbage", "string", "table", "math", "os", "io",
    }
    for _, name in ipairs(passthrough) do env[name] = _G[name] end
    env.setfenv    = setfenv
    env.getfenv    = getfenv
    env.loadstring = loadstring
    env._VERSION   = _VERSION
    env._G         = env

    -- ---- Blizzard surface -------------------------------------------
    local chatFrame = { messages = {} }
    function chatFrame:AddMessage(msg) self.messages[#self.messages + 1] = msg end
    env.DEFAULT_CHAT_FRAME = chatFrame

    env.CreateFrame      = function() return newFrame() end
    env.InCombatLockdown = function() return false end
    env.C_Timer          = { After = function(_, fn) if fn then fn() end end }
    env.C_AddOns         = {
        GetAddOnMetadata = function(_, key) return M.metadata[key] end,
        LoadAddOn        = function() return true end,
    }
    env.GetAddOnMetadata = function(_, key) return M.metadata[key] end

    env.StaticPopupDialogs = {}
    env.StaticPopup_Show   = noop
    env.GameTooltip        = newFrame()
    env.YES = "Yes"
    env.NO  = "No"

    -- Settings deliberately omits RegisterCanvasLayoutCategory so
    -- Config.lua's registerPanels() early-returns instead of building
    -- AceGUI widgets we don't model.
    env.Settings     = {}
    env.SettingsPanel = nil

    -- Font objects referenced via _G.GameFont* — harmless placeholders.
    for _, fname in ipairs({
        "GameFontNormal", "GameFontNormalLarge", "GameFontNormalHuge",
        "GameFontHighlight", "GameFontDisable",
    }) do env[fname] = newFrame() end

    -- ---- LibStub + Ace3 fakes ---------------------------------------
    local libs   = {}
    local addons = {}

    env.LibStub = function(name) return libs[name] end

    libs["AceAddon-3.0"] = {
        NewAddon = function(_, name)
            local addon = { name = name }
            addon.RegisterChatCommand = noop  -- AceConsole mixin
            addon.Printf              = noop
            addons[name] = addon
            return addon
        end,
        GetAddon = function(_, name) return addons[name] end,
    }

    libs["AceDB-3.0"] = {
        New = function(_, _svName, defaults)
            -- Copy every declared namespace (profile, global, ...) so
            -- migration code that reads db.global works, and guarantee
            -- both common namespaces exist even when undeclared.
            local db = {}
            if defaults then
                for k, v in pairs(defaults) do db[k] = deepcopy(v) end
            end
            db.profile = db.profile or {}
            db.global  = db.global or {}
            return db
        end,
    }

    libs["AceConsole-3.0"] = { RegisterChatCommand = noop }
    libs["AceGUI-3.0"]     = {
        Create = function() return newFrame() end,
        RegisterAsContainer = noop,
        RegisterAsWidget    = noop,
    }

    return env
end

return M
