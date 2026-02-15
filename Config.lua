local PrettyChat = LibStub("AceAddon-3.0"):GetAddon("PrettyChat")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local GOLD = "|cffffd700"
local WHITE = "|cffffffff"
local RESET = "|r"

local function MakeSpacer(order)
    return { type = "description", name = "\n", order = order, width = "full" }
end

local function MakeLabel(order, text, fontSize)
    return { type = "description", name = text, order = order, width = "full", fontSize = fontSize or "medium" }
end

local function MakeDisabledInput(order, getter)
    return { type = "input", name = "", order = order, width = "full", disabled = true, get = getter, set = function() end }
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

    group.args[globalName .. "_original_spacer"] = MakeSpacer(i + 4)

    group.args[globalName .. "_original_label"] = MakeLabel(i + 5, GOLD .. "Original Format String" .. RESET)

    group.args[globalName .. "_original"] = MakeDisabledInput(i + 6, function()
        if PrettyChatGlobalStrings and PrettyChatGlobalStrings[globalName] then
            return PrettyChatGlobalStrings[globalName]
        end
        return "(original not available)"
    end)

    group.args[globalName .. "_format_label"] = MakeLabel(i + 7, GOLD .. "New Format String" .. RESET)

    group.args[globalName] = {
        type = "input",
        name = "",
        order = i + 8,
        width = "full",
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

    group.args[globalName .. "_preview_label"] = MakeLabel(i + 9, GOLD .. "Preview" .. RESET)

    group.args[globalName .. "_preview"] = MakeDisabledInput(i + 10, function()
        return PrettyChat:GetStringValue(category, globalName)
    end)

    group.args[globalName .. "_spacer_bottom"] = MakeSpacer(i + 11)

    group.args[globalName .. "_hr"] = {
        type = "header",
        name = "",
        order = i + 12,
    }
end

local function BuildCategoryGroup(category, catData, order)
    local group = {
        type = "group",
        name = category,
        order = order,
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
        i = i + 13
    end

    return group
end

local options = {
    type = "group",
    name = "PrettyChat",
    args = {
        general = {
            type = "group",
            name = "General",
            order = 1,
            args = {
                description = {
                    type = "description",
                    name = "PrettyChat reformats chat messages with color-coded, pipe-delimited formatting.\n\nUse the category tabs to view and customize individual format strings. Each string uses WoW color escapes (|cAARRGGBB...|r) and format specifiers (%s, %d, %.1f) that must match Blizzard's originals.\n",
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
        },
    },
}

local order = 10
for category, catData in pairs(PrettyChatDefaults) do
    options.args[category] = BuildCategoryGroup(category, catData, order)
    order = order + 1
end

AceConfig:RegisterOptionsTable("PrettyChat", options)
PrettyChat.optionsFrame = AceConfigDialog:AddToBlizOptions("PrettyChat", "PrettyChat")
