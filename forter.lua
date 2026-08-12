--[[
    FORTER — ULTIMATE SCRIPT FOR XENO
    Версия: 8.1 (ИСПРАВЛЕНИЕ ESP V1 И V2)
    Исправлено: обновление после респавна, работа V2 на всех игроках, чистый контур
--]]

-- ===== СЕРВИСЫ =====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Camera = workspace.CurrentCamera

local player = Players.LocalPlayer
local character = player.Character
local humanoid = character and character:FindFirstChild("Humanoid")

-- ===== ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ =====
local flyEnabled = false
local espEnabled = false
local espMode = "v1" -- "v1" или "v2"
local menuOpen = false
local scriptActive = true
local dragging = false
local dragStart = nil
local dragStartPos = nil

-- ===== СИСТЕМА БИНДОВ =====
local bindings = {
    fly = nil,
    esp = nil,
    menu = Enum.KeyCode.LeftAlt
}

local waitingForBind = false
local bindingMode = nil

-- ===== ПОЛЁТ =====
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

-- ===== ESP (ДВА РЕЖИМА) =====
local espFolder = Instance.new("Folder")
espFolder.Name = "ForterESP"
espFolder.Parent = CoreGui

-- Создание ESP для одного игрока (режим v1 или v2)
local function createESPForPlayer(plr)
    if not plr or plr == player then return end
    if not espEnabled or not scriptActive then return end
    
    local userId = plr.UserId
    
    -- Удаляем все старые объекты ESP для этого игрока
    local oldHighlight = espFolder:FindFirstChild("ESP_" .. userId)
    if oldHighlight then oldHighlight:Destroy() end
    local oldGlow = espFolder:FindFirstChild("ESP_Glow_" .. userId)
    if oldGlow then oldGlow:Destroy() end
    
    local char = plr.Character
    if not char then return end
    
    -- Ждём полной загрузки персонажа
    local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
    if not rootPart then return end
    
    -- Основной Highlight
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_" .. userId
    highlight.Adornee = char
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    
    if espMode == "v1" then
        -- ESP v1: заливка зелёным + контур
        highlight.FillColor = Color3.fromRGB(0, 255, 128)
        highlight.FillTransparency = 0.25
        highlight.OutlineColor = Color3.fromRGB(0, 200, 100)
        highlight.OutlineTransparency = 0.05
        highlight.Parent = espFolder
        
    elseif espMode == "v2" then
        -- ESP v2: ТОЛЬКО КОНТУР (красный), без заливки
        highlight.FillColor = Color3.fromRGB(255, 0, 0)
        highlight.FillTransparency = 1.0  -- ПОЛНОСТЬЮ ПРОЗРАЧНАЯ ЗАЛИВКА
        highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
        highlight.OutlineTransparency = 0.0  -- ЯРКИЙ КОНТУР
        highlight.Parent = espFolder
        
        -- ДОПОЛНИТЕЛЬНЫЙ GLOW-СЛОЙ для усиления эффекта обводки
        local glowHighlight = Instance.new("Highlight")
        glowHighlight.Name = "ESP_Glow_" .. userId
        glowHighlight.Adornee = char
        glowHighlight.FillColor = Color3.fromRGB(255, 50, 50)
        glowHighlight.FillTransparency = 1.0  -- ТОЖЕ ПОЛНОСТЬЮ ПРОЗРАЧНЫЙ
        glowHighlight.OutlineColor = Color3.fromRGB(255, 0, 0)
        glowHighlight.OutlineTransparency = 0.0
        glowHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        glowHighlight.Parent = espFolder
    end
end

-- Создание ESP для всех игроков
local function createESPForAll()
    -- Удаляем все старые ESP
    for _, child in ipairs(espFolder:GetChildren()) do
        child:Destroy()
    end
    
    if not espEnabled or not scriptActive then
        return
    end
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            createESPForPlayer(plr)
        end
    end
end

-- Функция проверки и восстановления ESP (вызывается каждые 1.5 сек)
local function repairESP()
    if not espEnabled or not scriptActive then return end
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local highlight = espFolder:FindFirstChild("ESP_" .. plr.UserId)
            local char = plr.Character
            
            -- Если персонаж есть, а ESP нет - создаём
            if char and not highlight then
                createESPForPlayer(plr)
            end
            
            -- Если ESP есть, но персонаж изменился - обновляем Adornee
            if highlight and char then
                if highlight.Adornee ~= char then
                    highlight.Adornee = char
                end
                -- Обновляем glow если есть
                local glow = espFolder:FindFirstChild("ESP_Glow_" .. plr.UserId)
                if glow and glow:IsA("Highlight") then
                    if glow.Adornee ~= char then
                        glow.Adornee = char
                    end
                end
            end
            
            -- Если персонажа нет, а ESP есть - удаляем
            if not char and highlight then
                highlight:Destroy()
                local glow = espFolder:FindFirstChild("ESP_Glow_" .. plr.UserId)
                if glow then glow:Destroy() end
            end
        end
    end
end

-- Переключение ESP
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
    end
end

-- Смена режима ESP
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

-- Обновление кнопок ESP в UI
local function updateESPButtons()
    for _, child in ipairs(mainTab:GetChildren()) do
        if child:IsA("TextButton") and child.Name == "ESPMainBtn" then
            child.Text = espEnabled and "ESP: ON" or "ESP: OFF"
            child.BackgroundColor3 = espEnabled and Color3.fromRGB(0, 120, 60) or Color3.fromRGB(60, 50, 55)
        end
    end
    if visualsTab then
        for _, child in ipairs(visualsTab:GetChildren()) do
            if child:IsA("TextButton") then
                if child.Name == "ESPv1Btn" then
                    child.BackgroundColor3 = (espMode == "v1") and Color3.fromRGB(128, 0, 32) or Color3.fromRGB(45, 35, 40)
                elseif child.Name == "ESPv2Btn" then
                    child.BackgroundColor3 = (espMode == "v2") and Color3.fromRGB(128, 0, 32) or Color3.fromRGB(45, 35, 40)
                end
            end
        end
    end
end

-- ===== UI МЕНЮ =====
local screenGui = Instance.new("ScreenGui")
screenGui.Parent = CoreGui
screenGui.Name = "ForterUI"
screenGui.Enabled = false

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 640, 0, 560)
mainFrame.Position = UDim2.new(0.5, -320, 0.5, -280)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 20, 22)
mainFrame.BackgroundTransparency = 0.05
mainFrame.BorderSizePixel = 3
mainFrame.BorderColor3 = Color3.fromRGB(128, 0, 32)
mainFrame.Parent = screenGui

-- Заголовок
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 45)
titleBar.Position = UDim2.new(0, 0, 0, 0)
titleBar.BackgroundColor3 = Color3.fromRGB(128, 0, 32)
titleBar.BackgroundTransparency = 0.2
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "FORTER v8.1"
title.TextColor3 = Color3.fromRGB(200, 180, 190)
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 1, -10)
closeBtn.Position = UDim2.new(1, -50, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(128, 0, 32)
closeBtn.BackgroundTransparency = 0.3
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = titleBar
closeBtn.MouseButton1Click:Connect(function()
    menuOpen = false
    screenGui.Enabled = false
end)

-- ===== ПЕРЕТАСКИВАНИЕ МЕНЮ =====
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
tabFrame.Size = UDim2.new(1, 0, 0, 40)
tabFrame.Position = UDim2.new(0, 0, 0, 45)
tabFrame.BackgroundTransparency = 1
tabFrame.Parent = mainFrame

local tabs = {"Главная", "Visuals", "Бинды"}
local currentTab = 1
local tabButtons = {}

for i, name in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    local leftOffset = 15 + (i - 1) * 145
    btn.Size = UDim2.new(0, 130, 1, -6)
    btn.Position = UDim2.new(0, leftOffset, 0, 3)
    btn.BackgroundColor3 = (i == 1) and Color3.fromRGB(128, 0, 32) or Color3.fromRGB(45, 35, 40)
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(220, 200, 210)
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamSemibold
    btn.Parent = tabFrame
    tabButtons[i] = btn
    
    btn.MouseButton1Click:Connect(function()
        currentTab = i
        for j, b in ipairs(tabButtons) do
            b.BackgroundColor3 = (j == i) and Color3.fromRGB(128, 0, 32) or Color3.fromRGB(45, 35, 40)
        end
        updateTabContent()
    end)
end

local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -20, 1, -105)
contentFrame.Position = UDim2.new(0, 10, 0, 90)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

-- ===== ВКЛАДКА ГЛАВНАЯ =====
local mainTab = nil

local function createMainTab()
    local tab = Instance.new("Frame")
    tab.Size = UDim2.new(1, 0, 1, 0)
    tab.BackgroundTransparency = 1
    tab.Visible = true
    tab.Parent = contentFrame
    
    local espBtn = Instance.new("TextButton")
    espBtn.Name = "ESPMainBtn"
    espBtn.Size = UDim2.new(0, 200, 0, 50)
    espBtn.Position = UDim2.new(0.05, 0, 0.05, 0)
    espBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 55)
    espBtn.BorderSizePixel = 2
    espBtn.BorderColor3 = Color3.fromRGB(128, 0, 32)
    espBtn.Text = "ESP: ON"
    espBtn.TextColor3 = Color3.fromRGB(240, 220, 230)
    espBtn.TextScaled = true
    espBtn.Font = Enum.Font.GothamSemibold
    espBtn.Parent = tab
    espBtn.MouseButton1Click:Connect(function()
        toggleESP()
    end)
    
    local flyBtn = Instance.new("TextButton")
    flyBtn.Size = UDim2.new(0, 200, 0, 50)
    flyBtn.Position = UDim2.new(0.55, 0, 0.05, 0)
    flyBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 55)
    flyBtn.BorderSizePixel = 2
    flyBtn.BorderColor3 = Color3.fromRGB(128, 0, 32)
    flyBtn.Text = "FLY: OFF"
    flyBtn.TextColor3 = Color3.fromRGB(240, 220, 230)
    flyBtn.TextScaled = true
    flyBtn.Font = Enum.Font.GothamSemibold
    flyBtn.Parent = tab
    flyBtn.MouseButton1Click:Connect(function()
        flyEnabled = not flyEnabled
        flyBtn.Text = flyEnabled and "FLY: ON" or "FLY: OFF"
        flyBtn.BackgroundColor3 = flyEnabled and Color3.fromRGB(0, 120, 60) or Color3.fromRGB(60, 50, 55)
        if flyEnabled then
            startFly()
        else
            stopFly()
        end
    end)
    
    local shutdownBtn = Instance.new("TextButton")
    shutdownBtn.Size = UDim2.new(0.8, 0, 0, 55)
    shutdownBtn.Position = UDim2.new(0.1, 0, 0.78, 0)
    shutdownBtn.BackgroundColor3 = Color3.fromRGB(128, 0, 32)
    shutdownBtn.BorderSizePixel = 0
    shutdownBtn.Text = "🔴 ПОЛНОЕ ВЫКЛЮЧЕНИЕ"
    shutdownBtn.TextColor3 = Color3.fromRGB(255, 240, 245)
    shutdownBtn.TextScaled = true
    shutdownBtn.Font = Enum.Font.GothamBold
    shutdownBtn.Parent = tab
    shutdownBtn.MouseButton1Click:Connect(function()
        scriptActive = false
        flyEnabled = false
        espEnabled = false
        stopFly()
        for _, child in ipairs(espFolder:GetChildren()) do
            child:Destroy()
        end
        screenGui.Enabled = false
        menuOpen = false
        screenGui:Destroy()
        espFolder:Destroy()
    end)
    
    return tab
end

-- ===== ВКЛАДКА VISUALS =====
local visualsTab = nil

local function createVisualsTab()
    local tab = Instance.new("Frame")
    tab.Size = UDim2.new(1, 0, 1, 0)
    tab.BackgroundTransparency = 1
    tab.Visible = false
    tab.Parent = contentFrame
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 40)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "ВЫБЕРИТЕ РЕЖИМ ESP"
    titleLabel.TextColor3 = Color3.fromRGB(200, 180, 190)
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = tab
    
    -- ESP v1
    local espV1Btn = Instance.new("TextButton")
    espV1Btn.Name = "ESPv1Btn"
    espV1Btn.Size = UDim2.new(0.35, 0, 0, 80)
    espV1Btn.Position = UDim2.new(0.1, 0, 0.2, 0)
    espV1Btn.BackgroundColor3 = (espMode == "v1") and Color3.fromRGB(128, 0, 32) or Color3.fromRGB(45, 35, 40)
    espV1Btn.BorderSizePixel = 2
    espV1Btn.BorderColor3 = Color3.fromRGB(128, 0, 32)
    espV1Btn.Text = "ESP v1\n(Заливка)"
    espV1Btn.TextColor3 = Color3.fromRGB(240, 220, 230)
    espV1Btn.TextScaled = true
    espV1Btn.Font = Enum.Font.GothamSemibold
    espV1Btn.Parent = tab
    espV1Btn.MouseButton1Click:Connect(function()
        setESPMode("v1")
    end)
    
    -- ESP v2 (Glow)
    local espV2Btn = Instance.new("TextButton")
    espV2Btn.Name = "ESPv2Btn"
    espV2Btn.Size = UDim2.new(0.35, 0, 0, 80)
    espV2Btn.Position = UDim2.new(0.55, 0, 0.2, 0)
    espV2Btn.BackgroundColor3 = (espMode == "v2") and Color3.fromRGB(128, 0, 32) or Color3.fromRGB(45, 35, 40)
    espV2Btn.BorderSizePixel = 2
    espV2Btn.BorderColor3 = Color3.fromRGB(128, 0, 32)
    espV2Btn.Text = "ESP v2\n(Контур/Glow)"
    espV2Btn.TextColor3 = Color3.fromRGB(240, 220, 230)
    espV2Btn.TextScaled = true
    espV2Btn.Font = Enum.Font.GothamSemibold
    espV2Btn.Parent = tab
    espV2Btn.MouseButton1Click:Connect(function()
        setESPMode("v2")
    end)
    
    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(0.8, 0, 0, 50)
    descLabel.Position = UDim2.new(0.1, 0, 0.5, 0)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = "v1 — зелёная подсветка персонажа\nv2 — красный контур/обводка (без заливки)"
    descLabel.TextColor3 = Color3.fromRGB(150, 140, 150)
    descLabel.TextScaled = true
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.Parent = tab
    
    return tab
end

-- ===== ВКЛАДКА БИНДЫ =====
local function createBindTab()
    local tab = Instance.new("Frame")
    tab.Size = UDim2.new(1, 0, 1, 0)
    tab.BackgroundTransparency = 1
    tab.Visible = false
    tab.Parent = contentFrame
    
    local function createBindRow(name, bindKey)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 55)
        row.Position = UDim2.new(0, 0, #tab:GetChildren() * 0.13, 0)
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
        label.Parent = row
        
        local bindBtn = Instance.new("TextButton")
        bindBtn.Size = UDim2.new(0.35, 0, 0.7, 0)
        bindBtn.Position = UDim2.new(0.45, 0, 0.15, 0)
        local keyName = bindKey and tostring(bindKey):gsub("Enum.KeyCode.", "") or "Не назначена"
        bindBtn.Text = keyName
        bindBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 40)
        bindBtn.BorderSizePixel = 2
        bindBtn.BorderColor3 = Color3.fromRGB(128, 0, 32)
        bindBtn.TextColor3 = Color3.fromRGB(240, 220, 230)
        bindBtn.TextScaled = true
        bindBtn.Font = Enum.Font.GothamSemibold
        bindBtn.Parent = row
        
        bindBtn.MouseButton1Click:Connect(function()
            bindBtn.Text = "Нажми клавишу..."
            bindBtn.BackgroundColor3 = Color3.fromRGB(128, 0, 32)
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
                    bindBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 60)
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
    createBindRow("menu", bindings.menu)
    
    return tab
end

-- ===== ОБНОВЛЕНИЕ ВКЛАДОК =====
mainTab = createMainTab()
visualsTab = createVisualsTab()
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

-- ===== ОБРАБОТЧИК БИНДОВ =====
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if not scriptActive then return end
    local key = input.KeyCode
    if key == Enum.KeyCode.Unknown then return end
    
    if bindings.fly and key == bindings.fly then
        flyEnabled = not flyEnabled
        if flyEnabled then startFly() else stopFly() end
        if menuOpen then
            for _, child in ipairs(mainTab:GetChildren()) do
                if child:IsA("TextButton") and child.Text:find("FLY") then
                    child.Text = flyEnabled and "FLY: ON" or "FLY: OFF"
                    child.BackgroundColor3 = flyEnabled and Color3.fromRGB(0, 120, 60) or Color3.fromRGB(60, 50, 55)
                end
            end
        end
    end
    
    if bindings.esp and key == bindings.esp then
        toggleESP()
    end
    
    if bindings.menu and key == bindings.menu then
        menuOpen = not menuOpen
        screenGui.Enabled = menuOpen
        if menuOpen then
            updateESPButtons()
        end
    end
end)

-- ===== ОБРАБОТЧИКИ ИГРОКОВ =====
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        task.wait(0.2) -- ЗАДЕРЖКА 0.2 СЕК (оптимально для полной загрузки)
        if espEnabled and scriptActive then
            createESPForPlayer(plr)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(plr)
    local highlight = espFolder:FindFirstChild("ESP_" .. plr.UserId)
    if highlight then highlight:Destroy() end
    local glow = espFolder:FindFirstChild("ESP_Glow_" .. plr.UserId)
    if glow then glow:Destroy() end
end)

-- ===== ПЕРИОДИЧЕСКАЯ ПРОВЕРКА ESP (каждые 1.5 сек) =====
task.spawn(function()
    while scriptActive do
        task.wait(1.5)
        if espEnabled and scriptActive then
            repairESP()
        end
    end
end)

-- ===== ОСНОВНОЙ ЛУП =====
RunService.Heartbeat:Connect(function()
    if not scriptActive then return end
    if flyEnabled then
        updateFly()
    end
end)

-- ===== ИНИЦИАЛИЗАЦИЯ =====
task.wait(1)
if not character or not humanoid then
    player.CharacterAdded:Wait()
    character = player.Character
    humanoid = character:FindFirstChild("Humanoid")
end

espEnabled = true
espMode = "v1"
createESPForAll()

print("FORTER v8.1 загружен! ESP v1 и v2 исправлены, работают на всех игроках.")
