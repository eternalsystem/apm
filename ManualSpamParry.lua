--[[
    Manual Spam Parry — Stripped from Allusive & UwU AP
    Features: Manual Spam Parry, Keypress/Remote mode toggle, Animation Fix
    Toggle UI with RightShift
]]

repeat task.wait() until game:IsLoaded()

-- ===================== SERVICES ===================== --

local Players            = game:GetService('Players')
local Player             = Players.LocalPlayer
local ReplicatedStorage  = game:GetService('ReplicatedStorage')
local UserInputService   = game:GetService('UserInputService')
local RunService         = game:GetService('RunService')
local Debris             = game:GetService('Debris')
local GuiService         = game:GetService('GuiService')
local CoreGui            = game:GetService('CoreGui')
local TweenService       = game:GetService('TweenService')
local VirtualInputManager = game:GetService("VirtualInputManager")

-- ===================== STATE ===================== --

local Remotes            = {}
local PrivateKey         = nil
local HashOne, HashTwo, HashThree
local Parry_Key          = nil
local Parries            = 0
local firstParryFired    = false
local firstParryType     = 'F_Key'
local isMobile           = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local Last_Input         = UserInputService:GetLastInputType()

local SpamEnabled        = false
local KeypressMode       = false
local AnimFixEnabled     = false
local Selected_Parry_Type = 'Camera'

local Connections        = {}

-- ===================== LPH STUBS ===================== --

if not LPH_OBFUSCATED then
    function LPH_JIT(f) return f end
    function LPH_JIT_MAX(f) return f end
    function LPH_NO_VIRTUALIZE(f) return f end
end

-- ===================== REMOTE EXTRACTION ===================== --

local PropertyChangeOrder = {}

-- GC scan: find the parry handler by its signature
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
                break
            end
        end
    end
end)()

-- Find the three obfuscated remotes by watching property changes
LPH_NO_VIRTUALIZE(function()
    for _, Object in next, game:GetDescendants() do
        if Object:IsA("RemoteEvent") and string.find(Object.Name, "\n") then
            Object.Changed:Once(function()
                table.insert(PropertyChangeOrder, Object)
            end)
        end
    end
end)()

repeat task.wait() until #PropertyChangeOrder == 3

local ShouldPlayerJump    = PropertyChangeOrder[1]
local MainRemote          = PropertyChangeOrder[2]
local GetOpponentPosition = PropertyChangeOrder[3]

-- Hook __namecall to steal PrivateKey from the game's own remote calls
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

-- Secondary Parry_Key extraction from the Block button
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

-- ===================== CORE PARRY FUNCTIONS ===================== --

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
    ShouldPlayerJump:FireServer(HashOne, PrivateKey, ...)
    MainRemote:FireServer(HashTwo, PrivateKey, ...)
    GetOpponentPosition:FireServer(HashThree, PrivateKey, ...)
end

local Closest_Entity = nil

local function FindClosestPlayer()
    local Max_Distance = math.huge
    local Found = nil
    for _, Entity in pairs(workspace.Alive:GetChildren()) do
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
    for _, v in pairs(workspace.Alive:GetChildren()) do
        if v ~= Player.Character and v.PrimaryPart then
            local screenPos = Camera:WorldToScreenPoint(v.PrimaryPart.Position)
            Events[tostring(v)] = screenPos
        end
    end

    if Parry_Type == 'Camera' then
        return {0, Camera.CFrame, Events, MouseLoc}
    end

    if Parry_Type == 'Random' then
        return {0, CFrame.new(Camera.CFrame.Position, Vector3.new(
            math.random(-4000, 4000),
            math.random(-4000, 4000),
            math.random(-4000, 4000)
        )), Events, MouseLoc}
    end

    if Parry_Type == 'Backwards' then
        local dir = Camera.CFrame.LookVector * -10000
        dir = Vector3.new(dir.X, 0, dir.Z)
        return {0, CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + dir), Events, MouseLoc}
    end

    if Parry_Type == 'Straight' then
        local Aimed, ClosestDist = nil, math.huge
        local MV = Vector2.new(MouseLoc[1], MouseLoc[2])
        for _, v in pairs(workspace.Alive:GetChildren()) do
            if v ~= Player.Character and v.PrimaryPart then
                local sp, onScreen = Camera:WorldToScreenPoint(v.PrimaryPart.Position)
                if onScreen then
                    local d = (MV - Vector2.new(sp.X, sp.Y)).Magnitude
                    if d < ClosestDist then ClosestDist = d; Aimed = v end
                end
            end
        end
        local target = Aimed or Closest_Entity
        if target and target.PrimaryPart then
            return {0, CFrame.new(Player.Character.PrimaryPart.Position, target.PrimaryPart.Position), Events, MouseLoc}
        end
        return {0, Camera.CFrame, Events, MouseLoc}
    end

    if Parry_Type == 'High' then
        local dir = Camera.CFrame.UpVector * 10000
        return {0, CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + dir), Events, MouseLoc}
    end

    if Parry_Type == 'Left' then
        local dir = Camera.CFrame.RightVector * 10000
        return {0, CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position - dir), Events, MouseLoc}
    end

    if Parry_Type == 'Right' then
        local dir = Camera.CFrame.RightVector * 10000
        return {0, CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + dir), Events, MouseLoc}
    end

    if Parry_Type == 'RandomTarget' then
        local candidates = {}
        for _, v in pairs(workspace.Alive:GetChildren()) do
            if v ~= Player.Character and v.PrimaryPart then
                local sp, onScreen = Camera:WorldToScreenPoint(v.PrimaryPart.Position)
                if onScreen then
                    table.insert(candidates, { character = v, screenXY = {sp.X, sp.Y} })
                end
            end
        end
        if #candidates > 0 then
            local pick = candidates[math.random(1, #candidates)]
            return {0, CFrame.new(Player.Character.PrimaryPart.Position, pick.character.PrimaryPart.Position), Events, pick.screenXY}
        end
        return {0, Camera.CFrame, Events, {Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2}}
    end

    -- fallback: Camera
    return {0, Camera.CFrame, Events, MouseLoc}
end

local function DoParry(Parry_Type)
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
    -- main spam connection
    Connections['ManualSpam'] = RunService.PreSimulation:Connect(function()
        if KeypressMode then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
        else
            DoParry(Selected_Parry_Type)
        end
    end)

    -- animation fix: parallel keypress so parry animation plays visually
    if AnimFixEnabled then
        Connections['AnimFix'] = RunService.PreSimulation:Connect(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
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

local function UpdateAnimFix()
    -- if spam is running, restart the anim fix connection to match current state
    if Connections['AnimFix'] then
        Connections['AnimFix']:Disconnect()
        Connections['AnimFix'] = nil
    end
    if SpamEnabled and AnimFixEnabled then
        Connections['AnimFix'] = RunService.PreSimulation:Connect(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
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

-- helper: create a toggle row
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

    local btnCorner = Instance.new('UICorner')
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn

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

-- helper: create a dropdown row
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

    local btnCorner = Instance.new('UICorner')
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        currentIndex = (currentIndex % #options) + 1
        local val = options[currentIndex]
        btn.Text = val .. '  ▼'
        onChange(val)
    end)
end

-- Spam toggle
local spamToggle = MakeToggle(Panel, 42, 'Spam Parry', false, function(v)
    SpamEnabled = v
    if v then
        StartSpam()
    else
        StopSpam()
    end
end)

-- Mode: Keypress vs Remote
MakeDropdown(Panel, 76, 'Mode', {'Remote', 'Keypress'}, 'Remote', function(v)
    KeypressMode = (v == 'Keypress')
    -- restart spam if running so mode change takes effect
    if SpamEnabled then
        StopSpam()
        StartSpam()
    end
end)

-- Parry direction type
MakeDropdown(Panel, 110, 'Direction', {
    'Camera', 'Random', 'Backwards', 'Straight',
    'High', 'Left', 'Right', 'RandomTarget'
}, 'Camera', function(v)
    Selected_Parry_Type = v
end)

-- First parry type
MakeDropdown(Panel, 144, 'First Parry', {'F_Key', 'Left_Click', 'Navigation'}, 'F_Key', function(v)
    firstParryType = v
end)

-- Animation Fix toggle
MakeToggle(Panel, 178, 'Animation Fix', false, function(v)
    AnimFixEnabled = v
    UpdateAnimFix()
end)

-- status line
local Status = Instance.new('TextLabel')
Status.Size = UDim2.new(1, 0, 0, 20)
Status.Position = UDim2.new(0, 0, 1, -22)
Status.BackgroundTransparency = 1
Status.Text = 'RightShift to toggle UI'
Status.TextColor3 = Color3.fromRGB(100, 100, 108)
Status.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Regular)
Status.TextSize = 10
Status.Parent = Panel

-- toggle UI visibility with RightShift
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
