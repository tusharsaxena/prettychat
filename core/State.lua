local addonName, ns = ...

-- Session-only runtime state. Nothing here is persisted to SavedVariables. The debug
-- flag (ns.State.debug) defaults off and resets on every /reload and fresh login
-- (Ka0s standard, debug-logging-§5).
ns.State = ns.State or { debug = false }
