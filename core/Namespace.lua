local addonName, ns = ...

-- Shared namespace bootstrap. Records addon identity so any module can read
-- it without re-querying the TOC. `ns` is the addon's single private table — we never
-- create _G[addonName]. Loads right after Compat/Constants so metadata exists early.
ns.name    = addonName
ns.version = (ns.Compat and ns.Compat.GetAddOnMetadata(addonName, "Version")) or "1.4.0"
