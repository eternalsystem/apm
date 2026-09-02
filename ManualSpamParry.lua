--[[
    Manual Spam Parry — Stripped from Allusive & UwU AP
    Features: Manual Spam Parry, Keypress mode (default), Animation Fix
    Remote mode loads in background if remotes are found
    Toggle UI with RightShift
]]

repeat task.wait() until game:IsLoaded()

-- ===================== SERVICES ===================== --

local Players            = game:GetService('Players')
local Player             = Players.LocalPlayer
local UserInputService   = game:GetService('UserInputService')
local RunService         = game:GetService('RunService')
local GuiService         = game:GetService('GuiService')
local CoreGui            = game:GetService('CoreGui')
local TweenService       = game:GetService('TweenService')
local VirtualInputManager = game:GetService("VirtualInputManager")

-- ===================== STATE ===================== --

local SpamEnabled        = false
local KeypressMode       = true  -- default to Keypress (always works)
local AnimFixEnabled     = false
local RemoteReady        = false -- set to true when remote extraction succeeds

local Connections        = {}

-- ===================== KEYPRESS SPAM (always works) ===================== --

local function SpamKeypress()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
end

-- ===================== REMOTE EXTRACTION (background, optional) ===================== --

local Remotes            = {}
local PrivateKey         = nil
local HashOne, HashTwo, HashThree
local ShouldPlayerJump, MainRemote, GetOpponentPosition
local Parries            = 0
local firstParryFired    = false
local firstParryType     = 'F_Key'
local Selected_Parry_Type = 'Camera'
local Closest_Entity     = nil

local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local Last_Input = UserInputService:GetLastInputType()

-- LPH stubs
if not LPH_OBFUSCATED then
    function LPH_JIT(f) return f end
    function LPH_JIT_MAX(f) return f end
    function LPH_NO_VIRTUALIZE(f) return f end
end

local function updateNavigation(guiObject)
    GuiService.SelectedObject = guiObject
end

local function performFirstPress(parryType)
    if parryType == 'F_Key' then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, nil)
    elseif parryType == 'Left_Click' then
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    elseif parryType == 'Navigation' then
        local button = Player.PlayerGui.Hotbar.Block
        updateNavigation(button)
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        task.wait(0.01)
        updateNavigation(nil)
    end
end

local function FireParry(...)
    if not RemoteReady then return end
    ShouldPlayerJump:FireServer(HashOne, PrivateKey, ...)
    MainRemote:FireServer(HashTwo, PrivateKey, ...)
    GetOpponentPosition:FireServer(HashThree, PrivateKey, ...)
end

local function FindClosestPlayer()
    local Max_Distance = math.huge
    local Found = nil
    local ok, alive = pcall(function() return workspace.Alive:GetChildren() end)
    if not ok then return nil end
    for _, Entity in pairs(alive) do
        if tostring(Entity) ~= tostring(Player) then
            if Entity.PrimaryPart then
                local d = Player:DistanceFromCharacter(Entity.PrimaryPart.Position)
                if d < Max_Distance then
                    Max_Distance = d
                    Found = Entity
                end
            end
        end
    end
    Closest_Entity = Found
    return Found
end

local function BuildParryData(Parry_Type)
    FindClosestPlayer()
    local Camera = workspace.CurrentCamera
    local MouseLoc

    if Last_Input == Enum.UserInputType.MouseButton1
       or Last_Input == Enum.UserInputType.MouseButton2
       or Last_Input == Enum.UserInputType.Keyboard then
        local ml = UserInputService:GetMouseLocation()
        MouseLoc = {ml.X, ml.Y}
    else
        MouseLoc = {Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2}
    end
    if isMobile then
        MouseLoc = {Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2}
    end

    local Events = {}
    pcall(function()
        for _, v in pairs(workspace.Alive:GetChildren()) do
            if v ~= Player.Character and v.PrimaryPart then
                Events[tostring(v)] = Camera:WorldToScreenPoint(v.PrimaryPart.Position)
            end
        end
    end)

    if Parry_Type == 'Camera' then
        return {0, Camera.CFrame, Events, MouseLoc}
    elseif Parry_Type == 'Random' then
        return {0, CFrame.new(Camera.CFrame.Position, Vector3.new(
            math.random(-4000, 4000), math.random(-4000, 4000), math.random(-4000, 4000)
        )), Events, MouseLoc}
    elseif Parry_Type == 'Backwards' then
        local dir = Camera.CFrame.LookVector * -10000
        return {0, CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + Vector3.new(dir.X, 0, dir.Z)), Events, MouseLoc}
    elseif Parry_Type == 'Straight' then
        local Aimed, ClosestDist = nil, math.huge
        local MV = Vector2.new(MouseLoc[1], MouseLoc[2])
        pcall(function()
            for _, v in pairs(workspace.Alive:GetChildren()) do
                if v ~= Player.Character and v.PrimaryPart then
                    local sp, onScreen = Camera:WorldToScreenPoint(v.PrimaryPart.Position)
                    if onScreen then
                        local d = (MV - Vector2.new(sp.X, sp.Y)).Magnitude
                        if d < ClosestDist then ClosestDist = d; Aimed = v end
                    end
                end
            end
        end)
        local target = Aimed or Closest_Entity
        if target and target.PrimaryPart and Player.Character and Player.Character.PrimaryPart then
            return {0, CFrame.new(Player.Character.PrimaryPart.Position, target.PrimaryPart.Position), Events, MouseLoc}
        end
        return {0, Camera.CFrame, Events, MouseLoc}
    elseif Parry_Type == 'High' then
        return {0, CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + Camera.CFrame.UpVector * 10000), Events, MouseLoc}
    elseif Parry_Type == 'Left' then
        return {0, CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position - Camera.CFrame.RightVector * 10000), Events, MouseLoc}
    elseif Parry_Type == 'Right' then
        return {0, CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + Camera.CFrame.RightVector * 10000), Events, MouseLoc}
    elseif Parry_Type == 'RandomTarget' then
        local candidates = {}
        pcall(function()
            for _, v in pairs(workspace.Alive:GetChildren()) do
                if v ~= Player.Character and v.PrimaryPart then
                    local sp, onScreen = Camera:WorldToScreenPoint(v.PrimaryPart.Position)
                    if onScreen then
                        table.insert(candidates, { character = v, screenXY = {sp.X, sp.Y} })
                    end
                end
            end
        end)
        if #candidates > 0 then
            local pick = candidates[math.random(1, #candidates)]
            return {0, CFrame.new(Player.Character.PrimaryPart.Position, pick.character.PrimaryPart.Position), Events, pick.screenXY}
        end
        return {0, Camera.CFrame, Events, {Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2}}
    end
    return {0, Camera.CFrame, Events, MouseLoc}
end

local function DoRemoteParry(Parry_Type)
    if not RemoteReady then
        -- fallback to keypress if remotes aren't ready
        SpamKeypress()
        return
    end

    local data = BuildParryData(Parry_Type)
    if not firstParryFired then
        performFirstPress(firstParryType)
        firstParryFired = true
    else
        FireParry(data[1], data[2], data[3], data[4])
    end

    if Parries > 7 then return end
    Parries += 1
    task.delay(0.5, function()
        if Parries > 0 then Parries -= 1 end
    end)
end

-- ===================== SPAM LOGIC ===================== --

local function StartSpam()
    Connections['ManualSpam'] = RunService.PreSimulation:Connect(function()
        if KeypressMode then
            SpamKeypress()
        else
            DoRemoteParry(Selected_Parry_Type)
        end
    end)

    if AnimFixEnabled and not KeypressMode then
        Connections['AnimFix'] = RunService.PreSimulation:Connect(function()
            SpamKeypress()
        end)
    end
end

local function StopSpam()
    if Connections['ManualSpam'] then
        Connections['ManualSpam']:Disconnect()
        Connections['ManualSpam'] = nil
    end
    if Connections['AnimFix'] then
        Connections['AnimFix']:Disconnect()
        Connections['AnimFix'] = nil
    end
end

local function RestartSpamIfRunning()
    if SpamEnabled then
        StopSpam()
        StartSpam()
    end
end

local function UpdateAnimFix()
    if Connections['AnimFix'] then
        Connections['AnimFix']:Disconnect()
        Connections['AnimFix'] = nil
    end
    if SpamEnabled and AnimFixEnabled and not KeypressMode then
        Connections['AnimFix'] = RunService.PreSimulation:Connect(function()
            SpamKeypress()
        end)
    end
end

-- ===================== UI ===================== --

-- clean up previous instance
local oldGui = CoreGui:FindFirstChild('ManualSpamParryUI')
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'ManualSpamParryUI'
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = CoreGui

-- main panel
local Panel = Instance.new('Frame')
Panel.Name = 'Panel'
Panel.Size = UDim2.fromOffset(260, 240)
Panel.Position = UDim2.new(0.5, -130, 0.5, -120)
Panel.AnchorPoint = Vector2.new(0, 0)
Panel.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
Panel.BackgroundTransparency = 0.05
Panel.BorderSizePixel = 0
Panel.Active = true
Panel.Draggable = true
Panel.Parent = ScreenGui

local panelCorner = Instance.new('UICorner')
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = Panel

local panelStroke = Instance.new('UIStroke')
panelStroke.Color = Color3.fromRGB(60, 60, 70)
panelStroke.Thickness = 1
panelStroke.Transparency = 0.4
panelStroke.Parent = Panel

-- title
local Title = Instance.new('TextLabel')
Title.Size = UDim2.new(1, 0, 0, 32)
Title.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
Title.BackgroundTransparency = 0.3
Title.Text = '  Manual Spam Parry'
Title.TextColor3 = Color3.fromRGB(240, 240, 240)
Title.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Bold)
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.BorderSizePixel = 0
Title.Parent = Panel

local titleCorner = Instance.new('UICorner')
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = Title

-- helper: toggle row
local function MakeToggle(parent, yPos, label, default, onChange)
    local row = Instance.new('Frame')
    row.Size = UDim2.new(1, -20, 0, 28)
    row.Position = UDim2.new(0, 10, 0, yPos)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new('TextLabel')
    lbl.Size = UDim2.new(0.7, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(200, 200, 205)
    lbl.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Regular)
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new('TextButton')
    btn.Size = UDim2.fromOffset(44, 22)
    btn.Position = UDim2.new(1, -44, 0.5, -11)
    btn.BackgroundColor3 = default and Color3.fromRGB(120, 0, 0) or Color3.fromRGB(40, 40, 46)
    btn.Text = default and 'ON' or 'OFF'
    btn.TextColor3 = Color3.fromRGB(240, 240, 240)
    btn.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Bold)
    btn.TextSize = 11
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    btn.Parent = row

    Instance.new('UICorner', btn).CornerRadius = UDim.new(0, 6)

    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = state and 'ON' or 'OFF'
        TweenService:Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = state and Color3.fromRGB(120, 0, 0) or Color3.fromRGB(40, 40, 46)
        }):Play()
        onChange(state)
    end)

    return {
        SetState = function(v)
            state = v
            btn.Text = state and 'ON' or 'OFF'
            btn.BackgroundColor3 = state and Color3.fromRGB(120, 0, 0) or Color3.fromRGB(40, 40, 46)
        end,
        GetState = function() return state end
    }
end

-- helper: dropdown row
local function MakeDropdown(parent, yPos, label, options, default, onChange)
    local row = Instance.new('Frame')
    row.Size = UDim2.new(1, -20, 0, 28)
    row.Position = UDim2.new(0, 10, 0, yPos)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new('TextLabel')
    lbl.Size = UDim2.new(0.5, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(200, 200, 205)
    lbl.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Regular)
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local currentIndex = table.find(options, default) or 1
    local btn = Instance.new('TextButton')
    btn.Size = UDim2.fromOffset(110, 22)
    btn.Position = UDim2.new(1, -110, 0.5, -11)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
    btn.Text = options[currentIndex] .. '  ▼'
    btn.TextColor3 = Color3.fromRGB(200, 200, 205)
    btn.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Regular)
    btn.TextSize = 11
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    btn.Parent = row

    Instance.new('UICorner', btn).CornerRadius = UDim.new(0, 6)

    btn.MouseButton1Click:Connect(function()
        currentIndex = (currentIndex % #options) + 1
        local val = options[currentIndex]
        btn.Text = val .. '  ▼'
        onChange(val)
    end)

    return btn
end

-- status label (shows remote status)
local StatusLabel = Instance.new('TextLabel')
StatusLabel.Size = UDim2.new(1, 0, 0, 20)
StatusLabel.Position = UDim2.new(0, 0, 1, -22)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = 'Keypress mode ready | RightShift to hide'
StatusLabel.TextColor3 = Color3.fromRGB(100, 100, 108)
StatusLabel.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Regular)
StatusLabel.TextSize = 10
StatusLabel.Parent = Panel

-- Spam toggle
MakeToggle(Panel, 42, 'Spam Parry', false, function(v)
    SpamEnabled = v
    if v then StartSpam() else StopSpam() end
end)

-- Mode dropdown
local modeBtn = MakeDropdown(Panel, 76, 'Mode', {'Keypress', 'Remote'}, 'Keypress', function(v)
    KeypressMode = (v == 'Keypress')
    if not KeypressMode and not RemoteReady then
        StatusLabel.Text = '⚠ Remote not available — using keypress'
        StatusLabel.TextColor3 = Color3.fromRGB(200, 150, 50)
    else
        StatusLabel.Text = v .. ' mode | RightShift to hide'
        StatusLabel.TextColor3 = Color3.fromRGB(100, 100, 108)
    end
    RestartSpamIfRunning()
end)

-- Direction dropdown (only matters for Remote mode)
MakeDropdown(Panel, 110, 'Direction', {
    'Camera', 'Random', 'Backwards', 'Straight',
    'High', 'Left', 'Right', 'RandomTarget'
}, 'Camera', function(v)
    Selected_Parry_Type = v
end)

-- First parry type dropdown
MakeDropdown(Panel, 144, 'First Parry', {'F_Key', 'Left_Click', 'Navigation'}, 'F_Key', function(v)
    firstParryType = v
end)

-- Animation Fix toggle
MakeToggle(Panel, 178, 'Animation Fix', false, function(v)
    AnimFixEnabled = v
    UpdateAnimFix()
end)

-- toggle UI visibility
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        Panel.Visible = not Panel.Visible
    end
end)

-- cleanup on re-execute
ScreenGui.Destroying:Connect(function()
    StopSpam()
end)

warn("[MSP] UI loaded — Keypress mode ready!")

-- ===================== BACKGROUND REMOTE EXTRACTION ===================== --
-- Runs in a separate thread so the UI is already usable
-- If it succeeds, Remote mode becomes available

task.spawn(function()
    warn("[MSP] Attempting remote extraction in background...")

    -- Step 1: GC scan
    local gcFound = false
    local Parry_Key = nil

    LPH_NO_VIRTUALIZE(function()
        for _, Value in pairs(getgc(true)) do
            if type(Value) == "function" and islclosure(Value) then
                local Protos    = debug.getprotos(Value)
                local Upvalues  = debug.getupvalues(Value)
                local Constants = debug.getconstants(Value)
                if Protos and Upvalues and Constants
                   and (#Protos == 4) and (#Upvalues == 24) and (#Constants == 104) then
                    Remotes[debug.getupvalue(Value, 16)] = debug.getconstant(Value, 62)
                    Parry_Key = debug.getupvalue(Value, 17)
                    Remotes[debug.getupvalue(Value, 18)] = debug.getconstant(Value, 64)
                    Remotes[debug.getupvalue(Value, 19)] = debug.getconstant(Value, 65)
                    gcFound = true
                    break
                end
            end
        end
    end)()

    if not gcFound then
        warn("[MSP] Remote extraction failed — GC signature outdated. Keypress mode only.")
        StatusLabel.Text = 'Keypress only (remotes outdated)'
        StatusLabel.TextColor3 = Color3.fromRGB(200, 150, 50)
        return
    end

    -- Step 2: obfuscated remote detection
    local PropertyChangeOrder = {}
    local remoteCount = 0

    LPH_NO_VIRTUALIZE(function()
        for _, Object in next, game:GetDescendants() do
            if Object:IsA("RemoteEvent") and string.find(Object.Name, "\n") then
                remoteCount += 1
                Object.Changed:Once(function()
                    table.insert(PropertyChangeOrder, Object)
                end)
            end
        end
    end)()

    if remoteCount == 0 then
        warn("[MSP] No obfuscated remotes found. Keypress mode only.")
        StatusLabel.Text = 'Keypress only (no remotes found)'
        StatusLabel.TextColor3 = Color3.fromRGB(200, 150, 50)
        return
    end

    local waitStart = tick()
    repeat task.wait() until #PropertyChangeOrder == 3 or (tick() - waitStart > 15)

    if #PropertyChangeOrder < 3 then
        warn("[MSP] Remote timeout (" .. #PropertyChangeOrder .. "/3). Keypress mode only.")
        StatusLabel.Text = 'Keypress only (remote timeout)'
        StatusLabel.TextColor3 = Color3.fromRGB(200, 150, 50)
        return
    end

    ShouldPlayerJump    = PropertyChangeOrder[1]
    MainRemote          = PropertyChangeOrder[2]
    GetOpponentPosition = PropertyChangeOrder[3]

    -- Step 3: __namecall hook
    local __namecall
    __namecall = hookmetamethod(game, "__namecall", function(self, ...)
        local Args   = {...}
        local Method = getnamecallmethod()
        if not checkcaller() and (Method == "FireServer") and string.find(self.Name, "\n") then
            if Args[2] then
                PrivateKey = Args[2]
            end
        end
        return __namecall(self, ...)
    end)

    -- Step 4: Parry_Key
    pcall(function()
        for _, Value in pairs(getconnections(Player.PlayerGui.Hotbar.Block.Activated)) do
            if Value and Value.Function and not iscclosure(Value.Function) then
                for _, Value2 in pairs(getupvalues(Value.Function)) do
                    if type(Value2) == "function" then
                        Parry_Key = getupvalue(getupvalue(Value2, 2), 17)
                        break
                    end
                end
            end
        end
    end)

    RemoteReady = true
    warn("[MSP] Remote extraction SUCCESS — both modes available!")
    StatusLabel.Text = 'Both modes ready | RightShift to hide'
    StatusLabel.TextColor3 = Color3.fromRGB(80, 180, 80)
end)
