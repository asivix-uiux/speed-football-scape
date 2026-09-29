local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local UI = require(script.Parent:WaitForChild("UI"))

-- Local-only visuals: spinning shoe pickups, collected popups, knockback
local EffectsController = {}
EffectsController.__index = EffectsController

function EffectsController.new()
    local self = setmetatable({}, EffectsController)

    self.player = Players.LocalPlayer
    self.pickups = {}

    for _, model in ipairs(CollectionService:GetTagged("Pickup")) do
        self:_addPickup(model)
    end
    CollectionService:GetInstanceAddedSignal("Pickup"):Connect(function(model)
        self:_addPickup(model)
    end)
    CollectionService:GetInstanceRemovedSignal("Pickup"):Connect(function(model)
        local id = model:GetAttribute("PickupId")
        if id then
            self.pickups[id] = nil
        end
    end)

    ClientState.getRemote("PickupCollected").OnClientEvent:Connect(function(id, respawnTime, gained, position)
        self:_onCollected(id, respawnTime, gained, position)
    end)
    ClientState.getRemote("Knockback").OnClientEvent:Connect(function(velocity)
        self:_knockback(velocity)
    end)

    RunService.RenderStepped:Connect(function()
        self:_animatePickups()
    end)

    ClientState.Changed:Connect(function(stats)
        self:_highlightEquipped(stats.Equipped)
    end)

    return self
end

-- The equipped player's shop pedestal glows green (local only)
function EffectsController:_highlightEquipped(id)
    if id == self.highlightedId then
        return
    end
    local previous = self.highlightedPedestal
    if previous then
        previous.part.Color = previous.color
        previous.part.Material = previous.material
        self.highlightedPedestal = nil
    end
    self.highlightedId = id

    local map = Workspace:FindFirstChild("SpeedFootballMap")
    local lobby = map and map:FindFirstChild("Lobby")
    local pedestal = lobby and id and id ~= "" and lobby:FindFirstChild("PlayerPedestal_" .. id)
    if pedestal then
        self.highlightedPedestal = { part = pedestal, color = pedestal.Color, material = pedestal.Material }
        pedestal.Color = Color3.fromRGB(70, 255, 70)
        pedestal.Material = Enum.Material.Neon
    end
end

function EffectsController:_addPickup(model)
    local id = model:GetAttribute("PickupId")
    if not id or not model:IsA("Model") then
        return
    end
    self.pickups[id] = {
        model = model,
        base = model:GetPivot(),
        phase = id * 0.7,
        hidden = false,
    }
end

function EffectsController:_animatePickups()
    local t = os.clock()
    for _, pickup in pairs(self.pickups) do
        if not pickup.hidden and pickup.model.Parent then
            local bob = math.sin(t * 2.5 + pickup.phase) * 0.4
            pickup.model:PivotTo(pickup.base * CFrame.new(0, bob, 0) * CFrame.Angles(0, t * 2 + pickup.phase, 0))
        end
    end
end

function EffectsController:_setPickupVisible(pickup, visible)
    pickup.hidden = not visible
    for _, descendant in ipairs(pickup.model:GetDescendants()) do
        if descendant:IsA("BasePart") and descendant.Name ~= "Hitbox" then
            -- Client-side change only, so other players still see their own pickups
            descendant.Transparency = visible and 0 or 1
        elseif descendant:IsA("BillboardGui") then
            descendant.Enabled = visible
        end
    end
end

function EffectsController:_onCollected(id, respawnTime, gained, position)
    local pickup = self.pickups[id]
    if pickup then
        self:_setPickupVisible(pickup, false)
        task.delay(respawnTime, function()
            if self.pickups[id] == pickup then
                self:_setPickupVisible(pickup, true)
            end
        end)
    end

    -- Floating "+5 Speed" that rises and fades
    local anchor = Instance.new("Part")
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.CanQuery = false
    anchor.CanTouch = false
    anchor.Transparency = 1
    anchor.Size = Vector3.new(0.2, 0.2, 0.2)
    anchor.Position = position
    anchor.Parent = Workspace

    local gui = UI.create("BillboardGui", {
        Size = UDim2.fromOffset(160, 70),
        StudsOffset = Vector3.new(0, 1, 0),
        AlwaysOnTop = true,
        LightInfluence = 0,
    }, anchor)
    local icon = UI.label(gui, {
        Text = "👟",
        TextSize = 34,
        Size = UDim2.new(1, 0, 0, 38),
        Stroke = false,
    })
    local label = UI.label(gui, {
        Text = "+" .. gained .. " Speed",
        TextSize = 24,
        Color = Color3.fromRGB(50, 120, 255),
        Size = UDim2.new(1, 0, 0, 28),
        Position = UDim2.fromOffset(0, 38),
        StrokeColor = UI.White,
    })

    local info = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(gui, info, { StudsOffset = Vector3.new(0, 5, 0) }):Play()
    TweenService:Create(icon, info, { TextTransparency = 1 }):Play()
    TweenService:Create(label, info, { TextTransparency = 1 }):Play()
    local stroke = label:FindFirstChildOfClass("UIStroke")
    if stroke then
        TweenService:Create(stroke, info, { Transparency = 1 }):Play()
    end
    task.delay(1.1, function()
        anchor:Destroy()
    end)
end

function EffectsController:_knockback(velocity)
    local character = self.player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart or rootPart.Anchored then
        return
    end
    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    rootPart.AssemblyLinearVelocity = velocity
end

return EffectsController
