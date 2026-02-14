local PrettyChat = LibStub("AceAddon-3.0"):GetAddon("PrettyChat")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

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
                    if not PrettyChat.db.profile.categories[category] then
                        PrettyChat.db.profile.categories[category] = {}
                    end
                    PrettyChat.db.profile.categories[category].enabled = val
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
        -- Top spacer
        group.args[globalName .. "_spacer_top"] = {
            type = "description",
            name = "\n",
            order = i,
            width = "full",
        }
        -- Per-string enable toggle
        group.args[globalName .. "_toggle"] = {
            type = "toggle",
            name = "|cffffd700" .. strData.label .. "|r | |cffffffff" .. globalName .. "|r",
            order = i + 1,
            width = "full",
            disabled = function()
                return not PrettyChat:IsCategoryEnabled(category)
            end,
            get = function()
                return PrettyChat:IsStringEnabled(category, globalName)
            end,
            set = function(_, val)
                if not PrettyChat.db.profile.categories[category] then
                    PrettyChat.db.profile.categories[category] = {}
                end
                if not PrettyChat.db.profile.categories[category].disabledStrings then
                    PrettyChat.db.profile.categories[category].disabledStrings = {}
                end
                if val then
                    PrettyChat.db.profile.categories[category].disabledStrings[globalName] = nil
                else
                    PrettyChat.db.profile.categories[category].disabledStrings[globalName] = true
                end
                PrettyChat:ApplyStrings()
            end,
        }
        -- Format string input
        group.args[globalName] = {
            type = "input",
            name = "|cffffd700Format|r",
            order = i + 2,
            width = "full",
            disabled = function()
                return not PrettyChat:IsCategoryEnabled(category) or not PrettyChat:IsStringEnabled(category, globalName)
            end,
            get = function()
                return PrettyChat:GetStringValue(category, globalName):gsub("|", "||")
            end,
            set = function(_, val)
                val = val:gsub("||", "|")
                if not PrettyChat.db.profile.categories[category] then
                    PrettyChat.db.profile.categories[category] = {}
                end
                if not PrettyChat.db.profile.categories[category].strings then
                    PrettyChat.db.profile.categories[category].strings = {}
                end
                if val == PrettyChatDefaults[category].strings[globalName].default then
                    PrettyChat.db.profile.categories[category].strings[globalName] = nil
                else
                    PrettyChat.db.profile.categories[category].strings[globalName] = val
                end
                PrettyChat:ApplyStrings()
            end,
        }
        -- Preview label
        group.args[globalName .. "_preview_label"] = {
            type = "description",
            name = "|cffffd700Preview|r",
            order = i + 3,
            width = "full",
            fontSize = "medium",
        }
        -- Formatted preview (disabled edit box)
        group.args[globalName .. "_preview"] = {
            type = "input",
            name = "",
            order = i + 4,
            width = "full",
            disabled = true,
            get = function()
                return PrettyChat:GetStringValue(category, globalName)
            end,
            set = function() end,
        }
        -- Bottom spacer
        group.args[globalName .. "_spacer_bottom"] = {
            type = "description",
            name = "\n",
            order = i + 5,
            width = "full",
        }
        -- Horizontal line
        group.args[globalName .. "_hr"] = {
            type = "header",
            name = "",
            order = i + 6,
        }
        i = i + 7
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
