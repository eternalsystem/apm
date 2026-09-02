--[[
    Manual Spam Parry — Signal Mode
    RightShift = toggle UI
    Click [Hotkey] to rebind | Press hotkey to toggle spam
]]

repeat task.wait() until game:IsLoaded()

local Players           = game:GetService('Players')
local Player            = Players.LocalPlayer
local UserInputService  = game:GetService('UserInputService')
local RunService        = game:GetService('RunService')
local CoreGui           = game:GetService('CoreGui')
local TweenService      = game:GetService('TweenService')

local SpamEnabled    = false
local spamConns      = {}

local BindKey        = Enum.KeyCode.X
local BindType       = 'Key'
local bindListening  = false

local SpeedMode      = '3x'  -- default

-- ===================== PARRY ===================== --

local activatedSignal = nil

local function CacheBlock()
    local hotbar = Player.PlayerGui:FindFirstChild("Hotbar")
    if hotbar then
        local block = hotbar:FindFirstChild("Block")
        if block then
            activatedSignal = block.Activated
        end
    end
end

CacheBlock()

-- ===================== SPAM ===================== --

local function MakeBurst(n)
    -- return a function that fires exactly n times
    return function()
        local sig = activatedSignal
        if not sig then return end
        for i = 1, n do
            firesignal(sig)
        end
    end
end

local function StopSpam()
    SpamEnabled = false
    for i, c in pairs(spamConns) do
        c:Disconnect()
        spamConns[i] = nil
    end
end

local function StartSpam()
    StopSpam() -- clean any leftover connections first
    if not activatedSignal then CacheBlock() end
    if not activatedSignal then return end

    SpamEnabled = true

    if SpeedMode == '1x' then
        -- 1 connection, 1 fire per frame (~60/sec)
        local burst = MakeBurst(1)
        spamConns[1] = RunService.Heartbeat:Connect(burst)

    elseif SpeedMode == '3x' then
        -- 3 connections, 1 fire each (~180/sec)
        local burst = MakeBurst(1)
        spamConns[1] = RunService.PreSimulation:Connect(burst)
        spamConns[2] = RunService.Heartbeat:Connect(burst)
        spamConns[3] = RunService.RenderStepped:Connect(burst)

    elseif SpeedMode == '5x' then
        -- 3 connections, 5 fires each (~900/sec)
        local burst = MakeBurst(5)
        spamConns[1] = RunService.PreSimulation:Connect(burst)
        spamConns[2] = RunService.Heartbeat:Connect(burst)
        spamConns[3] = RunService.RenderStepped:Connect(burst)

    elseif SpeedMode == '10x' then
        -- 3 connections, 10 fires each (~1800/sec)
        local burst = MakeBurst(10)
        spamConns[1] = RunService.PreSimulation:Connect(burst)
        spamConns[2] = RunService.Heartbeat:Connect(burst)
        spamConns[3] = RunService.RenderStepped:Connect(burst)

    elseif SpeedMode == '20x' then
        -- 3 connections, 20 fires each (~3600/sec)
        local burst = MakeBurst(20)
        spamConns[1] = RunService.PreSimulation:Connect(burst)
        spamConns[2] = RunService.Heartbeat:Connect(burst)
        spamConns[3] = RunService.RenderStepped:Connect(burst)
    end
end

-- ===================== BIND HELPERS ===================== --

local function GetBindName()
    if BindType == 'Key' then
        return BindKey.Name
    else
        if BindKey == Enum.UserInputType.MouseButton1 then return 'Mouse1' end
        if BindKey == Enum.UserInputType.MouseButton2 then return 'Mouse2' end
        if BindKey == Enum.UserInputType.MouseButton3 then return 'Mouse3' end
        return tostring(BindKey)
    end
end

local function InputMatchesBind(input)
    if BindType == 'Key' then
        return input.KeyCode == BindKey
    else
        return input.UserInputType == BindKey
    end
end

-- ===================== UI ===================== --

local oldGui = CoreGui:FindFirstChild('MSP_UI')
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'MSP_UI'
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999

pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end
end)
pcall(function()
    if gethui then ScreenGui.Parent = gethui() return end
end)
if not ScreenGui.Parent then ScreenGui.Parent = CoreGui end

local Panel = Instance.new('Frame')
Panel.Name = 'Panel'
Panel.Size = UDim2.fromOffset(210, 130)
Panel.Position = UDim2.new(0.5, -105, 0.5, -65)
Panel.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
Panel.BackgroundTransparency = 0.05
Panel.BorderSizePixel = 0
Panel.Active = true
Panel.Draggable = true
Panel.Parent = ScreenGui

Instance.new('UICorner', Panel).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new('UIStroke', Panel)
stroke.Color = Color3.fromRGB(60, 60, 70)
stroke.Thickness = 1
stroke.Transparency = 0.4

-- title
local Title = Instance.new('TextLabel')
Title.Size = UDim2.new(1, 0, 0, 28)
Title.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
Title.BackgroundTransparency = 0.3
Title.Text = '  Spam Parry'
Title.TextColor3 = Color3.fromRGB(240, 240, 240)
Title.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Bold)
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.BorderSizePixel = 0
Title.Parent = Panel
Instance.new('UICorner', Title).CornerRadius = UDim.new(0, 10)

-- status
local StatusDot = Instance.new('TextLabel')
StatusDot.Size = UDim2.fromOffset(40, 14)
StatusDot.Position = UDim2.new(1, -45, 0, 7)
StatusDot.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
StatusDot.Text = 'OFF'
StatusDot.TextColor3 = Color3.fromRGB(180, 180, 180)
StatusDot.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Bold)
StatusDot.TextSize = 10
StatusDot.BorderSizePixel = 0
StatusDot.Parent = Panel
Instance.new('UICorner', StatusDot).CornerRadius = UDim.new(0, 6)

local function UpdateStatus()
    if SpamEnabled then
        StatusDot.Text = 'ON'
        TweenService:Create(StatusDot, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(0, 150, 0)}):Play()
    else
        StatusDot.Text = 'OFF'
        TweenService:Create(StatusDot, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(40, 40, 46)}):Play()
    end
end

-- helper: make a row
local function MakeRow(yPos, label)
    local row = Instance.new('Frame')
    row.Size = UDim2.new(1, -20, 0, 26)
    row.Position = UDim2.new(0, 10, 0, yPos)
    row.BackgroundTransparency = 1
    row.Parent = Panel

    local lbl = Instance.new('TextLabel')
    lbl.Size = UDim2.new(0.4, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(200, 200, 205)
    lbl.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Regular)
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new('TextButton')
    btn.Size = UDim2.fromOffset(100, 20)
    btn.Position = UDim2.new(1, -100, 0.5, -10)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
    btn.TextColor3 = Color3.fromRGB(200, 200, 205)
    btn.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Regular)
    btn.TextSize = 11
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    btn.Parent = row
    Instance.new('UICorner', btn).CornerRadius = UDim.new(0, 6)

    return btn
end

-- Hotkey bind
local bindBtn = MakeRow(33, 'Hotkey')
bindBtn.Text = '[X]'

bindBtn.MouseButton1Click:Connect(function()
    bindListening = true
    bindBtn.Text = '[ ... ]'
    TweenService:Create(bindBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(120, 0, 0)}):Play()
end)

-- Speed mode selector
local speedBtn = MakeRow(62, 'Speed')
local speedModes = {'1x', '3x', '5x', '10x', '20x'}
local speedIdx = 2  -- default 3x
speedBtn.Text = SpeedMode .. '  ▼'

speedBtn.MouseButton1Click:Connect(function()
    speedIdx = (speedIdx % #speedModes) + 1
    SpeedMode = speedModes[speedIdx]
    speedBtn.Text = SpeedMode .. '  ▼'
    -- restart if running
    if SpamEnabled then
        StartSpam()
        UpdateStatus()
    end
end)

-- hint
local hint = Instance.new('TextLabel')
hint.Size = UDim2.new(1, -10, 0, 28)
hint.Position = UDim2.new(0, 5, 1, -28)
hint.BackgroundTransparency = 1
hint.Text = 'Click [Hotkey] to rebind | RightShift hides UI'
hint.TextColor3 = Color3.fromRGB(80, 80, 88)
hint.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Regular)
hint.TextSize = 9
hint.TextWrapped = true
hint.Parent = Panel

-- ===================== INPUT ===================== --

local function FinishBind(type, value)
    BindType = type
    BindKey = value
    bindListening = false
    bindBtn.Text = '[' .. GetBindName() .. ']'
    TweenService:Create(bindBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(30, 30, 36)}):Play()
end

UserInputService.InputBegan:Connect(function(input, processed)
    if bindListening then
        local kc = input.KeyCode
        local uit = input.UserInputType

        if uit == Enum.UserInputType.MouseMovement then return end
        if uit == Enum.UserInputType.Focus then return end
        if kc == Enum.KeyCode.RightShift then return end

        if kc and kc ~= Enum.KeyCode.Unknown then
            FinishBind('Key', kc)
            return
        end

        if uit == Enum.UserInputType.MouseButton1
            or uit == Enum.UserInputType.MouseButton2
            or uit == Enum.UserInputType.MouseButton3 then
            FinishBind('Mouse', uit)
            return
        end

        if uit and uit ~= Enum.UserInputType.None
            and uit ~= Enum.UserInputType.Keyboard
            and uit ~= Enum.UserInputType.Touch then
            FinishBind('Mouse', uit)
            return
        end
        return
    end

    if input.KeyCode == Enum.KeyCode.RightShift then
        Panel.Visible = not Panel.Visible
        return
    end

    if processed then return end

    if InputMatchesBind(input) then
        if SpamEnabled then StopSpam() else StartSpam() end
        UpdateStatus()
    end
end)

ScreenGui.Destroying:Connect(function()
    StopSpam()
end)
