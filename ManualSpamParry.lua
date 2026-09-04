--[[
    PrivateKey Test — Blade Ball
    Extrait les remotes + clé hex 32 du SwordsController
    Teste différentes combinaisons de FireServer
    UN SEUL fire par combo pour éviter les kicks
]]

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")

-- ===================== GUI ===================== --

local oldGui = CoreGui:FindFirstChild("PKT_Output")
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PKT_Output"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 1001
pcall(function() if gethui then ScreenGui.Parent = gethui() return end end)
if not ScreenGui.Parent then
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end end)
    ScreenGui.Parent = CoreGui
end

local BG = Instance.new("Frame")
BG.Size = UDim2.new(0, 520, 0, 400)
BG.Position = UDim2.new(0, 10, 0, 10)
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
TitleBar.Text = "  ⚡ PrivateKey Test"
TitleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleBar.TextSize = 13
TitleBar.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
TitleBar.TextXAlignment = Enum.TextXAlignment.Left
TitleBar.BorderSizePixel = 0
TitleBar.Parent = BG
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 8)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.fromOffset(28, 28)
CloseBtn.Position = UDim2.new(1, -28, 0, 0)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
CloseBtn.TextSize = 14
CloseBtn.Parent = TitleBar
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -16, 1, -36)
Scroll.Position = UDim2.fromOffset(8, 32)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 4
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.Parent = BG

local Layout = Instance.new("UIListLayout")
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Padding = UDim.new(0, 1)
Layout.Parent = Scroll

local lineOrder = 0
local WHITE = Color3.fromRGB(255, 255, 255)
local GREEN = Color3.fromRGB(100, 255, 120)
local YELLOW = Color3.fromRGB(255, 220, 80)
local RED = Color3.fromRGB(255, 90, 90)
local CYAN = Color3.fromRGB(100, 200, 255)
local DIM = Color3.fromRGB(120, 120, 120)

local function addLine(text, color)
    lineOrder = lineOrder + 1
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 0)
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color or DIM
    lbl.TextSize = 11
    lbl.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextWrapped = true
    lbl.LayoutOrder = lineOrder
    lbl.Parent = Scroll
    return lbl
end

local function section(t) addLine(""); addLine("═══ " .. t .. " ═══", YELLOW) end
local function notify(t)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title = "PKTest", Text = t, Duration = 5})
    end)
end

local _getconnections = getconnections
local _getupvalues = typeof(getupvalues) == "function" and getupvalues or (debug and debug.getupvalues)
local _getupvalue = typeof(getupvalue) == "function" and getupvalue or (debug and debug.getupvalue)
local _getinfo = typeof(getinfo) == "function" and getinfo or (debug and debug.getinfo)

-- ===================== EXTRACT REMOTES + KEY ===================== --

local function ExtractParryData()
    local data = { remotes = {}, key32 = nil, key64 = nil, uuids = {} }

    local hotbar = Player.PlayerGui:FindFirstChild("Hotbar")
    if not hotbar then return nil, "Hotbar not found" end
    local block = hotbar:FindFirstChild("Block")
    if not block then return nil, "Block not found" end

    local conns = _getconnections(block.Activated)

    -- Find SwordsController connection
    local parryFn = nil
    for _, conn in ipairs(conns) do
        local fn = nil
        pcall(function() fn = conn.Function end)
        if fn and _getinfo then
            local ok, info = pcall(_getinfo, fn)
            if ok and info and info.source and tostring(info.source):find("SwordsController") then
                parryFn = fn
                break
            end
        end
    end

    -- Fallback: use last connection
    if not parryFn then
        for _, conn in ipairs(conns) do
            pcall(function() parryFn = conn.Function end)
        end
    end

    if not parryFn then return nil, "Cannot access parry function" end

    -- Deep walk to find remotes and hex strings
    local visited = {}

    local function walk(fn, depth)
        if not fn or depth > 12 then return end
        if type(fn) == "function" then
            if visited[fn] then return end
            visited[fn] = true

            local uvs = {}
            pcall(function()
                if _getupvalues then
                    uvs = _getupvalues(fn)
                elseif _getupvalue then
                    for i = 1, 200 do
                        local n, v = _getupvalue(fn, i)
                        if n == nil and v == nil then break end
                        uvs[i] = v
                    end
                end
            end)

            for _, val in pairs(uvs) do
                if typeof(val) == "Instance" and (val:IsA("RemoteEvent") or val:IsA("UnreliableRemoteEvent")) then
                    -- Check if already added
                    local already = false
                    for _, r in ipairs(data.remotes) do
                        if r == val then already = true; break end
                    end
                    if not already then
                        table.insert(data.remotes, val)
                    end
                elseif type(val) == "string" then
                    if #val == 32 and val:match("^[a-fA-F0-9]+$") then
                        data.key32 = val
                    elseif #val == 64 and val:match("^[a-fA-F0-9]+$") then
                        data.key64 = val
                    elseif #val == 36 and val:match("^%x+%-%x+%-%x+%-%x+%-%x+$") then
                        -- UUID
                        local already = false
                        for _, u in ipairs(data.uuids) do
                            if u == val then already = true; break end
                        end
                        if not already then
                            table.insert(data.uuids, val)
                        end
                    end
                elseif type(val) == "function" then
                    walk(val, depth + 1)
                elseif type(val) == "table" and not visited[val] then
                    visited[val] = true
                    local c = 0
                    for _, v in pairs(val) do
                        c = c + 1; if c > 80 then break end
                        if typeof(v) == "Instance" and (v:IsA("RemoteEvent") or v:IsA("UnreliableRemoteEvent")) then
                            local already = false
                            for _, r in ipairs(data.remotes) do
                                if r == v then already = true; break end
                            end
                            if not already then table.insert(data.remotes, v) end
                        elseif type(v) == "string" then
                            if #v == 32 and v:match("^[a-fA-F0-9]+$") then
                                data.key32 = v
                            elseif #v == 64 and v:match("^[a-fA-F0-9]+$") then
                                data.key64 = v
                            end
                        elseif type(v) == "function" then
                            walk(v, depth + 1)
                        elseif type(v) == "table" and not visited[v] then
                            visited[v] = true
                            local c2 = 0
                            for _, v2 in pairs(v) do
                                c2 = c2 + 1; if c2 > 60 then break end
                                if type(v2) == "string" then
                                    if #v2 == 32 and v2:match("^[a-fA-F0-9]+$") then
                                        data.key32 = v2
                                    elseif #v2 == 64 and v2:match("^[a-fA-F0-9]+$") then
                                        data.key64 = v2
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    walk(parryFn, 0)
    return data, nil
end

-- ===================== TEST FIRES ===================== --

addLine("⚡ PrivateKey Test — Blade Ball", WHITE)
addLine("Extracting parry data...", DIM)

section("EXTRACTION")

local data, err = ExtractParryData()

if not data then
    addLine("❌ " .. tostring(err), RED)
    notify("ERROR: " .. tostring(err))
    return
end

addLine("📡 Remotes found: " .. #data.remotes, GREEN)
for i, r in ipairs(data.remotes) do
    addLine("  [" .. i .. "] " .. r:GetFullName():sub(-60), CYAN)
end

addLine("", DIM)
addLine("🔑 Key32: " .. (data.key32 or "NOT FOUND"), data.key32 and GREEN or RED)
addLine("🔑 Key64: " .. (data.key64 and data.key64:sub(1, 40) .. "..." or "NOT FOUND"), data.key64 and GREEN or RED)

if #data.uuids > 0 then
    addLine("📋 UUIDs: " .. #data.uuids, DIM)
    for _, u in ipairs(data.uuids) do
        addLine("  " .. u, DIM)
    end
end

if #data.remotes == 0 then
    addLine("", RED)
    addLine("❌ No remotes found. Are you in a round?", RED)
    notify("No remotes found!")
    return
end

-- ===================== TEST BUTTONS ===================== --

section("TEST FIRE (press buttons below)")
addLine("⚠ Each button fires ONCE. Watch if you parry.", YELLOW)
addLine("  Only test during a round when ball is near you!", YELLOW)
addLine("", DIM)

local testResults = {}

local function makeTestBtn(text, color, callback)
    lineOrder = lineOrder + 1
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    btn.Text = "  ▶ " .. text
    btn.TextColor3 = color
    btn.TextSize = 12
    btn.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold)
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.AutoButtonColor = true
    btn.LayoutOrder = lineOrder
    btn.BorderSizePixel = 0
    btn.Parent = Scroll
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local resultLabel = addLine("    waiting...", DIM)

    btn.MouseButton1Click:Connect(function()
        btn.Text = "  ⏳ " .. text .. " (firing...)"
        local ok, fireErr = pcall(callback)
        if ok then
            resultLabel.Text = "    ✅ Fire sent! Did you parry?"
            resultLabel.TextColor3 = GREEN
            btn.Text = "  ✓ " .. text
            notify("Fire sent: " .. text)
        else
            resultLabel.Text = "    ❌ Error: " .. tostring(fireErr):sub(1, 60)
            resultLabel.TextColor3 = RED
            btn.Text = "  ✗ " .. text
            notify("Error: " .. tostring(fireErr):sub(1, 30))
        end
    end)

    return btn
end

-- Test for each remote
for i, remote in ipairs(data.remotes) do
    local shortName = "Remote#" .. i

    -- Test A: FireServer("Move")
    makeTestBtn(shortName .. " → FireServer(\"Move\")", CYAN, function()
        remote:FireServer("Move")
    end)

    -- Test B: FireServer("Move", key32)
    if data.key32 then
        makeTestBtn(shortName .. " → FireServer(\"Move\", Key32)", GREEN, function()
            remote:FireServer("Move", data.key32)
        end)
    end

    -- Test C: FireServer(key32)
    if data.key32 then
        makeTestBtn(shortName .. " → FireServer(Key32)", YELLOW, function()
            remote:FireServer(data.key32)
        end)
    end

    -- Test D: FireServer(key64, key32)
    if data.key64 and data.key32 then
        makeTestBtn(shortName .. " → FireServer(Key64, Key32)", MAGENTA, function()
            remote:FireServer(data.key64, data.key32)
        end)
    end

    -- Test E: FireServer("Move", key64)
    if data.key64 then
        makeTestBtn(shortName .. " → FireServer(\"Move\", Key64)", CYAN, function()
            remote:FireServer("Move", data.key64)
        end)
    end

    addLine("", DIM)
end

-- Test with UUIDs as potential keys
if #data.uuids > 0 and #data.remotes > 0 then
    section("UUID TESTS (Remote #1)")
    local remote = data.remotes[1]
    for _, uuid in ipairs(data.uuids) do
        makeTestBtn("UUID " .. uuid:sub(1, 8) .. "... → FireServer(UUID)", DIM, function()
            remote:FireServer(uuid)
        end)
    end
end

-- ===================== SPAM TEST BUTTON ===================== --

section("SPAM TEST (if a single fire works)")
addLine("  Once you find which fire works, press below to spam it", YELLOW)
addLine("", DIM)

local spamming = false
local spamConns = {}

local function stopSpam()
    spamming = false
    for _, c in pairs(spamConns) do pcall(function() c:Disconnect() end) end
    spamConns = {}
end

for i, remote in ipairs(data.remotes) do
    if data.key32 then
        local spamBtn
        lineOrder = lineOrder + 1
        spamBtn = Instance.new("TextButton")
        spamBtn.Size = UDim2.new(1, 0, 0, 34)
        spamBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
        spamBtn.Text = "  🔥 SPAM Remote#" .. i .. " + Key32 (Toggle)"
        spamBtn.TextColor3 = RED
        spamBtn.TextSize = 12
        spamBtn.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
        spamBtn.TextXAlignment = Enum.TextXAlignment.Left
        spamBtn.AutoButtonColor = true
        spamBtn.LayoutOrder = lineOrder
        spamBtn.BorderSizePixel = 0
        spamBtn.Parent = Scroll
        Instance.new("UICorner", spamBtn).CornerRadius = UDim.new(0, 6)

        local spamStatus = addLine("    OFF", DIM)

        spamBtn.MouseButton1Click:Connect(function()
            if spamming then
                stopSpam()
                spamBtn.Text = "  🔥 SPAM Remote#" .. i .. " + Key32 (Toggle)"
                spamBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
                spamStatus.Text = "    OFF"
                spamStatus.TextColor3 = DIM
            else
                stopSpam()
                spamming = true
                spamBtn.Text = "  ⏹ STOP SPAM Remote#" .. i .. " + Key32"
                spamBtn.BackgroundColor3 = Color3.fromRGB(20, 40, 20)
                spamStatus.Text = "    🔥 SPAMMING..."
                spamStatus.TextColor3 = GREEN

                -- Re-extract key in case it changed
                local freshData = ExtractParryData()
                local useKey = (freshData and freshData.key32) or data.key32
                local useRemote = remote

                if freshData and freshData.remotes[i] then
                    useRemote = freshData.remotes[i]
                end

                local fireCount = 0
                local function fire()
                    if not spamming then return end
                    pcall(function()
                        useRemote:FireServer("Move", useKey)
                    end)
                    fireCount = fireCount + 1
                end

                spamConns[1] = game:GetService("RunService").PreSimulation:Connect(fire)
                spamConns[2] = game:GetService("RunService").Heartbeat:Connect(fire)
                spamConns[3] = game:GetService("RunService").RenderStepped:Connect(fire)

                -- Update count display
                task.spawn(function()
                    while spamming do
                        if spamStatus.Parent then
                            spamStatus.Text = "    🔥 SPAMMING: " .. fireCount .. " fires"
                        end
                        task.wait(0.5)
                    end
                end)
            end
        end)
    end
end

-- Cleanup on destroy
ScreenGui.Destroying:Connect(function()
    stopSpam()
end)

section("DONE")
addLine("  Test each button one by one during a round", GREEN)
addLine("  Watch if the ball reacts (parry effect)", DIM)
notify("Ready! Test during a round")
