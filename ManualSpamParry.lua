--[[
    Manual Spam Parry — Signal Mode
    RightShift = toggle UI
    Click the hotkey button then press any key/mouse button to bind it
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
local spamThread     = nil

-- Toggle bind: stores either a KeyCode or UserInputType
local ToggleBind     = {Type = 'KeyCode', Value = Enum.KeyCode.X}
local bindListening  = false  -- true while waiting for user to press a key/button

-- ===================== PARRY (Signal only) ===================== --

local function DoParry()
    pcall(function()
        local block = Player.PlayerGui:FindFirstChild("Hotbar")
            and Player.PlayerGui.Hotbar:FindFirstChild("Block")
        if block and firesignal then
            firesignal(block.Activated)
        end
    end)
end

-- ===================== SPAM LOGIC ===================== --

local function SpamLoop()
    while SpamEnabled do
        DoParry()
        task.wait(SpamDelay * (0.8 + math.random() * 0.4))
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

-- ===================== BIND MATCHING ===================== --

local function InputMatchesBind(input)
    if ToggleBind.Type == 'KeyCode' then
        return input.KeyCode == ToggleBind.Value
    elseif ToggleBind.Type == 'UserInputType' then
        return input.UserInputType == ToggleBind.Value
    end
    return false
end

local function GetBindName()
    if ToggleBind.Type == 'KeyCode' then
        return ToggleBind.Value.Name
    elseif ToggleBind.Type == 'UserInputType' then
        local name = ToggleBind.Value.Name
        if ToggleBind.Value == Enum.UserInputType.MouseButton1 then return 'Mouse1'
        elseif ToggleBind.Value == Enum.UserInputType.MouseButton2 then return 'Mouse2'
        elseif ToggleBind.Value == Enum.UserInputType.MouseButton3 then return 'Mouse3'
        else return name end
    end
    return '?'
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
Panel.Size = UDim2.fromOffset(230, 160)
Panel.Position = UDim2.new(0.5, -115, 0.5, -80)
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

-- status
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

-- helper: make a row with label + button
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

-- ===== Hotkey bind button =====
local hotkeyBtn = MakeRow(36, 'Hotkey')
hotkeyBtn.Text = '[X]'

hotkeyBtn.MouseButton1Click:Connect(function()
    bindListening = true
    hotkeyBtn.Text = '[ ... ]'
    TweenService:Create(hotkeyBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(120, 0, 0)}):Play()
end)

-- ===== Speed selector =====
local speedBtn = MakeRow(66, 'Speed')
local speeds = {'Normal (0.05s)', 'Safe (0.08s)', 'Slow (0.12s)', 'Fast (0.03s)'}
local speedVals = {['Normal (0.05s)'] = 0.05, ['Safe (0.08s)'] = 0.08, ['Slow (0.12s)'] = 0.12, ['Fast (0.03s)'] = 0.03}
local speedIdx = 1
speedBtn.Text = speeds[speedIdx] .. '  ▼'

speedBtn.MouseButton1Click:Connect(function()
    speedIdx = (speedIdx % #speeds) + 1
    speedBtn.Text = speeds[speedIdx] .. '  ▼'
    SpamDelay = speedVals[speeds[speedIdx]]
end)

-- hints
local hint = Instance.new('TextLabel')
hint.Size = UDim2.new(1, -10, 0, 46)
hint.Position = UDim2.new(0, 5, 1, -48)
hint.BackgroundTransparency = 1
hint.Text = 'Press hotkey to toggle spam on/off\nClick [Hotkey] button to rebind\nRightShift to show/hide UI'
hint.TextColor3 = Color3.fromRGB(80, 80, 88)
hint.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Regular)
hint.TextSize = 9
hint.TextWrapped = true
hint.Parent = Panel

-- ===================== INPUT HANDLING ===================== --

-- Inputs to ignore when binding (UI toggle key, generic types)
local ignoredBinds = {
    [Enum.KeyCode.RightShift] = true,
    [Enum.KeyCode.Unknown] = true,
    [Enum.UserInputType.MouseMovement] = true,
    [Enum.UserInputType.Focus] = true,
    [Enum.UserInputType.Touch] = true,
}

UserInputService.InputBegan:Connect(function(input, processed)
    -- === BIND LISTENING MODE ===
    if bindListening then
        -- accept keyboard keys
        if input.KeyCode and input.KeyCode ~= Enum.KeyCode.Unknown and not ignoredBinds[input.KeyCode] then
            ToggleBind = {Type = 'KeyCode', Value = input.KeyCode}
            bindListening = false
            hotkeyBtn.Text = '[' .. GetBindName() .. ']'
            TweenService:Create(hotkeyBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(30, 30, 36)}):Play()
            return
        end

        -- accept mouse buttons (MB1, MB2, MB3, MB4/X1, MB5/X2)
        local uit = input.UserInputType
        if uit == Enum.UserInputType.MouseButton1
            or uit == Enum.UserInputType.MouseButton2
            or uit == Enum.UserInputType.MouseButton3 then
            ToggleBind = {Type = 'UserInputType', Value = uit}
            bindListening = false
            hotkeyBtn.Text = '[' .. GetBindName() .. ']'
            TweenService:Create(hotkeyBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(30, 30, 36)}):Play()
            return
        end

        return
    end

    -- === NORMAL MODE ===

    -- RightShift toggles UI (always, even when processed)
    if input.KeyCode == Enum.KeyCode.RightShift then
        Panel.Visible = not Panel.Visible
        return
    end

    if processed then return end

    -- check if input matches bound key/button
    if InputMatchesBind(input) then
        if SpamEnabled then StopSpam() else StartSpam() end
        UpdateStatus()
    end
end)

-- Handle mouse X1 and X2 buttons (they come through as KeyCode, not UserInputType)
-- X1 = Enum.KeyCode.Unknown sometimes, so we also listen via UserInputType
UserInputService.InputBegan:Connect(function(input, processed)
    if bindListening then return end
    if processed then return end

    -- some executors report X1/X2 through UserInputType
    if ToggleBind.Type == 'UserInputType' and input.UserInputType == ToggleBind.Value then
        -- already handled above
        return
    end
end)

ScreenGui.Destroying:Connect(function()
    StopSpam()
end)
