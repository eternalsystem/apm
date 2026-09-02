--[[
    Manual Spam Parry — Keypress Mode
    Toggle UI with RightShift
]]

repeat task.wait() until game:IsLoaded()

local Players            = game:GetService('Players')
local Player             = Players.LocalPlayer
local UserInputService   = game:GetService('UserInputService')
local RunService         = game:GetService('RunService')
local CoreGui            = game:GetService('CoreGui')
local TweenService       = game:GetService('TweenService')
local VirtualInputManager = game:GetService("VirtualInputManager")

local SpamEnabled   = false
local AnimFixEnabled = false
local Connections    = {}

-- ===================== SPAM LOGIC ===================== --

local function SpamKeypress()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
end

local function StartSpam()
    Connections['Spam'] = RunService.PreSimulation:Connect(function()
        SpamKeypress()
    end)
    if AnimFixEnabled then
        Connections['AnimFix'] = RunService.PreSimulation:Connect(function()
            SpamKeypress()
        end)
    end
end

local function StopSpam()
    if Connections['Spam'] then
        Connections['Spam']:Disconnect()
        Connections['Spam'] = nil
    end
    if Connections['AnimFix'] then
        Connections['AnimFix']:Disconnect()
        Connections['AnimFix'] = nil
    end
end

local function UpdateAnimFix()
    if Connections['AnimFix'] then
        Connections['AnimFix']:Disconnect()
        Connections['AnimFix'] = nil
    end
    if SpamEnabled and AnimFixEnabled then
        Connections['AnimFix'] = RunService.PreSimulation:Connect(function()
            SpamKeypress()
        end)
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
ScreenGui.Parent = CoreGui

local Panel = Instance.new('Frame')
Panel.Name = 'Panel'
Panel.Size = UDim2.fromOffset(220, 130)
Panel.Position = UDim2.new(0.5, -110, 0.5, -65)
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

local function MakeToggle(yPos, label, default, onChange)
    local row = Instance.new('Frame')
    row.Size = UDim2.new(1, -20, 0, 28)
    row.Position = UDim2.new(0, 10, 0, yPos)
    row.BackgroundTransparency = 1
    row.Parent = Panel

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
    Instance.new('UICorner', btn).CornerRadius = UDim.new(0, 6)

    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = state and 'ON' or 'OFF'
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = state and Color3.fromRGB(120, 0, 0) or Color3.fromRGB(40, 40, 46)
        }):Play()
        onChange(state)
    end)
end

MakeToggle(38, 'Spam Parry', false, function(v)
    SpamEnabled = v
    if v then StartSpam() else StopSpam() end
end)

MakeToggle(70, 'Animation Fix', false, function(v)
    AnimFixEnabled = v
    UpdateAnimFix()
end)

local hint = Instance.new('TextLabel')
hint.Size = UDim2.new(1, 0, 0, 18)
hint.Position = UDim2.new(0, 0, 1, -18)
hint.BackgroundTransparency = 1
hint.Text = 'RightShift to toggle UI'
hint.TextColor3 = Color3.fromRGB(80, 80, 88)
hint.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Regular)
hint.TextSize = 9
hint.Parent = Panel

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        Panel.Visible = not Panel.Visible
    end
end)

ScreenGui.Destroying:Connect(function()
    StopSpam()
end)
