--[[
    Manual Spam Parry
    Methods: DirectCall (fastest) / Signal (fallback)
    No hookmetamethod, no VIM, no __namecall hook
    RightShift = toggle UI
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

local SpamDelay      = 0
local MethodName     = 'DirectCall'

-- ===================== PARRY SETUP ===================== --

local activatedSignal = nil
local handlerFn       = nil  -- the actual parry function from getconnections

local function Setup()
    local hotbar = Player.PlayerGui:FindFirstChild("Hotbar")
    if not hotbar then return end
    local block = hotbar:FindFirstChild("Block")
    if not block then return end

    activatedSignal = block.Activated

    -- extract the connected handler function directly
    if getconnections then
        for _, conn in pairs(getconnections(block.Activated)) do
            if conn and conn.Function and not iscclosure(conn.Function) then
                handlerFn = conn.Function
                break
            end
        end
    end
end

Setup()

-- ===================== PARRY METHODS ===================== --

-- Method 1: Call the handler function directly (skips signal dispatch)
local function ParryDirectCall()
    if handlerFn then
        handlerFn()
    elseif activatedSignal then
        firesignal(activatedSignal)
    end
end

-- Method 2: firesignal on Block.Activated
local function ParrySignal()
    if activatedSignal then
        firesignal(activatedSignal)
    end
end

local function GetParryFn()
    if MethodName == 'DirectCall' then return ParryDirectCall end
    return ParrySignal
end

-- ===================== SPAM ===================== --

local function StopSpam()
    SpamEnabled = false
    for i, c in pairs(spamConns) do
        c:Disconnect()
        spamConns[i] = nil
    end
end

local function StartSpam()
    StopSpam()
    SpamEnabled = true

    local parryFn = GetParryFn()

    if SpamDelay <= 0 then
        spamConns[1] = RunService.PreSimulation:Connect(function() pcall(parryFn) end)
        spamConns[2] = RunService.Heartbeat:Connect(function() pcall(parryFn) end)
        spamConns[3] = RunService.RenderStepped:Connect(function() pcall(parryFn) end)
    else
        local lastFire = 0
        spamConns[1] = RunService.Heartbeat:Connect(function()
            local now = tick()
            if now - lastFire >= SpamDelay then
                lastFire = now
                pcall(parryFn)
            end
        end)
    end
end

-- ===================== BIND ===================== --

local function GetBindName()
    if BindType == 'Key' then return BindKey.Name end
    if BindKey == Enum.UserInputType.MouseButton1 then return 'Mouse1' end
    if BindKey == Enum.UserInputType.MouseButton2 then return 'Mouse2' end
    if BindKey == Enum.UserInputType.MouseButton3 then return 'Mouse3' end
    return tostring(BindKey)
end

local function InputMatchesBind(input)
    if BindType == 'Key' then return input.KeyCode == BindKey end
    return input.UserInputType == BindKey
end

-- ===================== UI ===================== --

local oldGui = CoreGui:FindFirstChild('MSP_UI')
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'MSP_UI'
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999

pcall(function() if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end end)
pcall(function() if gethui then ScreenGui.Parent = gethui() return end end)
if not ScreenGui.Parent then ScreenGui.Parent = CoreGui end

local Panel = Instance.new('Frame')
Panel.Name = 'Panel'
Panel.Size = UDim2.fromOffset(230, 175)
Panel.Position = UDim2.new(0.5, -115, 0.5, -87)
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

-- info label
local infoLabel = Instance.new('TextLabel')
infoLabel.Size = UDim2.new(1, -20, 0, 18)
infoLabel.Position = UDim2.new(0, 10, 0, 30)
infoLabel.BackgroundTransparency = 1
infoLabel.TextSize = 9
infoLabel.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Regular)
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.Parent = Panel

if handlerFn then
    infoLabel.Text = '✓ Handler function captured'
    infoLabel.TextColor3 = Color3.fromRGB(80, 200, 80)
else
    infoLabel.Text = '⚠ Handler not found, using Signal'
    infoLabel.TextColor3 = Color3.fromRGB(220, 180, 50)
    MethodName = 'Signal'
end

-- helper
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
    btn.Size = UDim2.fromOffset(115, 20)
    btn.Position = UDim2.new(1, -115, 0.5, -10)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
    btn.TextColor3 = Color3.fromRGB(200, 200, 205)
    btn.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Regular)
    btn.TextSize = 10
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    btn.Parent = row
    Instance.new('UICorner', btn).CornerRadius = UDim.new(0, 6)

    return btn
end

-- Method selector
local methodBtn = MakeRow(52, 'Method')
local methods = {'DirectCall', 'Signal'}
local methodIdx = (MethodName == 'DirectCall') and 1 or 2
methodBtn.Text = MethodName .. '  ▼'

methodBtn.MouseButton1Click:Connect(function()
    methodIdx = (methodIdx % #methods) + 1
    MethodName = methods[methodIdx]
    methodBtn.Text = MethodName .. '  ▼'
    if SpamEnabled then StartSpam() UpdateStatus() end
end)

-- Delay selector
local delayBtn = MakeRow(81, 'Delay')
local delays = {
    {name = 'Max (0ms)',  val = 0},
    {name = '10ms',       val = 0.01},
    {name = '20ms',       val = 0.02},
    {name = '50ms',       val = 0.05},
    {name = '100ms',      val = 0.1},
    {name = '200ms',      val = 0.2},
    {name = '500ms',      val = 0.5},
}
local delayIdx = 1
delayBtn.Text = delays[delayIdx].name .. '  ▼'

delayBtn.MouseButton1Click:Connect(function()
    delayIdx = (delayIdx % #delays) + 1
    SpamDelay = delays[delayIdx].val
    delayBtn.Text = delays[delayIdx].name .. '  ▼'
    if SpamEnabled then StartSpam() UpdateStatus() end
end)

-- Hotkey bind
local bindBtn = MakeRow(110, 'Hotkey')
bindBtn.Text = '[X]'

bindBtn.MouseButton1Click:Connect(function()
    bindListening = true
    bindBtn.Text = '[ ... ]'
    TweenService:Create(bindBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(120, 0, 0)}):Play()
end)

-- hint
local hint = Instance.new('TextLabel')
hint.Size = UDim2.new(1, -10, 0, 22)
hint.Position = UDim2.new(0, 5, 1, -24)
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
        if uit == Enum.UserInputType.MouseMovement or uit == Enum.UserInputType.Focus then return end
        if kc == Enum.KeyCode.RightShift then return end

        if kc and kc ~= Enum.KeyCode.Unknown then FinishBind('Key', kc) return end
        if uit == Enum.UserInputType.MouseButton1
            or uit == Enum.UserInputType.MouseButton2
            or uit == Enum.UserInputType.MouseButton3 then
            FinishBind('Mouse', uit) return
        end
        if uit and uit ~= Enum.UserInputType.None
            and uit ~= Enum.UserInputType.Keyboard
            and uit ~= Enum.UserInputType.Touch then
            FinishBind('Mouse', uit) return
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
