-- tests/test_database.lua — schema version + migration runner (PC-07).

return function(ctx)
    local t = ctx.t
    local test = ctx.test
    local inst = ctx.loadAddon()
    local Database = inst.ns.Database
    local db = inst.addon.db

    test("ns.Database and the db.global namespace exist", function()
        t.truthy(Database, "ns.Database exists")
        t.truthy(db.global, "db.global namespace provisioned")
    end)

    test("a fresh DB is stamped at the current schema version", function()
        -- OnInitialize ran RunMigrations -> DB stamped at current version.
        t.eq(db.global.schemaVersion, Database.SCHEMA_VERSION,
            "fresh DB stamped at current schema version")
    end)

    test("re-running migrations is idempotent", function()
        Database.RunMigrations(db)
        t.eq(db.global.schemaVersion, Database.SCHEMA_VERSION,
            "re-running migrations keeps version stable")
    end)

    test("RunMigrations tolerates a db without a .global namespace", function()
        local ok = pcall(Database.RunMigrations, {})
        t.truthy(ok, "RunMigrations tolerates a db without .global")
    end)

    test("an older DB is upgraded to the current version", function()
        local old = { global = { schemaVersion = 0 } }
        Database.RunMigrations(old)
        t.eq(old.global.schemaVersion, Database.SCHEMA_VERSION,
            "old DB upgraded to current version")
    end)
end
