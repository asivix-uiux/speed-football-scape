local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(SharedFolder:WaitForChild("Catalog"))
local RigBuilder = require(SharedFolder:WaitForChild("RigBuilder"))

-- Renders every player's equipped soccer player locally, running beside them
local FollowerController = {}
FollowerController.__index = FollowerController

local FOLLOW_OFFSET = Vector3.new(3.5, 0, 3)
local SNAP_DISTANCE = 40

function FollowerController.new()
    local self = setmetatable({}, FollowerController)

    self.followers = {}
    self.folder = Instance.new("Folder")
    self.folder.Name = "LocalFollowers"
    self.folder.Parent = Workspace

    local function watch(player)
        self:_update(player)
        player:GetAttributeChangedSignal("EquippedPlayer"):Connect(function()
            self:_update(player)
        end)
    end
    for _, player in ipairs(Players:GetPlayers()) do
        watch(player)
    end
    Players.PlayerAdded:Connect(watch)
    Players.PlayerRemoving:Connect(function(player)
        self:_remove(player)
    end)

    RunService.RenderStepped:Connect(function(dt)
        self:_step(dt)
    end)

    return self
end

function FollowerController:_remove(player)
    local follower = self.followers[player]
    if follower then
        follower.rig.model:Destroy()
        self.followers[player] = nil
    end
end

function FollowerController:_update(player)
    local id = player:GetAttribute("EquippedPlayer")
    local current = self.followers[player]
    if current and current.id == id then
        return
    end
    self:_remove(player)

    local definition = Catalog.getPlayer(id)
    if not definition then
        return
    end

    local rig = RigBuilder.build(definition, false)
    if definition.AuraColor then
        local fire = Instance.new("Fire")
        fire.Color = definition.AuraColor
        fire.SecondaryColor = Color3.new(1, 1, 1)
        fire.Size = 5
        fire.Parent = rig.parts.Torso
    end
    rig.model.Parent = self.folder

    self.followers[player] = {
        id = id,
        rig = rig,
        position = nil,
        facing = Vector3.new(0, 0, -1),
        phase = 0,
    }
end

function FollowerController:_step(dt)
    for player, follower in pairs(self.followers) do
        local character = player.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if rootPart and humanoid then
            local feetY = rootPart.Position.Y - humanoid.HipHeight - rootPart.Size.Y / 2
            local flatRoot = CFrame.lookAt(
                Vector3.new(rootPart.Position.X, feetY, rootPart.Position.Z),
                Vector3.new(rootPart.Position.X, feetY, rootPart.Position.Z) + Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
            )
            local target = (flatRoot * CFrame.new(FOLLOW_OFFSET)).Position

            local previous = follower.position
            if not previous or (previous - target).Magnitude > SNAP_DISTANCE then
                follower.position = target
            else
                follower.position = previous:Lerp(target, math.min(1, dt * 10))
            end

            local moved = previous and (follower.position - previous) or Vector3.zero
            local speed = moved.Magnitude / math.max(dt, 1e-3)
            local flatMove = Vector3.new(moved.X, 0, moved.Z)
            if flatMove.Magnitude > 0.02 then
                follower.facing = flatMove.Unit
            end

            follower.phase = follower.phase + dt * math.clamp(speed / 3, 0, 18)
            local swing = math.sin(follower.phase) * 0.8 * math.clamp(speed / 12, 0, 1)
            RigBuilder.pose(follower.rig, CFrame.lookAt(follower.position, follower.position + follower.facing), swing)
        end
    end
end

return FollowerController
