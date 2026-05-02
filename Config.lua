local PrettyChat = LibStub("AceAddon-3.0"):GetAddon("PrettyChat")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local PARENT_TITLE = "Ka0s Pretty Chat"

-- Display order of the sub-categories in the Blizzard addon list.
-- Iterating PrettyChatDefaults via pairs() would give a non-deterministic
-- order; this keeps the left-rail rows stable across launches.
local CATEGORY_ORDER = {
    "Loot", "Currency", "Money", "Reputation",
    "Experience", "Honor", "Tradeskill", "Misc",
}

local GOLD = "|cffffd700"
local WHITE = "|cffffffff"
local RESET = "|r"

local function MakeSpacer(order, width)
    return { type = "description", name = "\n", order = order, width = width or "full" }
end

local function MakeLabel(order, text, fontSize, width)
    return {
        type = "description",
        name = text,
        order = order,
        width = width or "full",
        fontSize = fontSize or "medium",
    }
end

local function MakeDisabledInput(order, getter, width)
    return {
        type = "input",
        name = "",
        order = order,
        width = width or "full",
        disabled = true,
        get = getter,
        set = function() end,
    }
end

local function BuildStringEntry(group, globalName, strData, category, i)
    group.args[globalName .. "_spacer_top"] = MakeSpacer(i)

    group.args[globalName .. "_toggle"] = {
        type = "toggle",
        name = "Enable",
        order = i + 1,
        width = 0.4,
        disabled = function()
            return not PrettyChat:IsCategoryEnabled(category)
        end,
        get = function()
            return PrettyChat:IsStringEnabled(category, globalName)
        end,
        set = function(_, val)
            local catDB = PrettyChat:EnsureCategoryDB(category)
            if not catDB.disabledStrings then catDB.disabledStrings = {} end
            catDB.disabledStrings[globalName] = (not val) or nil
            PrettyChat:ApplyStrings()
        end,
    }

    group.args[globalName .. "_toggle_label"] = {
        type = "description",
        name = GOLD .. strData.label .. RESET,
        order = i + 2,
        width = 2.0,
        fontSize = "large",
    }

    group.args[globalName .. "_toggle_globalname"] = {
        type = "description",
        name = WHITE .. globalName .. RESET,
        order = i + 3,
        width = "full",
        fontSize = "small",
    }

    -- Original / New format string sit side-by-side at 50%/50% of the
    -- row to exploit the extra horizontal space gained by moving
    -- navigation out of the right pane and into the addon list.
    -- A numeric `width = 0.5` would be 0.5 × 170 px = 85 px absolute;
    -- `width = "relative", relWidth = 0.5` is what AceGUI's flow layout
    -- treats as half the container width.
    group.args[globalName .. "_original_label"] = {
        type = "description",
        name = GOLD .. "Original Format String" .. RESET,
        order = i + 4,
        width = "relative",
        relWidth = 0.5,
        fontSize = "medium",
    }

    group.args[globalName .. "_format_label"] = {
        type = "description",
        name = GOLD .. "New Format String" .. RESET,
        order = i + 5,
        width = "relative",
        relWidth = 0.5,
        fontSize = "medium",
    }

    group.args[globalName .. "_original"] = {
        type = "input",
        name = "",
        order = i + 6,
        width = "relative",
        relWidth = 0.5,
        disabled = true,
        get = function()
            if PrettyChatGlobalStrings and PrettyChatGlobalStrings[globalName] then
                return PrettyChatGlobalStrings[globalName]
            end
            return "(original not available)"
        end,
        set = function() end,
    }

    group.args[globalName] = {
        type = "input",
        name = "",
        order = i + 7,
        width = "relative",
        relWidth = 0.5,
        disabled = function()
            return not PrettyChat:IsCategoryEnabled(category) or not PrettyChat:IsStringEnabled(category, globalName)
        end,
        get = function()
            return PrettyChat:GetStringValue(category, globalName):gsub("|", "||")
        end,
        set = function(_, val)
            val = val:gsub("||", "|")
            local catDB = PrettyChat:EnsureCategoryDB(category)
            if not catDB.strings then catDB.strings = {} end
            if val == PrettyChatDefaults[category].strings[globalName].default then
                catDB.strings[globalName] = nil
            else
                catDB.strings[globalName] = val
            end
            PrettyChat:ApplyStrings()
        end,
    }

    group.args[globalName .. "_preview_label"] =
        MakeLabel(i + 8, GOLD .. "Preview" .. RESET)

    group.args[globalName .. "_preview"] = MakeDisabledInput(i + 9, function()
        return PrettyChat:GetStringValue(category, globalName)
    end)

    group.args[globalName .. "_spacer_bottom"] = MakeSpacer(i + 10)

    group.args[globalName .. "_hr"] = {
        type = "header",
        name = "",
        order = i + 11,
    }
end

-- Returns the root options table for one category's sub-page. Each
-- sub-page is registered separately with AceConfig and added to the
-- Blizzard panel as a child of PARENT_TITLE, which renders it as its
-- own row in the addon list (no tabs in the right pane).
local function BuildCategoryOptions(category, catData)
    local group = {
        type = "group",
        name = category,
        args = {
            enabled = {
                type = "toggle",
                name = "Enable " .. category,
                desc = "Enable or disable all " .. category .. " string overrides.",
                order = 1,
                width = "full",
                get = function()
                    return PrettyChat:IsCategoryEnabled(category)
                end,
                set = function(_, val)
                    PrettyChat:EnsureCategoryDB(category).enabled = val
                    PrettyChat:ApplyStrings()
                end,
            },
            reset = {
                type = "execute",
                name = "Reset " .. category,
                desc = "Reset all " .. category .. " strings to defaults.",
                order = 2,
                confirm = true,
                confirmText = "Reset all " .. category .. " strings to defaults?",
                func = function()
                    PrettyChat:ResetCategory(category)
                end,
            },
            spacer = {
                type = "description",
                name = "",
                order = 3,
                width = "full",
            },
        },
    }

    local i = 10
    for globalName, strData in pairs(catData.strings) do
        BuildStringEntry(group, globalName, strData, category, i)
        i = i + 12
    end

    return group
end

-- Parent page — description + Reset All button only. The previous
-- nested args[category] groups (which AceConfig rendered as tabs) are
-- gone; categories now live as sibling sub-pages registered below.
local parentOptions = {
    type = "group",
    name = PARENT_TITLE,
    args = {
        description = {
            type = "description",
            name = "PrettyChat reformats chat messages with color-coded, pipe-delimited formatting.\n\nSelect a category from the addon list to view and customize individual format strings. Each string uses WoW color escapes (|cAARRGGBB...|r) and format specifiers (%s, %d, %.1f) that must match Blizzard's originals.\n",
            order = 1,
            fontSize = "medium",
        },
        resetAll = {
            type = "execute",
            name = "Reset All to Defaults",
            desc = "Reset all categories and strings to their default values.",
            order = 2,
            confirm = true,
            confirmText = "Reset ALL PrettyChat strings to defaults?",
            func = function()
                PrettyChat:ResetAll()
            end,
        },
    },
}

AceConfig:RegisterOptionsTable("PrettyChat", parentOptions)
PrettyChat.optionsFrame = AceConfigDialog:AddToBlizOptions("PrettyChat", PARENT_TITLE)

-- Register each category as its own Blizzard sub-page. The third arg
-- (parent) must match a previously-registered category's display name —
-- here, PARENT_TITLE — so the parent registration above must run first.
PrettyChat.subFrames = {}
for _, category in ipairs(CATEGORY_ORDER) do
    local catData = PrettyChatDefaults[category]
    if catData then
        local appName = "PrettyChat_" .. category
        AceConfig:RegisterOptionsTable(appName, BuildCategoryOptions(category, catData))
        PrettyChat.subFrames[category] =
            AceConfigDialog:AddToBlizOptions(appName, category, PARENT_TITLE)
    end
end
