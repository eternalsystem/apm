--[[
    PrivateKey Test v2 — Blade Ball
    Cherche les objets Net (tables avec méthode Fire/Send)
    dans les upvalues du SwordsController et teste leur .Fire()
]]

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

-- ===================== GUI ===================== --

local oldGui = CoreGui:FindFirstChild("PKT2_Output")
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PKT2_Output"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 1001
pcall(function() if gethui then ScreenGui.Parent = gethui() return end end)
if not ScreenGui.Parent then
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end end)
    ScreenGui.Parent = CoreGui
end

local BG = Instance.new("Frame")
BG.Size = UDim2.new(0, 540, 0, 420)
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
TitleBar.Text = "  ⚡ PKTest v2 — Net Fire Scan"
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
        StarterGui:SetCore("SendNotification", {Title = "PKTest v2", Text = t, Duration = 5})
    end)
end

local _getconnections = getconnections
local _getupvalues = typeof(getupvalues) == "function" and getupvalues or (debug and debug.getupvalues)
local _getupvalue = typeof(getupvalue) == "function" and getupvalue or (debug and debug.getupvalue)
local _getinfo = typeof(getinfo) == "function" and getinfo or (debug and debug.getinfo)

-- ===================== SCAN ===================== --

addLine("⚡ PKTest v2 — Finding Net Fire methods", WHITE)

section("SCANNING SWORDSCONTROLLER")

local hotbar = Player.PlayerGui:FindFirstChild("Hotbar")
if not hotbar then addLine("❌ Hotbar not found", RED); return end
local block = hotbar:FindFirstChild("Block")
if not block then addLine("❌ Block not found", RED); return end

local conns = _getconnections(block.Activated)
addLine("  " .. #conns .. " connections", CYAN)

-- Find SwordsController
local parryFn = nil
for _, conn in ipairs(conns) do
    local fn = nil
    pcall(function() fn = conn.Function end)
    if fn and _getinfo then
        local ok, info = pcall(_getinfo, fn)
        if ok and info and info.source and tostring(info.source):find("SwordsController") then
            parryFn = fn
            addLine("  ✅ SwordsController found", GREEN)
            break
        end
    end
end
if not parryFn then
    -- Fallback: last connection
    for _, conn in ipairs(conns) do
        pcall(function() parryFn = conn.Function end)
    end
    addLine("  ⚠ Using last connection as fallback", YELLOW)
end

-- ===================== FIND NET OBJECTS (tables with Fire/Send methods) ===================== --

section("SEARCHING FOR NET OBJECTS")

local visited = {}
local netObjects = {} -- tables that have a Fire or Send function
local allTables = {} -- all interesting tables with their keys listed

local function getUVs(fn)
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
    return uvs
end

local function scanForNetObjects(fn, depth, path)
    if not fn or depth > 10 then return end

    if type(fn) == "function" then
        if visited[fn] then return end
        visited[fn] = true

        local uvs = getUVs(fn)
        for idx, val in pairs(uvs) do
            local p = path .. ".UV[" .. tostring(idx) .. "]"
            if type(val) == "table" and not visited[val] then
                visited[val] = true
                -- Check if this table has Fire, Send, fire, send methods
                local methods = {}
                local fields = {}
                local hasRemote = false
                pcall(function()
                    for k, v in pairs(val) do
                        if type(v) == "function" then
                            methods[tostring(k)] = v
                        elseif typeof(v) == "Instance" then
                            if v:IsA("RemoteEvent") or v:IsA("UnreliableRemoteEvent") then
                                hasRemote = true
                                fields[tostring(k)] = "Remote: " .. v.Name:sub(1, 30)
                            else
                                fields[tostring(k)] = v.ClassName
                            end
                        elseif type(v) == "string" then
                            fields[tostring(k)] = "\"" .. v:sub(1, 40) .. "\""
                        elseif type(v) == "table" then
                            fields[tostring(k)] = "table"
                        elseif type(v) == "boolean" then
                            fields[tostring(k)] = tostring(v)
                        elseif type(v) == "number" then
                            fields[tostring(k)] = tostring(v)
                        end
                    end
                end)

                -- Check metatable too
                local mt = nil
                pcall(function() mt = getmetatable(val) end)
                if mt and type(mt) == "table" and not visited[mt] then
                    visited[mt] = true
                    pcall(function()
                        for k, v in pairs(mt) do
                            if type(v) == "function" then
                                methods["(mt)" .. tostring(k)] = v
                            end
                        end
                        -- Check __index
                        if mt.__index and type(mt.__index) == "table" and not visited[mt.__index] then
                            visited[mt.__index] = true
                            for k, v in pairs(mt.__index) do
                                if type(v) == "function" then
                                    methods["(__index)" .. tostring(k)] = v
                                end
                            end
                        end
                    end)
                end

                -- Is this a Net object?
                local isNet = false
                for mName, _ in pairs(methods) do
                    local ml = mName:lower()
                    if ml:find("fire") or ml:find("send") or ml == "invoke" then
                        isNet = true
                    end
                end

                if isNet or hasRemote then
                    table.insert(netObjects, {
                        path = p,
                        obj = val,
                        methods = methods,
                        fields = fields,
                        hasRemote = hasRemote
                    })
                end

                -- Recurse into table values
                pcall(function()
                    for k, v in pairs(val) do
                        if type(v) == "function" then
                            scanForNetObjects(v, depth + 1, p .. "[" .. tostring(k) .. "]")
                        elseif type(v) == "table" and not visited[v] then
                            -- Mark but don't deep recurse tables of tables (too much)
                        end
                    end
                end)
            elseif type(val) == "function" then
                scanForNetObjects(val, depth + 1, p)
            end
        end
    end
end

scanForNetObjects(parryFn, 0, "SwordsCtrl")

addLine("  Found " .. #netObjects .. " Net-like objects", #netObjects > 0 and GREEN or RED)

for i, no in ipairs(netObjects) do
    addLine("", DIM)
    addLine("─── Object #" .. i .. " ───", CYAN)
    addLine("  Path: " .. no.path, DIM)
    addLine("  Has Remote: " .. tostring(no.hasRemote), no.hasRemote and GREEN or DIM)

    addLine("  Methods:", MAGENTA)
    for mName, _ in pairs(no.methods) do
        addLine("    ▸ " .. mName .. "()", WHITE)
    end

    addLine("  Fields:", DIM)
    for fName, fVal in pairs(no.fields) do
        addLine("    " .. fName .. " = " .. fVal, DIM)
    end
end

-- ===================== ALSO: DUMP UV[17] STRUCTURE ===================== --

section("UV[17] DEEP DUMP (where remotes live)")

-- We know remotes are at Conn#3.UV[1].UV[2].UV[17]
-- Let's dump its full structure
pcall(function()
    local uvs1 = getUVs(parryFn)
    if not uvs1[1] or type(uvs1[1]) ~= "function" then
        addLine("  UV[1] is not a function: " .. type(uvs1[1]), RED)
        -- Try all UVs
        for idx, val in pairs(uvs1) do
            addLine("  UV[" .. idx .. "] = " .. type(val), DIM)
        end
        return
    end

    local uvs2 = getUVs(uvs1[1])
    if not uvs2[2] or type(uvs2[2]) ~= "function" then
        addLine("  UV[1].UV[2] is not a function: " .. type(uvs2[2] or "nil"), RED)
        for idx, val in pairs(uvs2) do
            addLine("  UV[1].UV[" .. idx .. "] = " .. type(val), DIM)
        end
        return
    end

    local uvs3 = getUVs(uvs2[2])
    addLine("  UV[1].UV[2] has " .. (function() local c=0; for _ in pairs(uvs3) do c=c+1 end; return c end)() .. " upvalues", CYAN)

    -- Find UV[17] or whatever index has the remotes
    for idx, val in pairs(uvs3) do
        if type(val) == "table" then
            -- Check if this table contains RemoteEvents
            local remoteCount = 0
            local stringCount = 0
            local funcCount = 0
            pcall(function()
                for k, v in pairs(val) do
                    if typeof(v) == "Instance" and (v:IsA("RemoteEvent") or v:IsA("UnreliableRemoteEvent")) then
                        remoteCount = remoteCount + 1
                    elseif type(v) == "string" then
                        stringCount = stringCount + 1
                    elseif type(v) == "function" then
                        funcCount = funcCount + 1
                    end
                end
            end)

            if remoteCount > 0 then
                addLine("", DIM)
                addLine("  📡 UV[" .. idx .. "] has " .. remoteCount .. " remotes + " .. stringCount .. " strings + " .. funcCount .. " functions", GREEN)

                -- Dump everything in this table
                pcall(function()
                    for k, v in pairs(val) do
                        local kStr = tostring(k)
                        if typeof(v) == "Instance" then
                            addLine("    [" .. kStr .. "] = " .. v.ClassName .. ": " .. v.Name:sub(1, 40), CYAN)
                        elseif type(v) == "string" then
                            local isHex = v:match("^[a-fA-F0-9]+$") and #v >= 16
                            addLine("    [" .. kStr .. "] = \"" .. v:sub(1, 50) .. "\" (len=" .. #v .. ")", isHex and GREEN or DIM)
                        elseif type(v) == "function" then
                            addLine("    [" .. kStr .. "] = function", MAGENTA)
                        elseif type(v) == "table" then
                            -- One level deeper
                            addLine("    [" .. kStr .. "] = table {", YELLOW)
                            local sc = 0
                            for k2, v2 in pairs(v) do
                                sc = sc + 1; if sc > 15 then addLine("      ...more", DIM); break end
                                if typeof(v2) == "Instance" then
                                    addLine("      [" .. tostring(k2) .. "] = " .. v2.ClassName .. ": " .. v2.Name:sub(1, 30), CYAN)
                                elseif type(v2) == "string" then
                                    addLine("      [" .. tostring(k2) .. "] = \"" .. v2:sub(1, 40) .. "\"", DIM)
                                elseif type(v2) == "function" then
                                    addLine("      [" .. tostring(k2) .. "] = function", MAGENTA)
                                    -- Check if method name is interesting
                                    local info2 = nil
                                    pcall(function() info2 = _getinfo(v2) end)
                                    if info2 and info2.name then
                                        addLine("        name: " .. info2.name, DIM)
                                    end
                                elseif type(v2) == "table" then
                                    addLine("      [" .. tostring(k2) .. "] = table (" .. (function() local c2=0; pcall(function() for _ in pairs(v2) do c2=c2+1 end end); return c2 end)() .. " items)", DIM)
                                else
                                    addLine("      [" .. tostring(k2) .. "] = " .. tostring(v2), DIM)
                                end
                            end
                            addLine("    }", YELLOW)
                        else
                            addLine("    [" .. kStr .. "] = " .. tostring(v), DIM)
                        end
                    end
                end)
            end
        end
    end
end)

-- ===================== TEST BUTTONS FOR NET OBJECTS ===================== --

if #netObjects > 0 then
    section("TEST FIRE (Net objects)")
    addLine("  Press buttons when ball approaches you!", YELLOW)
    addLine("", DIM)

    for i, no in ipairs(netObjects) do
        for mName, mFn in pairs(no.methods) do
            local ml = mName:lower()
            if ml:find("fire") or ml:find("send") then
                -- Create test buttons for this method

                -- Test: obj:Method()
                lineOrder = lineOrder + 1
                local btn1 = Instance.new("TextButton")
                btn1.Size = UDim2.new(1, 0, 0, 28)
                btn1.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
                btn1.Text = "  ▶ Obj#" .. i .. ":" .. mName .. "()"
                btn1.TextColor3 = CYAN
                btn1.TextSize = 11
                btn1.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold)
                btn1.TextXAlignment = Enum.TextXAlignment.Left
                btn1.AutoButtonColor = true
                btn1.LayoutOrder = lineOrder
                btn1.BorderSizePixel = 0
                btn1.Parent = Scroll
                Instance.new("UICorner", btn1).CornerRadius = UDim.new(0, 5)
                local r1 = addLine("    ...", DIM)
                btn1.MouseButton1Click:Connect(function()
                    local ok, e = pcall(function() mFn(no.obj) end)
                    r1.Text = ok and "    ✅ Sent!" or ("    ❌ " .. tostring(e):sub(1, 50))
                    r1.TextColor3 = ok and GREEN or RED
                end)

                -- Test: obj:Method("Move")
                lineOrder = lineOrder + 1
                local btn2 = Instance.new("TextButton")
                btn2.Size = UDim2.new(1, 0, 0, 28)
                btn2.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
                btn2.Text = "  ▶ Obj#" .. i .. ":" .. mName .. "(\"Move\")"
                btn2.TextColor3 = GREEN
                btn2.TextSize = 11
                btn2.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold)
                btn2.TextXAlignment = Enum.TextXAlignment.Left
                btn2.AutoButtonColor = true
                btn2.LayoutOrder = lineOrder
                btn2.BorderSizePixel = 0
                btn2.Parent = Scroll
                Instance.new("UICorner", btn2).CornerRadius = UDim.new(0, 5)
                local r2 = addLine("    ...", DIM)
                btn2.MouseButton1Click:Connect(function()
                    local ok, e = pcall(function() mFn(no.obj, "Move") end)
                    r2.Text = ok and "    ✅ Sent!" or ("    ❌ " .. tostring(e):sub(1, 50))
                    r2.TextColor3 = ok and GREEN or RED
                end)

                addLine("", DIM)
            end
        end
    end
end

-- ===================== FIRESIGNAL ARGS CAPTURE ===================== --

section("FIRESIGNAL CAPTURE TEST")
addLine("  Fires 1 firesignal then checks what changed", YELLOW)
addLine("", DIM)

lineOrder = lineOrder + 1
local captureBtn = Instance.new("TextButton")
captureBtn.Size = UDim2.new(1, 0, 0, 34)
captureBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 10)
captureBtn.Text = "  🔍 Fire 1 firesignal + capture upvalue changes"
captureBtn.TextColor3 = YELLOW
captureBtn.TextSize = 12
captureBtn.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
captureBtn.TextXAlignment = Enum.TextXAlignment.Left
captureBtn.AutoButtonColor = true
captureBtn.LayoutOrder = lineOrder
captureBtn.BorderSizePixel = 0
captureBtn.Parent = Scroll
Instance.new("UICorner", captureBtn).CornerRadius = UDim.new(0, 6)

local captureResult = addLine("    Press to test", DIM)

captureBtn.MouseButton1Click:Connect(function()
    captureResult.Text = "    Capturing..."
    captureResult.TextColor3 = YELLOW

    -- Snapshot upvalues before
    local before = {}
    pcall(function()
        local uvs1 = getUVs(parryFn)
        for i, v in pairs(uvs1) do
            if type(v) == "string" or type(v) == "number" or type(v) == "boolean" then
                before["UV[" .. i .. "]"] = tostring(v)
            end
        end
    end)

    -- Fire signal
    local ok, err = pcall(function()
        firesignal(block.Activated)
    end)

    task.wait(0.1) -- Let it process

    -- Snapshot after
    local after = {}
    pcall(function()
        local uvs1 = getUVs(parryFn)
        for i, v in pairs(uvs1) do
            if type(v) == "string" or type(v) == "number" or type(v) == "boolean" then
                after["UV[" .. i .. "]"] = tostring(v)
            end
        end
    end)

    if not ok then
        captureResult.Text = "    ❌ firesignal error: " .. tostring(err)
        captureResult.TextColor3 = RED
        return
    end

    -- Compare
    local changes = {}
    for path, val in pairs(after) do
        if before[path] ~= val then
            table.insert(changes, {path = path, old = before[path] or "(new)", new = val})
        end
    end

    if #changes > 0 then
        captureResult.Text = "    ⚡ " .. #changes .. " upvalues changed!"
        captureResult.TextColor3 = GREEN
        for _, ch in ipairs(changes) do
            addLine("    " .. ch.path .. ": " .. ch.old .. " → " .. ch.new, YELLOW)
        end
    else
        captureResult.Text = "    No direct upvalue changes (changes are deeper)"
        captureResult.TextColor3 = DIM
    end
end)

-- ===================== DONE ===================== --

section("DONE")
addLine("  Scroll up to see Net objects and test buttons", GREEN)
addLine("  Test buttons during a round when ball approaches", DIM)
notify("Ready! " .. #netObjects .. " Net objects found")
