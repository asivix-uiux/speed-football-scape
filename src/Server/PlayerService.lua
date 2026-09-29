local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Config = require(SharedFolder:WaitForChild("Config"))
local Remotes = require(SharedFolder:WaitForChild("Remotes"))
local Catalog = require(SharedFolder:WaitForChild("Catalog"))

local PlayerService = {}
PlayerService.__index = PlayerService

local STATS_SEND_INTERVAL = 0.1
local LOCKED_NOTIFY_COOLDOWN = 2

function PlayerService.new(dataService)
    local self = setmetatable({}, PlayerService)

    self.dataService = dataService
    self.states = {}

    local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
    self.statsUpdated = remotesFolder:WaitForChild(Remotes.EventNames.StatsUpdated)
    self.sprintRequest = remotesFolder:WaitForChild(Remotes.EventNames.SprintRequest)
    self.setCustomSpeed = remotesFolder:WaitForChild(Remotes.EventNames.SetCustomSpeed)
    self.notifyEvent = remotesFolder:WaitForChild(Remotes.EventNames.Notify)
    self.levelUpEvent = remotesFolder:WaitForChild(Remotes.EventNames.LevelUp)

    self.rayParams = RaycastParams.new()
    self.rayParams.FilterType = Enum.RaycastFilterType.Exclude

    self:_bindPlayers()
    self:_bindRemotes()
    self:_bindHeartbeat()

    return self
end

function PlayerService:_bindPlayers()
    Players.PlayerAdded:Connect(function(player)
        self:_setupPlayer(player)
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(function()
            self:_setupPlayer(player)
        end)
    end

    Players.PlayerRemoving:Connect(function(player)
        self.states[player] = nil
        self.dataService:release(player)
    end)
end

function PlayerService:_setupPlayer(player)
    local data = self.dataService:load(player)
    if not player.Parent then
        return
    end

    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    local winsValue = Instance.new("IntValue")
    winsValue.Name = "Wins"
    winsValue.Value = data.Wins
    winsValue.Parent = leaderstats
    local speedValue = Instance.new("IntValue")
    speedValue.Name = "Speed"
    speedValue.Value = data.Speed
    speedValue.Parent = leaderstats
    leaderstats.Parent = player

    local state = {
        data = data,
        winsValue = winsValue,
        speedValue = speedValue,
        stamina = Config.Player.StaminaMax,
        sprintHeld = false,
        sprinting = false,
        regenDelay = 0,
        gainTimer = 0,
        dirty = true,
        lastSent = 0,
        lastLockedNotify = 0,
        sessionPasses = {},
        joinTime = os.clock(),
        claimedRewards = {},
        -- Course progress (managed by CourseService)
        stage = 0,
        checkpoint = nil,
        dead = false,
        shieldUntil = 0,
    }
    self.states[player] = state

    player.CharacterAdded:Connect(function(character)
        self:_setupCharacter(player, character)
    end)
    if player.Character then
        self:_setupCharacter(player, player.Character)
    end
end

function PlayerService:_setupCharacter(player, character)
    local state = self.states[player]
    if not state then
        return
    end
    local humanoid = character:WaitForChild("Humanoid")
    humanoid.WalkSpeed = self:getWalkSpeed(player)
    state.stamina = Config.Player.StaminaMax
    state.sprinting = false
    state.dirty = true
end

function PlayerService:_bindRemotes()
    self.sprintRequest.OnServerEvent:Connect(function(player, held)
        local state = self.states[player]
        if state then
            state.sprintHeld = held == true
        end
    end)

    self.setCustomSpeed.OnServerEvent:Connect(function(player, value)
        local state = self.states[player]
        if not state or type(value) ~= "number" or value ~= value then
            return
        end
        local maxSpeed = Config.MaxSpeedForLevel(state.data.Level, state.data.Rebirths)
        value = math.floor(value)
        if value >= maxSpeed then
            state.data.CustomSpeed = 0
        else
            state.data.CustomSpeed = math.clamp(value, Config.Player.MinWalkSpeed, maxSpeed)
        end
        state.dirty = true
    end)
end

function PlayerService:get(player)
    return self.states[player]
end

function PlayerService:notify(player, text, color)
    self.notifyEvent:FireClient(player, text, color)
end

function PlayerService:hasPass(player, key)
    local state = self.states[player]
    if not state then
        return false
    end
    return state.data.Passes[key] == true or state.sessionPasses[key] == true
end

function PlayerService:grantPass(player, key, persistent)
    local state = self.states[player]
    if not state then
        return
    end
    if persistent then
        state.data.Passes[key] = true
    else
        state.sessionPasses[key] = true
    end
    state.dirty = true
end

function PlayerService:getMaxSpeed(player)
    local state = self.states[player]
    return Config.MaxSpeedForLevel(state and state.data.Level or 1, state and state.data.Rebirths or 0)
end

function PlayerService:getWalkSpeed(player)
    local state = self.states[player]
    if not state then
        return Config.Player.MinWalkSpeed
    end
    local maxSpeed = Config.MaxSpeedForLevel(state.data.Level, state.data.Rebirths)
    local speed = state.data.CustomSpeed
    if speed <= 0 or speed > maxSpeed then
        speed = maxSpeed
    end
    if state.sprinting then
        speed = speed * Config.Player.SprintMultiplier
    end
    return speed
end

-- Combined multiplier for earned Speed: 2x pass, rebirths and aura
function PlayerService:getSpeedMultiplier(player)
    local state = self.states[player]
    if not state then
        return 1
    end
    local multiplier = Catalog.rebirthMultiplier(state.data.Rebirths)
    local aura = Catalog.getAura(state.data.Aura)
    if aura then
        multiplier = multiplier * aura.Multiplier
    end
    if self:hasPass(player, "DoubleSpeed") then
        multiplier = multiplier * 2
    end
    if os.time() < state.data.BoostUntil then
        multiplier = multiplier * Config.SpeedBoost.Multiplier
    end
    return multiplier
end

-- Stacks bought speed boost time
function PlayerService:addBoost(player, seconds)
    local state = self.states[player]
    if not state then
        return
    end
    state.data.BoostUntil = math.max(os.time(), state.data.BoostUntil) + seconds
    state.dirty = true
end

-- Extra Speed per running step from the equipped soccer player
function PlayerService:getStepBonus(player)
    local state = self.states[player]
    local soccerPlayer = state and Catalog.getPlayer(state.data.Equipped)
    return soccerPlayer and soccerPlayer.Bonus or 0
end

-- boosted = true applies getSpeedMultiplier (used for running/pickups, not for purchases)
function PlayerService:addSpeed(player, amount, boosted)
    local state = self.states[player]
    if not state or amount <= 0 then
        return 0
    end
    if boosted then
        amount = math.floor(amount * self:getSpeedMultiplier(player) + 0.5)
    end

    local data = state.data
    data.Speed = data.Speed + amount
    state.speedValue.Value = math.min(data.Speed, 2 ^ 31 - 1)

    -- XP is earned 1:1 with speed; at MAX level the bar keeps filling up to its cap
    local oldLevel = data.Level
    data.XP = data.XP + amount
    while data.Level < Config.Player.MaxLevel and data.XP >= Config.XpForLevel(data.Level) do
        data.XP = data.XP - Config.XpForLevel(data.Level)
        data.Level = data.Level + 1
    end
    if data.Level >= Config.Player.MaxLevel then
        data.XP = math.min(data.XP, Config.XpForLevel(Config.Player.MaxLevel))
    end
    if data.Level > oldLevel then
        self.levelUpEvent:FireClient(player, oldLevel, data.Level)
    end

    state.dirty = true
    return amount
end

function PlayerService:addWins(player, amount, boosted)
    local state = self.states[player]
    if not state or amount <= 0 then
        return 0
    end
    if boosted and self:hasPass(player, "DoubleWins") then
        amount = amount * 2
    end
    state.data.Wins = state.data.Wins + amount
    state.winsValue.Value = state.data.Wins
    state.dirty = true
    return amount
end

function PlayerService:_getTreadmillMultiplier(player, rootPart)
    self.rayParams.FilterDescendantsInstances = { player.Character }
    local result = workspace:Raycast(rootPart.Position, Vector3.new(0, -8, 0), self.rayParams)
    if not result then
        return 1
    end

    local multiplier = result.Instance:GetAttribute("SpeedMultiplier")
    if not multiplier then
        return 1
    end

    local state = self.states[player]
    local requiredWins = result.Instance:GetAttribute("RequiredWins") or 0
    local requiredPass = result.Instance:GetAttribute("RequiredPass")
    local locked = false
    local message = nil

    if requiredPass and not self:hasPass(player, requiredPass) then
        locked = true
        message = "Buy the " .. multiplier .. "x Run Area to use this!"
    elseif state.data.Wins < requiredWins then
        locked = true
        message = "Need " .. (requiredWins - state.data.Wins) .. " more wins"
    end

    if locked then
        local now = os.clock()
        if now - state.lastLockedNotify > LOCKED_NOTIFY_COOLDOWN then
            state.lastLockedNotify = now
            self:notify(player, message, Color3.fromRGB(255, 40, 40))
        end
        return 1
    end

    return multiplier
end

function PlayerService:_updatePlayer(player, state, dt)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart or humanoid.Health <= 0 then
        return
    end

    local velocity = rootPart.AssemblyLinearVelocity
    local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
    local moving = humanoid.MoveDirection.Magnitude > 0.1 or horizontalSpeed > 4

    -- Stamina / sprint
    local wasSprinting = state.sprinting
    local oldStamina = state.stamina
    if state.sprintHeld and moving and state.stamina > 0 and not state.dead then
        state.sprinting = true
        state.stamina = math.max(0, state.stamina - Config.Player.StaminaDrain * dt)
        state.regenDelay = Config.Player.StaminaRegenDelay
    else
        state.sprinting = false
        if state.regenDelay > 0 then
            state.regenDelay = state.regenDelay - dt
        else
            state.stamina = math.min(Config.Player.StaminaMax, state.stamina + Config.Player.StaminaRegen * dt)
        end
    end
    if wasSprinting ~= state.sprinting or math.floor(oldStamina) ~= math.floor(state.stamina) then
        state.dirty = true
    end

    local walkSpeed = self:getWalkSpeed(player)
    if math.abs(humanoid.WalkSpeed - walkSpeed) > 0.01 then
        humanoid.WalkSpeed = walkSpeed
    end

    -- Passive speed gain while running
    state.gainTimer = state.gainTimer + dt
    if state.gainTimer >= Config.Player.GainInterval then
        state.gainTimer = state.gainTimer - Config.Player.GainInterval
        if moving and not state.dead then
            local multiplier = self:_getTreadmillMultiplier(player, rootPart)
            self:addSpeed(player, (Config.Player.SpeedPerTick + self:getStepBonus(player)) * multiplier, true)
        end
    end
end

function PlayerService:_sendStats(player, state)
    local data = state.data
    local passes = {}
    for key in pairs(Config.Passes) do
        passes[key] = self:hasPass(player, key)
    end

    self.statsUpdated:FireClient(player, {
        Speed = data.Speed,
        Wins = data.Wins,
        Level = data.Level,
        MaxLevel = Config.Player.MaxLevel,
        XP = data.XP,
        XPNeeded = Config.XpForLevel(data.Level),
        MaxSpeed = Config.MaxSpeedForLevel(data.Level, data.Rebirths),
        CustomSpeed = data.CustomSpeed,
        Stamina = state.stamina,
        StaminaMax = Config.Player.StaminaMax,
        Sprinting = state.sprinting,
        Stage = state.stage,
        Dead = state.dead,
        Passes = passes,
        Rebirths = data.Rebirths,
        Equipped = data.Equipped,
        Aura = data.Aura,
        Multiplier = self:getSpeedMultiplier(player),
        StepBonus = self:getStepBonus(player),
        PlayTime = os.clock() - state.joinTime,
        BoostRemaining = math.max(0, state.data.BoostUntil - os.time()),
        ClaimedRewards = state.claimedRewards,
    })
end

function PlayerService:_bindHeartbeat()
    RunService.Heartbeat:Connect(function(dt)
        local now = os.clock()
        for player, state in pairs(self.states) do
            self:_updatePlayer(player, state, dt)
            if state.dirty and now - state.lastSent >= STATS_SEND_INTERVAL then
                state.dirty = false
                state.lastSent = now
                self:_sendStats(player, state)
            end
        end
    end)
end

return PlayerService
