local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(SharedFolder:WaitForChild("Catalog"))
local Config = require(SharedFolder:WaitForChild("Config"))
local Format = require(SharedFolder:WaitForChild("Format"))

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local UI = require(script.Parent:WaitForChild("UI"))

-- Rebirth / Auras / FREE rewards popups opened from the HUD's left buttons
local PanelController = {}
PanelController.__index = PanelController

local DARK = Color3.fromRGB(40, 40, 55)
local GREY_TEXT = Color3.fromRGB(110, 110, 125)
local GREEN = Color3.fromRGB(70, 210, 60)
local GREY = Color3.fromRGB(150, 150, 160)
local ORANGE = Color3.fromRGB(255, 150, 30)

local function darkLabel(parent, props)
    props.Stroke = false
    props.Color = props.Color or DARK
    return UI.label(parent, props)
end

function PanelController.new(hud)
    local self = setmetatable({}, PanelController)

    self.hud = hud
    self.panels = {}
    self.rebirthRequest = ClientState.getRemote("RebirthRequest")
    self.auraRequest = ClientState.getRemote("AuraRequest")
    self.claimReward = ClientState.getRemote("ClaimReward")

    self:_buildRebirth()
    self:_buildAuras()
    self:_buildFree()

    ClientState.Changed:Connect(function()
        self:refresh()
    end)
    local nextTick = 0
    RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now >= nextTick then
            nextTick = now + 0.5
            self:_refreshFree()
        end
    end)

    return self
end

-- Shared panel frame ------------------------------------------------------------------------

function PanelController:_makePanel(name, title, color, height)
    local panel = UI.create("Frame", {
        Name = name .. "Panel",
        Visible = false,
        BackgroundColor3 = Color3.fromRGB(246, 246, 250),
        Size = UDim2.fromOffset(540, height),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ZIndex = 40,
    }, self.hud.root)
    UI.corner(panel, 10)
    UI.stroke(panel, 4, UI.Black, true)
    UI.create("UIScale", { Name = "PopScale" }, panel)

    local header = UI.create("Frame", {
        BackgroundColor3 = color,
        Size = UDim2.new(1, 0, 0, 58),
        ZIndex = 41,
    }, panel)
    UI.corner(header, 10)
    UI.stroke(header, 3, UI.Black, true)
    UI.label(header, {
        Text = title,
        TextSize = 36,
        Size = UDim2.fromScale(1, 1),
        StrokeThickness = 3,
        ZIndex = 42,
    })
    local close = UI.button(header, {
        Text = "X",
        TextSize = 26,
        Background = Color3.fromRGB(225, 30, 40),
        Size = UDim2.fromOffset(44, 44),
        Position = UDim2.new(1, -8, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BorderThickness = 2,
        ZIndex = 43,
    })
    close.MouseButton1Click:Connect(function()
        self:close()
    end)

    local content = UI.create("Frame", {
        Name = "Content",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -32, 1, -84),
        Position = UDim2.fromOffset(16, 70),
        ZIndex = 41,
    }, panel)

    self.panels[name] = panel
    return panel, content
end

function PanelController:open(name)
    local panel = self.panels[name]
    if not panel then
        return
    end
    local wasOpen = panel.Visible
    self:close()
    if wasOpen then
        return
    end
    panel.Visible = true
    local scale = panel:FindFirstChild("PopScale")
    scale.Scale = 0.7
    TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
    self:refresh()
end

function PanelController:close()
    for _, panel in pairs(self.panels) do
        panel.Visible = false
    end
end

-- Action button with a text label we can restyle
local function actionButton(parent, size, position, zIndex)
    local button, label = UI.button(parent, {
        Text = "",
        TextSize = 22,
        Background = GREEN,
        Size = size,
        Position = position,
        AnchorPoint = Vector2.new(1, 0.5),
        BorderThickness = 2,
        ZIndex = zIndex,
    })
    return button, label
end

local function setButton(button, label, text, color)
    label.Text = text
    button.BackgroundColor3 = color
end

-- Rebirth -----------------------------------------------------------------------------------

function PanelController:_buildRebirth()
    local _, content = self:_makePanel("Rebirth", "🔁 REBIRTH", Color3.fromRGB(60, 200, 230), 390)

    darkLabel(content, { Text = "🔁", TextSize = 56, Size = UDim2.new(1, 0, 0, 64), ZIndex = 42 })
    self.rebirthCount = darkLabel(content, {
        Text = "Rebirths: 0",
        TextSize = 30,
        Size = UDim2.new(1, 0, 0, 36),
        Position = UDim2.fromOffset(0, 64),
        ZIndex = 42,
    })
    self.rebirthBoost = UI.label(content, {
        Text = "Speed Boost: x1 > x1.5",
        TextSize = 26,
        Color = GREEN,
        StrokeColor = Color3.fromRGB(20, 70, 20),
        Size = UDim2.new(1, 0, 0, 32),
        Position = UDim2.fromOffset(0, 102),
        ZIndex = 42,
    })
    self.rebirthRequirement = darkLabel(content, {
        Text = "",
        TextSize = 22,
        Size = UDim2.new(1, 0, 0, 28),
        Position = UDim2.fromOffset(0, 140),
        ZIndex = 42,
    })
    darkLabel(content, {
        Text = "Level resets to 1. Max Speed +" .. Config.Player.MaxSpeedPerRebirth .. ". Speed and Wins are kept!",
        TextSize = 16,
        Color = GREY_TEXT,
        Size = UDim2.new(1, 0, 0, 22),
        Position = UDim2.fromOffset(0, 170),
        ZIndex = 42,
    })

    local button, label = UI.button(content, {
        Text = "REBIRTH",
        TextSize = 32,
        Background = GREEN,
        Size = UDim2.fromOffset(240, 58),
        Position = UDim2.new(0.5, 0, 0, 210),
        AnchorPoint = Vector2.new(0.5, 0),
        BorderThickness = 3,
        ZIndex = 42,
    })
    self.rebirthButton, self.rebirthButtonLabel = button, label
    button.MouseButton1Click:Connect(function()
        self.rebirthRequest:FireServer()
    end)
end

function PanelController:_refreshRebirth(stats)
    local current = Catalog.rebirthMultiplier(stats.Rebirths)
    local nextMultiplier = Catalog.rebirthMultiplier(stats.Rebirths + 1)
    self.rebirthCount.Text = "Rebirths: " .. stats.Rebirths
    self.rebirthBoost.Text = "Speed Boost: x" .. current .. " > x" .. nextMultiplier

    local ready = stats.Level >= stats.MaxLevel
    self.rebirthRequirement.Text = "Requires Level " .. stats.MaxLevel .. " (You: Level " .. stats.Level .. ")"
    self.rebirthRequirement.TextColor3 = ready and Color3.fromRGB(40, 160, 40) or Color3.fromRGB(220, 40, 40)
    setButton(self.rebirthButton, self.rebirthButtonLabel, ready and "REBIRTH" or "LOCKED", ready and GREEN or GREY)
end

-- Auras -------------------------------------------------------------------------------------

function PanelController:_buildAuras()
    local _, content = self:_makePanel("Auras", "🐉 AURAS", Color3.fromRGB(120, 230, 40), 460)

    local list = UI.create("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 8,
        ZIndex = 42,
    }, content)
    UI.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)

    self.auraRows = {}
    for index, aura in ipairs(Catalog.Auras) do
        local row = UI.create("Frame", {
            LayoutOrder = index,
            BackgroundColor3 = Color3.fromRGB(232, 234, 242),
            Size = UDim2.new(1, -12, 0, 64),
            ZIndex = 42,
        }, list)
        UI.corner(row, 8)
        UI.stroke(row, 2, Color3.fromRGB(190, 190, 205), true)

        local swatch = UI.create("Frame", {
            BackgroundColor3 = aura.Color,
            Size = UDim2.fromOffset(44, 44),
            Position = UDim2.new(0, 10, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            ZIndex = 43,
        }, row)
        UI.corner(swatch, 100)
        UI.stroke(swatch, 2, UI.Black, true)
        if aura.Effect == "Rainbow" then
            UI.gradient(swatch, UI.Rainbow, 45)
        end

        darkLabel(row, {
            Text = aura.Name,
            TextSize = 24,
            Size = UDim2.new(0.5, 0, 0, 28),
            Position = UDim2.fromOffset(66, 6),
            XAlignment = Enum.TextXAlignment.Left,
            ZIndex = 43,
        })
        local requirement = aura.Pass and "Robux exclusive" or (Format.abbreviate(aura.RequiredWins) .. " Wins")
        darkLabel(row, {
            Text = "x" .. aura.Multiplier .. " Speed  •  " .. requirement,
            TextSize = 16,
            Color = GREY_TEXT,
            Size = UDim2.new(0.5, 0, 0, 22),
            Position = UDim2.fromOffset(66, 34),
            XAlignment = Enum.TextXAlignment.Left,
            ZIndex = 43,
        })

        local button, label = actionButton(row, UDim2.fromOffset(130, 42), UDim2.new(1, -10, 0.5, 0), 43)
        button.MouseButton1Click:Connect(function()
            self.auraRequest:FireServer(aura.Id)
        end)
        self.auraRows[aura.Id] = { aura = aura, button = button, label = label }
    end
end

function PanelController:_refreshAuras(stats)
    for id, row in pairs(self.auraRows) do
        local aura = row.aura
        if stats.Aura == id then
            setButton(row.button, row.label, "UNEQUIP", ORANGE)
        elseif aura.Pass then
            local owned = stats.Passes and stats.Passes[aura.Pass]
            local pass = Config.Passes[aura.Pass]
            setButton(row.button, row.label, owned and "EQUIP" or ((pass and pass.Price or 0) .. " R$"), GREEN)
        elseif stats.Wins >= aura.RequiredWins then
            setButton(row.button, row.label, "EQUIP", GREEN)
        else
            setButton(row.button, row.label, "🔒 LOCKED", GREY)
        end
    end
end

-- FREE rewards ------------------------------------------------------------------------------

function PanelController:_buildFree()
    local _, content = self:_makePanel("Free", "🎁 FREE REWARDS", Color3.fromRGB(220, 30, 40), 470)

    darkLabel(content, {
        Text = "Keep playing to unlock free rewards!",
        TextSize = 18,
        Color = GREY_TEXT,
        Size = UDim2.new(1, 0, 0, 24),
        ZIndex = 42,
    })

    local list = UI.create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, -30),
        Position = UDim2.fromOffset(0, 30),
        ZIndex = 42,
    }, content)
    UI.create("UIGridLayout", {
        CellSize = UDim2.new(0.5, -6, 0, 104),
        CellPadding = UDim2.fromOffset(12, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, list)

    self.freeRows = {}
    for index, reward in ipairs(Catalog.FreeRewards) do
        local cell = UI.create("Frame", {
            LayoutOrder = index,
            BackgroundColor3 = Color3.fromRGB(232, 234, 242),
            ZIndex = 42,
        }, list)
        UI.corner(cell, 8)
        UI.stroke(cell, 2, Color3.fromRGB(190, 190, 205), true)

        local isWins = reward.Wins ~= nil
        darkLabel(cell, {
            Text = isWins and "🏆" or "👟",
            TextSize = 34,
            Size = UDim2.fromOffset(50, 50),
            Position = UDim2.fromOffset(8, 6),
            ZIndex = 43,
        })
        UI.label(cell, {
            Text = isWins and ("+" .. reward.Wins .. " Wins") or ("+" .. Format.abbreviate(reward.Speed) .. " Speed"),
            TextSize = 24,
            Color = isWins and Color3.fromRGB(255, 205, 40) or Color3.fromRGB(60, 140, 255),
            Size = UDim2.new(1, -66, 0, 30),
            Position = UDim2.fromOffset(60, 8),
            XAlignment = Enum.TextXAlignment.Left,
            ZIndex = 43,
        })
        darkLabel(cell, {
            Text = reward.Minutes .. " min",
            TextSize = 16,
            Color = GREY_TEXT,
            Size = UDim2.new(1, -66, 0, 20),
            Position = UDim2.fromOffset(60, 36),
            XAlignment = Enum.TextXAlignment.Left,
            ZIndex = 43,
        })

        local button, label = actionButton(cell, UDim2.new(1, -16, 0, 36), UDim2.new(1, -8, 1, -26), 43)
        button.MouseButton1Click:Connect(function()
            self.claimReward:FireServer(index)
        end)
        self.freeRows[index] = { reward = reward, button = button, label = label }
    end
end

function PanelController:_refreshFree()
    local stats = ClientState.stats
    if not stats then
        return
    end
    local playTime = ClientState.getPlayTime()
    local anyReady = false

    for index, row in ipairs(self.freeRows) do
        local claimed = stats.ClaimedRewards and stats.ClaimedRewards[tostring(index)]
        local remaining = row.reward.Minutes * 60 - playTime
        if claimed then
            setButton(row.button, row.label, "CLAIMED", GREY)
        elseif remaining <= 0 then
            anyReady = true
            setButton(row.button, row.label, "CLAIM!", GREEN)
        else
            setButton(row.button, row.label, "⏰ " .. Format.clock(remaining), GREY)
        end
    end

    if self.hud.freeBadge then
        self.hud.freeBadge.Visible = anyReady
    end
end

function PanelController:refresh()
    local stats = ClientState.stats
    if not stats then
        return
    end
    self:_refreshRebirth(stats)
    self:_refreshAuras(stats)
    self:_refreshFree()
end

return PanelController
