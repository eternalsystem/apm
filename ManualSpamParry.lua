--[[
    Blade Ball Full Dump
    Decompiles all client scripts, creates a ZIP, uploads to gofile.io
    Requires: decompile(), getscripts(), request/http_request, writefile (optional)
]]

repeat task.wait() until game:IsLoaded()
task.wait(3) -- Let game fully load

local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")

-- ===================== GUI ===================== --

local oldGui = CoreGui:FindFirstChild("Dump_UI")
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Dump_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 1002
pcall(function() if gethui then ScreenGui.Parent = gethui() return end end)
if not ScreenGui.Parent then
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end end)
    ScreenGui.Parent = CoreGui
end

local BG = Instance.new("Frame")
BG.Size = UDim2.new(0, 420, 0, 300)
BG.Position = UDim2.new(0.5, -210, 0.5, -150)
BG.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
BG.BackgroundTransparency = 0.05
BG.BorderSizePixel = 0
BG.Active = true
BG.Draggable = true
BG.Parent = ScreenGui
Instance.new("UICorner", BG).CornerRadius = UDim.new(0, 8)

local TitleBar = Instance.new("TextLabel")
TitleBar.Size = UDim2.new(1, 0, 0, 28)
TitleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
TitleBar.Text = "  📦 Blade Ball Dumper"
TitleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleBar.TextSize = 13
TitleBar.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
TitleBar.TextXAlignment = Enum.TextXAlignment.Left
TitleBar.BorderSizePixel = 0
TitleBar.Parent = BG
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 8)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -32, 0, 0)
StatusLabel.Position = UDim2.fromOffset(16, 40)
StatusLabel.AutomaticSize = Enum.AutomaticSize.Y
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Ready to dump..."
StatusLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
StatusLabel.TextSize = 12
StatusLabel.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular)
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextYAlignment = Enum.TextYAlignment.Top
StatusLabel.TextWrapped = true
StatusLabel.Parent = BG

local ProgressBar = Instance.new("Frame")
ProgressBar.Size = UDim2.new(1, -32, 0, 6)
ProgressBar.Position = UDim2.new(0, 16, 1, -50)
ProgressBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ProgressBar.BorderSizePixel = 0
ProgressBar.Parent = BG
Instance.new("UICorner", ProgressBar).CornerRadius = UDim.new(1, 0)

local ProgressFill = Instance.new("Frame")
ProgressFill.Size = UDim2.new(0, 0, 1, 0)
ProgressFill.BackgroundColor3 = Color3.fromRGB(80, 140, 255)
ProgressFill.BorderSizePixel = 0
ProgressFill.Parent = ProgressBar
Instance.new("UICorner", ProgressFill).CornerRadius = UDim.new(1, 0)

local LinkLabel = Instance.new("TextButton")
LinkLabel.Size = UDim2.new(1, -32, 0, 28)
LinkLabel.Position = UDim2.new(0, 16, 1, -36)
LinkLabel.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
LinkLabel.Text = ""
LinkLabel.TextColor3 = Color3.fromRGB(100, 255, 120)
LinkLabel.TextSize = 11
LinkLabel.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.SemiBold)
LinkLabel.Visible = false
LinkLabel.AutoButtonColor = true
LinkLabel.BorderSizePixel = 0
LinkLabel.Parent = BG
Instance.new("UICorner", LinkLabel).CornerRadius = UDim.new(0, 5)

local function setStatus(text)
    StatusLabel.Text = text
end

local function setProgress(pct)
    ProgressFill.Size = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0)
end

local function notify(text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title = "Dumper", Text = text, Duration = 8})
    end)
end

-- ===================== REQUEST WRAPPER ===================== --

local _request = nil
if typeof(request) == "function" then _request = request
elseif typeof(http_request) == "function" then _request = http_request
elseif typeof(syn) == "table" and typeof(syn.request) == "function" then _request = syn.request
elseif typeof(http) == "table" and typeof(http.request) == "function" then _request = http.request
elseif typeof(fluxus) == "table" and typeof(fluxus.request) == "function" then _request = fluxus.request
end

-- ===================== ZIP BUILDER ===================== --

local function numToLE2(n)
    return string.char(n % 256, math.floor(n / 256) % 256)
end

local function numToLE4(n)
    return string.char(
        n % 256,
        math.floor(n / 256) % 256,
        math.floor(n / 65536) % 256,
        math.floor(n / 16777216) % 256
    )
end

-- CRC32 table
local crc32_table = {}
for i = 0, 255 do
    local c = i
    for _ = 1, 8 do
        if bit32.band(c, 1) == 1 then
            c = bit32.bxor(bit32.rshift(c, 1), 0xEDB88320)
        else
            c = bit32.rshift(c, 1)
        end
    end
    crc32_table[i] = c
end

local function crc32(data)
    local crc = 0xFFFFFFFF
    for i = 1, #data do
        local b = string.byte(data, i)
        crc = bit32.bxor(bit32.rshift(crc, 8), crc32_table[bit32.band(bit32.bxor(crc, b), 0xFF)])
    end
    return bit32.bxor(crc, 0xFFFFFFFF)
end

local function buildZip(files)
    -- files = {{name = "path/to/file.lua", data = "content"}, ...}
    local localHeaders = {}
    local centralEntries = {}
    local offset = 0

    for _, file in ipairs(files) do
        local name = file.name
        local data = file.data
        local crc = crc32(data)
        local size = #data
        local nameLen = #name

        -- Local file header
        local lh = table.concat({
            "PK\3\4",          -- signature
            numToLE2(20),      -- version needed
            numToLE2(0),       -- flags
            numToLE2(0),       -- compression (STORE)
            numToLE2(0),       -- mod time
            numToLE2(0),       -- mod date
            numToLE4(crc),     -- crc32
            numToLE4(size),    -- compressed size
            numToLE4(size),    -- uncompressed size
            numToLE2(nameLen), -- filename length
            numToLE2(0),       -- extra field length
            name,              -- filename
            data               -- file data
        })

        table.insert(localHeaders, lh)

        -- Central directory entry
        local ce = table.concat({
            "PK\1\2",          -- signature
            numToLE2(20),      -- version made by
            numToLE2(20),      -- version needed
            numToLE2(0),       -- flags
            numToLE2(0),       -- compression
            numToLE2(0),       -- mod time
            numToLE2(0),       -- mod date
            numToLE4(crc),     -- crc32
            numToLE4(size),    -- compressed size
            numToLE4(size),    -- uncompressed size
            numToLE2(nameLen), -- filename length
            numToLE2(0),       -- extra field length
            numToLE2(0),       -- comment length
            numToLE2(0),       -- disk start
            numToLE2(0),       -- internal attrs
            numToLE4(0),       -- external attrs
            numToLE4(offset),  -- local header offset
            name               -- filename
        })

        table.insert(centralEntries, ce)
        offset = offset + #lh
    end

    local centralDir = table.concat(centralEntries)
    local centralDirOffset = offset
    local centralDirSize = #centralDir

    -- End of central directory
    local eocd = table.concat({
        "PK\5\6",                    -- signature
        numToLE2(0),                 -- disk number
        numToLE2(0),                 -- central dir disk
        numToLE2(#files),            -- entries on disk
        numToLE2(#files),            -- total entries
        numToLE4(centralDirSize),    -- central dir size
        numToLE4(centralDirOffset),  -- central dir offset
        numToLE2(0)                  -- comment length
    })

    return table.concat(localHeaders) .. centralDir .. eocd
end

-- ===================== DECOMPILE ===================== --

local function safeDecompile(script)
    local ok, source = pcall(function()
        return decompile(script)
    end)
    if ok and source and #source > 0 then
        return source
    end
    -- Fallback: try to get Source property (won't work for most)
    local ok2, src2 = pcall(function() return script.Source end)
    if ok2 and src2 and #src2 > 0 then
        return src2
    end
    return "-- [Decompile failed for " .. script:GetFullName() .. "]"
end

local function getScriptPath(script)
    local path = script:GetFullName()
    -- Replace dots and special chars for filesystem
    path = path:gsub("%.", "/")
    -- Add extension
    if script:IsA("LocalScript") then
        path = path .. ".client.lua"
    elseif script:IsA("ModuleScript") then
        path = path .. ".module.lua"
    else
        path = path .. ".lua"
    end
    return path
end

-- ===================== MAIN ===================== --

task.spawn(function()
    -- Check capabilities
    if not typeof(decompile) == "function" then
        setStatus("❌ decompile() not available!")
        notify("ERROR: decompile missing")
        return
    end

    if not typeof(getscripts) == "function" then
        setStatus("❌ getscripts() not available!")
        notify("ERROR: getscripts missing")
        return
    end

    if not _request then
        setStatus("❌ request/http_request not available!")
        notify("ERROR: request missing")
        return
    end

    setStatus("📋 Collecting scripts...")
    setProgress(0)

    -- Get all scripts
    local allScripts = {}
    pcall(function()
        for _, s in ipairs(getscripts()) do
            if s:IsA("LocalScript") or s:IsA("ModuleScript") then
                table.insert(allScripts, s)
            end
        end
    end)

    -- Also manually scan key locations
    local locations = {
        game:GetService("ReplicatedStorage"),
        game:GetService("ReplicatedFirst"),
        game:GetService("StarterPlayer"),
        game:GetService("StarterGui"),
    }

    local seen = {}
    for _, s in ipairs(allScripts) do
        seen[s] = true
    end

    for _, loc in ipairs(locations) do
        pcall(function()
            for _, desc in ipairs(loc:GetDescendants()) do
                if (desc:IsA("LocalScript") or desc:IsA("ModuleScript")) and not seen[desc] then
                    seen[desc] = true
                    table.insert(allScripts, desc)
                end
            end
        end)
    end

    local total = #allScripts
    setStatus("📋 Found " .. total .. " scripts\n🔧 Decompiling...")

    -- Decompile all
    local files = {}
    local decompiled = 0
    local failed = 0

    for i, script in ipairs(allScripts) do
        local path = getScriptPath(script)
        local ok, source = pcall(safeDecompile, script)

        if ok and source then
            table.insert(files, {
                name = path,
                data = source
            })
            decompiled = decompiled + 1
        else
            failed = failed + 1
            table.insert(files, {
                name = path,
                data = "-- [DECOMPILE FAILED]\n-- Error: " .. tostring(source)
            })
        end

        if i % 5 == 0 or i == total then
            setProgress(i / total * 0.6)
            setStatus(
                "🔧 Decompiling: " .. i .. "/" .. total ..
                "\n✅ OK: " .. decompiled .. " | ❌ Failed: " .. failed ..
                "\n📄 Current: " .. path:sub(1, 50)
            )
            task.wait() -- Yield to prevent timeout
        end
    end

    -- Add an index file
    local indexContent = "-- Blade Ball Client Dump\n"
    indexContent = indexContent .. "-- Date: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
    indexContent = indexContent .. "-- Total scripts: " .. total .. "\n"
    indexContent = indexContent .. "-- Decompiled: " .. decompiled .. "\n"
    indexContent = indexContent .. "-- Failed: " .. failed .. "\n\n"
    indexContent = indexContent .. "-- File list:\n"
    for _, f in ipairs(files) do
        indexContent = indexContent .. "--   " .. f.name .. " (" .. #f.data .. " bytes)\n"
    end
    table.insert(files, 1, {name = "_INDEX.lua", data = indexContent})

    setStatus(
        "✅ Decompiled: " .. decompiled .. "/" .. total ..
        "\n📦 Building ZIP (" .. #files .. " files)..."
    )
    setProgress(0.65)
    task.wait()

    -- Build ZIP
    local zipData = buildZip(files)

    setStatus(
        "✅ ZIP built: " .. math.floor(#zipData / 1024) .. " KB" ..
        "\n☁️ Getting gofile server..."
    )
    setProgress(0.75)

    -- Also save locally if possible
    pcall(function()
        writefile("BladeBall_Dump.zip", zipData)
        setStatus(StatusLabel.Text .. "\n💾 Also saved to workspace/BladeBall_Dump.zip")
    end)

    -- Get gofile server
    local serverName = nil
    local ok1, res1 = pcall(function()
        return _request({
            Url = "https://api.gofile.io/servers",
            Method = "GET"
        })
    end)

    if ok1 and res1 and res1.Body then
        local ok2, data = pcall(function()
            return HttpService:JSONDecode(res1.Body)
        end)
        if ok2 and data and data.data and data.data.servers then
            for _, srv in ipairs(data.data.servers) do
                serverName = srv.name
                break
            end
        end
    end

    if not serverName then
        serverName = "store1" -- fallback
    end

    setStatus(
        "✅ ZIP: " .. math.floor(#zipData / 1024) .. " KB" ..
        "\n☁️ Uploading to " .. serverName .. ".gofile.io..."
    )
    setProgress(0.85)

    -- Upload to gofile via multipart
    local boundary = "----BladeBallDump" .. tostring(math.random(100000, 999999))
    local fileName = "BladeBall_Dump_" .. os.date("%Y%m%d_%H%M%S") .. ".zip"

    local multipartBody = table.concat({
        "--" .. boundary .. "\r\n",
        'Content-Disposition: form-data; name="file"; filename="' .. fileName .. '"\r\n',
        "Content-Type: application/zip\r\n",
        "\r\n",
        zipData,
        "\r\n",
        "--" .. boundary .. "--\r\n"
    })

    local uploadUrl = "https://" .. serverName .. ".gofile.io/contents/uploadfile"

    local ok3, res3 = pcall(function()
        return _request({
            Url = uploadUrl,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "multipart/form-data; boundary=" .. boundary
            },
            Body = multipartBody
        })
    end)

    setProgress(1)

    if ok3 and res3 and res3.Body then
        local ok4, uploadData = pcall(function()
            return HttpService:JSONDecode(res3.Body)
        end)

        if ok4 and uploadData and uploadData.status == "ok" and uploadData.data then
            local downloadPage = uploadData.data.downloadPage
            local code = uploadData.data.code or uploadData.data.fileId or "?"

            setStatus(
                "✅ UPLOAD COMPLETE!\n\n" ..
                "📦 " .. #files .. " files (" .. math.floor(#zipData / 1024) .. " KB)\n" ..
                "🔗 " .. (downloadPage or ("https://gofile.io/d/" .. code))
            )

            local link = downloadPage or ("https://gofile.io/d/" .. code)
            LinkLabel.Text = "  📋 " .. link .. "  (click to copy)"
            LinkLabel.Visible = true
            LinkLabel.MouseButton1Click:Connect(function()
                pcall(function()
                    setclipboard(link)
                    LinkLabel.Text = "  ✅ Copied!"
                    notify("Link copied!")
                    task.delay(2, function()
                        if LinkLabel.Parent then
                            LinkLabel.Text = "  📋 " .. link .. "  (click to copy)"
                        end
                    end)
                end)
            end)

            notify("Upload done! " .. link)
        else
            local errMsg = res3.Body:sub(1, 100)
            setStatus(
                "❌ Upload response error\n" ..
                "Response: " .. errMsg .. "\n\n" ..
                "💾 ZIP saved locally: workspace/BladeBall_Dump.zip"
            )
            notify("Upload failed - saved locally")
        end
    else
        local errMsg = ok3 and "No response body" or tostring(res3)
        setStatus(
            "❌ Upload failed: " .. errMsg:sub(1, 80) .. "\n\n" ..
            "💾 ZIP saved locally: workspace/BladeBall_Dump.zip"
        )
        notify("Upload failed - saved locally")
    end
end)
