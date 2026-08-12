--[[
    FORTER — ULTIMATE SCRIPT FOR XENO
    Версия: 10.9 (ESP И HP BAR ВЫКЛЮЧЕНЫ ПО УМОЛЧАНИЮ + БИНД HP)
    Исправлено: ESP и HP Bar теперь выключены при старте, HP Bar в Visuals
--]]

-- ===== СЕРВИСЫ =====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera

local player = Players.LocalPlayer
local character = player.Character
local humanoid = character and character:FindFirstChild("Humanoid")

-- ===== ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ =====
local flyEnabled = false
local espEnabled = false          -- ВЫКЛЮЧЕН ПО УМОЛЧАНИЮ
local espMode = "v1"
local menuOpen = false
local scriptActive = true
local dragging = false
local dragStart = nil
local dragStartPos = nil
local animating = false
local espCreating = false
local hpBarsEnabled = false       -- ВЫКЛЮЧЕН ПО УМОЛЧАНИЮ

-- ===== СИСТЕМА БИНДОВ =====
local bindings = {
    fly = nil,
    esp = nil,
    hp = nil,   -- НОВЫЙ БИНД ДЛЯ HP
    menu = Enum.KeyCode.LeftAlt
}

local waitingForBind = false
local bindingMode = nil

-- ============================================
-- ЧАСТЬ 1: ПОЛЁТ
-- ============================================
local flySpeed = 80
local bodyVelocity = nil
local bodyGyro = nil

local function startFly()
    if not character or not humanoid then return end
    if bodyVelocity then return end
    
    humanoid.PlatformStand = true
    local rootPart = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
    if not rootPart then return end
    
    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bodyVelocity.Parent = rootPart
    
    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.CFrame = rootPart.CFrame
    bodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    bodyGyro.Parent = rootPart
end

local function stopFly()
    if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
    if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
    if humanoid then humanoid.PlatformStand = false end
end

local function updateFly()
    if not flyEnabled or not scriptActive then
        stopFly()
        return
    end
    
    if not character or not humanoid then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
    if not rootPart then return end
    
    local moveDirection = Vector3.new(0, 0, 0)
    local cameraLook = Camera.CFrame.LookVector
    local cameraRight = Camera.CFrame.RightVector
    
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDirection = moveDirection + cameraLook end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDirection = moveDirection - cameraLook end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDirection = moveDirection - cameraRight end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDirection = moveDirection + cameraRight end
    
    if moveDirection.Magnitude > 0 then
        moveDirection = moveDirection.Unit * flySpeed
    end
    
    if bodyVelocity then
        bodyVelocity.Velocity = moveDirection
    end
    
    if bodyGyro and rootPart then
        bodyGyro.CFrame = CFrame.new(rootPart.Position, rootPart.Position + cameraLook * 10)
    end
end

-- ============================================
-- ЧАСТЬ 2: ESP
-- ============================================
local espFolder = Instance.new("Folder")
espFolder.Name = "ForterESP"
espFolder.Parent = CoreGui

local function createESPForPlayer(plr)
    if not plr or plr == player then return end
    if not espEnabled or not scriptActive then return end
    
    local userId = plr.UserId
    
    local oldHighlight = espFolder:FindFirstChild("ESP_" .. userId)
    if oldHighlight then oldHighlight:Destroy() end
    local oldGlow = espFolder:FindFirstChild("ESP_Glow_" .. userId)
    if oldGlow then oldGlow:Destroy() end
    
    local char = plr.Character
    if not char then return end
    
    local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
    if not rootPart then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_" .. userId
    highlight.Adornee = char
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    
    if espMode == "v1" then
        highlight.FillColor = Color3.fromRGB(0, 255, 128)
        highlight.FillTransparency = 0.25
        highlight.OutlineColor = Color3.fromRGB(0, 200, 100)
        highlight.OutlineTransparency = 0.05
        highlight.Parent = espFolder
    elseif espMode == "v2" then
        highlight.FillColor = Color3.fromRGB(255, 0, 0)
        highlight.FillTransparency = 1.0
        highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
        highlight.OutlineTransparency = 0.0
        highlight.Parent = espFolder
        
        local glowHighlight = Instance.new("Highlight")
        glowHighlight.Name = "ESP_Glow_" .. userId
        glowHighlight.Adornee = char
        glowHighlight.FillColor = Color3.fromRGB(255, 50, 50)
        glowHighlight.FillTransparency = 1.0
        glowHighlight.OutlineColor = Color3.fromRGB(255, 0, 0)
        glowHighlight.OutlineTransparency = 0.0
        glowHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        glowHighlight.Parent = espFolder
    end
end

local function createESPForAll()
    if espCreating then return end
    espCreating = true
    
    for _, child in ipairs(espFolder:GetChildren()) do
        child:Destroy()
    end
    
    if not espEnabled or not scriptActive then
        espCreating = false
        return
    end
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            createESPForPlayer(plr)
        end
    end
    
    espCreating = false
end

local function repairESP()
    if not espEnabled or not scriptActive or espCreating then return end
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local highlight = espFolder:FindFirstChild("ESP_" .. plr.UserId)
            local char = plr.Character
            
            if char and not highlight then
                createESPForPlayer(plr)
            end
            
            if highlight and char then
                if highlight.Adornee ~= char then
                    highlight.Adornee = char
                end
                local glow = espFolder:FindFirstChild("ESP_Glow_" .. plr.UserId)
                if glow and glow:IsA("Highlight") then
                    if glow.Adornee ~= char then
                        glow.Adornee = char
                    end
                end
            end
            
            if not char and highlight then
                highlight:Destroy()
                local glow = espFolder:FindFirstChild("ESP_Glow_" .. plr.UserId)
                if glow then glow:Destroy() end
            end
        end
    end
end

local function toggleESP()
    espEnabled = not espEnabled
    if espEnabled then
        createESPForAll()
    else
        for _, child in ipairs(espFolder:GetChildren()) do
            child:Destroy()
        end
    end
    if menuOpen then
        updateESPButtons()
        updateHPButton()
    end
end

local function setESPMode(mode)
    if mode ~= "v1" and mode ~= "v2" then return end
    espMode = mode
    if espEnabled then
        createESPForAll()
    end
    if menuOpen then
        updateESPButtons()
    end
end

-- ============================================
-- ЧАСТЬ 3: HP BAR
-- ============================================
local hpBarScreenGui = Instance.new("ScreenGui")
hpBarScreenGui.Name = "ForterHPBars"
hpBarScreenGui.Parent = CoreGui
hpBarScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
hpBarScreenGui.IgnoreGuiInset = true

local hpBarData = {}

local function createHPBar(plr)
    if not plr or plr == player then return end
    if not hpBarsEnabled or not scriptActive then return end
    
    local userId = plr.UserId
    local char = plr.Character
    if not char then return end
    
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    if hpBarData[userId] then
        if hpBarData[userId].frame then hpBarData[userId].frame:Destroy() end
        if hpBarData[userId].connection then hpBarData[userId].connection:Disconnect() end
        hpBarData[userId] = nil
    end
    
    local frame = Instance.new("Frame")
    frame.Name = "HPBar_" .. userId
    frame.Size = UDim2.new(0, 8, 0, 80)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 1
    frame.BorderColor3 = Color3.fromRGB(0, 0, 0)
    frame.Visible = true
    frame.ZIndex = 10
    frame.Parent = hpBarScreenGui
    
    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.Position = UDim2.new(0, 0, 0, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    fill.BorderSizePixel = 0
    fill.BackgroundTransparency = 0.1
    fill.Parent = frame
    
    hpBarData[userId] = {
        frame = frame,
        fill = fill,
        humanoid = humanoid,
        character = char,
        connection = nil
    }
    
    local function updateHP()
        local data = hpBarData[userId]
        if not data or not data.fill or not data.humanoid then return end
        local health = data.humanoid.Health
        local maxHealth = data.humanoid.MaxHealth
        local percent = math.clamp(health / maxHealth, 0, 1)
        
        data.fill.Size = UDim2.new(1, 0, percent, 0)
        data.fill.Position = UDim2.new(0, 0, 0, 0)
        
        local r = 1 - percent
        local g = percent
        data.fill.BackgroundColor3 = Color3.fromRGB(r * 255, g * 255, 0)
    end
    
    local connection = humanoid.HealthChanged:Connect(updateHP)
    hpBarData[userId].connection = connection
    
    task.wait(0.05)
    updateHP()
end

local function updateHPBarPositions()
    if not hpBarsEnabled or not scriptActive then return end
    
    local camera = workspace.CurrentCamera
    if not camera then return end
    
    for userId, data in pairs(hpBarData) do
        if not data or not data.frame then
            hpBarData[userId] = nil
            continue
        end
        
        local char = data.character
        if not char or not char.Parent then
            data.frame.Visible = false
            continue
        end
        
        local head = char:FindFirstChild("Head")
        if not head then
            data.frame.Visible = false
            continue
        end
        
        local headPos = head.Position + Vector3.new(-2.5, 0, 0)
        local screenPos, onScreen = camera:WorldToViewportPoint(headPos)
        
        if onScreen then
            data.frame.Visible = true
            data.frame.Position = UDim2.new(0, screenPos.X - 4, 0, screenPos.Y - 40)
        else
            data.frame.Visible = false
        end
    end
end

local function createHPBarsForAll()
    for userId, data in pairs(hpBarData) do
        if data and data.frame then data.frame:Destroy() end
        if data and data.connection then data.connection:Disconnect() end
    end
    hpBarData = {}
    
    for _, child in ipairs(hpBarScreenGui:GetChildren()) do
        child:Destroy()
    end
    
    if not hpBarsEnabled or not scriptActive then return end
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            task.spawn(function()
                task.wait(0.1)
                if plr.Character then
                    createHPBar(plr)
                end
            end)
        end
    end
end

local function repairHPBars()
    if not hpBarsEnabled or not scriptActive then return end
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local data = hpBarData[plr.UserId]
            local char = plr.Character
            
            if char and not data then
                createHPBar(plr)
            elseif data and char then
                data.character = char
                local humanoid = char:FindFirstChild("Humanoid")
                if humanoid and humanoid ~= data.humanoid then
                    if data.connection then data.connection:Disconnect() end
                    data.humanoid = humanoid
                    local function updateHP()
                        if not data or not data.fill or not data.humanoid then return end
                        local health = data.humanoid.Health
                        local maxHealth = data.humanoid.MaxHealth
                        local percent = math.clamp(health / maxHealth, 0, 1)
                        data.fill.Size = UDim2.new(1, 0, percent, 0)
                        data.fill.Position = UDim2.new(0, 0, 0, 0)
                        local r = 1 - percent
                        local g = percent
                        data.fill.BackgroundColor3 = Color3.fromRGB(r * 255, g * 255, 0)
                    end
                    data.connection = humanoid.HealthChanged:Connect(updateHP)
                    updateHP()
                end
            elseif not char and data then
                if data.frame then data.frame:Destroy() end
                if data.connection then data.connection:Disconnect() end
                hpBarData[plr.UserId] = nil
            end
        end
    end
end

local function toggleHPBars()
    hpBarsEnabled = not hpBarsEnabled
    if hpBarsEnabled then
        createHPBarsForAll()
    else
        for userId, data in pairs(hpBarData) do
            if data and data.frame then data.frame:Destroy() end
            if data and data.connection then data.connection:Disconnect() end
        end
        hpBarData = {}
        for _, child in ipairs(hpBarScreenGui:GetChildren()) do
            child:Destroy()
        end
    end
    if menuOpen then
        updateHPButton()
    end
end

-- ============================================
-- ЧАСТЬ 4: UI
-- ============================================
local espV1Btn = nil
local espV2Btn = nil
local hpVisualBtn = nil

function updateESPButtons()
    if mainTab and mainTab:IsA("Frame") then
        for _, child in ipairs(mainTab:GetChildren()) do
            if child:IsA("TextButton") and child.Name == "ESPMainBtn" then
                child.Text = espEnabled and "ESP: ON" or "ESP: OFF"
                child.BackgroundColor3 = espEnabled and Color3.fromRGB(0, 140, 70) or Color3.fromRGB(60, 50, 55)
            end
        end
    end
    
    if espV1Btn and espV2Btn then
        if espMode == "v1" then
            espV1Btn.BackgroundColor3 = Color3.fromRGB(180, 50, 60)
            espV1Btn.BackgroundTransparency = 0
            espV2Btn.BackgroundColor3 = Color3.fromRGB(40, 35, 45)
            espV2Btn.BackgroundTransparency = 0.3
        else
            espV2Btn.BackgroundColor3 = Color3.fromRGB(180, 50, 60)
            espV2Btn.BackgroundTransparency = 0
            espV1Btn.BackgroundColor3 = Color3.fromRGB(40, 35, 45)
            espV1Btn.BackgroundTransparency = 0.3
        end
    end
    
    if hpVisualBtn then
        hpVisualBtn.Text = hpBarsEnabled and "HP: ON" or "HP: OFF"
        hpVisualBtn.BackgroundColor3 = hpBarsEnabled and Color3.fromRGB(0, 140, 70) or Color3.fromRGB(60, 50, 55)
    end
end

function updateHPButton()
    if hpVisualBtn then
        hpVisualBtn.Text = hpBarsEnabled and "HP: ON" or "HP: OFF"
        hpVisualBtn.BackgroundColor3 = hpBarsEnabled and Color3.fromRGB(0, 140, 70) or Color3.fromRGB(60, 50, 55)
    end
end

-- ===== UI =====
local screenGui = Instance.new("ScreenGui")
screenGui.Parent = CoreGui
screenGui.Name = "ForterUI"
screenGui.Enabled = false

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 640, 0, 560)
mainFrame.Position = UDim2.new(0.5, -320, 0.5, -280)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 18, 22)
mainFrame.BackgroundTransparency = 0.08
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 16)
mainCorner.Parent = mainFrame

local shadow = Instance.new("Frame")
shadow.Size = UDim2.new(1, 0, 1, 0)
shadow.Position = UDim2.new(0, 0, 0, 0)
shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shadow.BackgroundTransparency = 0.6
shadow.BorderSizePixel = 0
shadow.ZIndex = 0
shadow.Parent = mainFrame

local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(0, 16)
shadowCorner.Parent = shadow

local container = Instance.new("Frame")
container.Size = UDim2.new(1, 0, 1, 0)
container.Position = UDim2.new(0, 0, 0, 0)
container.BackgroundTransparency = 1
container.ClipsDescendants = true
container.ZIndex = 1
container.Parent = mainFrame

local border = Instance.new("Frame")
border.Size = UDim2.new(1, 0, 1, 0)
border.Position = UDim2.new(0, 0, 0, 0)
border.BackgroundTransparency = 1
border.BorderSizePixel = 2
border.BorderColor3 = Color3.fromRGB(180, 50, 60)
border.ZIndex = 2
border.Parent = mainFrame

local borderCorner = Instance.new("UICorner")
borderCorner.CornerRadius = UDim.new(0, 16)
borderCorner.Parent = border

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 50)
titleBar.Position = UDim2.new(0, 0, 0, 0)
titleBar.BackgroundColor3 = Color3.fromRGB(180, 50, 60)
titleBar.BackgroundTransparency = 0.15
titleBar.BorderSizePixel = 0
titleBar.ZIndex = 3
titleBar.Parent = container

local titleBarCorner = Instance.new("UICorner")
titleBarCorner.CornerRadius = UDim.new(0, 16)
titleBarCorner.Parent = titleBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 1, 0)
title.Position = UDim2.new(0, 15, 0, 0)
title.BackgroundTransparency = 1
title.Text = "FORTER v10.9"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.ZIndex = 4
title.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 35, 0, 35)
closeBtn.Position = UDim2.new(1, -45, 0, 7)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
closeBtn.BackgroundTransparency = 0.3
closeBtn.BorderSizePixel = 0
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.ZIndex = 4
closeBtn.Parent = titleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
    toggleMenu(false)
end)

closeBtn.MouseEnter:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
end)
closeBtn.MouseLeave:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.3}):Play()
end)

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        dragStartPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            dragStartPos.X.Scale,
            dragStartPos.X.Offset + delta.X,
            dragStartPos.Y.Scale,
            dragStartPos.Y.Offset + delta.Y
        )
    end
end)

-- ===== ВКЛАДКИ =====
local tabFrame = Instance.new("Frame")
tabFrame.Size = UDim2.new(1, -20, 0, 45)
tabFrame.Position = UDim2.new(0, 10, 0, 55)
tabFrame.BackgroundTransparency = 1
tabFrame.ZIndex = 3
tabFrame.Parent = container

local tabs = {"Главная", "Visuals", "Бинды"}
local currentTab = 1
local tabButtons = {}

for i, name in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    local leftOffset = 10 + (i - 1) * 140
    btn.Size = UDim2.new(0, 130, 1, -8)
    btn.Position = UDim2.new(0, leftOffset, 0, 4)
    btn.BackgroundColor3 = (i == 1) and Color3.fromRGB(180, 50, 60) or Color3.fromRGB(40, 35, 45)
    btn.BackgroundTransparency = (i == 1) and 0 or 0.3
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(220, 210, 220)
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamSemibold
    btn.ZIndex = 4
    btn.Parent = tabFrame
    tabButtons[i] = btn
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn
    
    btn.MouseEnter:Connect(function()
        if currentTab ~= i then
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.1}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if currentTab ~= i then
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.3}):Play()
        end
    end)
    
    btn.MouseButton1Click:Connect(function()
        if currentTab == i then return end
        currentTab = i
        for j, b in ipairs(tabButtons) do
            local isActive = (j == i)
            TweenService:Create(b, TweenInfo.new(0.2), {
                BackgroundColor3 = isActive and Color3.fromRGB(180, 50, 60) or Color3.fromRGB(40, 35, 45),
                BackgroundTransparency = isActive and 0 or 0.3
            }):Play()
        end
        updateTabContent()
    end)
end

local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -20, 1, -115)
contentFrame.Position = UDim2.new(0, 10, 0, 105)
contentFrame.BackgroundTransparency = 1
contentFrame.ClipsDescendants = true
contentFrame.ZIndex = 3
contentFrame.Parent = container

-- ===== ВКЛАДКА ГЛАВНАЯ (БЕЗ HP) =====
local mainTab = nil

local function createMainTab()
    local tab = Instance.new("Frame")
    tab.Name = "Tab_Main"
    tab.Size = UDim2.new(1, 0, 1, 0)
    tab.BackgroundTransparency = 1
    tab.Visible = true
    tab.Parent = contentFrame
    
    local espBtn = Instance.new("TextButton")
    espBtn.Name = "ESPMainBtn"
    espBtn.Size = UDim2.new(0, 190, 0, 45)
    espBtn.Position = UDim2.new(0.05, 0, 0.03, 0)
    espBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 55)
    espBtn.BackgroundTransparency = 0.2
    espBtn.BorderSizePixel = 0
    espBtn.Text = "ESP: OFF"
    espBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    espBtn.TextScaled = true
    espBtn.Font = Enum.Font.GothamSemibold
    espBtn.ZIndex = 4
    espBtn.Parent = tab
    
    local espCorner = Instance.new("UICorner")
    espCorner.CornerRadius = UDim.new(0, 10)
    espCorner.Parent = espBtn
    
    espBtn.MouseButton1Click:Connect(function()
        toggleESP()
        espBtn.Text = espEnabled and "ESP: ON" or "ESP: OFF"
        espBtn.BackgroundColor3 = espEnabled and Color3.fromRGB(0, 140, 70) or Color3.fromRGB(60, 50, 55)
    end)
    
    local flyBtn = Instance.new("TextButton")
    flyBtn.Size = UDim2.new(0, 190, 0, 45)
    flyBtn.Position = UDim2.new(0.55, 0, 0.03, 0)
    flyBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 55)
    flyBtn.BackgroundTransparency = 0.2
    flyBtn.BorderSizePixel = 0
    flyBtn.Text = "FLY: OFF"
    flyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    flyBtn.TextScaled = true
    flyBtn.Font = Enum.Font.GothamSemibold
    flyBtn.ZIndex = 4
    flyBtn.Parent = tab
    
    local flyCorner = Instance.new("UICorner")
    flyCorner.CornerRadius = UDim.new(0, 10)
    flyCorner.Parent = flyBtn
    
    flyBtn.MouseButton1Click:Connect(function()
        flyEnabled = not flyEnabled
        flyBtn.Text = flyEnabled and "FLY: ON" or "FLY: OFF"
        flyBtn.BackgroundColor3 = flyEnabled and Color3.fromRGB(0, 140, 70) or Color3.fromRGB(60, 50, 55)
        if flyEnabled then
            startFly()
        else
            stopFly()
        end
    end)
    
    local shutdownBtn = Instance.new("TextButton")
    shutdownBtn.Size = UDim2.new(0.8, 0, 0, 50)
    shutdownBtn.Position = UDim2.new(0.1, 0, 0.78, 0)
    shutdownBtn.BackgroundColor3 = Color3.fromRGB(180, 30, 40)
    shutdownBtn.BackgroundTransparency = 0.1
    shutdownBtn.BorderSizePixel = 0
    shutdownBtn.Text = "🔴 ПОЛНОЕ ВЫКЛЮЧЕНИЕ"
    shutdownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    shutdownBtn.TextScaled = true
    shutdownBtn.Font = Enum.Font.GothamBold
    shutdownBtn.ZIndex = 4
    shutdownBtn.Parent = tab
    
    local shutdownCorner = Instance.new("UICorner")
    shutdownCorner.CornerRadius = UDim.new(0, 10)
    shutdownCorner.Parent = shutdownBtn
    
    shutdownBtn.MouseButton1Click:Connect(function()
        scriptActive = false
        flyEnabled = false
        espEnabled = false
        hpBarsEnabled = false
        stopFly()
        for _, child in ipairs(espFolder:GetChildren()) do
            child:Destroy()
        end
        for userId, data in pairs(hpBarData) do
            if data and data.frame then data.frame:Destroy() end
            if data and data.connection then data.connection:Disconnect() end
        end
        hpBarData = {}
        for _, child in ipairs(hpBarScreenGui:GetChildren()) do
            child:Destroy()
        end
        screenGui.Enabled = false
        menuOpen = false
        screenGui:Destroy()
        espFolder:Destroy()
        hpBarScreenGui:Destroy()
    end)
    
    return tab
end

-- ===== ВКЛАДКА VISUALS (С HP) =====
local function createVisualsTab()
    local tab = Instance.new("Frame")
    tab.Name = "Tab_Visuals"
    tab.Size = UDim2.new(1, 0, 1, 0)
    tab.BackgroundTransparency = 1
    tab.Visible = false
    tab.Parent = contentFrame
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 40)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "ВЫБЕРИТЕ РЕЖИМ ESP"
    titleLabel.TextColor3 = Color3.fromRGB(200, 190, 200)
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.ZIndex = 4
    titleLabel.Parent = tab
    
    local v1Btn = Instance.new("TextButton")
    v1Btn.Name = "ESPv1Btn"
    v1Btn.Size = UDim2.new(0.35, 0, 0, 70)
    v1Btn.Position = UDim2.new(0.1, 0, 0.2, 0)
    v1Btn.BackgroundColor3 = (espMode == "v1") and Color3.fromRGB(180, 50, 60) or Color3.fromRGB(40, 35, 45)
    v1Btn.BackgroundTransparency = (espMode == "v1") and 0 or 0.3
    v1Btn.BorderSizePixel = 0
    v1Btn.Text = "ESP v1\n(Заливка)"
    v1Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    v1Btn.TextScaled = true
    v1Btn.Font = Enum.Font.GothamSemibold
    v1Btn.ZIndex = 4
    v1Btn.Parent = tab
    
    local v1Corner = Instance.new("UICorner")
    v1Corner.CornerRadius = UDim.new(0, 12)
    v1Corner.Parent = v1Btn
    
    v1Btn.MouseButton1Click:Connect(function()
        setESPMode("v1")
        espV1Btn = v1Btn
        espV2Btn = v2Btn
        updateESPButtons()
    end)
    
    local v2Btn = Instance.new("TextButton")
    v2Btn.Name = "ESPv2Btn"
    v2Btn.Size = UDim2.new(0.35, 0, 0, 70)
    v2Btn.Position = UDim2.new(0.55, 0, 0.2, 0)
    v2Btn.BackgroundColor3 = (espMode == "v2") and Color3.fromRGB(180, 50, 60) or Color3.fromRGB(40, 35, 45)
    v2Btn.BackgroundTransparency = (espMode == "v2") and 0 or 0.3
    v2Btn.BorderSizePixel = 0
    v2Btn.Text = "ESP v2\n(Контур/Glow)"
    v2Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    v2Btn.TextScaled = true
    v2Btn.Font = Enum.Font.GothamSemibold
    v2Btn.ZIndex = 4
    v2Btn.Parent = tab
    
    local v2Corner = Instance.new("UICorner")
    v2Corner.CornerRadius = UDim.new(0, 12)
    v2Corner.Parent = v2Btn
    
    v2Btn.MouseButton1Click:Connect(function()
        setESPMode("v2")
        espV1Btn = v1Btn
        espV2Btn = v2Btn
        updateESPButtons()
    end)
    
    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(0.8, 0, 0, 40)
    descLabel.Position = UDim2.new(0.1, 0, 0.48, 0)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = "v1 — зелёная подсветка\nv2 — красный контур (без заливки)"
    descLabel.TextColor3 = Color3.fromRGB(150, 140, 150)
    descLabel.TextScaled = true
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.ZIndex = 4
    descLabel.Parent = tab
    
    -- ===== HP BAR BUTTON (В VISUALS) =====
    local hpBtn = Instance.new("TextButton")
    hpBtn.Name = "HPVisualBtn"
    hpBtn.Size = UDim2.new(0.8, 0, 0, 45)
    hpBtn.Position = UDim2.new(0.1, 0, 0.7, 0)
    hpBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 55)
    hpBtn.BackgroundTransparency = 0.2
    hpBtn.BorderSizePixel = 2
    hpBtn.BorderColor3 = Color3.fromRGB(180, 50, 60)
    hpBtn.Text = "HP: OFF"
    hpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    hpBtn.TextScaled = true
    hpBtn.Font = Enum.Font.GothamSemibold
    hpBtn.ZIndex = 4
    hpBtn.Parent = tab
    
    local hpCorner = Instance.new("UICorner")
    hpCorner.CornerRadius = UDim.new(0, 10)
    hpCorner.Parent = hpBtn
    
    hpBtn.MouseButton1Click:Connect(function()
        toggleHPBars()
        hpBtn.Text = hpBarsEnabled and "HP: ON" or "HP: OFF"
        hpBtn.BackgroundColor3 = hpBarsEnabled and Color3.fromRGB(0, 140, 70) or Color3.fromRGB(60, 50, 55)
    end)
    
    hpVisualBtn = hpBtn
    
    espV1Btn = v1Btn
    espV2Btn = v2Btn
    
    return tab
end

-- ===== ВКЛАДКА БИНДЫ (С HP) =====
local function createBindTab()
    local tab = Instance.new("Frame")
    tab.Name = "Tab_Binds"
    tab.Size = UDim2.new(1, 0, 1, 0)
    tab.BackgroundTransparency = 1
    tab.Visible = false
    tab.Parent = contentFrame
    
    local function createBindRow(name, bindKey)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 50)
        row.Position = UDim2.new(0, 0, #tab:GetChildren() * 0.14, 0)
        row.BackgroundTransparency = 1
        row.Parent = tab
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.35, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = name:upper()
        label.TextColor3 = Color3.fromRGB(200, 180, 190)
        label.TextScaled = true
        label.Font = Enum.Font.GothamSemibold
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.ZIndex = 4
        label.Parent = row
        
        local bindBtn = Instance.new("TextButton")
        bindBtn.Size = UDim2.new(0.35, 0, 0.7, 0)
        bindBtn.Position = UDim2.new(0.45, 0, 0.15, 0)
        local keyName = bindKey and tostring(bindKey):gsub("Enum.KeyCode.", "") or "Не назначена"
        bindBtn.Text = keyName
        bindBtn.BackgroundColor3 = Color3.fromRGB(40, 35, 45)
        bindBtn.BackgroundTransparency = 0.3
        bindBtn.BorderSizePixel = 0
        bindBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        bindBtn.TextScaled = true
        bindBtn.Font = Enum.Font.GothamSemibold
        bindBtn.ZIndex = 4
        bindBtn.Parent = row
        
        local bindCorner = Instance.new("UICorner")
        bindCorner.CornerRadius = UDim.new(0, 8)
        bindCorner.Parent = bindBtn
        
        bindBtn.MouseButton1Click:Connect(function()
            bindBtn.Text = "Нажми клавишу..."
            bindBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 60)
            bindBtn.BackgroundTransparency = 0
            waitingForBind = true
            bindingMode = name
            
            local con
            con = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if gameProcessed then return end
                if not waitingForBind or bindingMode ~= name then return end
                local key = input.KeyCode
                if key ~= Enum.KeyCode.Unknown then
                    bindings[name] = key
                    bindBtn.Text = tostring(key):gsub("Enum.KeyCode.", "")
                    bindBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 70)
                    bindBtn.BackgroundTransparency = 0.2
                    waitingForBind = false
                    bindingMode = nil
                    con:Disconnect()
                end
            end)
        end)
        
        return row
    end
    
    createBindRow("fly", bindings.fly)
    createBindRow("esp", bindings.esp)
    createBindRow("hp", bindings.hp)   -- НОВЫЙ БИНД ДЛЯ HP
    createBindRow("menu", bindings.menu)
    
    return tab
end

-- ===== ИНИЦИАЛИЗАЦИЯ ВКЛАДОК =====
mainTab = createMainTab()
local visualsTab = createVisualsTab()
local bindTab = createBindTab()
local tabContents = {mainTab, visualsTab, bindTab}

function updateTabContent()
    for i, tab in ipairs(tabContents) do
        tab.Visible = (i == currentTab)
    end
    if currentTab == 2 then
        updateESPButtons()
    end
end

updateTabContent()

-- ===== ФУНКЦИЯ ОТКРЫТИЯ/ЗАКРЫТИЯ МЕНЮ =====
function toggleMenu(open)
    if animating then return end
    menuOpen = open
    animating = true
    
    if open then
        screenGui.Enabled = true
        mainFrame.Size = UDim2.new(0, 0, 0, 0)
        mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
        mainFrame.BackgroundTransparency = 1
        
        local tween1 = TweenService:Create(mainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 640, 0, 560),
            Position = UDim2.new(0.5, -320, 0.5, -280)
        })
        local tween2 = TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0.08
        })
        
        tween1:Play()
        tween2:Play()
        tween1.Completed:Connect(function()
            animating = false
            updateESPButtons()
        end)
    else
        local tween1 = TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(0.5, 0, 0.5, 0)
        })
        local tween2 = TweenService:Create(mainFrame, TweenInfo.new(0.15), {
            BackgroundTransparency = 1
        })
        
        tween1:Play()
        tween2:Play()
        tween1.Completed:Connect(function()
            screenGui.Enabled = false
            animating = false
        end)
    end
end

-- ============================================
-- ЧАСТЬ 5: ОБРАБОТЧИКИ СОБЫТИЙ
-- ============================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if not scriptActive then return end
    local key = input.KeyCode
    if key == Enum.KeyCode.Unknown then return end
    
    -- FLY BIND
    if bindings.fly and key == bindings.fly then
        flyEnabled = not flyEnabled
        if flyEnabled then startFly() else stopFly() end
        if menuOpen then
            for _, child in ipairs(mainTab:GetChildren()) do
                if child:IsA("TextButton") and child.Text:find("FLY") then
                    child.Text = flyEnabled and "FLY: ON" or "FLY: OFF"
                    child.BackgroundColor3 = flyEnabled and Color3.fromRGB(0, 140, 70) or Color3.fromRGB(60, 50, 55)
                end
            end
        end
    end
    
    -- ESP BIND
    if bindings.esp and key == bindings.esp then
        toggleESP()
    end
    
    -- HP BIND (НОВЫЙ)
    if bindings.hp and key == bindings.hp then
        toggleHPBars()
        if menuOpen then
            updateESPButtons()
        end
    end
    
    -- MENU BIND
    if bindings.menu and key == bindings.menu then
        toggleMenu(not menuOpen)
    end
end)

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        task.wait(0.1)
        if espEnabled and scriptActive then
            createESPForPlayer(plr)
        end
        if hpBarsEnabled and scriptActive then
            createHPBar(plr)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(plr)
    local highlight = espFolder:FindFirstChild("ESP_" .. plr.UserId)
    if highlight then highlight:Destroy() end
    local glow = espFolder:FindFirstChild("ESP_Glow_" .. plr.UserId)
    if glow then glow:Destroy() end
    
    local data = hpBarData[plr.UserId]
    if data then
        if data.frame then data.frame:Destroy() end
        if data.connection then data.connection:Disconnect() end
        hpBarData[plr.UserId] = nil
    end
end)

task.spawn(function()
    while scriptActive do
        task.wait(3)
        if espEnabled and scriptActive then
            repairESP()
        end
        if hpBarsEnabled and scriptActive then
            repairHPBars()
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not scriptActive then return end
    if flyEnabled then
        updateFly()
    end
    updateHPBarPositions()
end)

-- ============================================
-- ИНИЦИАЛИЗАЦИЯ (ESP И HP ВЫКЛЮЧЕНЫ)
-- ============================================
task.wait(1)
if not character or not humanoid then
    player.CharacterAdded:Wait()
    character = player.Character
    humanoid = character:FindFirstChild("Humanoid")
end

-- ВСЁ ВЫКЛЮЧЕНО ПО УМОЛЧАНИЮ
espEnabled = false
espMode = "v1"
hpBarsEnabled = false

-- НЕ СОЗДАЁМ ESP И HP BAR ПРИ СТАРТЕ
print("FORTER v10.9 загружен! ESP и HP Bar выключены по умолчанию.")
print("Нажми Alt для меню. Включи их вручную.")
