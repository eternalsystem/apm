--[[
    Manual Spam Parry v2
    ForceUnlock: zeros u165/u163 every frame so EVERY firesignal reaches PRY
    No hookmetamethod, no VIM, no __namecall hook
]]

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

local activatedSignal = nil
local _getconnections = typeof(getconnections) == "function" and getconnections or nil
local _getinfo = typeof(getinfo) == "function" and getinfo or (typeof(debug) == "table" and typeof(debug.getinfo) == "function" and debug.getinfo) or nil
local _getupvalues = typeof(getupvalues) == "function" and getupvalues or (typeof(debug) == "table" and typeof(debug.getupvalues) == "function" and debug.getupvalues) or nil
local _setupvalue = typeof(setupvalue) == "function" and setupvalue or (typeof(debug) == "table" and typeof(debug.setupvalue) == "function" and debug.setupvalue) or nil

-- Cached reference to u177 (the inner parry handler function)
-- u177 upvalues: [1]=u162(stunned) [2]=u165(parrying) [3]=u163(animating) ... [12]=u166(1.3s)
local _cachedU177 = nil

local function FindU177()
    if _cachedU177 then return _cachedU177 end
    if not _getconnections or not _getinfo or not _getupvalues then return nil end

    local ok, result = pcall(function()
        local hotbar = Player.PlayerGui:FindFirstChild("Hotbar")
        if not hotbar then return nil end
        local block = hotbar:FindFirstChild("Block")
        if not block then return nil end

        for _, conn in ipairs(_getconnections(block.Activated)) do
            local fn = nil
            pcall(function() fn = conn.Function end)
            if not fn then continue end

            local info = nil
            pcall(function() info = _getinfo(fn) end)
            if not info or not info.source or not tostring(info.source):find("SwordsController") then continue end

            -- Conn#3 fn → UV[1] (wrapper) → UV[2] (u177)
            local uvs1 = nil
            pcall(function() uvs1 = _getupvalues(fn) end)
            if not uvs1 or type(uvs1[1]) ~= "function" then return nil end

            local uvs2 = nil
            pcall(function() uvs2 = _getupvalues(uvs1[1]) end)
            if not uvs2 or type(uvs2[2]) ~= "function" then return nil end

            return uvs2[2] -- u177
        end
        return nil
    end)

    if ok and result then
        _cachedU177 = result
    end
    return _cachedU177
end

-- Force u165=false, u163=false so the handler never blocks
-- Just 2 setupvalue calls = nearly free, no scanning
local function ForceUnlock()
    if not _setupvalue then return end
    local fn = FindU177()
    if not fn then return end
    pcall(_setupvalue, fn, 2, false)  -- u165 = false (parrying flag)
    pcall(_setupvalue, fn, 3, false)  -- u163 = false (animation flag)
end

-- Mute the click sound so firesignal doesn't spam audio
-- Handler #1 (ClickSFX) still runs (can't disconnect = kick), but sound is silent
local function MuteClickSound()
    pcall(function()
        local hotbar = Player.PlayerGui:FindFirstChild("Hotbar")
        if not hotbar then return end
        local block = hotbar:FindFirstChild("Block")
        if not block then return end
        for _, desc in block:GetDescendants() do
            if desc:IsA("Sound") then
                desc.Volume = 0
            end
        end
    end)
end

local function Setup()
    _cachedU177 = nil
    local hotbar = Player.PlayerGui:FindFirstChild("Hotbar")
    if not hotbar then return end
    local block = hotbar:FindFirstChild("Block")
    if not block then return end
    activatedSignal = block.Activated
    MuteClickSound()
    ForceUnlock()
end

Setup()

-- ===================== PARRY FIRE ===================== --

local function ParrySignal()
    if activatedSignal then
        firesignal(activatedSignal)
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
    SpamEnabled = true
    spamSession = spamSession + 1
    local mySession = spamSession
    local fireFn = ParrySignal

    ForceUnlock()

    -- ForceUnlock EVERY frame (2 setupvalue calls = near-zero cost)
    -- Fire at 60/sec — sound is muted so audio overhead is gone
    -- 60/sec = one attempt every 16ms = ~38 shots in the tightest window (625ms)
    local lastFire = 0
    spamConns[1] = RunService.Heartbeat:Connect(function()
        if not SpamEnabled or spamSession ~= mySession then return end
        ForceUnlock()
        local now = tick()
        if now - lastFire >= 0.016 then
            lastFire = now
            pcall(fireFn)
        end
    end)

    -- Instant re-fire on parry success — does NOT reset lastFire
    -- so it's a free bonus shot that doesn't delay the regular cycle
    local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
    local parryRemote = remotes and remotes:FindFirstChild("ParrySuccess")
    if parryRemote then
        spamConns[2] = parryRemote.OnClientEvent:Connect(function()
            if not SpamEnabled or spamSession ~= mySession then return end
            ForceUnlock()
            pcall(fireFn)
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
Panel.Size = UDim2.fromOffset(320, 198)
Panel.Position = UDim2.new(0.5, -160, 0.5, -99)
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

local StatusLabel = Instance.new('TextLabel')
StatusLabel.Name = 'Status'
StatusLabel.Size = UDim2.fromOffset(30, 14)
StatusLabel.Position = UDim2.fromOffset(125, 14)
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

-- Divider
local SectionDiv = Instance.new('Frame')
SectionDiv.Size = UDim2.new(1, 0, 0, 1)
SectionDiv.Position = UDim2.fromOffset(0, 138)
SectionDiv.BackgroundColor3 = C.divider
SectionDiv.BorderSizePixel = 0
SectionDiv.Parent = Panel

-- UI section
MakeSectionLabel(Panel, 144, 'UI')

local uiBindBtn, uiBindStroke = MakeRow(Panel, 160, 'Show / Hide')
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
    local label = SpamEnabled and 'ON' or 'OFF'
    local color = SpamEnabled and C.white or C.textDim
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

-- ==================== RESPAWN ==================== --

Player.CharacterAdded:Connect(function(char)
    task.delay(2, function()
        Setup()
    end)
end)

-- ==================== CLEANUP ==================== --

ScreenGui.Destroying:Connect(function()
    StopSpam()
end)
