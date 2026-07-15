local addonName, ns = ...

-- ns.Database — SavedVariables schema version + migration runner.
--
-- The addon's live settings are keyed by Blizzard GLOBALNAME constants,
-- which are stable, so no migration is needed yet — the runner exists so
-- a future storage-shape change (renamed key, restructured category
-- table) has a versioned home instead of ad-hoc `if db.x then` patches.
ns.Database = ns.Database or {}
local Database = ns.Database

-- Bump when the stored shape changes AND add a migrations[N] entry that
-- upgrades a DB at version N-1 to version N.
Database.SCHEMA_VERSION = 1

-- Defaults merged into AceDB (PrettyChat.lua adds `profile`). `global`
-- carries the persisted schema version. Starts at 0 so a brand-new DB
-- runs cleanly up to SCHEMA_VERSION (a no-op while migrations is empty).
Database.defaults = {
    global = {
        schemaVersion = 0,
    },
}

-- migrations[v](db) upgrades a DB from version v-1 to v. Empty today.
local migrations = {}

-- Run every pending migration in order, then stamp the current version.
-- Idempotent: a DB already at SCHEMA_VERSION runs no steps.
function Database.RunMigrations(db)
    if not (db and db.global) then return end
    local from = db.global.schemaVersion or 0
    local ran = 0
    for v = from + 1, Database.SCHEMA_VERSION do
        local step = migrations[v]
        if step then
            local ok, err = pcall(step, db)
            if not ok and ns.Print then
                ns.Print("schema migration " .. v .. " failed: " .. tostring(err))
            end
            ran = ran + 1
        end
    end
    db.global.schemaVersion = Database.SCHEMA_VERSION
    -- Lifecycle trace (debug-logging-§8): only when a migration step actually ran.
    if ran > 0 and ns.Debug then
        ns.Debug("Migrate", "v%d→v%d (%d step%s)",
            from, Database.SCHEMA_VERSION, ran, ran == 1 and "" or "s")
    end
end
