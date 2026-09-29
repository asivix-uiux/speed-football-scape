local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Config = require(SharedFolder:WaitForChild("Config"))
local Remotes = require(SharedFolder:WaitForChild("Remotes"))

local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))

local CourseService = {}
CourseService.__index = CourseService

local KNOCK_COOLDOWN = 0.8
local PAD_COOLDOWN = 2
local WALL_WARN_COLOR = Color3.fromRGB(255, 40, 40)
local WALL_STRIP_COLOR = Color3.fromRGB(232, 36, 52)

local function getPlayerFromHit(hit)
    if not hit or not hit.Parent then
        return nil
    end
    local player = Players:GetPlayerFromCharacter(hit.Parent)
    if not player and hit.Parent.Parent then
        player = Players:GetPlayerFromCharacter(hit.Parent.Parent)
    end
    return player
end

local function getRoot(player)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart or humanoid.Health <= 0 then
        return nil
    end
    return rootPart, character
end

function CourseService.new(playerService, map)
    local self = setmetatable({}, CourseService)

    self.playerService = playerService
    self.map = map
    self.shopService = nil
    self.collected = {}
    self.cooldowns = {}
    self.balls = {}
    self.ballTimers = {}
    self.rng = Random.new()
    self.clock = 0

    local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
    self.stageEntered = remotesFolder:WaitForChild(Remotes.EventNames.StageEntered)
    self.pickupCollected = remotesFolder:WaitForChild(Remotes.EventNames.PickupCollected)
    self.knockbackEvent = remotesFolder:WaitForChild(Remotes.EventNames.Knockback)
    self.diedEvent = remotesFolder:WaitForChild(Remotes.EventNames.Died)
    self.reviveChoice = remotesFolder:WaitForChild(Remotes.EventNames.ReviveChoice)

    self.overlapParams = OverlapParams.new()
    self.overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    self.overlapParams.FilterDescendantsInstances = { map.root }

    for index in ipairs(map.stages) do
        self.ballTimers[index] = 0
    end

    self:_bindPlayers()
    self:_bindTriggers()
    self:_bindPickups()
    self:_bindPads()
    self:_bindKillParts()
    self:_bindRevive()
    self:_bindHeartbeat()

    return self
end

function CourseService:setShopService(shopService)
    self.shopService = shopService
end

function CourseService:_cooldown(player, key, duration)
    local now = os.clock()
    local playerCooldowns = self.cooldowns[player]
    if not playerCooldowns then
        playerCooldowns = {}
        self.cooldowns[player] = playerCooldowns
    end
    if playerCooldowns[key] and now < playerCooldowns[key] then
        return false
    end
    playerCooldowns[key] = now + duration
    return true
end

function CourseService:_bindPlayers()
    local function onPlayer(player)
        player.CharacterAdded:Connect(function()
            local state = self.playerService:get(player)
            if state then
                state.dead = false
                state.revivePending = false
                state.stage = 0
                state.checkpoint = nil
                state.dirty = true
            end
            self.stageEntered:FireClient(player, 0)
        end)
    end

    Players.PlayerAdded:Connect(onPlayer)
    for _, player in ipairs(Players:GetPlayers()) do
        onPlayer(player)
    end

    Players.PlayerRemoving:Connect(function(player)
        self.collected[player] = nil
        self.cooldowns[player] = nil
    end)
end

function CourseService:_bindTriggers()
    for _, trigger in ipairs(self.map.stageTriggers) do
        local stageData = self.map.stages[trigger.index]
        trigger.part.Touched:Connect(function(hit)
            local player = getPlayerFromHit(hit)
            local state = player and self.playerService:get(player)
            if not state or state.dead or state.stage == trigger.index then
                return
            end
            state.stage = trigger.index
            state.checkpoint = stageData.checkpoint
            state.dirty = true
            self.stageEntered:FireClient(player, trigger.index)
        end)
    end
end

function CourseService:_bindPickups()
    for _, pickup in ipairs(self.map.pickups) do
        pickup.hitbox.Touched:Connect(function(hit)
            local player = getPlayerFromHit(hit)
            local state = player and self.playerService:get(player)
            if not state or state.dead then
                return
            end

            local collected = self.collected[player]
            if not collected then
                collected = {}
                self.collected[player] = collected
            end
            local now = os.clock()
            if collected[pickup.id] and now < collected[pickup.id] then
                return
            end
            collected[pickup.id] = now + Config.Course.PickupRespawn

            local gained = self.playerService:addSpeed(player, pickup.amount, true)
            self.pickupCollected:FireClient(player, pickup.id, Config.Course.PickupRespawn, gained, pickup.hitbox.Position)
        end)
    end
end

function CourseService:_bindPads()
    for _, pad in ipairs(self.map.returnPads) do
        pad.part.Touched:Connect(function(hit)
            local player = getPlayerFromHit(hit)
            local state = player and self.playerService:get(player)
            if not state or state.dead or not self:_cooldown(player, "ReturnPad", PAD_COOLDOWN) then
                return
            end
            local gained = self.playerService:addWins(player, pad.wins, true)
            self.playerService:notify(player, "+" .. gained .. " Wins!", Color3.fromRGB(255, 215, 40))
            self:sendToLobby(player)
        end)
    end

    for _, portal in ipairs(self.map.stagePortals) do
        portal.part.Touched:Connect(function(hit)
            local player = getPlayerFromHit(hit)
            local state = player and self.playerService:get(player)
            if not state or state.dead or not self:_cooldown(player, "Portal", PAD_COOLDOWN) then
                return
            end
            local missing = portal.requiredWins - state.data.Wins
            if missing > 0 then
                self.playerService:notify(player, "Need " .. missing .. " more wins", Color3.fromRGB(255, 40, 40))
                return
            end
            if not self.map.stages[portal.stage] then
                self.playerService:notify(player, "Stage " .. portal.stage .. " is coming soon!", Color3.fromRGB(255, 200, 40))
                return
            end
            self:teleportToStage(player, portal.stage)
        end)
    end

    for _, pad in ipairs(self.map.speedBoostPads) do
        pad.Touched:Connect(function(hit)
            local player = getPlayerFromHit(hit)
            if player and self.shopService and self:_cooldown(player, "SpeedBoostPad", 5) then
                self.shopService:prompt(player, "Product", "SpeedBoost")
            end
        end)
    end

    for _, pad in ipairs(self.map.doubleWinsPads) do
        pad.Touched:Connect(function(hit)
            local player = getPlayerFromHit(hit)
            if not player or not self:_cooldown(player, "DoubleWinsPad", 5) then
                return
            end
            if self.playerService:hasPass(player, "DoubleWins") then
                self.playerService:notify(player, "x2 Wins is active!", Color3.fromRGB(200, 80, 255))
            elseif self.shopService then
                self.shopService:prompt(player, "Pass", "DoubleWins")
            end
        end)
    end
end

function CourseService:_bindKillParts()
    for _, part in ipairs(CollectionService:GetTagged("KillPart")) do
        part.Touched:Connect(function(hit)
            local player = getPlayerFromHit(hit)
            if player then
                self:kill(player)
            end
        end)
    end
end

-- Death / revive ----------------------------------------------------------------

function CourseService:_teleport(player, cframe)
    local rootPart, character = getRoot(player)
    if not rootPart then
        return
    end
    character:PivotTo(cframe)
    rootPart.AssemblyLinearVelocity = Vector3.zero
    rootPart.AssemblyAngularVelocity = Vector3.zero
    rootPart.Anchored = false
end

function CourseService:_offerRevive(player)
    local state = self.playerService:get(player)
    if not state then
        return
    end
    state.deathToken = (state.deathToken or 0) + 1
    local token = state.deathToken
    self.diedEvent:FireClient(player, Config.Revive.Timeout, Config.Products.Revive.Price)

    task.delay(Config.Revive.Timeout, function()
        if state.dead and not state.revivePending and state.deathToken == token then
            self:sendToLobby(player)
        end
    end)
end

function CourseService:kill(player)
    local state = self.playerService:get(player)
    if not state or state.dead or os.clock() < state.shieldUntil then
        return
    end
    local rootPart = getRoot(player)
    if not rootPart then
        return
    end

    if not state.checkpoint then
        -- Nothing to revive to (e.g. fell out of the lobby)
        self:sendToLobby(player)
        return
    end

    state.dead = true
    state.revivePending = false
    state.dirty = true
    rootPart.AssemblyLinearVelocity = Vector3.zero
    rootPart.Anchored = true
    self:_offerRevive(player)
end

function CourseService:revive(player)
    local state = self.playerService:get(player)
    if not state or not state.dead or not state.checkpoint then
        return false
    end
    state.dead = false
    state.revivePending = false
    state.shieldUntil = os.clock() + Config.Revive.ShieldTime
    state.dirty = true
    self:_teleport(player, state.checkpoint)

    local character = player.Character
    if character then
        local shield = Instance.new("ForceField")
        shield.Parent = character
        task.delay(Config.Revive.ShieldTime, function()
            shield:Destroy()
        end)
    end
    return true
end

function CourseService:teleportToStage(player, stageIndex)
    local state = self.playerService:get(player)
    local stageData = self.map.stages[stageIndex]
    if not state or not stageData then
        return
    end
    state.stage = stageIndex
    state.checkpoint = stageData.checkpoint
    state.dirty = true
    self:_teleport(player, stageData.checkpoint)
    self.stageEntered:FireClient(player, stageIndex)
end

function CourseService:sendToLobby(player)
    local state = self.playerService:get(player)
    if state then
        state.dead = false
        state.revivePending = false
        state.stage = 0
        state.checkpoint = nil
        state.dirty = true
    end
    self:_teleport(player, self.map.lobbySpawn)
    self.stageEntered:FireClient(player, 0)
end

function CourseService:_bindRevive()
    self.reviveChoice.OnServerEvent:Connect(function(player, wantsRevive)
        local state = self.playerService:get(player)
        if not state or not state.dead or state.revivePending then
            return
        end

        if wantsRevive ~= true or not self.shopService then
            self:sendToLobby(player)
            return
        end

        state.revivePending = true
        self.shopService:prompt(player, "Product", "Revive", function(purchased)
            if not purchased and state.dead then
                state.revivePending = false
                self:_offerRevive(player)
            end
        end)
    end)
end

-- Knockback ----------------------------------------------------------------------

function CourseService:_knockback(player, direction, strength)
    if not self:_cooldown(player, "Knockback", KNOCK_COOLDOWN) then
        return
    end
    local flat = Vector3.new(direction.X, 0, direction.Z)
    if flat.Magnitude < 0.01 then
        flat = Vector3.new(0, 0, -1)
    end
    self.knockbackEvent:FireClient(player, flat.Unit * strength + Vector3.new(0, strength * 0.45, 0))
end

-- Rolling balls --------------------------------------------------------------------

function CourseService:_spawnBall(stageData)
    local course = Config.Course
    local config = stageData.config
    local diameter = self.rng:NextInteger(config.BallSizeMin or 8, config.BallSizeMax or 13)
    local halfRange = math.max(0, (config.PathWidth or course.Width) / 2 - diameter / 2 - 1)
    local x = self.rng:NextNumber(-halfRange, halfRange)
    local z = stageData.endZ - course.EndZoneLength + 4

    local ball = MapBuilder.makeFootball(diameter, false)
    ball.CustomPhysicalProperties = PhysicalProperties.new(0.4, 0.3, 0.2)
    MapBuilder.placeFootball(ball, CFrame.new(x, diameter / 2 + 1, z), self.map.ballsFolder)
    ball:SetNetworkOwner(nil)

    local speed = stageData.config.BallSpeed
    ball.AssemblyLinearVelocity = Vector3.new(0, 0, -speed)
    ball.AssemblyAngularVelocity = Vector3.new(-speed / (diameter / 2), 0, 0)

    ball.Touched:Connect(function(hit)
        local player = getPlayerFromHit(hit)
        local rootPart = player and getRoot(player)
        if rootPart then
            local away = rootPart.Position - ball.Position
            self:_knockback(player, away + Vector3.new(0, 0, -diameter), course.BallKnockback)
        end
    end)

    table.insert(self.balls, {
        part = ball,
        speed = speed,
        minZ = stageData.startZ,
        expires = os.clock() + course.BallLifetime,
    })
end

function CourseService:_updateBalls(dt)
    local now = os.clock()

    for index = #self.balls, 1, -1 do
        local ball = self.balls[index]
        local part = ball.part
        if not part.Parent or now > ball.expires or part.Position.Y < Config.Course.VoidY or part.Position.Z < ball.minZ then
            part:Destroy()
            table.remove(self.balls, index)
        else
            local velocity = part.AssemblyLinearVelocity
            part.AssemblyLinearVelocity = Vector3.new(velocity.X, velocity.Y, -ball.speed)
        end
    end

    -- Only spawn balls in stages that have a living player in them
    local occupied = {}
    for player, state in pairs(self.playerService.states) do
        if state.stage > 0 and not state.dead and player.Parent then
            occupied[state.stage] = true
        end
    end

    for index, stageData in ipairs(self.map.stages) do
        if occupied[index] then
            self.ballTimers[index] = self.ballTimers[index] + dt
            if self.ballTimers[index] >= stageData.config.BallInterval then
                self.ballTimers[index] = 0
                self:_spawnBall(stageData)
            end
        end
    end
end

-- Falling walls & sweepers ---------------------------------------------------------------

function CourseService:_crushCheck(part)
    local hits = Workspace:GetPartBoundsInBox(part.CFrame, part.Size, self.overlapParams)
    local handled = {}
    for _, hit in ipairs(hits) do
        local player = getPlayerFromHit(hit)
        if player and not handled[player] then
            handled[player] = true
            self:kill(player)
        end
    end
end

function CourseService:_updateFallingWalls()
    local timing = Config.FallingWalls
    local warnStart = timing.RaisedTime
    local fallStart = warnStart + timing.WarnTime
    local downStart = fallStart + timing.FallTime
    local riseStart = downStart + timing.DownTime
    local cycle = riseStart + timing.RiseTime

    for _, stageData in ipairs(self.map.stages) do
        for _, wall in ipairs(stageData.fallingWalls) do
            local phase = (self.clock + wall.offset) % cycle
            local state, cframe

            if phase < warnStart then
                state, cframe = "up", wall.upCFrame
            elseif phase < fallStart then
                state, cframe = "warn", wall.upCFrame
            elseif phase < downStart then
                local alpha = (phase - fallStart) / timing.FallTime
                state, cframe = "falling", wall.upCFrame:Lerp(wall.downCFrame, alpha * alpha)
            elseif phase < riseStart then
                state, cframe = "down", wall.downCFrame
            else
                local alpha = (phase - riseStart) / timing.RiseTime
                state, cframe = "rising", wall.downCFrame:Lerp(wall.upCFrame, alpha)
            end

            if wall.part.CFrame ~= cframe then
                wall.part.CFrame = cframe
            end

            if state ~= wall.state then
                local warning = state == "warn" or state == "falling"
                wall.strip.Material = warning and Enum.Material.Neon or Enum.Material.Plastic
                wall.strip.Color = warning and WALL_WARN_COLOR or WALL_STRIP_COLOR
                wall.part.Color = warning and Color3.fromRGB(200, 120, 140) or Color3.fromRGB(150, 138, 168)
            end

            if state == "falling" or (state == "down" and wall.state == "falling") then
                self:_crushCheck(wall.part)
            end
            wall.state = state
        end
    end
end

function CourseService:_updateSweepers(dt)
    for _, stageData in ipairs(self.map.stages) do
        for _, sweeper in ipairs(stageData.sweepers) do
            sweeper.angle = sweeper.angle + sweeper.speed * dt
            local cframe = CFrame.new(sweeper.center) * CFrame.Angles(0, sweeper.angle, 0)
            sweeper.part.CFrame = cframe

            local axis = cframe.RightVector
            for player, state in pairs(self.playerService.states) do
                if state.stage == stageData.index and not state.dead then
                    local rootPart = getRoot(player)
                    if rootPart then
                        local offset = rootPart.Position - sweeper.center
                        local along = offset:Dot(axis)
                        local perpendicular = offset - axis * along
                        local flatDistance = Vector3.new(perpendicular.X, 0, perpendicular.Z).Magnitude
                        if math.abs(offset.Y) < 4 and math.abs(along) <= sweeper.halfLength + 1 and flatDistance < 2.4 then
                            local push = flatDistance > 0.1 and perpendicular or cframe.LookVector
                            self:_knockback(player, push, 60)
                        end
                    end
                end
            end
        end
    end
end

-- "RUN!" stages: a wall waits at the start, then sweeps to the end and kills anyone it catches
function CourseService:_updateChase(dt)
    for _, stageData in ipairs(self.map.stages) do
        local chase = stageData.chase
        if chase then
            if not chase.z then
                chase.timer = chase.timer + dt
                if chase.timer >= chase.wait then
                    chase.timer = 0
                    chase.z = chase.fromZ
                end
            else
                chase.z = chase.z + chase.speed * dt
                if chase.z > chase.toZ then
                    chase.z = nil
                    chase.part.CFrame = CFrame.new(0, -200, chase.fromZ)
                else
                    chase.part.CFrame = CFrame.new(0, chase.part.Size.Y / 2, chase.z)
                    self:_crushCheck(chase.part)
                end
            end
        end
    end
end

function CourseService:_checkVoid()
    for player, state in pairs(self.playerService.states) do
        if not state.dead then
            local rootPart = getRoot(player)
            if rootPart and rootPart.Position.Y < Config.Course.VoidY then
                self:kill(player)
            end
        end
    end
end

function CourseService:_bindHeartbeat()
    RunService.Heartbeat:Connect(function(dt)
        self.clock = self.clock + dt
        self:_updateFallingWalls()
        self:_updateSweepers(dt)
        self:_updateChase(dt)
        self:_updateBalls(dt)
        self:_checkVoid()
    end)
end

return CourseService
