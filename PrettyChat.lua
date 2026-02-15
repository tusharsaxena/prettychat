local PrettyChat = LibStub("AceAddon-3.0"):NewAddon("PrettyChat", "AceConsole-3.0")

local defaults = {
    profile = {
        categories = {},
    },
}

function PrettyChat:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("PrettyChatDB", defaults, true)

    self:RegisterChatCommand("pc", "OpenConfig")
    self:RegisterChatCommand("prettychat", "OpenConfig")
end

function PrettyChat:OnEnable()
    self.originalStrings = {}
    for cat, catData in pairs(PrettyChatDefaults) do
        for globalName in pairs(catData.strings) do
            self.originalStrings[globalName] = _G[globalName]
        end
    end
    self:ApplyStrings()
end

function PrettyChat:OpenConfig()
    Settings.OpenToCategory(self.optionsFrame.name)
end

function PrettyChat:GetStringValue(category, globalName)
    local catDB = self.db.profile.categories[category]
    if catDB and catDB.strings and catDB.strings[globalName] ~= nil then
        return catDB.strings[globalName]
    end
    return PrettyChatDefaults[category].strings[globalName].default
end

function PrettyChat:IsCategoryEnabled(category)
    local catDB = self.db.profile.categories[category]
    if catDB and catDB.enabled ~= nil then
        return catDB.enabled
    end
    return PrettyChatDefaults[category].enabled
end

function PrettyChat:IsStringEnabled(category, globalName)
    local catDB = self.db.profile.categories[category]
    if catDB and catDB.disabledStrings and catDB.disabledStrings[globalName] then
        return false
    end
    return true
end

function PrettyChat:EnsureCategoryDB(category)
    if not self.db.profile.categories[category] then
        self.db.profile.categories[category] = {}
    end
    return self.db.profile.categories[category]
end

function PrettyChat:ApplyStrings()
    for category, catData in pairs(PrettyChatDefaults) do
        for globalName in pairs(catData.strings) do
            if self:IsCategoryEnabled(category) and self:IsStringEnabled(category, globalName) then
                _G[globalName] = self:GetStringValue(category, globalName)
            elseif self.originalStrings and self.originalStrings[globalName] then
                _G[globalName] = self.originalStrings[globalName]
            end
        end
    end
end

function PrettyChat:ResetCategory(category)
    if self.db.profile.categories[category] then
        self.db.profile.categories[category] = nil
    end
    self:ApplyStrings()
end

function PrettyChat:ResetAll()
    self.db.profile.categories = {}
    self:ApplyStrings()
end
