--[[
    SwordsController Targeted Extractor
    Extracts ONLY the missing files that couldn't be saved due to
    trailing spaces in folder names + any other parry-related scripts.
    Sanitizes paths, ZIPs, and uploads to gofile.io
]]

repeat task.wait() until game:IsLoaded()
task.wait(3)

local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")

-- ===================== GUI ===================== --

local oldGui = CoreGui:FindFirstChild("SWC_Dump_UI")
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SWC_Dump_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 1003
pcall(function() if gethui then ScreenGui.Parent = gethui() return end end)
if not ScreenGui.Parent then
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end end)
    ScreenGui.Parent = CoreGui
end

local BG = Instance.new("Frame")
BG.Size = UDim2.new(0, 440, 0, 320)
BG.Position = UDim2.new(0.5, -220, 0.5, -160)
BG.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
BG.BackgroundTransparency = 0.05
BG.BorderSizePixel = 0
BG.Active = true
BG.Draggable = true
BG.Parent = ScreenGui
Instance.new("UICorner", BG).CornerRadius = UDim.new(0, 8)

local TitleBar = Instance.new("TextLabel")
TitleBar.Size = UDim2.new(1, 0, 0, 28)
TitleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
TitleBar.Text = "  ⚔️ SwordsController Extractor"
TitleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleBar.TextSize = 13
TitleBar.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
TitleBar.TextXAlignment = Enum.TextXAlignment.Left
TitleBar.BorderSizePixel = 0
TitleBar.Parent = BG
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 8)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -32, 0, 0)
StatusLabel.Position = UDim2.fromOffset(16, 40)
StatusLabel.AutomaticSize = Enum.AutomaticSize.Y
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Scanning for targets..."
StatusLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
StatusLabel.TextSize = 12
StatusLabel.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular)
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextYAlignment = Enum.TextYAlignment.Top
StatusLabel.TextWrapped = true
StatusLabel.Parent = BG

local ProgressBar = Instance.new("Frame")
ProgressBar.Size = UDim2.new(1, -32, 0, 6)
ProgressBar.Position = UDim2.new(0, 16, 1, -50)
ProgressBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ProgressBar.BorderSizePixel = 0
ProgressBar.Parent = BG
Instance.new("UICorner", ProgressBar).CornerRadius = UDim.new(1, 0)

local ProgressFill = Instance.new("Frame")
ProgressFill.Size = UDim2.new(0, 0, 1, 0)
ProgressFill.BackgroundColor3 = Color3.fromRGB(255, 160, 40)
ProgressFill.BorderSizePixel = 0
ProgressFill.Parent = ProgressBar
Instance.new("UICorner", ProgressFill).CornerRadius = UDim.new(1, 0)

local LinkLabel = Instance.new("TextButton")
LinkLabel.Size = UDim2.new(1, -32, 0, 28)
LinkLabel.Position = UDim2.new(0, 16, 1, -36)
LinkLabel.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
LinkLabel.Text = ""
LinkLabel.TextColor3 = Color3.fromRGB(100, 255, 120)
LinkLabel.TextSize = 11
LinkLabel.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.SemiBold)
LinkLabel.Visible = false
LinkLabel.AutoButtonColor = true
LinkLabel.BorderSizePixel = 0
LinkLabel.Parent = BG
Instance.new("UICorner", LinkLabel).CornerRadius = UDim.new(0, 5)

local function setStatus(text) StatusLabel.Text = text end
local function setProgress(pct) ProgressFill.Size = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0) end
local function notify(text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title = "SWC Dump", Text = text, Duration = 8})
    end)
end

-- ===================== REQUEST ===================== --

local _request = nil
if typeof(request) == "function" then _request = request
elseif typeof(http_request) == "function" then _request = http_request
elseif typeof(syn) == "table" and typeof(syn.request) == "function" then _request = syn.request
elseif typeof(http) == "table" and typeof(http.request) == "function" then _request = http.request
elseif typeof(fluxus) == "table" and typeof(fluxus.request) == "function" then _request = fluxus.request
end

-- ===================== ZIP BUILDER ===================== --

local function numToLE2(n)
    return string.char(n % 256, math.floor(n / 256) % 256)
end
local function numToLE4(n)
    return string.char(
        n % 256,
        math.floor(n / 256) % 256,
        math.floor(n / 65536) % 256,
        math.floor(n / 16777216) % 256
    )
end

local crc32_table = {}
for i = 0, 255 do
    local c = i
    for _ = 1, 8 do
        if bit32.band(c, 1) == 1 then
            c = bit32.bxor(bit32.rshift(c, 1), 0xEDB88320)
        else
            c = bit32.rshift(c, 1)
        end
    end
    crc32_table[i] = c
end

local function crc32(data)
    local crc = 0xFFFFFFFF
    for i = 1, #data do
        local b = string.byte(data, i)
        crc = bit32.bxor(bit32.rshift(crc, 8), crc32_table[bit32.band(bit32.bxor(crc, b), 0xFF)])
    end
    return bit32.bxor(crc, 0xFFFFFFFF)
end

local function buildZip(files)
    local localHeaders = {}
    local centralEntries = {}
    local offset = 0
    for _, file in ipairs(files) do
        local name = file.name
        local data = file.data
        local c = crc32(data)
        local size = #data
        local nameLen = #name
        local lh = table.concat({
            "PK\3\4", numToLE2(20), numToLE2(0), numToLE2(0),
            numToLE2(0), numToLE2(0), numToLE4(c),
            numToLE4(size), numToLE4(size), numToLE2(nameLen),
            numToLE2(0), name, data
        })
        table.insert(localHeaders, lh)
        local ce = table.concat({
            "PK\1\2", numToLE2(20), numToLE2(20), numToLE2(0),
            numToLE2(0), numToLE2(0), numToLE2(0), numToLE4(c),
            numToLE4(size), numToLE4(size), numToLE2(nameLen),
            numToLE2(0), numToLE2(0), numToLE2(0), numToLE2(0),
            numToLE4(0), numToLE4(offset), name
        })
        table.insert(centralEntries, ce)
        offset = offset + #lh
    end
    local centralDir = table.concat(centralEntries)
    local centralDirOffset = offset
    local centralDirSize = #centralDir
    local eocd = table.concat({
        "PK\5\6", numToLE2(0), numToLE2(0),
        numToLE2(#files), numToLE2(#files),
        numToLE4(centralDirSize), numToLE4(centralDirOffset),
        numToLE2(0)
    })
    return table.concat(localHeaders) .. centralDir .. eocd
end

-- ===================== DECOMPILE ===================== --

local function safeDecompile(script)
    local ok, source = pcall(function() return decompile(script) end)
    if ok and source and #source > 0 then return source end
    local ok2, src2 = pcall(function() return script.Source end)
    if ok2 and src2 and #src2 > 0 then return src2 end
    return "-- [Decompile failed for " .. script:GetFullName() .. "]"
end

-- ===================== PATH SANITIZER ===================== --

local function sanitizePath(path)
    -- Remove trailing spaces from each path segment (the Windows problem)
    -- "SwordsController .module.lua" -> "SwordsController.module.lua"
    -- "SwordsController /PRY.module.lua" -> "SwordsController/PRY.module.lua"
    path = path:gsub(" /", "/")      -- trailing space before /
    path = path:gsub(" %.", ".")     -- trailing space before .
    path = path:gsub(" $", "")       -- trailing space at end
    -- Also remove any double spaces
    path = path:gsub("  +", " ")
    return path
end

local function getScriptPath(script)
    local path = script:GetFullName():gsub("%.", "/")
    if script:IsA("LocalScript") then
        path = path .. ".client.lua"
    elseif script:IsA("ModuleScript") then
        path = path .. ".module.lua"
    else
        path = path .. ".lua"
    end
    return sanitizePath(path)
end

-- ===================== TARGET FINDER ===================== --

local function shouldExtract(script)
    local fullName = script:GetFullName():lower()
    local name = script.Name:lower()

    -- Primary targets: SwordsController and children (PRY module)
    if fullName:find("swordscontroller") then return true end

    -- Net library source (the VM-obfuscated one, re-grab for completeness)
    if fullName:find("sleitnick_net") then return true end

    -- Any script whose source references parry/block mechanics
    -- (we check name patterns first, decompile check is done separately)
    if name:find("parry") then return true end
    if name:find("pry") and not name:find("encrypt") then return true end

    -- Hotbar-related (Block button chain)
    if name:find("hotbar") and fullName:find("controller") then return true end

    -- Ball controller/system
    if name:find("ballcontroller") or name:find("ballindicator") then return true end

    -- Game round/match logic
    if name:find("roundcontroller") or name:find("matchcontroller") then return true end

    -- Ability system (parry counter is an ability)
    if name:find("abilitycontroller") then return true end

    -- Anti-cheat (to understand what's monitored)
    if name:find("anticheat") or name:find("antifling") or name:find("integrity") then return true end

    -- Training mode (simulates parry)
    if name:find("trainingmode") or name:find("lobbytraining") then return true end

    -- UseBall2 (ball targeting system)
    if name == "useball2" then return true end

    -- Rhythm LTM (has parry cooldown logic)
    if name:find("rhythmltm") then return true end

    -- VFX controller (parry effects)
    if name:find("clientfx") then return true end

    -- ServerInfo
    if name == "serverinfo" then return true end

    return false
end

-- ===================== MAIN ===================== --

task.spawn(function()
    if typeof(decompile) ~= "function" then
        setStatus("❌ decompile() not available!")
        notify("ERROR: decompile missing")
        return
    end

    if not _request then
        setStatus("❌ request/http_request not available!")
        notify("ERROR: request missing")
        return
    end

    setStatus("🔍 Phase 1: Scanning all scripts...")
    setProgress(0)

    -- Collect ALL scripts
    local allScripts = {}
    local seen = {}

    pcall(function()
        for _, s in ipairs(getscripts()) do
            if (s:IsA("LocalScript") or s:IsA("ModuleScript")) and not seen[s] then
                seen[s] = true
                table.insert(allScripts, s)
            end
        end
    end)

    -- Also scan key locations manually
    local locations = {
        game:GetService("ReplicatedStorage"),
        game:GetService("ReplicatedFirst"),
        game:GetService("StarterPlayer"),
        game:GetService("StarterGui"),
        game:GetService("Players").LocalPlayer,
    }
    pcall(function() table.insert(locations, workspace) end)

    for _, loc in ipairs(locations) do
        pcall(function()
            for _, desc in ipairs(loc:GetDescendants()) do
                if (desc:IsA("LocalScript") or desc:IsA("ModuleScript")) and not seen[desc] then
                    seen[desc] = true
                    table.insert(allScripts, desc)
                end
            end
        end)
    end

    setStatus("🔍 Found " .. #allScripts .. " total scripts\n🎯 Filtering targets...")
    setProgress(0.1)
    task.wait()

    -- Phase 1: Filter by name/path
    local targets = {}
    for _, s in ipairs(allScripts) do
        if shouldExtract(s) then
            table.insert(targets, s)
        end
    end

    setStatus(
        "🎯 " .. #targets .. " targeted by name\n" ..
        "🔧 Phase 2: Decompiling targets..."
    )
    setProgress(0.15)
    task.wait()

    -- Phase 2: Decompile targets
    local files = {}
    local decompiled = 0
    local failed = 0

    for i, script in ipairs(targets) do
        local path = getScriptPath(script)
        local ok, source = pcall(safeDecompile, script)

        if ok and source then
            table.insert(files, {
                name = path,
                data = source,
                size = #source,
                fullName = script:GetFullName()
            })
            decompiled = decompiled + 1
        else
            failed = failed + 1
            table.insert(files, {
                name = path,
                data = "-- [DECOMPILE FAILED]\n-- " .. tostring(source),
                size = 0,
                fullName = script:GetFullName()
            })
        end

        if i % 3 == 0 or i == #targets then
            setProgress(0.15 + (i / #targets) * 0.35)
            setStatus(
                "🔧 Decompiling: " .. i .. "/" .. #targets ..
                "\n✅ OK: " .. decompiled .. " | ❌ Failed: " .. failed ..
                "\n📄 " .. path:sub(1, 55)
            )
            task.wait()
        end
    end

    -- Phase 3: Scan ALL remaining scripts for parry-related source code
    setStatus(
        "✅ Targets done: " .. decompiled .. "/" .. #targets ..
        "\n🔎 Phase 3: Scanning all sources for parry refs..."
    )
    setProgress(0.5)
    task.wait()

    local extraFound = 0
    local targetPaths = {}
    for _, f in ipairs(files) do
        targetPaths[f.fullName] = true
    end

    for i, script in ipairs(allScripts) do
        if not targetPaths[script:GetFullName()] then
            -- Quick decompile + search for parry keywords
            local ok, source = pcall(safeDecompile, script)
            if ok and source and #source > 0 then
                local srcLower = source:lower()
                -- Only grab scripts that reference core parry mechanics
                if srcLower:find("block%.activated") or
                   srcLower:find("swordscontroller") or
                   srcLower:find("parrycooldown") or
                   srcLower:find("parrysuccess") or
                   (srcLower:find("firesignal") and srcLower:find("block")) then
                    local path = getScriptPath(script)
                    table.insert(files, {
                        name = path,
                        data = source,
                        size = #source,
                        fullName = script:GetFullName()
                    })
                    extraFound = extraFound + 1
                    decompiled = decompiled + 1
                end
            end
        end

        if i % 50 == 0 then
            setProgress(0.5 + (i / #allScripts) * 0.15)
            setStatus(
                "🔎 Source scanning: " .. i .. "/" .. #allScripts ..
                "\n🆕 Extra parry-related: " .. extraFound
            )
            task.wait()
        end
    end

    -- Phase 4: Also dump runtime info
    setStatus("📊 Phase 4: Dumping runtime parry info...")
    setProgress(0.65)
    task.wait()

    -- Dump Block.Activated connection info
    local runtimeInfo = "-- SwordsController Runtime Analysis\n"
    runtimeInfo = runtimeInfo .. "-- Generated: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n"

    pcall(function()
        local Player = game:GetService("Players").LocalPlayer
        local hotbar = Player.PlayerGui:FindFirstChild("Hotbar")
        if hotbar then
            local block = hotbar:FindFirstChild("Block")
            if block then
                runtimeInfo = runtimeInfo .. "-- Block button found: " .. block:GetFullName() .. "\n"
                runtimeInfo = runtimeInfo .. "-- Block.ClassName: " .. block.ClassName .. "\n\n"

                local _gc = getconnections or false
                local _gi = getinfo or debug.info or false
                local _gu = getupvalues or debug.getupvalues or false
                local _gc2 = getconstants or debug.getconstants or false

                if _gc then
                    local conns = _gc(block.Activated)
                    runtimeInfo = runtimeInfo .. "-- Block.Activated connections: " .. #conns .. "\n\n"

                    for idx, conn in ipairs(conns) do
                        runtimeInfo = runtimeInfo .. "-- ========== CONNECTION #" .. idx .. " ==========\n"

                        local fn = nil
                        pcall(function() fn = conn.Function end)
                        if not fn then
                            runtimeInfo = runtimeInfo .. "-- Function: <unavailable>\n\n"
                        else
                            runtimeInfo = runtimeInfo .. "-- Function: " .. tostring(fn) .. "\n"

                            -- getinfo
                            if _gi then
                                pcall(function()
                                    local info = _gi(fn)
                                    runtimeInfo = runtimeInfo .. "-- Source: " .. tostring(info.source or "?") .. "\n"
                                    runtimeInfo = runtimeInfo .. "-- Name: " .. tostring(info.name or "?") .. "\n"
                                    runtimeInfo = runtimeInfo .. "-- Line: " .. tostring(info.currentline or info.linedefined or "?") .. "\n"
                                    runtimeInfo = runtimeInfo .. "-- NumParams: " .. tostring(info.numparams or "?") .. "\n"
                                    runtimeInfo = runtimeInfo .. "-- IsVarArg: " .. tostring(info.is_vararg or "?") .. "\n"
                                end)
                            end

                            -- getupvalues (3 levels deep for SwordsController)
                            if _gu then
                                pcall(function()
                                    local uvs1 = _gu(fn)
                                    runtimeInfo = runtimeInfo .. "-- Upvalues L1: " .. #uvs1 .. " entries\n"
                                    for k, v in pairs(uvs1) do
                                        local vStr = tostring(v)
                                        if #vStr > 100 then vStr = vStr:sub(1, 100) .. "..." end
                                        runtimeInfo = runtimeInfo .. "--   UV1[" .. tostring(k) .. "] = (" .. typeof(v) .. ") " .. vStr .. "\n"
                                    end

                                    -- Level 2
                                    for k, v in pairs(uvs1) do
                                        if type(v) == "function" then
                                            pcall(function()
                                                local uvs2 = _gu(v)
                                                runtimeInfo = runtimeInfo .. "-- Upvalues L2 (from UV1[" .. k .. "]): " .. #uvs2 .. " entries\n"
                                                for k2, v2 in pairs(uvs2) do
                                                    local vStr2 = tostring(v2)
                                                    if #vStr2 > 100 then vStr2 = vStr2:sub(1, 100) .. "..." end
                                                    runtimeInfo = runtimeInfo .. "--   UV2[" .. tostring(k2) .. "] = (" .. typeof(v2) .. ") " .. vStr2 .. "\n"
                                                end

                                                -- Level 3
                                                for k2, v2 in pairs(uvs2) do
                                                    if type(v2) == "function" then
                                                        pcall(function()
                                                            local uvs3 = _gu(v2)
                                                            runtimeInfo = runtimeInfo .. "-- Upvalues L3 (from UV2[" .. k2 .. "]): " .. #uvs3 .. " entries\n"
                                                            for k3, v3 in pairs(uvs3) do
                                                                local vStr3 = tostring(v3)
                                                                if #vStr3 > 200 then vStr3 = vStr3:sub(1, 200) .. "..." end
                                                                runtimeInfo = runtimeInfo .. "--   UV3[" .. tostring(k3) .. "] = (" .. typeof(v3) .. ") " .. vStr3 .. "\n"
                                                            end
                                                        end)
                                                    end
                                                end
                                            end)
                                        end
                                    end
                                end)
                            end

                            -- getconstants
                            if _gc2 then
                                pcall(function()
                                    local consts = _gc2(fn)
                                    runtimeInfo = runtimeInfo .. "-- Constants: " .. #consts .. " entries\n"
                                    for k, v in pairs(consts) do
                                        runtimeInfo = runtimeInfo .. "--   C[" .. tostring(k) .. "] = (" .. typeof(v) .. ") " .. tostring(v) .. "\n"
                                    end
                                end)
                            end

                            runtimeInfo = runtimeInfo .. "\n"
                        end
                    end
                else
                    runtimeInfo = runtimeInfo .. "-- getconnections not available\n"
                end
            else
                runtimeInfo = runtimeInfo .. "-- Block button NOT found in Hotbar\n"
            end
        else
            runtimeInfo = runtimeInfo .. "-- Hotbar NOT found in PlayerGui\n"
        end
    end)

    -- Dump Net remotes info
    runtimeInfo = runtimeInfo .. "\n-- ========== NET REMOTES ==========\n"
    pcall(function()
        for _, child in ipairs(game:GetService("ReplicatedStorage"):GetChildren()) do
            if child.Name:sub(1, 3) == "RE/" or child.Name:sub(1, 3) == "RF/" then
                runtimeInfo = runtimeInfo .. "-- " .. child.ClassName .. ": " .. child.Name .. "\n"
            end
        end
    end)

    -- Dump Remotes folder
    runtimeInfo = runtimeInfo .. "\n-- ========== REMOTES FOLDER ==========\n"
    pcall(function()
        local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
        if remotes then
            for _, r in ipairs(remotes:GetDescendants()) do
                if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") or r:IsA("BindableEvent") then
                    runtimeInfo = runtimeInfo .. "-- " .. r.ClassName .. ": " .. r:GetFullName() .. "\n"
                end
            end
        end
    end)

    table.insert(files, {
        name = "_RUNTIME_ANALYSIS.lua",
        data = runtimeInfo,
        size = #runtimeInfo,
        fullName = "_runtime"
    })

    -- Build index
    local indexContent = "-- SwordsController Targeted Dump\n"
    indexContent = indexContent .. "-- Date: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
    indexContent = indexContent .. "-- Total files: " .. #files .. "\n"
    indexContent = indexContent .. "-- Decompiled: " .. decompiled .. "\n"
    indexContent = indexContent .. "-- Failed: " .. failed .. "\n"
    indexContent = indexContent .. "-- Extra parry-refs: " .. extraFound .. "\n\n"

    -- Sort by size (biggest first = most important)
    table.sort(files, function(a, b) return (a.size or 0) > (b.size or 0) end)

    indexContent = indexContent .. "-- Files (sorted by size, biggest first):\n"
    for _, f in ipairs(files) do
        indexContent = indexContent .. "--   " .. f.name .. " (" .. (f.size or #f.data) .. " bytes)\n"
    end
    table.insert(files, 1, {name = "_INDEX.lua", data = indexContent})

    setStatus(
        "✅ Total: " .. #files .. " files\n" ..
        "📦 Building ZIP..."
    )
    setProgress(0.7)
    task.wait()

    -- Build ZIP
    local zipData = buildZip(files)

    setStatus(
        "✅ ZIP built: " .. math.floor(#zipData / 1024) .. " KB\n" ..
        "☁️ Getting gofile server..."
    )
    setProgress(0.8)

    -- Save locally
    pcall(function()
        writefile("SwordsController_Dump.zip", zipData)
        setStatus(StatusLabel.Text .. "\n💾 Saved locally too")
    end)

    -- Upload to gofile
    local serverName = nil
    local ok1, res1 = pcall(function()
        return _request({
            Url = "https://api.gofile.io/servers",
            Method = "GET"
        })
    end)
    if ok1 and res1 and res1.Body then
        pcall(function()
            local data = HttpService:JSONDecode(res1.Body)
            if data and data.data and data.data.servers then
                for _, srv in ipairs(data.data.servers) do
                    serverName = srv.name
                    break
                end
            end
        end)
    end
    if not serverName then serverName = "store1" end

    setStatus(
        "✅ ZIP: " .. math.floor(#zipData / 1024) .. " KB\n" ..
        "☁️ Uploading to " .. serverName .. ".gofile.io..."
    )
    setProgress(0.9)

    local boundary = "----SWCDump" .. tostring(math.random(100000, 999999))
    local fileName = "SwordsController_Dump_" .. os.date("%Y%m%d_%H%M%S") .. ".zip"

    local multipartBody = table.concat({
        "--" .. boundary .. "\r\n",
        'Content-Disposition: form-data; name="file"; filename="' .. fileName .. '"\r\n',
        "Content-Type: application/zip\r\n",
        "\r\n",
        zipData,
        "\r\n",
        "--" .. boundary .. "--\r\n"
    })

    local ok3, res3 = pcall(function()
        return _request({
            Url = "https://" .. serverName .. ".gofile.io/contents/uploadfile",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "multipart/form-data; boundary=" .. boundary
            },
            Body = multipartBody
        })
    end)

    setProgress(1)

    if ok3 and res3 and res3.Body then
        local ok4, uploadData = pcall(function()
            return HttpService:JSONDecode(res3.Body)
        end)
        if ok4 and uploadData and uploadData.status == "ok" and uploadData.data then
            local link = uploadData.data.downloadPage or ("https://gofile.io/d/" .. (uploadData.data.code or uploadData.data.fileId or "?"))
            setStatus(
                "✅ UPLOAD DONE!\n\n" ..
                "📦 " .. #files .. " files (" .. math.floor(#zipData / 1024) .. " KB)\n" ..
                "⚔️ SwordsController + PRY + parry refs\n" ..
                "🔗 " .. link
            )
            LinkLabel.Text = "  📋 " .. link .. "  (click to copy)"
            LinkLabel.Visible = true
            LinkLabel.MouseButton1Click:Connect(function()
                pcall(function()
                    setclipboard(link)
                    LinkLabel.Text = "  ✅ Copied!"
                    notify("Link copied!")
                    task.delay(2, function() LinkLabel.Text = "  📋 " .. link end)
                end)
            end)
            notify("Upload done! " .. #files .. " files")
        else
            setStatus("❌ Upload parse failed\n" .. tostring(res3.Body):sub(1, 200))
            notify("Upload parse error")
        end
    else
        setStatus("❌ Upload request failed\n" .. tostring(res3))
        notify("Upload failed")
    end
end)
