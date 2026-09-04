--[[
    Speed Test — Blade Ball
    Optimise firesignal en remplaçant les handlers inutiles
    par des fonctions vides (sans disconnect = pas de kick)
    + cherche les cooldown client-side dans SwordsController
]]

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

-- ===================== GUI ===================== --

local oldGui = CoreGui:FindFirstChild("ST_Output")
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ST_Output"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 1001
pcall(function() if gethui then ScreenGui.Parent = gethui() return end end)
if not ScreenGui.Parent then
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end end)
    ScreenGui.Parent = CoreGui
end

local BG = Instance.new("Frame")
BG.Size = UDim2.new(0, 480, 0, 420)
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
TitleBar.Text = "  🚀 Speed Optimizer"
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
local MAGENTA = Color3.fromRGB(255, 130, 255)
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
        StarterGui:SetCore("SendNotification", {Title = "SpeedTest", Text = t, Duration = 5})
    end)
end

local _getconnections = getconnections
local _getinfo = typeof(getinfo) == "function" and getinfo or (debug and debug.getinfo)
local _getupvalues = typeof(getupvalues) == "function" and getupvalues or (debug and debug.getupvalues)
local _getupvalue = typeof(getupvalue) == "function" and getupvalue or (debug and debug.getupvalue)
local _setupvalue = typeof(setupvalue) == "function" and setupvalue or (debug and debug.setupvalue)
local _hookfunction = typeof(hookfunction) == "function" and hookfunction or (typeof(replaceclosure) == "function" and replaceclosure) or nil

local function makeBtn(text, color, callback)
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
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    local result = addLine("    ...", DIM)
    btn.MouseButton1Click:Connect(function()
        btn.Text = "  ⏳ " .. text
        local ok, err = pcall(callback)
        if ok then
            result.Text = "    ✅ Done!"
            result.TextColor3 = GREEN
            btn.Text = "  ✓ " .. text
        else
            result.Text = "    ❌ " .. tostring(err):sub(1, 60)
            result.TextColor3 = RED
            btn.Text = "  ✗ " .. text
        end
    end)
    return btn, result
end

-- ===================== CAPABILITIES ===================== --

addLine("🚀 Speed Optimizer — Blade Ball", WHITE)

section("CAPABILITIES")
addLine("  hookfunction: " .. ((_hookfunction and "✅") or "❌"), _hookfunction and GREEN or RED)
addLine("  setupvalue: " .. ((_setupvalue and "✅") or "❌"), _setupvalue and GREEN or RED)

-- ===================== IDENTIFY CONNECTIONS ===================== --

section("CONNECTIONS")

local hotbar = Player.PlayerGui:FindFirstChild("Hotbar")
if not hotbar then addLine("❌ Hotbar not found", RED); return end
local block = hotbar:FindFirstChild("Block")
if not block then addLine("❌ Block not found", RED); return end

local conns = _getconnections(block.Activated)
addLine("  " .. #conns .. " connections on Block.Activated", CYAN)

local soundConn = nil
local analyticsConn = nil
local parryConn = nil
local soundFn = nil
local analyticsFn = nil
local parryFn = nil

for i, conn in ipairs(conns) do
    local fn = nil
    pcall(function() fn = conn.Function end)
    if fn and _getinfo then
        local ok, info = pcall(_getinfo, fn)
        if ok and info and info.source then
            local src = tostring(info.source)
            local label = ""
            if src:find("ClickSFX") or src:find("ComponentsController") then
                soundConn = conn
                soundFn = fn
                label = "🔊 SOUND (ClickSFX)"
            elseif src:find("AnalyticsController") then
                analyticsConn = conn
                analyticsFn = fn
                label = "📊 ANALYTICS"
            elseif src:find("SwordsController") then
                parryConn = conn
                parryFn = fn
                label = "⚔️ PARRY (SwordsController)"
            else
                label = "❓ " .. src:sub(-40)
            end
            addLine("  #" .. i .. " = " .. label, CYAN)
        end
    end
end

if not parryFn then
    addLine("❌ SwordsController not found!", RED)
    return
end

-- ===================== SPEED TESTS ===================== --

section("SPEED BENCHMARK")
addLine("  Measures fires per second with different configs", YELLOW)
addLine("", DIM)

local function benchmark(label, fireFn, duration)
    duration = duration or 2
    local count = 0
    local startTime = tick()

    -- Run for N seconds
    local benchConn
    local done = false

    benchConn = RunService.Heartbeat:Connect(function()
        if done then return end
        if tick() - startTime >= duration then
            done = true
            benchConn:Disconnect()
            return
        end
        pcall(fireFn)
        count = count + 1
    end)

    -- Wait for completion
    repeat task.wait(0.1) until done
    task.wait(0.1)

    local elapsed = tick() - startTime
    local fps = math.floor(count / elapsed)
    return fps, count
end

-- Benchmark 1: Normal firesignal (all 3 connections)
makeBtn("Benchmark: Normal firesignal (2 sec)", CYAN, function()
    local fps, total = benchmark("normal", function()
        firesignal(block.Activated)
    end, 2)
    addLine("    → " .. fps .. " fires/sec (" .. total .. " total in 2s)", GREEN)
    notify("Normal: " .. fps .. " fires/sec")
end)

-- ===================== OPTIMIZATION 1: hookfunction on sound ===================== --

section("OPTIMIZATION: Replace Sound Handler")
addLine("  Replace ClickSFX function with empty (no disconnect)", YELLOW)
addLine("", DIM)

local soundHooked = false
local originalSoundFn = nil

if _hookfunction and soundFn then
    makeBtn("Hook Sound → empty function", GREEN, function()
        if soundHooked then
            addLine("    Already hooked!", YELLOW)
            return
        end
        originalSoundFn = _hookfunction(soundFn, function() end)
        soundHooked = true
        addLine("    ✅ Sound handler replaced with empty function", GREEN)
        notify("Sound hooked!")
    end)

    makeBtn("Restore original Sound", DIM, function()
        if not soundHooked or not originalSoundFn then
            addLine("    Not hooked yet", DIM)
            return
        end
        _hookfunction(soundFn, originalSoundFn)
        soundHooked = false
        addLine("    ✅ Sound restored", GREEN)
    end)
else
    addLine("  ⚠ hookfunction not available or sound conn not found", RED)
    if soundFn then
        addLine("  Trying replaceclosure...", YELLOW)
    end
end

-- ===================== OPTIMIZATION 2: hookfunction on analytics ===================== --

section("OPTIMIZATION: Replace Analytics Handler")
addLine("  Replace AnalyticsController with empty", YELLOW)
addLine("", DIM)

local analyticsHooked = false
local originalAnalyticsFn = nil

if _hookfunction and analyticsFn then
    makeBtn("Hook Analytics → empty function", GREEN, function()
        if analyticsHooked then
            addLine("    Already hooked!", YELLOW)
            return
        end
        originalAnalyticsFn = _hookfunction(analyticsFn, function() end)
        analyticsHooked = true
        addLine("    ✅ Analytics handler replaced with empty function", GREEN)
        notify("Analytics hooked!")
    end)

    makeBtn("Restore original Analytics", DIM, function()
        if not analyticsHooked or not originalAnalyticsFn then
            addLine("    Not hooked yet", DIM)
            return
        end
        _hookfunction(analyticsFn, originalAnalyticsFn)
        analyticsHooked = false
        addLine("    ✅ Analytics restored", GREEN)
    end)
else
    addLine("  ⚠ hookfunction not available or analytics conn not found", RED)
end

-- ===================== BENCHMARK AFTER HOOKS ===================== --

section("BENCHMARK AFTER OPTIMIZATIONS")
addLine("  Run this AFTER hooking sound + analytics", YELLOW)
addLine("", DIM)

makeBtn("Benchmark: Optimized firesignal (2 sec)", CYAN, function()
    local fps, total = benchmark("optimized", function()
        firesignal(block.Activated)
    end, 2)
    addLine("    → " .. fps .. " fires/sec (" .. total .. " total in 2s)", GREEN)
    notify("Optimized: " .. fps .. " fires/sec")
end)

-- ===================== SPAM TEST ===================== --

section("SPAM TEST (3 RunService events)")
addLine("  Full speed spam with all optimizations", YELLOW)
addLine("", DIM)

local spamming = false
local spamConns = {}
local fireCounter = 0

local function stopSpam()
    spamming = false
    for _, c in pairs(spamConns) do pcall(function() c:Disconnect() end) end
    spamConns = {}
end

lineOrder = lineOrder + 1
local spamBtn = Instance.new("TextButton")
spamBtn.Size = UDim2.new(1, 0, 0, 34)
spamBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
spamBtn.Text = "  🔥 TOGGLE SPAM (firesignal × 3 events)"
spamBtn.TextColor3 = RED
spamBtn.TextSize = 12
spamBtn.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
spamBtn.TextXAlignment = Enum.TextXAlignment.Left
spamBtn.AutoButtonColor = true
spamBtn.LayoutOrder = lineOrder
spamBtn.BorderSizePixel = 0
spamBtn.Parent = Scroll
Instance.new("UICorner", spamBtn).CornerRadius = UDim.new(0, 6)

local spamInfo = addLine("    OFF", DIM)

spamBtn.MouseButton1Click:Connect(function()
    if spamming then
        stopSpam()
        spamBtn.Text = "  🔥 TOGGLE SPAM (firesignal × 3 events)"
        spamBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
        spamInfo.Text = "    OFF — total fires: " .. fireCounter
        spamInfo.TextColor3 = DIM
    else
        stopSpam()
        spamming = true
        fireCounter = 0
        spamBtn.Text = "  ⏹ STOP SPAM"
        spamBtn.BackgroundColor3 = Color3.fromRGB(20, 40, 20)
        spamInfo.Text = "    🔥 SPAMMING..."
        spamInfo.TextColor3 = GREEN

        local activatedSignal = block.Activated

        local function fire()
            if not spamming then return end
            pcall(firesignal, activatedSignal)
            fireCounter = fireCounter + 1
        end

        spamConns[1] = RunService.PreSimulation:Connect(fire)
        spamConns[2] = RunService.Heartbeat:Connect(fire)
        spamConns[3] = RunService.RenderStepped:Connect(fire)

        -- Counter display
        task.spawn(function()
            local startT = tick()
            while spamming do
                task.wait(0.5)
                local elapsed = tick() - startT
                local fps = math.floor(fireCounter / math.max(elapsed, 0.01))
                if spamInfo.Parent then
                    spamInfo.Text = "    🔥 " .. fireCounter .. " fires (" .. fps .. "/sec) — " .. math.floor(elapsed) .. "s"
                end
            end
        end)
    end
end)

-- ===================== COOLDOWN SCAN ===================== --

section("COOLDOWN SCAN")
addLine("  Looking for cooldown/timer values in SwordsController", YELLOW)
addLine("", DIM)

-- Walk SwordsController upvalues for numbers that could be cooldowns
local cooldownCandidates = {}

pcall(function()
    local function scanCooldowns(fn, depth, path, visited)
        if not fn or depth > 6 or type(fn) ~= "function" then return end
        if visited[fn] then return end
        visited[fn] = true

        local uvs = {}
        pcall(function()
            if _getupvalues then uvs = _getupvalues(fn)
            elseif _getupvalue then
                for i = 1, 100 do
                    local n, v = _getupvalue(fn, i)
                    if n == nil and v == nil then break end
                    uvs[i] = v
                end
            end
        end)

        for idx, val in pairs(uvs) do
            local p = path .. ".UV[" .. tostring(idx) .. "]"
            if type(val) == "number" and val > 0 and val <= 10 then
                -- Numbers between 0 and 10 could be cooldowns (seconds)
                table.insert(cooldownCandidates, {
                    path = p,
                    value = val,
                    fnRef = fn,
                    uvIdx = idx
                })
            elseif type(val) == "boolean" then
                table.insert(cooldownCandidates, {
                    path = p,
                    value = val,
                    fnRef = fn,
                    uvIdx = idx,
                    isBool = true
                })
            elseif type(val) == "function" then
                scanCooldowns(val, depth + 1, p, visited)
            end
        end
    end

    scanCooldowns(parryFn, 0, "Parry", {})
end)

if #cooldownCandidates > 0 then
    addLine("  Found " .. #cooldownCandidates .. " potential cooldown values:", CYAN)
    for i, cd in ipairs(cooldownCandidates) do
        if cd.isBool then
            addLine("  [" .. i .. "] " .. cd.path .. " = " .. tostring(cd.value) .. " (boolean)", MAGENTA)
        else
            addLine("  [" .. i .. "] " .. cd.path .. " = " .. cd.value .. " sec?", cd.value < 1 and GREEN or YELLOW)
        end
    end

    if _setupvalue then
        addLine("", DIM)
        addLine("  setupvalue available — can modify these values!", GREEN)

        -- Create buttons to zero out number cooldowns
        for i, cd in ipairs(cooldownCandidates) do
            if not cd.isBool and cd.value > 0 then
                makeBtn("Set [" .. i .. "] " .. cd.path:sub(-30) .. " (" .. cd.value .. " → 0)", YELLOW, function()
                    _setupvalue(cd.fnRef, cd.uvIdx, 0)
                    addLine("    Set to 0!", GREEN)
                    notify("Cooldown #" .. i .. " set to 0")
                end)
            end
        end
    end
else
    addLine("  No obvious cooldown values found in top-level upvalues", DIM)
end

-- ===================== DONE ===================== --

section("INSTRUCTIONS")
addLine("  1. Run 'Benchmark: Normal' to see base speed", WHITE)
addLine("  2. Click 'Hook Sound' + 'Hook Analytics'", WHITE)
addLine("  3. Run 'Benchmark: Optimized' to compare", WHITE)
addLine("  4. If no kick after 30s, try 'TOGGLE SPAM'", WHITE)
addLine("  5. Check cooldown values at bottom", WHITE)
addLine("", DIM)
addLine("  If hookfunction causes kick, try only one at a time", YELLOW)
notify("Ready!")

ScreenGui.Destroying:Connect(function()
    stopSpam()
end)
