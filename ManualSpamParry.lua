--[[
    Manual Spam Parry
    Instant capture (hook+VIM+unhook in 2 frames)
    Direct replay spam = near-zero FPS
]]

local MSP_VERSION = '2.0.0'

repeat task.wait() until game:IsLoaded()

local Players           = game:GetService('Players')
local Player            = Players.LocalPlayer
local UserInputService  = game:GetService('UserInputService')
local RunService        = game:GetService('RunService')
local CoreGui           = game:GetService('CoreGui')
local TweenService      = game:GetService('TweenService')

-- ===================== CONFIG ===================== --

local SpamEnabled    = false
local spamConns      = {}

local ActivateBind   = { type = 'Key', value = Enum.KeyCode.X }
local UIBind         = { type = 'Key', value = Enum.KeyCode.RightShift }
local activeListener = nil

local ActivateMode   = 'Toggle'
local IsAnchored     = false
local ParryPower     = 10   -- 1-10: controls u165 force rate (10=every call, 1=light)

-- ===================== COLORS ===================== --

local C = {
    panel      = Color3.fromRGB(17, 17, 17),
    border     = Color3.fromRGB(34, 34, 34),
    surface    = Color3.fromRGB(24, 24, 24),
    surfaceHov = Color3.fromRGB(31, 31, 31),
    divider    = Color3.fromRGB(30, 30, 30),
    text       = Color3.fromRGB(232, 232, 232),
    textMid    = Color3.fromRGB(153, 153, 153),
    textDim    = Color3.fromRGB(85, 85, 85),
    white      = Color3.fromRGB(255, 255, 255),
    black      = Color3.fromRGB(0, 0, 0),
}

-- ===================== PARRY ENGINE ===================== --
-- INSTANT CAPTURE: hook exists for ~2 frames only (when user presses X)
--   1. Install hook on ParryAttempt
--   2. VIM click triggers real parry pipeline -> hook captures args
--   3. Unhook after 2 frames (~33ms) -> undetectable
--   4. Spam direct replay = near-zero FPS
-- FALLBACK: VIM click spam if capture fails

-- Capture state
local _parryRemote = nil
local _parryArgs = nil
local _captured = false
local _origFireServer = nil
local _engineReady = false
local _parryMode = "none"    -- "direct" or "click"

-- Resolve exploit functions
local _hf
pcall(function() _hf = hookfunction or replaceclosure end)

-- VirtualInputManager
local _vim
pcall(function() _vim = game:GetService("VirtualInputManager") end)

-- ParryAttempt reference
local _paRemote = nil
pcall(function()
    local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 10)
    if R then _paRemote = R:FindFirstChild("ParryAttempt") end
end)

warn("[MSP] hookfn=" .. tostring(typeof(_hf))
    .. " VIM=" .. tostring(_vim ~= nil)
    .. " ParryAttempt=" .. tostring(_paRemote ~= nil))

-- === INSTANT CAPTURE (called on first X press) ===
-- Hook window: ~2 frames. PRY integrity checks run every ~1-5s.

local function AttemptCapture()
    if _captured then return true end
    if typeof(_hf) ~= "function" or not _vim or not _paRemote then
        warn("[MSP] Can't capture (missing hookfn/VIM/remote)")
        return false
    end

    warn("[MSP] Capture: hook -> VIM click -> unhook...")

    -- Step 1: Install hook
    local origFS
    origFS = _hf(_paRemote.FireServer, function(...)
        if not _captured then
            _parryRemote = _paRemote
            _parryArgs = {select(2, ...)}
            _captured = true
            _origFireServer = origFS
            _parryMode = "direct"
        end
        return origFS(...)
    end)

    -- Step 2: VIM click (triggers BaseUIS -> PRY -> FireServer through hook)
    pcall(function()
        local vp = workspace.CurrentCamera.ViewportSize
        _vim:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, true, game, 0)
    end)

    -- Step 3: Wait 2 frames for click to propagate through pipeline
    RunService.Heartbeat:Wait()
    RunService.Heartbeat:Wait()

    -- Step 4: Mouse up + unhook
    pcall(function()
        local vp = workspace.CurrentCamera.ViewportSize
        _vim:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, false, game, 0)
    end)
    pcall(function() _hf(_paRemote.FireServer, origFS) end)

    if _captured then
        warn("[MSP] >>> CAPTURED - direct replay mode <<<")
    else
        warn("[MSP] Capture missed - VIM click fallback")
        _parryMode = "click"
    end
    return _captured
end

-- Direct replay (near-zero FPS)
local function DirectParry()
    if _origFireServer and _parryRemote and _parryArgs then
        _origFireServer(_parryRemote, unpack(_parryArgs))
    end
end

-- VIM click (simulates real mouse click)
local function ClickParry()
    if not _vim then return end
    pcall(function()
        local vp = workspace.CurrentCamera.ViewportSize
        _vim:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, true, game, 0)
        task.defer(function()
            pcall(function()
                _vim:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, false, game, 0)
            end)
        end)
    end)
end

-- Best available parry
local function DoParry()
    if _captured then
        DirectParry()
    else
        ClickParry()
    end
end

-- Setup (just marks engine ready)
task.spawn(function()
    if not Player.Character then Player.CharacterAdded:Wait() end
    task.wait(1)
    _engineReady = true
    warn("[MSP] Ready - press X to activate")
end)

Player.CharacterAdded:Connect(function()
    _captured = false
    _parryMode = "none"
    task.wait(2)
    _engineReady = true
    warn("[MSP] Respawn - ready")
end)

-- ===================== SPAM ===================== --

local spamSession = 0

local function StopSpam()
    SpamEnabled = false
    spamSession = spamSession + 1
    for i, c in pairs(spamConns) do
        pcall(function() c:Disconnect() end)
        spamConns[i] = nil
    end
    spamConns = {}
end

local function StartSpam()
    StopSpam()

    if not _engineReady then
        warn("[MSP] Not ready - waiting for setup")
        return
    end

    SpamEnabled = true
    spamSession = spamSession + 1
    local mySession = spamSession

    -- Attempt capture on first activation (runs in thread because it yields)
    task.spawn(function()
        if not _captured then
            AttemptCapture()
            if spamSession ~= mySession or not SpamEnabled then return end
            pcall(UpdateStatus)
        end

        local rate = 3 + (ParryPower - 1) * 7 / 9
        local interval = 1 / rate
        local lastFire = 0

        warn("[MSP] Spam ON - " .. _parryMode .. " - " .. math.floor(rate) .. "/sec")

        -- Single Heartbeat with clock-based throttle
        spamConns[1] = RunService.Heartbeat:Connect(function()
            if not SpamEnabled or spamSession ~= mySession then return end
            local now = tick()
            if now - lastFire >= interval then
                lastFire = now
                pcall(DoParry)
            end
        end)

        -- ParrySuccess = instant re-fire
        local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
        local ps = remotes and remotes:FindFirstChild("ParrySuccess")
        if ps then
            spamConns[2] = ps.OnClientEvent:Connect(function()
                if not SpamEnabled or spamSession ~= mySession then return end
                lastFire = tick()
                pcall(DoParry)
            end)
        end
    end)
end

-- ===================== BIND HELPERS ===================== --

local function GetBindName(bind)
    if bind.type == 'Key' then return bind.value.Name end
    if bind.value == Enum.UserInputType.MouseButton1 then return 'Mouse1' end
    if bind.value == Enum.UserInputType.MouseButton2 then return 'Mouse2' end
    if bind.value == Enum.UserInputType.MouseButton3 then return 'Mouse3' end
    return tostring(bind.value)
end

local function InputMatchesBind(input, bind)
    if bind.type == 'Key' then return input.KeyCode == bind.value end
    return input.UserInputType == bind.value
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

local Font_Bold    = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Bold)
local Font_Semi    = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold)
local Font_Regular = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Regular)

-- ==================== FULL PANEL ==================== --

local Panel = Instance.new('Frame')
Panel.Name = 'Panel'
Panel.Size = UDim2.fromOffset(320, 242)
Panel.Position = UDim2.new(0.5, -160, 0.5, -121)
Panel.BackgroundColor3 = C.panel
Panel.BackgroundTransparency = 0
Panel.BorderSizePixel = 0
Panel.Active = true
Panel.Draggable = true
Panel.Parent = ScreenGui

Instance.new('UICorner', Panel).CornerRadius = UDim.new(0, 12)
local panelStroke = Instance.new('UIStroke', Panel)
panelStroke.Color = C.border
panelStroke.Thickness = 1

-- Header
local Header = Instance.new('Frame')
Header.Name = 'Header'
Header.Size = UDim2.new(1, 0, 0, 42)
Header.BackgroundTransparency = 1
Header.BorderSizePixel = 0
Header.Parent = Panel

local Title = Instance.new('TextLabel')
Title.Size = UDim2.new(0, 100, 1, 0)
Title.Position = UDim2.fromOffset(18, 0)
Title.BackgroundTransparency = 1
Title.Text = 'Spam Parry'
Title.TextColor3 = C.white
Title.FontFace = Font_Bold
Title.TextSize = 15
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local VersionLabel = Instance.new('TextLabel')
VersionLabel.Size = UDim2.fromOffset(40, 14)
VersionLabel.Position = UDim2.fromOffset(118, 6)
VersionLabel.BackgroundTransparency = 1
VersionLabel.Text = 'v' .. MSP_VERSION
VersionLabel.TextColor3 = C.textDim
VersionLabel.FontFace = Font_Regular
VersionLabel.TextSize = 9
VersionLabel.TextXAlignment = Enum.TextXAlignment.Left
VersionLabel.Parent = Header

local StatusLabel = Instance.new('TextLabel')
StatusLabel.Name = 'Status'
StatusLabel.Size = UDim2.fromOffset(30, 14)
StatusLabel.Position = UDim2.fromOffset(118, 22)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = 'OFF'
StatusLabel.TextColor3 = C.textDim
StatusLabel.FontFace = Font_Semi
StatusLabel.TextSize = 11
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = Header

-- Header buttons
local function MakeHeaderBtn(text, posFromRight)
    local btn = Instance.new('TextButton')
    btn.Size = UDim2.fromOffset(22, 22)
    btn.Position = UDim2.new(1, -posFromRight, 0.5, -11)
    btn.BackgroundColor3 = C.surface
    btn.BackgroundTransparency = 1
    btn.Text = text
    btn.TextColor3 = C.textDim
    btn.FontFace = Font_Regular
    btn.TextSize = 14
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    btn.Parent = Header
    Instance.new('UICorner', btn).CornerRadius = UDim.new(1, 0)
    btn.MouseEnter:Connect(function()
        btn.BackgroundTransparency = 0
        btn.TextColor3 = C.text
    end)
    btn.MouseLeave:Connect(function()
        btn.BackgroundTransparency = 1
        btn.TextColor3 = C.textDim
    end)
    return btn
end

local CloseBtn = MakeHeaderBtn('✕', 30)
local AnchorBtn = MakeHeaderBtn('―', 56)

-- Divider under header
local HeaderDiv = Instance.new('Frame')
HeaderDiv.Size = UDim2.new(1, 0, 0, 1)
HeaderDiv.Position = UDim2.new(0, 0, 0, 42)
HeaderDiv.BackgroundColor3 = C.divider
HeaderDiv.BorderSizePixel = 0
HeaderDiv.Parent = Panel

-- ==================== SECTIONS ==================== --

local function MakeSectionLabel(parent, yPos, text)
    local lbl = Instance.new('TextLabel')
    lbl.Size = UDim2.new(1, -36, 0, 14)
    lbl.Position = UDim2.fromOffset(18, yPos)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = C.textDim
    lbl.FontFace = Font_Semi
    lbl.TextSize = 9
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = parent
    return lbl
end

local function MakeRow(parent, yPos, label)
    local row = Instance.new('Frame')
    row.Size = UDim2.new(1, -36, 0, 34)
    row.Position = UDim2.fromOffset(18, yPos)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new('TextLabel')
    lbl.Size = UDim2.new(0, 80, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = C.textMid
    lbl.FontFace = Font_Regular
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new('TextButton')
    btn.Size = UDim2.fromOffset(130, 28)
    btn.Position = UDim2.new(1, -130, 0.5, -14)
    btn.BackgroundColor3 = C.surface
    btn.TextColor3 = C.text
    btn.FontFace = Font_Regular
    btn.TextSize = 12
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    btn.Parent = row
    Instance.new('UICorner', btn).CornerRadius = UDim.new(0, 6)
    local btnStroke = Instance.new('UIStroke', btn)
    btnStroke.Color = C.border
    btnStroke.Thickness = 1

    btn.MouseEnter:Connect(function()
        btn.BackgroundColor3 = C.surfaceHov
        btnStroke.Color = Color3.fromRGB(42, 42, 42)
    end)
    btn.MouseLeave:Connect(function()
        btn.BackgroundColor3 = C.surface
        btnStroke.Color = C.border
    end)

    return btn, btnStroke
end

-- PARRY section
MakeSectionLabel(Panel, 50, 'PARRY')

local activateBindBtn, activateBindStroke = MakeRow(Panel, 66, 'Activate')
activateBindBtn.Text = '[' .. GetBindName(ActivateBind) .. ']'
activateBindBtn.FontFace = Font_Semi
activateBindBtn.TextSize = 13

local modeBtn = MakeRow(Panel, 100, 'Mode')
modeBtn.Text = ActivateMode .. '  ▼'

-- Power slider row
local powerRow = Instance.new('Frame')
powerRow.Size = UDim2.new(1, -36, 0, 34)
powerRow.Position = UDim2.fromOffset(18, 134)
powerRow.BackgroundTransparency = 1
powerRow.Parent = Panel

local powerLabel = Instance.new('TextLabel')
powerLabel.Size = UDim2.new(0, 50, 1, 0)
powerLabel.BackgroundTransparency = 1
powerLabel.Text = 'Power'
powerLabel.TextColor3 = C.textMid
powerLabel.FontFace = Font_Regular
powerLabel.TextSize = 13
powerLabel.TextXAlignment = Enum.TextXAlignment.Left
powerLabel.Parent = powerRow

local powerValue = Instance.new('TextLabel')
powerValue.Size = UDim2.fromOffset(28, 28)
powerValue.Position = UDim2.new(1, -28, 0.5, -14)
powerValue.BackgroundTransparency = 1
powerValue.Text = tostring(ParryPower)
powerValue.TextColor3 = C.white
powerValue.FontFace = Font_Bold
powerValue.TextSize = 13
powerValue.TextXAlignment = Enum.TextXAlignment.Right
powerValue.Parent = powerRow

-- Slider track
local sliderTrack = Instance.new('TextButton')
sliderTrack.Size = UDim2.fromOffset(150, 12)
sliderTrack.Position = UDim2.new(1, -188, 0.5, -6)
sliderTrack.BackgroundColor3 = C.surface
sliderTrack.Text = ''
sliderTrack.AutoButtonColor = false
sliderTrack.BorderSizePixel = 0
sliderTrack.Parent = powerRow
Instance.new('UICorner', sliderTrack).CornerRadius = UDim.new(1, 0)
local trackStroke = Instance.new('UIStroke', sliderTrack)
trackStroke.Color = C.border
trackStroke.Thickness = 1

-- Slider fill
local sliderFill = Instance.new('Frame')
sliderFill.Size = UDim2.new(1, 0, 1, 0) -- starts at 100% (power=10)
sliderFill.BackgroundColor3 = C.white
sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderTrack
Instance.new('UICorner', sliderFill).CornerRadius = UDim.new(1, 0)

-- Slider handle
local sliderHandle = Instance.new('Frame')
sliderHandle.Size = UDim2.fromOffset(16, 16)
sliderHandle.Position = UDim2.new(1, -8, 0.5, -8) -- right edge at power=10
sliderHandle.BackgroundColor3 = C.white
sliderHandle.BorderSizePixel = 0
sliderHandle.ZIndex = 2
sliderHandle.Parent = sliderTrack
Instance.new('UICorner', sliderHandle).CornerRadius = UDim.new(1, 0)

local function UpdateSlider()
    local pct = (ParryPower - 1) / 9
    sliderFill.Size = UDim2.new(pct, 0, 1, 0)
    sliderHandle.Position = UDim2.new(pct, -8, 0.5, -8)
    powerValue.Text = tostring(ParryPower)
end

local sliderDragging = false

local function SetPowerFromX(absX)
    local trackAbsX = sliderTrack.AbsolutePosition.X
    local trackW = sliderTrack.AbsoluteSize.X
    local rel = math.clamp((absX - trackAbsX) / trackW, 0, 1)
    ParryPower = math.clamp(math.floor(rel * 9 + 1.5), 1, 10)
    UpdateSlider()
end

sliderTrack.MouseButton1Down:Connect(function()
    sliderDragging = true
end)

sliderTrack.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        sliderDragging = true
        SetPowerFromX(input.Position.X)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if sliderDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        SetPowerFromX(input.Position.X)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        sliderDragging = false
    end
end)

UpdateSlider()

-- Divider
local SectionDiv = Instance.new('Frame')
SectionDiv.Size = UDim2.new(1, 0, 0, 1)
SectionDiv.Position = UDim2.fromOffset(0, 180)
SectionDiv.BackgroundColor3 = C.divider
SectionDiv.BorderSizePixel = 0
SectionDiv.Parent = Panel

-- UI section
MakeSectionLabel(Panel, 186, 'UI')

local uiBindBtn, uiBindStroke = MakeRow(Panel, 202, 'Show / Hide')
uiBindBtn.Text = '[' .. GetBindName(UIBind) .. ']'
uiBindBtn.FontFace = Font_Semi
uiBindBtn.TextSize = 13

-- ==================== ANCHOR (MINI) ==================== --

local AnchorPanel = Instance.new('Frame')
AnchorPanel.Name = 'Anchor'
AnchorPanel.Size = UDim2.fromOffset(140, 36)
AnchorPanel.Position = UDim2.new(0.5, -70, 0.5, -18)
AnchorPanel.BackgroundColor3 = C.panel
AnchorPanel.BorderSizePixel = 0
AnchorPanel.Active = true
AnchorPanel.Draggable = true
AnchorPanel.Visible = false
AnchorPanel.Parent = ScreenGui

Instance.new('UICorner', AnchorPanel).CornerRadius = UDim.new(0, 10)
local anchorStroke = Instance.new('UIStroke', AnchorPanel)
anchorStroke.Color = C.border
anchorStroke.Thickness = 1

local AnchorTitle = Instance.new('TextLabel')
AnchorTitle.Size = UDim2.fromOffset(24, 36)
AnchorTitle.Position = UDim2.fromOffset(14, 0)
AnchorTitle.BackgroundTransparency = 1
AnchorTitle.Text = 'SP'
AnchorTitle.TextColor3 = C.textMid
AnchorTitle.FontFace = Font_Bold
AnchorTitle.TextSize = 12
AnchorTitle.TextXAlignment = Enum.TextXAlignment.Left
AnchorTitle.Parent = AnchorPanel

local AnchorStatus = Instance.new('TextLabel')
AnchorStatus.Size = UDim2.fromOffset(30, 36)
AnchorStatus.Position = UDim2.fromOffset(42, 0)
AnchorStatus.BackgroundTransparency = 1
AnchorStatus.Text = 'OFF'
AnchorStatus.TextColor3 = C.textDim
AnchorStatus.FontFace = Font_Semi
AnchorStatus.TextSize = 10
AnchorStatus.TextXAlignment = Enum.TextXAlignment.Left
AnchorStatus.Parent = AnchorPanel

-- Separator line in anchor
local AnchorSep = Instance.new('Frame')
AnchorSep.Size = UDim2.fromOffset(1, 16)
AnchorSep.Position = UDim2.new(0, 85, 0.5, -8)
AnchorSep.BackgroundColor3 = C.divider
AnchorSep.BorderSizePixel = 0
AnchorSep.Parent = AnchorPanel

-- Expand button
local ExpandBtn = Instance.new('TextButton')
ExpandBtn.Size = UDim2.fromOffset(22, 22)
ExpandBtn.Position = UDim2.new(0, 100, 0.5, -11)
ExpandBtn.BackgroundTransparency = 1
ExpandBtn.Text = '＋'
ExpandBtn.TextColor3 = C.textDim
ExpandBtn.FontFace = Font_Regular
ExpandBtn.TextSize = 13
ExpandBtn.AutoButtonColor = false
ExpandBtn.BorderSizePixel = 0
ExpandBtn.Parent = AnchorPanel
Instance.new('UICorner', ExpandBtn).CornerRadius = UDim.new(1, 0)

ExpandBtn.MouseEnter:Connect(function()
    ExpandBtn.BackgroundTransparency = 0
    ExpandBtn.BackgroundColor3 = C.surface
    ExpandBtn.TextColor3 = C.text
end)
ExpandBtn.MouseLeave:Connect(function()
    ExpandBtn.BackgroundTransparency = 1
    ExpandBtn.TextColor3 = C.textDim
end)

-- ==================== STATUS UPDATE ==================== --

local function UpdateStatus()
    local label, color
    if not _engineReady then
        label = 'SETUP'
        color = Color3.fromRGB(255, 180, 50)
    elseif SpamEnabled then
        label = _captured and 'ON' or 'ON*'
        color = C.white
    else
        label = 'READY'
        color = Color3.fromRGB(80, 220, 80)
    end
    StatusLabel.Text = label
    StatusLabel.TextColor3 = color
    AnchorStatus.Text = label
    AnchorStatus.TextColor3 = color
end

-- ==================== ANCHOR LOGIC ==================== --

local function GoAnchor()
    IsAnchored = true
    AnchorPanel.Position = Panel.Position
    Panel.Visible = false
    AnchorPanel.Visible = true
end

local function GoFull()
    IsAnchored = false
    Panel.Position = AnchorPanel.Position
    AnchorPanel.Visible = false
    Panel.Visible = true
end

AnchorBtn.MouseButton1Click:Connect(GoAnchor)
ExpandBtn.MouseButton1Click:Connect(GoFull)

-- ==================== CLOSE ==================== --

CloseBtn.MouseButton1Click:Connect(function()
    Panel.Visible = false
    AnchorPanel.Visible = false
end)

-- ==================== DROPDOWNS ==================== --

local modeOptions = {'Toggle', 'Hold'}
local modeIdx = 1

modeBtn.MouseButton1Click:Connect(function()
    modeIdx = (modeIdx % #modeOptions) + 1
    ActivateMode = modeOptions[modeIdx]
    modeBtn.Text = ActivateMode .. '  ▼'
    if SpamEnabled then
        StopSpam()
        UpdateStatus()
    end
end)

-- ==================== BIND LISTENING ==================== --

local function StartListening(which)
    activeListener = which
    local btn, stroke
    if which == 'activate' then
        btn, stroke = activateBindBtn, activateBindStroke
    else
        btn, stroke = uiBindBtn, uiBindStroke
    end
    btn.Text = '[ ... ]'
    btn.BackgroundColor3 = C.white
    btn.TextColor3 = C.black
    stroke.Color = C.white
end

local function FinishBind(which, bindType, bindValue)
    local bind = { type = bindType, value = bindValue }
    local btn, stroke

    if which == 'activate' then
        ActivateBind = bind
        btn, stroke = activateBindBtn, activateBindStroke
    else
        UIBind = bind
        btn, stroke = uiBindBtn, uiBindStroke
    end

    btn.Text = '[' .. GetBindName(bind) .. ']'
    btn.BackgroundColor3 = C.surface
    btn.TextColor3 = C.text
    stroke.Color = C.border
    activeListener = nil
end

activateBindBtn.MouseButton1Click:Connect(function() StartListening('activate') end)
uiBindBtn.MouseButton1Click:Connect(function() StartListening('ui') end)

-- ==================== INPUT ==================== --

UserInputService.InputBegan:Connect(function(input, processed)
    local kc = input.KeyCode
    local uit = input.UserInputType

    if activeListener then
        if uit == Enum.UserInputType.MouseMovement or uit == Enum.UserInputType.Focus then return end
        if kc and kc ~= Enum.KeyCode.Unknown then
            FinishBind(activeListener, 'Key', kc)
            return
        end
        if uit == Enum.UserInputType.MouseButton1
            or uit == Enum.UserInputType.MouseButton2
            or uit == Enum.UserInputType.MouseButton3 then
            FinishBind(activeListener, 'Mouse', uit)
            return
        end
        if uit and uit ~= Enum.UserInputType.None
            and uit ~= Enum.UserInputType.Keyboard
            and uit ~= Enum.UserInputType.Touch then
            FinishBind(activeListener, 'Mouse', uit)
            return
        end
        return
    end

    if InputMatchesBind(input, UIBind) then
        if Panel.Visible or AnchorPanel.Visible then
            Panel.Visible = false
            AnchorPanel.Visible = false
        else
            if IsAnchored then
                AnchorPanel.Visible = true
            else
                Panel.Visible = true
            end
        end
        return
    end

    if processed then return end

    if InputMatchesBind(input, ActivateBind) then
        if ActivateMode == 'Toggle' then
            if SpamEnabled then StopSpam() else StartSpam() end
            UpdateStatus()
        else
            if not SpamEnabled then
                StartSpam()
                UpdateStatus()
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if ActivateMode == 'Hold' and InputMatchesBind(input, ActivateBind) then
        if SpamEnabled then
            StopSpam()
            UpdateStatus()
        end
    end
end)

-- ==================== ENGINE + CAPTURE WATCHER ==================== --
-- Poll until engine ready, then keep watching for hook capture

task.spawn(function()
    while not _engineReady do
        task.wait(0.5)
        UpdateStatus()
    end
    UpdateStatus()
end)

-- Initial status
UpdateStatus()

-- ==================== CLEANUP ==================== --

ScreenGui.Destroying:Connect(function()
    StopSpam()
end)
