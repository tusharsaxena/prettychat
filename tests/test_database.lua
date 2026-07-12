-- tests/test_database.lua — schema version + migration runner (PC-07).

return function(ctx)
    local t = ctx.t
    local inst = ctx.loadAddon()
    local Database = inst.ns.Database
    local db = inst.addon.db

    t.truthy(Database, "ns.Database exists")
    t.truthy(db.global, "db.global namespace provisioned")

    -- OnInitialize ran RunMigrations -> DB stamped at current version.
    t.eq(db.global.schemaVersion, Database.SCHEMA_VERSION,
        "fresh DB stamped at current schema version")

    -- Idempotent: re-running changes nothing.
    Database.RunMigrations(db)
    t.eq(db.global.schemaVersion, Database.SCHEMA_VERSION,
        "re-running migrations keeps version stable")

    -- Robust against a DB with no global namespace.
    local ok = pcall(Database.RunMigrations, {})
    t.truthy(ok, "RunMigrations tolerates a db without .global")

    -- An older DB is upgraded up to the current version.
    local old = { global = { schemaVersion = 0 } }
    Database.RunMigrations(old)
    t.eq(old.global.schemaVersion, Database.SCHEMA_VERSION,
        "old DB upgraded to current version")
end
