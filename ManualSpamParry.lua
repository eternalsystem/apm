--[[
    PrivateKey Finder — Blade Ball
    Explore passivement les upvalues + GC pour trouver le PrivateKey
    Aucun hook, aucune modification = pas de kick
]]

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local RunService = game:GetService("RunService")

-- ===================== OUTPUT ===================== --

local function log(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring(select(i, ...))
    end
    -- Print to console (F9)
    print("[PKFinder]", table.concat(parts, " "))
end

local function logSection(title)
    log("========================================")
    log("  " .. title)
    log("========================================")
end

-- ===================== DEEP UPVALUE WALKER ===================== --

-- Walk all upvalues recursively, tracking visited objects to avoid loops
local function DeepWalkUpvalues(fn, depth, visited, results, path)
    if not fn or type(fn) ~= "function" then return end
    if depth > 12 then return end -- max depth
    visited = visited or {}
    results = results or {}
    path = path or "root"

    if visited[fn] then return end
    visited[fn] = true

    local ok, info = pcall(getinfo, fn)
    local fnName = (ok and info and info.name) or "?"

    -- Get upvalue count
    local uvCount = 0
    pcall(function()
        for i = 1, 200 do
            local name, val = getupvalue(fn, i)
            if name == nil then break end -- debug.getupvalue convention: nil name = past end
            uvCount = i
        end
    end)

    -- Scan each upvalue
    for i = 1, uvCount do
        local ok2, name, val = pcall(function()
            local n, v = getupvalue(fn, i)
            return n, v
        end)
        if not ok2 then break end

        local uvPath = path .. " → UV[" .. i .. "](" .. tostring(name) .. ")"

        if val == nil then
            -- skip nil
        elseif type(val) == "string" then
            -- Strings that look like keys: long hex, base64, or UUID-like
            if #val >= 16 then
                table.insert(results, {
                    path = uvPath,
                    type = "string",
                    length = #val,
                    value = val,
                    preview = #val > 80 and (val:sub(1, 80) .. "...") or val
                })
            end
        elseif type(val) == "number" then
            -- Large numbers could be hashes
            if val > 1000000 then
                table.insert(results, {
                    path = uvPath,
                    type = "number",
                    value = val
                })
            end
        elseif type(val) == "table" then
            if not visited[val] then
                visited[val] = true
                -- Scan table contents
                local count = 0
                for k, v in pairs(val) do
                    count = count + 1
                    if count > 50 then break end -- limit

                    local kStr = tostring(k)
                    local entryPath = uvPath .. "[" .. kStr .. "]"

                    if type(v) == "string" and #v >= 8 then
                        table.insert(results, {
                            path = entryPath,
                            type = "table-string",
                            key = kStr,
                            length = #v,
                            value = v,
                            preview = #v > 80 and (v:sub(1, 80) .. "...") or v
                        })
                    elseif type(v) == "function" then
                        -- Recurse into nested functions
                        DeepWalkUpvalues(v, depth + 1, visited, results, entryPath)
                    elseif type(v) == "table" and not visited[v] then
                        visited[v] = true
                        -- One more level into sub-tables
                        local subCount = 0
                        for k2, v2 in pairs(v) do
                            subCount = subCount + 1
                            if subCount > 30 then break end
                            local subPath = entryPath .. "[" .. tostring(k2) .. "]"
                            if type(v2) == "string" and #v2 >= 8 then
                                table.insert(results, {
                                    path = subPath,
                                    type = "nested-string",
                                    key = tostring(k2),
                                    length = #v2,
                                    value = v2,
                                    preview = #v2 > 80 and (v2:sub(1, 80) .. "...") or v2
                                })
                            elseif type(v2) == "function" then
                                DeepWalkUpvalues(v2, depth + 1, visited, results, subPath)
                            end
                        end
                    end
                end
            end
        elseif type(val) == "function" then
            -- Recurse into nested function upvalues
            DeepWalkUpvalues(val, depth + 1, visited, results, uvPath)
        elseif typeof(val) == "Instance" then
            if val:IsA("RemoteEvent") or val:IsA("RemoteFunction") then
                table.insert(results, {
                    path = uvPath,
                    type = "remote",
                    className = val.ClassName,
                    fullName = val:GetFullName(),
                    value = val
                })
            end
        end
    end

    return results
end

-- ===================== GC SCAN ===================== --

local function ScanGCForKeys()
    local results = {}
    local gc = getgc(true)

    for _, obj in pairs(gc) do
        if type(obj) == "table" then
            -- Look for tables that have a "PrivateKey" or similar field
            local hasPrivateKey = false
            local hasHash = false
            local hasFire = false

            pcall(function()
                for k, v in pairs(obj) do
                    local kLower = type(k) == "string" and k:lower() or ""

                    if kLower:find("private") or kLower:find("key") or kLower:find("secret") then
                        hasPrivateKey = true
                        table.insert(results, {
                            source = "GC-table",
                            key = tostring(k),
                            valueType = type(v),
                            value = type(v) == "string" and v or tostring(v),
                            preview = type(v) == "string" and (#v > 80 and v:sub(1, 80) .. "..." or v) or tostring(v)
                        })
                    end

                    if kLower:find("hash") then
                        hasHash = true
                        table.insert(results, {
                            source = "GC-table",
                            key = tostring(k),
                            valueType = type(v),
                            value = type(v) == "string" and v or tostring(v),
                            preview = type(v) == "string" and (#v > 80 and v:sub(1, 80) .. "..." or v) or tostring(v)
                        })
                    end
                end
            end)
        elseif type(obj) == "function" then
            -- Check function upvalues for "PrivateKey" named upvalues
            pcall(function()
                for i = 1, 50 do
                    local name, val = getupvalue(obj, i)
                    if name == nil then break end
                    if type(name) == "string" then
                        local nameLower = name:lower()
                        if nameLower:find("private") or nameLower:find("key") or nameLower:find("secret") or nameLower == "parry_key" then
                            table.insert(results, {
                                source = "GC-function-UV",
                                uvName = name,
                                uvIndex = i,
                                valueType = type(val),
                                value = type(val) == "string" and val or tostring(val),
                                preview = type(val) == "string" and (#val > 80 and val:sub(1, 80) .. "..." or val) or tostring(val)
                            })
                        end
                    end
                end
            end)
        end
    end

    return results
end

-- ===================== NET MODULE SCAN ===================== --

-- Look for sleitnick Net module tables in GC
local function ScanNetModule()
    local results = {}
    local gc = getgc(true)

    for _, obj in pairs(gc) do
        if type(obj) == "table" then
            pcall(function()
                -- Net module usually has: Client, Server, or specific method tables
                -- Look for tables with RemoteEvent references + string keys
                local hasRemote = false
                local hasStringKey = false
                local remoteRef = nil
                local stringKeys = {}

                for k, v in pairs(obj) do
                    if typeof(v) == "Instance" and v:IsA("RemoteEvent") then
                        hasRemote = true
                        remoteRef = v
                    end
                    if type(k) == "string" and #k >= 16 and k:match("^[a-f0-9]+$") then
                        hasStringKey = true
                    end
                    if type(v) == "string" and #v >= 16 then
                        table.insert(stringKeys, {key = tostring(k), value = v})
                    end
                end

                if hasRemote and #stringKeys > 0 then
                    table.insert(results, {
                        source = "Net-module-candidate",
                        remote = remoteRef and remoteRef:GetFullName() or "?",
                        strings = stringKeys
                    })
                end
            end)
        end
    end

    return results
end

-- ===================== CONNECTION UPVALUE SCAN ===================== --

local function ScanConnectionUpvalues()
    local results = {}

    local hotbar = Player.PlayerGui:FindFirstChild("Hotbar")
    if not hotbar then
        log("ERROR: Hotbar not found")
        return results
    end

    local block = hotbar:FindFirstChild("Block")
    if not block then
        log("ERROR: Block button not found")
        return results
    end

    local conns = getconnections(block.Activated)
    log("Found", #conns, "connections on Block.Activated")

    for idx, conn in ipairs(conns) do
        log("")
        logSection("Connection #" .. idx)

        local fn = nil
        pcall(function() fn = conn.Function end)

        if fn then
            local ok, info = pcall(getinfo, fn)
            if ok and info then
                log("  Source:", info.source or "?")
                log("  Name:", info.name or "anonymous")
                log("  NumParams:", info.numparams or "?")
            end

            -- Deep walk this function's upvalues
            local uvResults = DeepWalkUpvalues(fn, 0, nil, nil, "Conn#" .. idx)

            if uvResults and #uvResults > 0 then
                log("  Found", #uvResults, "interesting values:")
                for _, r in ipairs(uvResults) do
                    if r.type == "string" or r.type == "table-string" or r.type == "nested-string" then
                        log("    📝", r.path)
                        log("       Length:", r.length, "| Preview:", r.preview)
                    elseif r.type == "remote" then
                        log("    📡", r.path)
                        log("       Class:", r.className, "| FullName:", r.fullName)
                    elseif r.type == "number" then
                        log("    🔢", r.path, "=", r.value)
                    end
                end

                -- Save to results
                for _, r in ipairs(uvResults) do
                    r.connection = idx
                    table.insert(results, r)
                end
            else
                log("  No interesting values found in upvalues")
            end
        else
            log("  Cannot access function (protected)")
        end
    end

    return results
end

-- ===================== CONSTANTS SCAN ===================== --

local function ScanConstants()
    local results = {}

    local hotbar = Player.PlayerGui:FindFirstChild("Hotbar")
    if not hotbar then return results end
    local block = hotbar:FindFirstChild("Block")
    if not block then return results end

    local conns = getconnections(block.Activated)

    for idx, conn in ipairs(conns) do
        local fn = nil
        pcall(function() fn = conn.Function end)
        if not fn then continue end

        -- Get constants of this function
        pcall(function()
            local constants = getconstants(fn)
            if constants and #constants > 0 then
                log("")
                log("Constants for Connection #" .. idx .. ":")
                for i, c in ipairs(constants) do
                    if type(c) == "string" and #c >= 2 then
                        log("  C[" .. i .. "] =", c)
                        table.insert(results, {
                            connection = idx,
                            constIndex = i,
                            value = c
                        })
                    end
                end
            end
        end)
    end

    return results
end

-- ===================== MONITOR ===================== --

local lastSnapshot = {}

local function TakeSnapshot(connResults, gcResults)
    local snap = {}
    for _, r in ipairs(connResults) do
        if r.type == "string" or r.type == "table-string" or r.type == "nested-string" then
            snap[r.path] = r.value
        end
    end
    for _, r in ipairs(gcResults) do
        snap[r.source .. "/" .. (r.key or r.uvName or "?")] = r.value
    end
    return snap
end

local function CompareSnapshots(old, new)
    local changes = {}
    for path, val in pairs(new) do
        if old[path] ~= val then
            table.insert(changes, {
                path = path,
                oldVal = old[path] or "(new)",
                newVal = val
            })
        end
    end
    for path, val in pairs(old) do
        if new[path] == nil then
            table.insert(changes, {
                path = path,
                oldVal = val,
                newVal = "(removed)"
            })
        end
    end
    return changes
end

-- ===================== MAIN ===================== --

logSection("PRIVATE KEY FINDER — BLADE BALL")
log("Starting scan...")
log("")

-- 1) Scan connection upvalues (deep walk)
logSection("PHASE 1: Connection Upvalues (deep walk)")
local connResults = ScanConnectionUpvalues()

-- 2) Scan constants
logSection("PHASE 2: Function Constants")
local constResults = ScanConstants()

-- 3) GC scan for PrivateKey / Hash fields
logSection("PHASE 3: GC Scan (PrivateKey/Hash fields)")
local gcResults = ScanGCForKeys()

if #gcResults > 0 then
    log("Found", #gcResults, "potential key-related values:")
    for _, r in ipairs(gcResults) do
        log("  🔑", r.source, "| Key:", r.key or r.uvName or "?", "| Type:", r.valueType)
        log("     Preview:", r.preview)
    end
else
    log("No 'PrivateKey'/'Hash'/'Secret' fields found in GC")
end

-- 4) Net module scan
logSection("PHASE 4: Net Module Candidates")
local netResults = ScanNetModule()

if #netResults > 0 then
    log("Found", #netResults, "Net module candidates:")
    for _, r in ipairs(netResults) do
        log("  📡 Remote:", r.remote)
        for _, s in ipairs(r.strings) do
            log("     Key:", s.key, "| Value:", s.value:sub(1, 60))
        end
    end
else
    log("No Net module candidates found")
end

-- 5) Summary
logSection("SUMMARY")

-- Collect all potential keys
local potentialKeys = {}
for _, r in ipairs(connResults) do
    if (r.type == "string" or r.type == "table-string" or r.type == "nested-string") and r.length >= 16 then
        table.insert(potentialKeys, {
            source = "Connection #" .. (r.connection or "?"),
            path = r.path,
            length = r.length,
            preview = r.preview
        })
    end
end
for _, r in ipairs(gcResults) do
    table.insert(potentialKeys, {
        source = r.source,
        path = r.key or r.uvName or "?",
        length = #(r.value or ""),
        preview = r.preview
    })
end

if #potentialKeys > 0 then
    log("🔑 " .. #potentialKeys .. " potential keys/secrets found:")
    for i, pk in ipairs(potentialKeys) do
        log("  [" .. i .. "] Source:", pk.source)
        log("      Path:", pk.path)
        log("      Length:", pk.length)
        log("      Value:", pk.preview)
        log("")
    end
else
    log("❌ No potential keys found")
end

-- 6) Start monitor (re-scan every 30 seconds)
logSection("MONITOR: Re-scanning every 30s for changes")

lastSnapshot = TakeSnapshot(connResults, gcResults)

local monitorConn
monitorConn = task.spawn(function()
    local scanCount = 0
    while true do
        task.wait(30)
        scanCount = scanCount + 1

        -- Re-scan
        local newConnResults = {}
        pcall(function()
            newConnResults = ScanConnectionUpvalues()
        end)

        local newGcResults = {}
        pcall(function()
            newGcResults = ScanGCForKeys()
        end)

        local newSnap = TakeSnapshot(newConnResults, newGcResults)
        local changes = CompareSnapshots(lastSnapshot, newSnap)

        if #changes > 0 then
            log("")
            logSection("⚡ CHANGE DETECTED (scan #" .. scanCount .. ")")
            for _, ch in ipairs(changes) do
                log("  Path:", ch.path)
                log("  Old:", tostring(ch.oldVal):sub(1, 60))
                log("  New:", tostring(ch.newVal):sub(1, 60))
                log("")
            end
        else
            log("Monitor scan #" .. scanCount .. " — no changes")
        end

        lastSnapshot = newSnap
    end
end)

log("")
log("✅ Scanner running. Check the console (F9) for results.")
log("   Monitor will re-scan every 30 seconds and report any key changes.")
