local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Config = require(SharedFolder:WaitForChild("Config"))
local Format = require(SharedFolder:WaitForChild("Format"))

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local UI = require(script.Parent:WaitForChild("UI"))

local HUDController = {}
HUDController.__index = HUDController

local DESIGN_SIZE = Vector2.new(1280, 720)
local RED = Color3.fromRGB(230, 35, 45)
local GREEN = Color3.fromRGB(110, 230, 50)
local PRICE_GREEN = Color3.fromRGB(90, 235, 60)

function HUDController.new()
    local self = setmetatable({}, HUDController)

    self.player = Players.LocalPlayer
    self.purchaseRequest = ClientState.getRemote("PurchaseRequest")
    self.setCustomSpeed = ClientState.getRemote("SetCustomSpeed")
    self.reviveChoice = ClientState.getRemote("ReviveChoice")
    self.sprintRequest = ClientState.getRemote("SprintRequest")

    self.gui = UI.create("ScreenGui", {
        Name = "SpeedFootballHUD",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, self.player:WaitForChild("PlayerGui"))

    -- Everything is laid out in 1280x720 design pixels and scaled to the screen
    self.root = UI.create("Frame", { Name = "Root", BackgroundTransparency = 1 }, self.gui)
    self.rootScale = UI.create("UIScale", {}, self.root)
    self:_bindViewport()

    self.offerIndex = 1
    self.offerHiddenUntil = 0
    self.startTime = os.clock()
    self.musicOn = true

    self:_buildTop()
    self:_buildLeft()
    self:_buildRight()
    self:_buildBottom()
    self:_buildRevive()
    self:_buildBanners()
    self:_buildMobileSprint()

    self:_bindRemotes()
    self:_bindTimers()
    self:_setupMusic()

    if ClientState.stats then
        self:_applyStats(ClientState.stats)
    end
    ClientState.Changed:Connect(function(stats)
        self:_applyStats(stats)
    end)

    return self
end

function HUDController:_bindViewport()
    local function update()
        local camera = Workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or DESIGN_SIZE
        local scale = math.min(viewport.X / DESIGN_SIZE.X, viewport.Y / DESIGN_SIZE.Y)
        if scale <= 0 then
            return
        end
        self.rootScale.Scale = scale
        self.root.Size = UDim2.fromOffset(viewport.X / scale, viewport.Y / scale)
    end
    update()

    local function watchCamera()
        local camera = Workspace.CurrentCamera
        if camera then
            camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
        end
        update()
    end
    watchCamera()
    Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
end

-- Top: sprint hint + rotating offer -----------------------------------------------------

function HUDController:_buildTop()
    local hint = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
        and "~ HOLD SPRINT TO RUN FASTER! ~" or "~ HOLD SHIFT TO SPRINT! ~"
    UI.label(self.root, {
        Text = hint,
        TextSize = 21,
        Size = UDim2.fromOffset(420, 28),
        Position = UDim2.new(0.5, -12, 0, 10),
        AnchorPoint = Vector2.new(0.5, 0),
    })

    local offer = UI.create("Frame", {
        Name = "Offer",
        BackgroundColor3 = Color3.fromRGB(240, 240, 244),
        Size = UDim2.fromOffset(280, 84),
        Position = UDim2.new(0.5, -14, 0, 64),
        AnchorPoint = Vector2.new(0.5, 0),
    }, self.root)
    UI.stroke(offer, 3, UI.Black, true)
    self.offer = offer

    self.offerIcon = UI.label(offer, {
        Text = "👟",
        TextSize = 52,
        Size = UDim2.fromOffset(84, 84),
        Position = UDim2.fromOffset(8, 0),
        Stroke = false,
    })
    self.offerTitle = UI.label(offer, {
        Text = "1M Speed",
        TextSize = 24,
        Color = Color3.fromRGB(30, 30, 40),
        Size = UDim2.fromOffset(180, 30),
        Position = UDim2.fromOffset(92, 4),
        Stroke = false,
    })
    self.offerPrice = UI.label(offer, {
        Text = "149 R$",
        TextSize = 38,
        Color = PRICE_GREEN,
        Size = UDim2.fromOffset(180, 44),
        Position = UDim2.fromOffset(92, 32),
        StrokeColor = Color3.fromRGB(20, 90, 20),
    })

    local yes = UI.button(offer, {
        Text = "YES",
        Background = GREEN,
        Size = UDim2.fromOffset(102, 32),
        Position = UDim2.fromOffset(27, 90),
        TextSize = 24,
        BorderThickness = 2,
    })
    local no = UI.button(offer, {
        Text = "NO",
        Background = RED,
        Size = UDim2.fromOffset(102, 32),
        Position = UDim2.fromOffset(151, 90),
        TextSize = 24,
        BorderThickness = 2,
    })

    yes.MouseButton1Click:Connect(function()
        local current = Config.Offers[self.offerIndex]
        self.purchaseRequest:FireServer(current.Kind, current.Key)
    end)
    no.MouseButton1Click:Connect(function()
        self.offerHiddenUntil = os.clock() + Config.OfferRotateTime
        self.offer.Visible = false
    end)

    self:_showOffer(1)
end

function HUDController:_showOffer(index)
    self.offerIndex = index
    local offer = Config.Offers[index]
    local definition = offer.Kind == "Pass" and Config.Passes[offer.Key] or Config.Products[offer.Key]
    self.offerTitle.Text = offer.Title
    self.offerPrice.Text = definition.Price .. " R$"
    if offer.Key == "StarterPack" then
        self.offerIcon.Text = "📦"
    else
        self.offerIcon.Text = offer.Kind == "Pass" and "⚽" or "👟"
    end
end

-- Left column: Rebirth / Auras / FREE -----------------------------------------------------

function HUDController:_sideButton(y, title, icon, color)
    local button = UI.button(self.root, {
        Name = title,
        Background = color,
        Size = UDim2.fromOffset(88, 86),
        Position = UDim2.fromOffset(16, y),
        BorderThickness = 2,
        Corner = 2,
    })
    UI.label(button, {
        Text = icon,
        TextSize = 44,
        Size = UDim2.new(1, 0, 0, 56),
        Position = UDim2.fromOffset(0, 2),
        Stroke = false,
        ZIndex = 2,
    })
    UI.label(button, {
        Text = title,
        TextSize = 20,
        Size = UDim2.new(1, 0, 0, 26),
        Position = UDim2.new(0, 0, 1, -28),
        ZIndex = 2,
    })
    return button
end

function HUDController:_buildLeft()
    local rebirth = self:_sideButton(182, "Rebirth", "🔁", Color3.fromRGB(60, 200, 230))
    local _, rebirthLabel = UI.badge(rebirth, "0%", Color3.fromRGB(40, 110, 255), UDim2.new(1, 2, 0, 8), UDim2.fromOffset(36, 24))
    self.rebirthPercent = rebirthLabel

    local auras = self:_sideButton(282, "Auras", "🐉", Color3.fromRGB(120, 230, 40))
    local free = self:_sideButton(382, "FREE!", "🎁", Color3.fromRGB(220, 30, 40))
    self.freeBadge = UI.badge(free, "!", RED, UDim2.new(1, 0, 0, 0))
    self.freeBadge.Visible = false

    -- self.panels is attached by the client bootstrap (PanelController)
    local function open(name)
        if self.panels then
            self.panels:open(name)
        end
    end
    rebirth.MouseButton1Click:Connect(function()
        open("Rebirth")
    end)
    auras.MouseButton1Click:Connect(function()
        open("Auras")
    end)
    free.MouseButton1Click:Connect(function()
        open("Free")
    end)
end

-- Right column: starter pack / custom speed / 2x speed ---------------------------------------

function HUDController:_buildRight()
    local pack = UI.create("TextButton", {
        Name = "StarterPack",
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(170, 145),
        Position = UDim2.new(1, -200, 0, 96),
    }, self.root)
    UI.label(pack, {
        Text = "OP STARTER\nPACK",
        TextSize = 18,
        Size = UDim2.new(1, 0, 0, 42),
    })
    UI.label(pack, {
        Text = "🎁",
        TextSize = 44,
        Size = UDim2.new(1, 0, 0, 50),
        Position = UDim2.fromOffset(0, 38),
        Stroke = false,
    })
    self.packTimer = UI.label(pack, {
        Text = "⏰ 15:00",
        TextSize = 17,
        Color = PRICE_GREEN,
        Size = UDim2.new(1, 0, 0, 20),
        Position = UDim2.fromOffset(10, 92),
    })
    UI.label(pack, {
        Text = "ONLY R$" .. Config.Products.StarterPack.Price,
        TextSize = 21,
        Color = Color3.fromRGB(190, 255, 60),
        Size = UDim2.new(1, 0, 0, 24),
        Position = UDim2.fromOffset(0, 114),
        StrokeColor = Color3.fromRGB(20, 80, 20),
    })
    self.starterPack = pack
    pack.MouseButton1Click:Connect(function()
        self.purchaseRequest:FireServer("Product", "StarterPack")
    end)

    -- Custom speed
    UI.label(self.root, {
        Text = "Custom Speed",
        TextSize = 25,
        Size = UDim2.fromOffset(220, 30),
        Position = UDim2.new(1, -225, 0, 248),
    })
    local box = UI.create("Frame", {
        BackgroundColor3 = Color3.fromRGB(245, 245, 248),
        Size = UDim2.fromOffset(176, 72),
        Position = UDim2.new(1, -203, 0, 280),
    }, self.root)
    UI.stroke(box, 3, UI.Black, true)
    self.customSpeedBox = UI.create("TextBox", {
        BackgroundTransparency = 1,
        Font = UI.Font,
        TextSize = 44,
        TextColor3 = Color3.fromRGB(215, 50, 60),
        Text = "16",
        ClearTextOnFocus = true,
        Size = UDim2.new(1, 0, 0, 50),
        Position = UDim2.fromOffset(0, 0),
    }, box)
    UI.stroke(self.customSpeedBox, 2, Color3.fromRGB(90, 20, 20))
    self.maxSpeedLabel = UI.label(box, {
        Text = "Max: 16",
        TextSize = 20,
        Size = UDim2.new(1, 0, 0, 22),
        Position = UDim2.new(0, 0, 1, -24),
    })
    UI.label(self.root, {
        Text = "✏️",
        TextSize = 40,
        Size = UDim2.fromOffset(50, 50),
        Position = UDim2.new(1, -236, 0, 280),
        Stroke = false,
    })
    self.customSpeedBox.FocusLost:Connect(function()
        local value = tonumber(self.customSpeedBox.Text)
        if value then
            self.setCustomSpeed:FireServer(value)
        end
        if ClientState.stats then
            self:_applyStats(ClientState.stats)
        end
    end)

    -- 2x Speed
    local doubleSpeed = UI.button(self.root, {
        Name = "DoubleSpeed",
        Text = "2x Speed",
        TextSize = 32,
        Background = UI.White,
        Gradient = UI.Rainbow,
        GradientRotation = 20,
        Size = UDim2.fromOffset(170, 66),
        Position = UDim2.new(1, -200, 0, 372),
        BorderThickness = 2,
        Corner = 2,
    })
    self.doubleSpeedPrice = UI.label(self.root, {
        Text = "ONLY R$" .. Config.Passes.DoubleSpeed.Price,
        TextSize = 23,
        Size = UDim2.fromOffset(170, 30),
        Position = UDim2.new(1, -200, 0, 444),
    })
    doubleSpeed.MouseButton1Click:Connect(function()
        self.purchaseRequest:FireServer("Pass", "DoubleSpeed")
    end)
end

-- Bottom: speed, level bar, stamina, speed products, wins ------------------------------------

function HUDController:_buildBottom()
    local bottom = UI.create("Frame", {
        Name = "Bottom",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(520, 230),
        Position = UDim2.new(0.5, 0, 1, 0),
        AnchorPoint = Vector2.new(0.5, 1),
    }, self.root)

    self.speedLabel = UI.label(bottom, {
        Text = "0 Speed",
        TextSize = 23,
        Size = UDim2.fromOffset(300, 28),
        Position = UDim2.fromOffset(110, 4),
    })

    self.boostLabel = UI.label(bottom, {
        Text = "",
        TextSize = 20,
        Color = Color3.fromRGB(40, 200, 255),
        StrokeColor = Color3.fromRGB(10, 40, 120),
        Size = UDim2.fromOffset(300, 24),
        Position = UDim2.fromOffset(110, -22),
    })
    self.boostLabel.Visible = false

    -- Level bar
    local levelBar = UI.create("Frame", {
        BackgroundColor3 = Color3.fromRGB(246, 246, 250),
        Size = UDim2.fromOffset(510, 52),
        Position = UDim2.fromOffset(5, 48),
        ClipsDescendants = false,
    }, bottom)
    UI.stroke(levelBar, 3, UI.Black, true)
    self.levelFill = UI.create("Frame", {
        BackgroundColor3 = UI.White,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(0, 1),
    }, levelBar)
    UI.gradient(self.levelFill, { Color3.fromRGB(30, 30, 220), Color3.fromRGB(120, 120, 255) }, 0)
    self.levelLabel = UI.label(levelBar, {
        Text = "Level 1 / 30",
        TextSize = 30,
        Size = UDim2.new(0.6, 0, 1, 0),
        Position = UDim2.fromOffset(14, 0),
        XAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2,
    })
    self.xpLabel = UI.label(levelBar, {
        Text = "0 / 15",
        TextSize = 30,
        Size = UDim2.new(0.5, 0, 1, 0),
        Position = UDim2.new(0.5, -14, 0, 0),
        XAlignment = Enum.TextXAlignment.Right,
        ZIndex = 2,
    })

    -- Stamina bar
    local stamina = UI.create("Frame", {
        BackgroundColor3 = Color3.fromRGB(250, 228, 180),
        Size = UDim2.fromOffset(394, 38),
        Position = UDim2.fromOffset(63, 106),
    }, bottom)
    UI.stroke(stamina, 2, UI.Black, true)
    self.staminaFill = UI.create("Frame", {
        BackgroundColor3 = UI.White,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
    }, stamina)
    UI.gradient(self.staminaFill, { Color3.fromRGB(255, 205, 90), Color3.fromRGB(240, 170, 40) }, 90)
    UI.label(stamina, {
        Text = "👟",
        TextSize = 26,
        Size = UDim2.fromOffset(40, 38),
        Position = UDim2.fromOffset(2, 0),
        Stroke = false,
        ZIndex = 2,
    })
    self.staminaLabel = UI.label(stamina, {
        Text = "12/12",
        TextSize = 22,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 2,
    })

    -- Speed products
    local products = {
        { key = "Speed10K", text = "+10K", x = 13, width = 137, colors = { Color3.fromRGB(255, 225, 40), Color3.fromRGB(255, 140, 30) } },
        { key = "Speed100K", text = "+100K", x = 162, width = 142, colors = { Color3.fromRGB(190, 60, 255), Color3.fromRGB(255, 70, 200) } },
        { key = "Speed1M", text = "+1M SPEED", x = 317, width = 192, rainbow = true },
    }
    for _, product in ipairs(products) do
        local button = UI.button(bottom, {
            Name = product.key,
            Text = product.text,
            TextSize = 30,
            Background = UI.White,
            Gradient = product.rainbow and UI.Rainbow or product.colors,
            GradientRotation = product.rainbow and 0 or 45,
            Size = UDim2.fromOffset(product.width, product.rainbow and 58 or 50),
            Position = UDim2.fromOffset(product.x, product.rainbow and 156 or 162),
            BorderThickness = 2,
            Corner = 2,
        })
        button.MouseButton1Click:Connect(function()
            self.purchaseRequest:FireServer("Product", product.key)
        end)
    end

    -- Wins (bottom-left)
    UI.label(self.root, {
        Text = "🏆",
        TextSize = 44,
        Size = UDim2.fromOffset(54, 54),
        Position = UDim2.new(0, 14, 1, -96),
        Stroke = false,
    })
    self.winsLabel = UI.label(self.root, {
        Text = "0",
        TextSize = 38,
        Size = UDim2.fromOffset(200, 50),
        Position = UDim2.new(0, 70, 1, -94),
        XAlignment = Enum.TextXAlignment.Left,
        StrokeThickness = 3,
    })
    UI.label(self.root, {
        Text = "😊 Add friends for XP boost! ➕",
        TextSize = 14,
        Size = UDim2.fromOffset(280, 22),
        Position = UDim2.new(0, 12, 1, -34),
        XAlignment = Enum.TextXAlignment.Left,
        StrokeThickness = 1.5,
    })

    -- Music toggle (bottom-right)
    local music, musicLabel = UI.button(self.root, {
        Name = "Music",
        Text = "🎵",
        TextSize = 30,
        Background = Color3.fromRGB(30, 80, 210),
        Size = UDim2.fromOffset(52, 52),
        Position = UDim2.new(1, -110, 1, -92),
        BorderThickness = 2,
    })
    music.MouseButton1Click:Connect(function()
        self.musicOn = not self.musicOn
        musicLabel.TextTransparency = self.musicOn and 0 or 0.6
        if self.music then
            self.music.Playing = self.musicOn
        end
    end)
end

-- Revive popup -------------------------------------------------------------------------------

function HUDController:_buildRevive()
    local popup = UI.create("Frame", {
        Name = "Revive",
        Visible = false,
        BackgroundColor3 = Color3.fromRGB(40, 30, 10),
        BackgroundTransparency = 0.35,
        Size = UDim2.fromOffset(262, 146),
        Position = UDim2.new(0.5, -3, 0, 88),
        AnchorPoint = Vector2.new(0.5, 0),
        ZIndex = 20,
    }, self.root)
    UI.stroke(popup, 2, UI.Black, true)
    self.revivePopup = popup

    local header = UI.create("Frame", {
        BackgroundColor3 = Color3.fromRGB(215, 20, 25),
        Size = UDim2.new(1, 0, 0, 30),
        ZIndex = 21,
    }, popup)
    UI.stroke(header, 2, UI.Black, true)
    UI.label(header, {
        Text = "💀 REVIVE",
        TextSize = 26,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 22,
    })
    local close = UI.button(header, {
        Text = "X",
        TextSize = 16,
        Background = Color3.fromRGB(160, 10, 15),
        Size = UDim2.fromOffset(24, 22),
        Position = UDim2.new(1, -30, 0, 4),
        BorderThickness = 1,
        ZIndex = 22,
    })

    local reviveButton, reviveLabel = UI.button(popup, {
        Text = "9 Robux",
        TextSize = 22,
        Background = Color3.fromRGB(60, 220, 40),
        Size = UDim2.fromOffset(140, 30),
        Position = UDim2.new(0.5, 0, 0, 52),
        AnchorPoint = Vector2.new(0.5, 0),
        BorderThickness = 1,
        ZIndex = 21,
    })
    self.reviveLabel = reviveLabel
    local noButton = UI.button(popup, {
        Text = "No!",
        TextSize = 22,
        Background = Color3.fromRGB(220, 25, 30),
        Size = UDim2.fromOffset(152, 30),
        Position = UDim2.new(0.5, 0, 0, 90),
        AnchorPoint = Vector2.new(0.5, 0),
        BorderThickness = 1,
        ZIndex = 21,
    })
    self.reviveTimer = UI.label(popup, {
        Text = "",
        TextSize = 14,
        Size = UDim2.new(1, 0, 0, 18),
        Position = UDim2.new(0, 0, 1, -20),
        ZIndex = 21,
        StrokeThickness = 1.5,
    })

    reviveButton.MouseButton1Click:Connect(function()
        popup.Visible = false
        self.reviveChoice:FireServer(true)
    end)
    local function decline()
        popup.Visible = false
        self.reviveChoice:FireServer(false)
    end
    noButton.MouseButton1Click:Connect(decline)
    close.MouseButton1Click:Connect(decline)
end

-- Level-up banner + notifications --------------------------------------------------------------

function HUDController:_buildBanners()
    local banner = UI.create("Frame", {
        Name = "LevelUp",
        Visible = false,
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.45,
        Size = UDim2.new(1, 0, 0, 78),
        Position = UDim2.new(0, 0, 1, -288),
        ZIndex = 10,
    }, self.root)
    self.levelBanner = banner
    self.levelBannerLabel = UI.label(banner, {
        Text = "Level 1 > 2",
        TextSize = 34,
        Color = Color3.fromRGB(70, 225, 235),
        Size = UDim2.fromOffset(300, 50),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        StrokeColor = Color3.fromRGB(10, 50, 60),
        StrokeThickness = 3,
        ZIndex = 11,
    })
    for _, side in ipairs({ -1, 1 }) do
        UI.label(banner, {
            Text = "⬆",
            TextSize = 44,
            Color = Color3.fromRGB(255, 210, 60),
            Size = UDim2.fromOffset(50, 60),
            Position = UDim2.new(0.5, side * 190, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            StrokeColor = Color3.fromRGB(120, 70, 0),
            ZIndex = 11,
        })
    end

    self.notification = UI.label(self.root, {
        Name = "Notification",
        Text = "",
        TextSize = 34,
        Color = RED,
        Size = UDim2.fromOffset(700, 44),
        Position = UDim2.new(0.5, 0, 1, -118),
        AnchorPoint = Vector2.new(0.5, 0.5),
        StrokeColor = Color3.fromRGB(60, 0, 0),
        StrokeThickness = 3,
        ZIndex = 30,
    })
    self.notification.Visible = false
    self.notificationToken = 0
end

function HUDController:notify(text, color)
    self.notificationToken = self.notificationToken + 1
    local token = self.notificationToken
    local label = self.notification
    label.Text = text
    label.TextColor3 = color or RED
    label.TextTransparency = 0
    label.Visible = true
    label.Size = UDim2.fromOffset(560, 36)
    TweenService:Create(label, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(700, 44) }):Play()

    task.delay(1.8, function()
        if self.notificationToken == token then
            TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
            task.wait(0.4)
            if self.notificationToken == token then
                label.Visible = false
            end
        end
    end)
end

function HUDController:showLevelUp(oldLevel, newLevel)
    self.levelBannerLabel.Text = "Level " .. oldLevel .. " > " .. newLevel
    self.levelBanner.Visible = true
    self.levelBanner.BackgroundTransparency = 1
    TweenService:Create(self.levelBanner, TweenInfo.new(0.25), { BackgroundTransparency = 0.45 }):Play()

    self.levelUpToken = (self.levelUpToken or 0) + 1
    local token = self.levelUpToken
    task.delay(2.5, function()
        if self.levelUpToken == token then
            self.levelBanner.Visible = false
        end
    end)
end

-- Mobile sprint button -----------------------------------------------------------------------

function HUDController:_buildMobileSprint()
    if not UserInputService.TouchEnabled then
        return
    end
    local button = UI.button(self.root, {
        Name = "Sprint",
        Text = "SPRINT",
        TextSize = 20,
        Background = Color3.fromRGB(255, 170, 40),
        Size = UDim2.fromOffset(96, 96),
        Position = UDim2.new(1, -250, 1, -210),
        Corner = 48,
    })
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.sprintRequest:FireServer(true)
        end
    end)
    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.sprintRequest:FireServer(false)
        end
    end)
end

-- Data binding ---------------------------------------------------------------------------------

function HUDController:_applyStats(stats)
    self.speedLabel.Text = Format.abbreviate(stats.Speed) .. " Speed"
    self.winsLabel.Text = Format.abbreviate(stats.Wins)

    if stats.Level >= stats.MaxLevel then
        self.levelLabel.Text = "Level MAX"
    else
        self.levelLabel.Text = "Level " .. stats.Level .. " / " .. stats.MaxLevel
    end
    self.xpLabel.Text = Format.abbreviate(stats.XP) .. " / " .. Format.abbreviate(stats.XPNeeded)
    local xpFraction = math.clamp(stats.XP / stats.XPNeeded, 0, 1)
    TweenService:Create(self.levelFill, TweenInfo.new(0.2), { Size = UDim2.fromScale(xpFraction, 1) }):Play()

    self.staminaLabel.Text = math.floor(stats.Stamina + 0.5) .. "/" .. stats.StaminaMax
    self.staminaFill.Size = UDim2.fromScale(math.clamp(stats.Stamina / stats.StaminaMax, 0, 1), 1)

    self.rebirthPercent.Text = math.floor(stats.Level / stats.MaxLevel * 100) .. "%"

    if not self.customSpeedBox:IsFocused() then
        local custom = stats.CustomSpeed
        if custom <= 0 or custom > stats.MaxSpeed then
            custom = stats.MaxSpeed
        end
        self.customSpeedBox.Text = tostring(custom)
    end
    self.maxSpeedLabel.Text = "Max: " .. stats.MaxSpeed

    if stats.Passes and stats.Passes.DoubleSpeed then
        self.doubleSpeedPrice.Text = "OWNED"
    end

    if not stats.Dead and self.revivePopup.Visible then
        self.revivePopup.Visible = false
    end
end

function HUDController:_bindRemotes()
    ClientState.getRemote("Notify").OnClientEvent:Connect(function(text, color)
        self:notify(text, color)
    end)

    ClientState.getRemote("LevelUp").OnClientEvent:Connect(function(oldLevel, newLevel)
        self:showLevelUp(oldLevel, newLevel)
    end)

    ClientState.getRemote("StageEntered").OnClientEvent:Connect(function(stageIndex)
        local stage = Config.Course.Stages[stageIndex]
        if stage then
            self:notify(stage.Name .. " - " .. stage.Subtitle, stage.SubtitleColor)
        end
    end)

    ClientState.getRemote("Died").OnClientEvent:Connect(function(timeout, price)
        self.reviveLabel.Text = price .. " Robux"
        self.reviveDeadline = os.clock() + timeout
        self.revivePopup.Visible = true
    end)
end

function HUDController:_bindTimers()
    local rotateAt = os.clock() + Config.OfferRotateTime
    RunService.Heartbeat:Connect(function()
        local now = os.clock()

        -- Rotating top offer
        if now >= rotateAt then
            rotateAt = now + Config.OfferRotateTime
            self:_showOffer((self.offerIndex % #Config.Offers) + 1)
        end
        if not self.offer.Visible and now >= self.offerHiddenUntil then
            self.offer.Visible = true
        end

        -- Starter pack countdown
        local remaining = Config.StarterPackDuration - (now - self.startTime)
        if remaining <= 0 then
            self.starterPack.Visible = false
        else
            self.packTimer.Text = "⏰ " .. Format.clock(remaining)
        end

        -- Bought speed boost countdown
        local stats = ClientState.stats
        local boostLeft = stats and stats.BoostRemaining and (stats.BoostRemaining - (now - ClientState.receivedAt)) or 0
        self.boostLabel.Visible = boostLeft > 0
        if boostLeft > 0 then
            self.boostLabel.Text = "⚡ x" .. Config.SpeedBoost.Multiplier .. " SPEED BOOST " .. Format.clock(boostLeft)
        end

        if self.revivePopup.Visible and self.reviveDeadline then
            self.reviveTimer.Text = "Returning to lobby in " .. math.max(0, math.ceil(self.reviveDeadline - now)) .. "s"
        end
    end)
end

function HUDController:_setupMusic()
    if Config.MusicSoundId == 0 then
        return
    end
    self.music = UI.create("Sound", {
        Name = "Music",
        SoundId = "rbxassetid://" .. Config.MusicSoundId,
        Looped = true,
        Volume = 0.35,
    }, SoundService)
    self.music:Play()
end

return HUDController
