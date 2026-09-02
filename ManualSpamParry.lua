--[[
    Manual Spam Parry — Direct Remote Mode
    Phase 1: Press F once in-game to let the script capture remotes
    Phase 2: Spam parry directly via remotes with configurable delay
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

local SpamDelay      = 0  -- 0 = max speed (every frame), in seconds
local MethodName     = 'Remote'  -- 'Remote' or 'Signal'

-- ===================== REMOTE CAPTURE ===================== --

local CapturedRemotes = {}  -- list of {remote, args} captured from a real parry
local PrivateKeys     = {}  -- track private keys per remote
local RemoteReady     = false
local Capturing       = true  -- start in capture mode

-- firesignal fallback
local activatedSignal = nil
local function CacheBlock()
    local hotbar = Player.PlayerGui:FindFirstChild("Hotbar")
    if hotbar then
        local block = hotbar:FindFirstChild("Block")
        if block then activatedSignal = block.Activated end
    end
end
CacheBlock()

-- Hook __namecall to intercept ALL remote calls the game makes
local capturedSet     = {}  -- avoid duplicates
local captureWindow   = false
local captureBuffer   = {}

local __namecall
__namecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    -- capture FireServer calls during the capture window
    if captureWindow and not checkcaller() and method == "FireServer" and self:IsA("RemoteEvent") then
        table.insert(captureBuffer, {
            remote = self,
            args = args,
        })
    end

    return __namecall(self, ...)
end)

-- When the player presses F (real parry), capture what remotes fire
local function StartCaptureWindow()
    captureWindow = true
    captureBuffer = {}

    -- wait a short time for all remotes from this parry to fire
    task.delay(0.15, function()
        captureWindow = false

        if #captureBuffer > 0 then
            CapturedRemotes = {}
            for _, entry in ipairs(captureBuffer) do
                table.insert(CapturedRemotes, {
                    remote = entry.remote,
                    argCount = #entry.args,
                    -- store the args as template (we'll reuse structure)
                    templateArgs = entry.args,
                })
            end
            RemoteReady = true
            Capturing = false
        end
    end)
end

-- Listen for the player's real F press to trigger capture
local captureConn
captureConn = UserInputService.InputBegan:Connect(function(input, processed)
    if not Capturing then return end
    if input.KeyCode == Enum.KeyCode.F then
        StartCaptureWindow()
    end
end)

-- ===================== DIRECT REMOTE PARRY ===================== --

local function DirectParry()
    for _, entry in ipairs(CapturedRemotes) do
        entry.remote:FireServer(unpack(entry.templateArgs))
    end
end

-- ===================== SIGNAL PARRY (fallback) ===================== --

local function SignalParry()
    if activatedSignal then
        firesignal(activatedSignal)
    end
end

-- ===================== SPAM LOGIC ===================== --

local function GetParryFn()
    if MethodName == 'Remote' and RemoteReady then
        return DirectParry
    else
        return SignalParry
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
    StopSpam()
    SpamEnabled = true

    local parryFn = GetParryFn()

    if SpamDelay <= 0 then
        -- max speed: every frame on all 3 events
        spamConns[1] = RunService.PreSimulation:Connect(function() pcall(parryFn) end)
        spamConns[2] = RunService.Heartbeat:Connect(function() pcall(parryFn) end)
        spamConns[3] = RunService.RenderStepped:Connect(function() pcall(parryFn) end)
    else
        -- timed mode: single heartbeat connection with delay tracking
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

-- ===================== BIND HELPERS ===================== --

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
Panel.Size = UDim2.fromOffset(230, 195)
Panel.Position = UDim2.new(0.5, -115, 0.5, -97)
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

-- Row 1: Status / instruction
local infoLabel = Instance.new('TextLabel')
infoLabel.Size = UDim2.new(1, -20, 0, 22)
infoLabel.Position = UDim2.new(0, 10, 0, 32)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = '⚠ Press F once to capture remotes'
infoLabel.TextColor3 = Color3.fromRGB(220, 180, 50)
infoLabel.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Bold)
infoLabel.TextSize = 10
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.Parent = Panel

-- update info when captured
task.spawn(function()
    while Capturing do task.wait(0.2) end
    infoLabel.Text = '✓ Captured ' .. #CapturedRemotes .. ' remotes'
    infoLabel.TextColor3 = Color3.fromRGB(80, 200, 80)
end)

-- Row 2: Method selector
local methodBtn = MakeRow(58, 'Method')
local methods = {'Remote', 'Signal'}
local methodIdx = 1
methodBtn.Text = MethodName .. '  ▼'

methodBtn.MouseButton1Click:Connect(function()
    methodIdx = (methodIdx % #methods) + 1
    MethodName = methods[methodIdx]
    methodBtn.Text = MethodName .. '  ▼'
    if SpamEnabled then StartSpam() UpdateStatus() end
end)

-- Row 3: Delay selector
local delayBtn = MakeRow(87, 'Delay')
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

-- Row 4: Hotkey bind
local bindBtn = MakeRow(116, 'Hotkey')
bindBtn.Text = '[X]'

bindBtn.MouseButton1Click:Connect(function()
    bindListening = true
    bindBtn.Text = '[ ... ]'
    TweenService:Create(bindBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(120, 0, 0)}):Play()
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
        if uit == Enum.UserInputType.MouseMovement or uit == Enum.UserInputType.Focus then return end
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
