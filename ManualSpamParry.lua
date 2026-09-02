--[[
    Manual Spam Parry — Max Speed
    RightShift = toggle UI
    Click [Hotkey] then press any key/mouse to bind
    X1/X2 mouse buttons: remap them to a keyboard key in your mouse software
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
local spamSession    = 0  -- unique ID per spam session, threads check this to self-terminate

local BindKey   = Enum.KeyCode.X
local BindType  = 'Key'
local bindListening = false

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

-- ===================== SPAM — absolute max throughput ===================== --

local function StartSpam()
    -- kill any previous session first
    spamSession += 1
    local mySession = spamSession
    SpamEnabled = true

    if not activatedSignal then CacheBlock() end
    local sig = activatedSignal
    if not sig then return end

    -- RunService connections: 3 events × 20 fires each = 60 per frame
    local function Burst()
        firesignal(sig) firesignal(sig) firesignal(sig) firesignal(sig) firesignal(sig)
        firesignal(sig) firesignal(sig) firesignal(sig) firesignal(sig) firesignal(sig)
        firesignal(sig) firesignal(sig) firesignal(sig) firesignal(sig) firesignal(sig)
        firesignal(sig) firesignal(sig) firesignal(sig) firesignal(sig) firesignal(sig)
    end

    spamConns[1] = RunService.PreSimulation:Connect(Burst)
    spamConns[2] = RunService.Heartbeat:Connect(Burst)
    spamConns[3] = RunService.RenderStepped:Connect(Burst)

    -- 4 tight loop threads firing between frames, each checks session ID to stop
    for t = 1, 4 do
        task.spawn(function()
            while spamSession == mySession do
                firesignal(sig) firesignal(sig) firesignal(sig) firesignal(sig) firesignal(sig)
                firesignal(sig) firesignal(sig) firesignal(sig) firesignal(sig) firesignal(sig)
                task.wait()
            end
        end)
    end
end

function StopSpam()
    SpamEnabled = false
    spamSession += 1  -- all threads see the session changed and exit

    for i, c in pairs(spamConns) do
        if typeof(c) == 'RBXScriptConnection' then
            c:Disconnect()
        end
        spamConns[i] = nil
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
Panel.Size = UDim2.fromOffset(210, 100)
Panel.Position = UDim2.new(0.5, -105, 0.5, -50)
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

-- hotkey row
local bindRow = Instance.new('Frame')
bindRow.Size = UDim2.new(1, -20, 0, 26)
bindRow.Position = UDim2.new(0, 10, 0, 33)
bindRow.BackgroundTransparency = 1
bindRow.Parent = Panel

local bindLbl = Instance.new('TextLabel')
bindLbl.Size = UDim2.new(0.4, 0, 1, 0)
bindLbl.BackgroundTransparency = 1
bindLbl.Text = 'Hotkey'
bindLbl.TextColor3 = Color3.fromRGB(200, 200, 205)
bindLbl.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Regular)
bindLbl.TextSize = 12
bindLbl.TextXAlignment = Enum.TextXAlignment.Left
bindLbl.Parent = bindRow

local bindBtn = Instance.new('TextButton')
bindBtn.Size = UDim2.fromOffset(100, 20)
bindBtn.Position = UDim2.new(1, -100, 0.5, -10)
bindBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
bindBtn.Text = '[X]'
bindBtn.TextColor3 = Color3.fromRGB(200, 200, 205)
bindBtn.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Regular)
bindBtn.TextSize = 11
bindBtn.AutoButtonColor = false
bindBtn.BorderSizePixel = 0
bindBtn.Parent = bindRow
Instance.new('UICorner', bindBtn).CornerRadius = UDim.new(0, 6)

bindBtn.MouseButton1Click:Connect(function()
    bindListening = true
    bindBtn.Text = '[ ... ]'
    TweenService:Create(bindBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(120, 0, 0)}):Play()
end)

-- hint
local hint = Instance.new('TextLabel')
hint.Size = UDim2.new(1, -10, 0, 28)
hint.Position = UDim2.new(0, 5, 1, -30)
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
