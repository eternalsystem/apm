--[[
    SwordsController Direct Reader
    Decompiles SwordsController + PRY directly into clipboard/GUI
    No file saving — avoids the Windows trailing-space issue entirely
]]

repeat task.wait() until game:IsLoaded()
task.wait(3)

local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- ===================== GUI ===================== --

local oldGui = CoreGui:FindFirstChild("SWC_Reader")
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SWC_Reader"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 1004
pcall(function() if gethui then ScreenGui.Parent = gethui() return end end)
if not ScreenGui.Parent then
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end end)
    ScreenGui.Parent = CoreGui
end

local BG = Instance.new("Frame")
BG.Size = UDim2.new(0, 500, 0, 400)
BG.Position = UDim2.new(0.5, -250, 0.5, -200)
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
TitleBar.Text = "  ⚔️ SwordsController Reader"
TitleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleBar.TextSize = 13
TitleBar.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
TitleBar.TextXAlignment = Enum.TextXAlignment.Left
TitleBar.BorderSizePixel = 0
TitleBar.Parent = BG
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 8)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 50)
StatusLabel.Position = UDim2.fromOffset(10, 32)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Starting..."
StatusLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
StatusLabel.TextSize = 11
StatusLabel.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json")
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextYAlignment = Enum.TextYAlignment.Top
StatusLabel.TextWrapped = true
StatusLabel.Parent = BG

-- Scrolling source view
local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, -20, 1, -120)
ScrollFrame.Position = UDim2.fromOffset(10, 85)
ScrollFrame.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 6
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
ScrollFrame.Parent = BG
Instance.new("UICorner", ScrollFrame).CornerRadius = UDim.new(0, 4)

local SourceLabel = Instance.new("TextLabel")
SourceLabel.Size = UDim2.new(1, -10, 0, 0)
SourceLabel.Position = UDim2.fromOffset(5, 0)
SourceLabel.AutomaticSize = Enum.AutomaticSize.Y
SourceLabel.BackgroundTransparency = 1
SourceLabel.Text = ""
SourceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
SourceLabel.TextSize = 10
SourceLabel.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json")
SourceLabel.TextXAlignment = Enum.TextXAlignment.Left
SourceLabel.TextYAlignment = Enum.TextYAlignment.Top
SourceLabel.TextWrapped = true
SourceLabel.RichText = false
SourceLabel.Parent = ScrollFrame

-- Button row
local BtnRow = Instance.new("Frame")
BtnRow.Size = UDim2.new(1, -20, 0, 28)
BtnRow.Position = UDim2.new(0, 10, 1, -32)
BtnRow.BackgroundTransparency = 1
BtnRow.Parent = BG

local function makeBtn(text, color, xPos)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 150, 1, 0)
    btn.Position = UDim2.new(0, xPos, 0, 0)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 11
    btn.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
    btn.AutoButtonColor = true
    btn.BorderSizePixel = 0
    btn.Parent = BtnRow
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    return btn
end

local CopyBtn = makeBtn("📋 Copy Current", Color3.fromRGB(40, 80, 40), 0)
local NextBtn = makeBtn("➡️ Next File", Color3.fromRGB(40, 40, 80), 160)
local UploadBtn = makeBtn("☁️ Upload All", Color3.fromRGB(80, 50, 20), 320)

local function setStatus(t) StatusLabel.Text = t end

local function notify(text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title = "SWC", Text = text, Duration = 6})
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

-- ===================== ZIP (for upload) ===================== --

local function numToLE2(n) return string.char(n%256, math.floor(n/256)%256) end
local function numToLE4(n) return string.char(n%256, math.floor(n/256)%256, math.floor(n/65536)%256, math.floor(n/16777216)%256) end

local crc32_table = {}
for i = 0, 255 do
    local c = i
    for _ = 1, 8 do
        if bit32.band(c, 1) == 1 then c = bit32.bxor(bit32.rshift(c, 1), 0xEDB88320) else c = bit32.rshift(c, 1) end
    end
    crc32_table[i] = c
end
local function crc32(data)
    local crc = 0xFFFFFFFF
    for i = 1, #data do crc = bit32.bxor(bit32.rshift(crc, 8), crc32_table[bit32.band(bit32.bxor(crc, string.byte(data, i)), 0xFF)]) end
    return bit32.bxor(crc, 0xFFFFFFFF)
end
local function buildZip(files)
    local lh, ce, off = {}, {}, 0
    for _, f in ipairs(files) do
        local n, d, c, s = f.name, f.data, crc32(f.data), #f.data
        local h = "PK\3\4"..numToLE2(20)..numToLE2(0)..numToLE2(0)..numToLE2(0)..numToLE2(0)..numToLE4(c)..numToLE4(s)..numToLE4(s)..numToLE2(#n)..numToLE2(0)..n..d
        lh[#lh+1] = h
        ce[#ce+1] = "PK\1\2"..numToLE2(20)..numToLE2(20)..numToLE2(0)..numToLE2(0)..numToLE2(0)..numToLE2(0)..numToLE4(c)..numToLE4(s)..numToLE4(s)..numToLE2(#n)..numToLE2(0)..numToLE2(0)..numToLE2(0)..numToLE2(0)..numToLE4(0)..numToLE4(off)..n
        off = off + #h
    end
    local cd = table.concat(ce)
    return table.concat(lh)..cd.."PK\5\6"..numToLE2(0)..numToLE2(0)..numToLE2(#files)..numToLE2(#files)..numToLE4(#cd)..numToLE4(off)..numToLE2(0)
end

-- ===================== MAIN ===================== --

task.spawn(function()
    if typeof(decompile) ~= "function" then
        setStatus("❌ decompile() not available!")
        return
    end

    setStatus("🔍 Finding SwordsController...")

    -- Find the SwordsController module
    local Controllers = ReplicatedStorage:FindFirstChild("Controllers")
    if not Controllers then
        setStatus("❌ ReplicatedStorage.Controllers not found!")
        return
    end

    -- Search for SwordsController (with or without trailing space)
    local swcModule = nil
    local pryModule = nil
    local allTargets = {}

    for _, child in ipairs(Controllers:GetChildren()) do
        -- Check name with/without trailing spaces
        local cleanName = child.Name:gsub("%s+$", "")
        if cleanName == "SwordsController" then
            if child:IsA("ModuleScript") then
                swcModule = child
                table.insert(allTargets, {script = child, label = "SwordsController (main)"})
            end
            -- Check children (PRY module)
            for _, sub in ipairs(child:GetDescendants()) do
                if sub:IsA("ModuleScript") or sub:IsA("LocalScript") then
                    table.insert(allTargets, {script = sub, label = "SwordsController/" .. sub.Name})
                    if sub.Name:upper():find("PRY") then
                        pryModule = sub
                    end
                end
            end
        end
    end

    -- Also search via getscripts() as backup
    if #allTargets == 0 then
        setStatus("🔍 Not in Children, trying getscripts()...")
        pcall(function()
            for _, s in ipairs(getscripts()) do
                local fn = s:GetFullName()
                if fn:find("SwordsController") then
                    table.insert(allTargets, {script = s, label = fn:gsub(".*Controllers%.", "")})
                    if s.Name:upper():find("PRY") then pryModule = s end
                    if fn:match("SwordsController%s*$") or fn:match("SwordsController%s*%.module") then
                        swcModule = s
                    end
                end
            end
        end)
    end

    -- Also find it by scanning ControllerRunners
    if #allTargets == 0 then
        setStatus("🔍 Searching ControllerRunners...")
        pcall(function()
            local player = game:GetService("Players").LocalPlayer
            local runners = player.PlayerScripts:FindFirstChild("ClientLoader")
            if runners then
                runners = runners:FindFirstChild("ControllerRunners")
            end
            if runners then
                for _, runner in ipairs(runners:GetChildren()) do
                    local cleanName = runner.Name:gsub("%s+$", "")
                    if cleanName == "SwordsController" then
                        local target = runner:FindFirstChild("Target")
                        if target and target:IsA("ObjectValue") and target.Value then
                            local actualModule = target.Value
                            table.insert(allTargets, {script = actualModule, label = "SwordsController (via runner Target)"})
                            swcModule = actualModule
                            for _, sub in ipairs(actualModule:GetDescendants()) do
                                if sub:IsA("ModuleScript") or sub:IsA("LocalScript") then
                                    table.insert(allTargets, {script = sub, label = "SwordsController/" .. sub.Name})
                                    if sub.Name:upper():find("PRY") then pryModule = sub end
                                end
                            end
                        end
                    end
                end
            end
        end)
    end

    if #allTargets == 0 then
        setStatus("❌ SwordsController not found anywhere!\nTry clicking Block once first.")
        return
    end

    setStatus(
        "✅ Found " .. #allTargets .. " target(s)\n" ..
        "📄 SWC: " .. (swcModule and swcModule:GetFullName() or "?") .. "\n" ..
        "📄 PRY: " .. (pryModule and pryModule:GetFullName() or "?") .. "\n" ..
        "🔧 Decompiling..."
    )
    task.wait()

    -- Decompile all targets
    local results = {} -- {name, source, size}

    for i, target in ipairs(allTargets) do
        setStatus("🔧 Decompiling " .. i .. "/" .. #allTargets .. ": " .. target.label)
        task.wait()

        local ok, source = pcall(function() return decompile(target.script) end)
        if not ok or not source or #source == 0 then
            pcall(function() source = target.script.Source end)
        end
        if not source or #source == 0 then
            source = "-- [DECOMPILE FAILED for " .. target.script:GetFullName() .. "]"
        end

        local cleanName = target.label:gsub("%s+/", "/"):gsub("%s+%.", "."):gsub("%s+$", "")
        table.insert(results, {
            name = cleanName,
            source = source,
            size = #source
        })
    end

    -- Also add runtime deep scan of Connection #3
    local runtimeDump = "-- ===== RUNTIME: Connection #3 Deep Scan =====\n\n"
    pcall(function()
        local _gc = getconnections
        local _gi = getinfo or debug.info
        local _gu = getupvalues or debug.getupvalues
        local _gc2 = getconstants or debug.getconstants
        local _gp = getprotos or debug.getprotos

        local block = game:GetService("Players").LocalPlayer.PlayerGui.Hotbar.Block
        local conns = _gc(block.Activated)

        for idx, conn in ipairs(conns) do
            local fn = nil
            pcall(function() fn = conn.Function end)
            if not fn then continue end
            local ok, info = pcall(_gi, fn)
            if not ok or not info then continue end
            if not tostring(info.source or ""):find("SwordsController") then continue end

            runtimeDump = runtimeDump .. "-- Found SwordsController handler (conn #" .. idx .. ")\n"
            runtimeDump = runtimeDump .. "-- Source: " .. tostring(info.source) .. "\n"
            runtimeDump = runtimeDump .. "-- Line: " .. tostring(info.currentline or info.linedefined) .. "\n\n"

            -- Deep upvalue walk (5 levels)
            local function dumpUpvalues(f, prefix, depth)
                if depth > 5 then return end
                local ok2, uvs = pcall(_gu, f)
                if not ok2 or not uvs then return end
                for k, v in pairs(uvs) do
                    local vt = typeof(v)
                    local vs = tostring(v)
                    if #vs > 200 then vs = vs:sub(1, 200) .. "..." end
                    runtimeDump = runtimeDump .. prefix .. "UV[" .. k .. "] = (" .. vt .. ") " .. vs .. "\n"

                    -- If it's a table, dump its string keys
                    if type(v) == "table" and depth <= 3 then
                        local count = 0
                        for tk, tv in pairs(v) do
                            if count > 30 then
                                runtimeDump = runtimeDump .. prefix .. "  ... (truncated)\n"
                                break
                            end
                            if type(tk) == "string" then
                                runtimeDump = runtimeDump .. prefix .. "  ." .. tk .. " = (" .. typeof(tv) .. ") " .. tostring(tv):sub(1,120) .. "\n"
                            elseif type(tk) == "number" then
                                runtimeDump = runtimeDump .. prefix .. "  [" .. tk .. "] = (" .. typeof(tv) .. ") " .. tostring(tv):sub(1,120) .. "\n"
                            end
                            count = count + 1
                        end
                    end

                    -- Recurse into functions
                    if type(v) == "function" then
                        -- Get constants of this function
                        if _gc2 then
                            pcall(function()
                                local consts = _gc2(v)
                                if consts and #consts > 0 then
                                    runtimeDump = runtimeDump .. prefix .. "  CONSTANTS:\n"
                                    for ck, cv in pairs(consts) do
                                        runtimeDump = runtimeDump .. prefix .. "    C[" .. ck .. "] = (" .. typeof(cv) .. ") " .. tostring(cv) .. "\n"
                                    end
                                end
                            end)
                        end
                        -- Get info
                        if _gi then
                            pcall(function()
                                local fi = _gi(v)
                                if fi then
                                    runtimeDump = runtimeDump .. prefix .. "  INFO: src=" .. tostring(fi.source) .. " line=" .. tostring(fi.currentline or fi.linedefined) .. "\n"
                                end
                            end)
                        end
                        -- Recurse
                        dumpUpvalues(v, prefix .. "  ", depth + 1)
                    end
                end
            end

            runtimeDump = runtimeDump .. "-- === Upvalue tree ===\n"
            dumpUpvalues(fn, "-- ", 0)
            runtimeDump = runtimeDump .. "\n"

            -- Also dump constants of the handler itself
            if _gc2 then
                pcall(function()
                    local consts = _gc2(fn)
                    runtimeDump = runtimeDump .. "-- Handler constants: " .. #consts .. "\n"
                    for k, v in pairs(consts) do
                        runtimeDump = runtimeDump .. "--   C[" .. k .. "] = (" .. typeof(v) .. ") " .. tostring(v) .. "\n"
                    end
                end)
            end

            -- Get protos (sub-functions)
            if _gp then
                pcall(function()
                    local protos = _gp(fn)
                    runtimeDump = runtimeDump .. "\n-- Handler protos: " .. #protos .. "\n"
                    for pi, pf in ipairs(protos) do
                        runtimeDump = runtimeDump .. "--   Proto[" .. pi .. "]: " .. tostring(pf) .. "\n"
                        if _gc2 then
                            pcall(function()
                                local pc = _gc2(pf)
                                for pk, pv in pairs(pc) do
                                    runtimeDump = runtimeDump .. "--     C[" .. pk .. "] = (" .. typeof(pv) .. ") " .. tostring(pv) .. "\n"
                                end
                            end)
                        end
                    end
                end)
            end

            break -- Only need connection #3
        end
    end)

    table.insert(results, {
        name = "_RUNTIME_DEEP_SCAN",
        source = runtimeDump,
        size = #runtimeDump
    })

    -- Sort: biggest first
    table.sort(results, function(a, b) return a.size > b.size end)

    -- Display first result
    local currentIdx = 1
    local function showResult(idx)
        if idx < 1 or idx > #results then return end
        currentIdx = idx
        local r = results[idx]
        setStatus(
            "📄 [" .. idx .. "/" .. #results .. "] " .. r.name ..
            " (" .. r.size .. " bytes)\n" ..
            "💡 Use buttons below to copy or navigate"
        )
        -- Truncate display to avoid lag (show first 50K chars)
        local display = r.source
        if #display > 50000 then
            display = display:sub(1, 50000) .. "\n\n-- [TRUNCATED - full source in clipboard/upload]"
        end
        SourceLabel.Text = display
    end
    showResult(1)

    -- Button handlers
    CopyBtn.MouseButton1Click:Connect(function()
        pcall(function()
            setclipboard(results[currentIdx].source)
            notify("Copied " .. results[currentIdx].name .. " (" .. results[currentIdx].size .. " bytes)")
            CopyBtn.Text = "✅ Copied!"
            task.delay(2, function() CopyBtn.Text = "📋 Copy Current" end)
        end)
    end)

    NextBtn.MouseButton1Click:Connect(function()
        local next = currentIdx + 1
        if next > #results then next = 1 end
        showResult(next)
    end)

    UploadBtn.MouseButton1Click:Connect(function()
        if not _request then
            notify("request() not available!")
            return
        end

        UploadBtn.Text = "☁️ Uploading..."

        task.spawn(function()
            -- Build ZIP with sanitized names
            local zipFiles = {}
            for _, r in ipairs(results) do
                local fname = r.name:gsub("[^%w%./%-_]", "_")
                if not fname:find("%.lua$") then
                    fname = fname .. ".lua"
                end
                table.insert(zipFiles, {name = fname, data = r.source})
            end

            local zipData = buildZip(zipFiles)

            -- Get gofile server
            local serverName = "store1"
            pcall(function()
                local res = _request({Url = "https://api.gofile.io/servers", Method = "GET"})
                local data = HttpService:JSONDecode(res.Body)
                if data.data and data.data.servers then
                    serverName = data.data.servers[1].name
                end
            end)

            local boundary = "----SWC" .. tostring(math.random(100000, 999999))
            local fileName = "SwordsController_Source_" .. os.date("%Y%m%d_%H%M%S") .. ".zip"

            local body = "--" .. boundary .. "\r\n"
                .. 'Content-Disposition: form-data; name="file"; filename="' .. fileName .. '"\r\n'
                .. "Content-Type: application/zip\r\n\r\n"
                .. zipData .. "\r\n--" .. boundary .. "--\r\n"

            local ok, res = pcall(function()
                return _request({
                    Url = "https://" .. serverName .. ".gofile.io/contents/uploadfile",
                    Method = "POST",
                    Headers = {["Content-Type"] = "multipart/form-data; boundary=" .. boundary},
                    Body = body
                })
            end)

            if ok and res and res.Body then
                pcall(function()
                    local data = HttpService:JSONDecode(res.Body)
                    if data.status == "ok" and data.data then
                        local link = data.data.downloadPage or ("https://gofile.io/d/" .. (data.data.code or "?"))
                        UploadBtn.Text = "✅ Uploaded!"
                        notify("Upload done: " .. link)
                        setStatus(
                            "✅ UPLOADED: " .. #zipFiles .. " files\n" ..
                            "🔗 " .. link .. "\n" ..
                            "📄 Currently viewing: [" .. currentIdx .. "/" .. #results .. "] " .. results[currentIdx].name
                        )
                        pcall(function() setclipboard(link) end)
                    else
                        UploadBtn.Text = "❌ Failed"
                        notify("Upload failed: " .. tostring(data.status))
                    end
                end)
            else
                UploadBtn.Text = "❌ Error"
                notify("Upload request failed")
            end
            task.delay(3, function() UploadBtn.Text = "☁️ Upload All" end)
        end)
    end)

    notify("Ready! " .. #results .. " files decompiled")
end)
