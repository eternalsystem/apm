--[[
    Manual Spam Parry
    Power slider ForceUnlock + ParrySuccess instant re-fire
    MuteClickSound for audio optimization
]]

local MSP_VERSION = '1.3.0'

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

-- ===================== REMOTE CAPTURE ENGINE ===================== --
-- Installs ALL available hooks simultaneously (they don't conflict).
-- Any one that fires first captures the remote + args.
-- After capture, all hooks become ultra-fast no-ops.
--
-- Strategy 1: hookfunction  - hooks the C closure (fastest if executor supports it)
-- Strategy 2: __index hook  - intercepts property lookup (catches Luraph VM decomposition)
-- Strategy 3: __namecall    - intercepts method calls (fallback)

local _parryRemote = nil
local _parryArgs = nil
local _remoteCaptured = false
local _hookInstalled = false
local _origFireServer = nil

local function isInRemotes(inst)
    local ok, result = pcall(function()
        local p = inst.Parent
        return p and p.Name == "Remotes"
            and p.Parent == game:GetService("ReplicatedStorage")
    end)
    return ok and result
end

do
    pcall(function()
        local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
        if remotes then
            warn("[MSP] Remotes contents:")
            for _, child in ipairs(remotes:GetChildren()) do
                warn("  > " .. child.Name .. " [" .. child.ClassName .. "]")
            end
        end
    end)

    local _hf, _hm, _nc, _cc, _gnm
    pcall(function() _hf  = hookfunction or replaceclosure end)
    pcall(function() _hm  = hookmetamethod end)
    pcall(function() _nc  = newcclosure end)
    pcall(function() _cc  = checkcaller end)
    pcall(function() _gnm = getnamecallmethod end)

    local wrap = typeof(_nc) == "function" and _nc or function(f) return f end
    local strategies = {}

    -- Log available functions for diagnostics
    warn("[MSP] hookfunction=" .. tostring(typeof(_hf))
        .. " hookmetamethod=" .. tostring(typeof(_hm))
        .. " checkcaller=" .. tostring(typeof(_cc)))

    -- === STRATEGY 1: hookfunction on each remote in Remotes ===
    pcall(function()
        if typeof(_hf) ~= "function" or typeof(_cc) ~= "function" then return end

        local Remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
        if not Remotes then return end

        local seenFS = {}
        for _, child in ipairs(Remotes:GetChildren()) do
            if child:IsA("RemoteEvent") then
                pcall(function()
                    local rawFS = child.FireServer
                    if seenFS[rawFS] then return end
                    seenFS[rawFS] = true

                    local origFS
                    origFS = _hf(rawFS, wrap(function(...)
                        if not _remoteCaptured and not _cc() then
                            local self = ...
                            if typeof(self) == "Instance" and self:IsA("RemoteEvent")
                                and isInRemotes(self) then
                                _parryRemote = self
                                _parryArgs = {select(2, ...)}
                                _remoteCaptured = true
                                pcall(warn, "[MSP] Captured via hookfunction: " .. tostring(self.Name))
                            end
                        end
                        return origFS(...)
                    end))
                    if not _origFireServer then _origFireServer = origFS end
                end)
            end
        end
        table.insert(strategies, "hookfn")
    end)

    -- === STRATEGY 2: __index hook (catches Luraph VM __index+CALL pattern) ===
    pcall(function()
        if typeof(_hm) ~= "function" or typeof(_cc) ~= "function" then return end

        local oldIndex
        oldIndex = _hm(game, "__index", wrap(function(self, key)
            -- Ultra-fast path after capture: 1 boolean check
            if _remoteCaptured or key ~= "FireServer" then
                return oldIndex(self, key)
            end

            -- Only wrap game code accessing FireServer on Remotes children
            if not _cc() and typeof(self) == "Instance"
                and self:IsA("RemoteEvent") and isInRemotes(self) then
                local original = oldIndex(self, key)
                -- Return wrapper that captures args when called
                return function(...)
                    if not _remoteCaptured then
                        _parryRemote = (...)
                        _parryArgs = {select(2, ...)}
                        _remoteCaptured = true
                        _origFireServer = _origFireServer or original
                        pcall(warn, "[MSP] Captured via __index: " .. tostring(self.Name))
                    end
                    return original(...)
                end
            end

            return oldIndex(self, key)
        end))
        table.insert(strategies, "__index")
    end)

    -- === STRATEGY 3: __namecall hook (fallback for standard method calls) ===
    pcall(function()
        if typeof(_hm) ~= "function" or typeof(_cc) ~= "function"
            or typeof(_gnm) ~= "function" then return end

        local oldNamecall
        oldNamecall = _hm(game, "__namecall", wrap(function(...)
            if not _remoteCaptured then
                pcall(function(...)
                    if not _cc() and _gnm() == "FireServer" then
                        local self = ...
                        if typeof(self) == "Instance" and self:IsA("RemoteEvent")
                            and isInRemotes(self) then
                            _parryRemote = self
                            _parryArgs = {select(2, ...)}
                            _remoteCaptured = true
                            pcall(warn, "[MSP] Captured via __namecall: " .. tostring(self.Name))
                        end
                    end
                end, ...)
            end
            return oldNamecall(...)
        end))
        table.insert(strategies, "__namecall")
    end)

    _hookInstalled = #strategies > 0
    warn("[MSP] Active hooks: " .. (#strategies > 0 and table.concat(strategies, "+") or "NONE"))
end

-- ===================== PARRY FIRE ===================== --

local function DirectParry()
    if _parryRemote and _parryArgs then
        if _origFireServer then
            _origFireServer(_parryRemote, unpack(_parryArgs))
        else
            _parryRemote:FireServer(unpack(_parryArgs))
        end
    end
end

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

    if not _remoteCaptured then
        warn("[MSP] Remote not captured - do one manual parry first!")
        return
    end

    SpamEnabled = true
    spamSession = spamSession + 1
    local mySession = spamSession

    -- RATE-LIMITED spam - avoids server-side kick detection
    -- Old approach: 180 raw FireServer/sec = instant kick
    -- New approach: controlled rate + ParrySuccess instant re-fire
    -- Power 1 = 3/sec, Power 10 = 20/sec (enough for every ball bounce)
    local rate = 3 + (ParryPower - 1) * 17 / 9
    local interval = 1 / rate
    local lastFire = 0

    warn("[MSP] Spam ON - rate: " .. math.floor(rate) .. "/sec")

    -- Single Heartbeat connection with clock-based throttle
    spamConns[1] = RunService.Heartbeat:Connect(function()
        if not SpamEnabled or spamSession ~= mySession then return end
        local now = tick()
        if now - lastFire >= interval then
            lastFire = now
            pcall(DirectParry)
        end
    end)

    -- ParrySuccess = instant re-fire (bypasses rate limit)
    -- When server confirms a parry, fire again ASAP to catch the next bounce
    local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
    local parrySuccess = remotes and remotes:FindFirstChild("ParrySuccess")
    if parrySuccess then
        spamConns[2] = parrySuccess.OnClientEvent:Connect(function()
            if not SpamEnabled or spamSession ~= mySession then return end
            lastFire = tick()
            pcall(DirectParry)
        end)
    end
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
    if not _hookInstalled then
        label = 'NO HOOK'
        color = Color3.fromRGB(255, 80, 80)
    elseif not _remoteCaptured then
        label = 'PARRY 1x'
        color = Color3.fromRGB(255, 180, 50)
    elseif SpamEnabled then
        label = 'ON'
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

-- ==================== REMOTE CAPTURE WATCHER ==================== --
-- Poll until remote is captured, then update UI

task.spawn(function()
    while not _remoteCaptured do
        task.wait(0.5)
        UpdateStatus()
    end
    UpdateStatus()  -- show READY
end)

-- Initial status
UpdateStatus()

-- ==================== CLEANUP ==================== --

ScreenGui.Destroying:Connect(function()
    StopSpam()
end)
