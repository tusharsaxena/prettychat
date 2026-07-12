-- tests/test_apply.lua — the master -> category -> string enable cascade,
-- and (post-PC-16) deterministic apply for cross-registered globals.

local function firstFormatRow(Schema, category)
    for _, row in ipairs(Schema.RowsByCategory(category)) do
        if row.kind == "string_format" then return row end
    end
end

return function(ctx)
    local t = ctx.t
    local inst   = ctx.loadAddon()
    local Schema = inst.ns.Schema
    local env    = inst.env

    local row = firstFormatRow(Schema, "Loot")
    t.truthy(row, "found a Loot format row")
    local g, cat = row.globalName, row.category
    local def    = Schema.Get(row.path)
    local orig   = "ORIG:" .. g

    -- Default state: all three layers enabled -> override is live.
    t.eq(env[g], def, "override applied by default")

    -- Master off -> original restored regardless of lower layers.
    Schema.Set("General.enabled", false)
    t.eq(env[g], orig, "master off restores original")
    Schema.Set("General.enabled", true)
    t.eq(env[g], def, "master back on reapplies override")

    -- Category off -> original restored.
    Schema.Set(cat .. ".enabled", false)
    t.eq(env[g], orig, "category off restores original")
    Schema.Set(cat .. ".enabled", true)
    t.eq(env[g], def, "category back on reapplies override")

    -- Per-string off -> original restored.
    Schema.Set(cat .. "." .. g .. ".enabled", false)
    t.eq(env[g], orig, "string off restores original")
    Schema.Set(cat .. "." .. g .. ".enabled", true)
    t.eq(env[g], def, "string back on reapplies override")

    -- Deterministic cross-registered apply (PC-16): a global registered
    -- under more than one category must resolve to the documented winner
    -- — the LAST category in CATEGORY_ORDER that registers it — stably.
    -- LOOT_ITEM_CREATED_SELF is shared by Loot + Tradeskill.
    local shared = Schema.crossRegisteredGlobals or {}
    local name = "LOOT_ITEM_CREATED_SELF"
    if shared[name] then
        local winner
        for _, c in ipairs(Schema.CATEGORY_ORDER) do
            for _, reg in ipairs(shared[name]) do
                if reg == c then winner = c end
            end
        end
        t.truthy(winner, "resolved a deterministic winner category")
        inst.addon:ApplyStrings()
        t.eq(env[name], inst.addon:GetStringValue(winner, name),
            "cross-registered global resolves to last CATEGORY_ORDER registrant")
        local first = env[name]
        for _ = 1, 5 do inst.addon:ApplyStrings() end
        t.eq(env[name], first, "repeated apply is stable")
    end
end
