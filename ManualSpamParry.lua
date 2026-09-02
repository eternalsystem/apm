--[[
    Manual Spam Parry — Keypress Mode
    RightShift = toggle UI
    Choose your hotkey to toggle spam on/off
]]

repeat task.wait() until game:IsLoaded()

local Players           = game:GetService('Players')
local Player            = Players.LocalPlayer
local UserInputService  = game:GetService('UserInputService')
local RunService        = game:GetService('RunService')
local CoreGui           = game:GetService('CoreGui')
local TweenService      = game:GetService('TweenService')

local SpamEnabled    = false
local SpamDelay      = 0.05
local ToggleKey      = Enum.KeyCode.X
local MethodName     = 'Signal'
local spamThread     = nil

-- ===================== PARRY METHODS ===================== --

-- Method 1: firesignal on Block button (no input simulation at all)
local function ParrySignal()
    local ok, err = pcall(function()
        local block = Player.PlayerGui:FindFirstChild("Hotbar")
            and Player.PlayerGui.Hotbar:FindFirstChild("Block")
        if block then
            if firesignal then
                firesignal(block.Activated)
            elseif fireclick then
                fireclick(block)
            end
        end
    end)
end

-- Method 2: keypress/keyrelease (executor-level, not VIM)
local function ParryKeypress()
    if keypress and keyrelease then
        keypress(0x46) -- F key
        task.defer(function()
            keyrelease(0x46)
        end)
    elseif Input and Input.KeyPress then
        Input.KeyPress(0x46)
        task.defer(function()
            Input.KeyRelease(0x46)
        end)
    else
        -- fallback to VIM only if nothing else works
        local ok, vim = pcall(function()
            if cloneref then
                return cloneref(game:GetService("VirtualInputManager"))
            end
            return game:GetService("VirtualInputManager")
        end)
        if ok and vim then
            vim:SendKeyEvent(true, Enum.KeyCode.F, false, game)
            task.defer(function()
                vim:SendKeyEvent(false, Enum.KeyCode.F, false, game)
            end)
        end
    end
end

-- Method 3: mouse1click on Block button
local function ParryClick()
    local ok = pcall(function()
        local block = Player.PlayerGui:FindFirstChild("Hotbar")
            and Player.PlayerGui.Hotbar:FindFirstChild("Block")
        if block then
            if fireclickdetector then
                -- try click detector
                fireclickdetector(block)
            elseif firetouchinterest then
                firetouchinterest(block, true)
                task.defer(function()
                    firetouchinterest(block, false)
                end)
            end
        end
    end)
end

local Methods = {
    Signal   = ParrySignal,
    Keypress = ParryKeypress,
    Click    = ParryClick,
}

-- ===================== SPAM LOGIC ===================== --

local function SpamLoop()
    while SpamEnabled do
        local fn = Methods[MethodName] or ParrySignal
        pcall(fn)
        -- randomize delay slightly to look more human
        local jitter = SpamDelay * (0.8 + math.random() * 0.4)
        task.wait(jitter)
    end
end

local function StartSpam()
    SpamEnabled = true
    if spamThread then pcall(task.cancel, spamThread) end
    spamThread = task.spawn(SpamLoop)
end

local function StopSpam()
    SpamEnabled = false
    spamThread = nil
end

-- ===================== UI ===================== --

local oldGui = CoreGui:FindFirstChild('MSP_UI')
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'MSP_UI'
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999

-- protect gui if possible
pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end
end)
pcall(function()
    if gethui then
        ScreenGui.Parent = gethui()
        return
    end
end)
if not ScreenGui.Parent then
    ScreenGui.Parent = CoreGui
end

local Panel = Instance.new('Frame')
Panel.Name = 'Panel'
Panel.Size = UDim2.fromOffset(230, 210)
Panel.Position = UDim2.new(0.5, -115, 0.5, -105)
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

-- title bar
local Title = Instance.new('TextLabel')
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
Title.BackgroundTransparency = 0.3
Title.Text = '  Manual Spam Parry'
Title.TextColor3 = Color3.fromRGB(240, 240, 240)
Title.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Bold)
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.BorderSizePixel = 0
Title.Parent = Panel
Instance.new('UICorner', Title).CornerRadius = UDim.new(0, 10)

-- status dot
local StatusDot = Instance.new('TextLabel')
StatusDot.Size = UDim2.fromOffset(50, 16)
StatusDot.Position = UDim2.new(1, -55, 0, 7)
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

-- helper: dropdown
local function MakeDropdown(yPos, label, options, default, onChange)
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

    local idx = table.find(options, default) or 1
    local btn = Instance.new('TextButton')
    btn.Size = UDim2.fromOffset(115, 20)
    btn.Position = UDim2.new(1, -115, 0.5, -10)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
    btn.Text = options[idx] .. '  ▼'
    btn.TextColor3 = Color3.fromRGB(200, 200, 205)
    btn.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Regular)
    btn.TextSize = 10
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    btn.Parent = row
    Instance.new('UICorner', btn).CornerRadius = UDim.new(0, 6)

    btn.MouseButton1Click:Connect(function()
        idx = (idx % #options) + 1
        btn.Text = options[idx] .. '  ▼'
        onChange(options[idx])
    end)
end

-- Method selector
MakeDropdown(36, 'Method', {'Signal', 'Keypress', 'Click'}, 'Signal', function(v)
    MethodName = v
end)

-- Hotkey selector
local keyNames = {'X', 'C', 'V', 'G', 'H', 'J', 'K', 'N', 'M'}
local keyMap = {
    X = Enum.KeyCode.X, C = Enum.KeyCode.C, V = Enum.KeyCode.V,
    G = Enum.KeyCode.G, H = Enum.KeyCode.H, J = Enum.KeyCode.J,
    K = Enum.KeyCode.K, N = Enum.KeyCode.N, M = Enum.KeyCode.M,
}
MakeDropdown(66, 'Hotkey', keyNames, 'X', function(v)
    ToggleKey = keyMap[v]
end)

-- Speed selector
local speeds = {'Fast (0.03s)', 'Normal (0.05s)', 'Safe (0.08s)', 'Slow (0.12s)'}
local speedMap = {
    ['Fast (0.03s)'] = 0.03,
    ['Normal (0.05s)'] = 0.05,
    ['Safe (0.08s)'] = 0.08,
    ['Slow (0.12s)'] = 0.12,
}
MakeDropdown(96, 'Speed', speeds, 'Normal (0.05s)', function(v)
    SpamDelay = speedMap[v]
end)

-- hints
local hint = Instance.new('TextLabel')
hint.Size = UDim2.new(1, -10, 0, 46)
hint.Position = UDim2.new(0, 5, 1, -52)
hint.BackgroundTransparency = 1
hint.Text = 'Press X to toggle spam on/off\nRightShift to show/hide UI\nTry Signal method first (least detected)'
hint.TextColor3 = Color3.fromRGB(80, 80, 88)
hint.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Regular)
hint.TextSize = 9
hint.TextWrapped = true
hint.Parent = Panel

-- ===================== INPUT ===================== --

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        Panel.Visible = not Panel.Visible
        return
    end
    if input.KeyCode == ToggleKey then
        if SpamEnabled then
            StopSpam()
        else
            StartSpam()
        end
        UpdateStatus()
    end
end)

ScreenGui.Destroying:Connect(function()
    StopSpam()
end)
