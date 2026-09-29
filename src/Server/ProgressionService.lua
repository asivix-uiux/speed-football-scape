local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(SharedFolder:WaitForChild("Catalog"))
local Config = require(SharedFolder:WaitForChild("Config"))
local Format = require(SharedFolder:WaitForChild("Format"))
local Remotes = require(SharedFolder:WaitForChild("Remotes"))

local ProgressionService = {}
ProgressionService.__index = ProgressionService

local RED = Color3.fromRGB(255, 40, 40)
local GREEN = Color3.fromRGB(80, 255, 100)
local PEDESTAL_COOLDOWN = 1.5
local PLAYTIME_TOLERANCE = 3

local function clearAuraEffects(part)
    for _, child in ipairs(part:GetChildren()) do
        if child:GetAttribute("SFS_Aura") then
            child:Destroy()
        end
    end
end

-- Replaces the aura effects on a part (character root or a shop rig). Effects must be direct children of a part.
function ProgressionService.applyAuraEffect(part, aura)
    clearAuraEffects(part)
    if not aura then
        return
    end

    local effects = {}
    if aura.Effect == "Sparkles" or aura.Effect == "Rainbow" then
        local sparkles = Instance.new("Sparkles")
        sparkles.SparkleColor = aura.Color
        table.insert(effects, sparkles)
    end
    if aura.Effect == "Fire" then
        local fire = Instance.new("Fire")
        fire.Color = aura.Color
        fire.SecondaryColor = Color3.new(1, 1, 1)
        fire.Size = 7
        fire.Heat = 9
        table.insert(effects, fire)
    end
    if aura.Effect == "Particles" or aura.Effect == "Rainbow" then
        local emitter = Instance.new("ParticleEmitter")
        if aura.Effect == "Rainbow" then
            emitter.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
                ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 40)),
                ColorSequenceKeypoint.new(0.66, Color3.fromRGB(60, 220, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 60, 255)),
            })
        else
            emitter.Color = ColorSequence.new(aura.Color)
        end
        emitter.LightEmission = 1
        emitter.Rate = 40
        emitter.Lifetime = NumberRange.new(0.5, 1)
        emitter.Speed = NumberRange.new(3, 6)
        emitter.SpreadAngle = Vector2.new(180, 180)
        emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
        table.insert(effects, emitter)
    end

    for _, effect in ipairs(effects) do
        effect:SetAttribute("SFS_Aura", true)
        effect.Parent = part
    end
end

function ProgressionService.new(playerService, shopService, map)
    local self = setmetatable({}, ProgressionService)

    self.playerService = playerService
    self.shopService = shopService
    self.map = map
    self.cooldowns = {}

    local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
    self.rebirthRequest = remotesFolder:WaitForChild(Remotes.EventNames.RebirthRequest)
    self.auraRequest = remotesFolder:WaitForChild(Remotes.EventNames.AuraRequest)
    self.claimReward = remotesFolder:WaitForChild(Remotes.EventNames.ClaimReward)

    self:_bindPlayers()
    self:_bindPedestals()
    self:_bindRemotes()

    return self
end

-- Players ---------------------------------------------------------------------------------

function ProgressionService:_applyVisuals(player)
    local state = self.playerService:get(player)
    if not state then
        return
    end
    player:SetAttribute("EquippedPlayer", state.data.Equipped ~= "" and state.data.Equipped or nil)

    local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if rootPart then
        ProgressionService.applyAuraEffect(rootPart, Catalog.getAura(state.data.Aura))
    end
end

function ProgressionService:_bindPlayers()
    local function onPlayer(player)
        task.spawn(function()
            -- Data loads asynchronously
            while player.Parent and not self.playerService:get(player) do
                task.wait(0.25)
            end
            self:_validateOwnership(player)
            self:_applyVisuals(player)
        end)
        player.CharacterAdded:Connect(function(character)
            character:WaitForChild("HumanoidRootPart")
            self:_applyVisuals(player)
        end)
    end

    Players.PlayerAdded:Connect(onPlayer)
    for _, player in ipairs(Players:GetPlayers()) do
        onPlayer(player)
    end
    Players.PlayerRemoving:Connect(function(player)
        self.cooldowns[player] = nil
    end)
end

-- Drop saved pass items if the pass is no longer owned (e.g. Studio test grants)
function ProgressionService:_validateOwnership(player)
    task.wait(2) -- give ShopService time to confirm owned passes
    local state = self.playerService:get(player)
    if not state then
        return
    end
    local equipped = Catalog.getPlayer(state.data.Equipped)
    if equipped and equipped.Pass and not self.playerService:hasPass(player, equipped.Pass) then
        state.data.Equipped = ""
    end
    local aura = Catalog.getAura(state.data.Aura)
    if aura and aura.Pass and not self.playerService:hasPass(player, aura.Pass) then
        state.data.Aura = ""
    end
    state.dirty = true
    self:_applyVisuals(player)
end

-- Checks wins / pass requirements. Returns true if unlocked, otherwise notifies or prompts.
function ProgressionService:_checkUnlocked(player, definition, onPurchased)
    local state = self.playerService:get(player)
    if definition.Pass then
        if self.playerService:hasPass(player, definition.Pass) then
            return true
        end
        self.shopService:prompt(player, "Pass", definition.Pass, function(purchased)
            if purchased then
                onPurchased()
            end
        end)
        return false
    end

    local missing = (definition.RequiredWins or 0) - state.data.Wins
    if missing > 0 then
        self.playerService:notify(player, "Need " .. Format.abbreviate(missing) .. " more wins", RED)
        return false
    end
    return true
end

-- Soccer players ------------------------------------------------------------------------------

function ProgressionService:equipPlayer(player, definition)
    local state = self.playerService:get(player)
    if not state then
        return
    end
    if state.data.Equipped == definition.Id then
        self.playerService:notify(player, "Already equipped", RED)
        return
    end
    if not self:_checkUnlocked(player, definition, function()
        self:equipPlayer(player, definition)
    end) then
        return
    end

    state.data.Equipped = definition.Id
    state.dirty = true
    self:_applyVisuals(player)
    self.playerService:notify(player, "Equipped " .. definition.Name .. "! +" .. Format.abbreviate(definition.Bonus) .. " Speed", GREEN)
end

function ProgressionService:_bindPedestals()
    for _, pedestal in ipairs(self.map.pedestals) do
        pedestal.part.Touched:Connect(function(hit)
            local character = hit.Parent
            local player = character and Players:GetPlayerFromCharacter(character)
            if not player then
                return
            end

            local now = os.clock()
            local playerCooldowns = self.cooldowns[player] or {}
            self.cooldowns[player] = playerCooldowns
            if playerCooldowns[pedestal.definition.Id] and now < playerCooldowns[pedestal.definition.Id] then
                return
            end
            playerCooldowns[pedestal.definition.Id] = now + PEDESTAL_COOLDOWN

            self:equipPlayer(player, pedestal.definition)
        end)
    end
end

-- Rebirth / auras / free rewards -------------------------------------------------------------

function ProgressionService:rebirth(player)
    local state = self.playerService:get(player)
    if not state then
        return
    end
    local data = state.data
    if data.Level < Config.Player.MaxLevel then
        self.playerService:notify(player, "Reach Level " .. Config.Player.MaxLevel .. " to Rebirth!", RED)
        return
    end

    data.Rebirths = data.Rebirths + 1
    data.Level = 1
    data.XP = 0
    data.CustomSpeed = 0
    state.dirty = true
    self.playerService:notify(player, "REBIRTH! Speed boost is now x" .. Catalog.rebirthMultiplier(data.Rebirths), Color3.fromRGB(80, 220, 255))
end

function ProgressionService:setAura(player, auraId)
    local state = self.playerService:get(player)
    local aura = Catalog.getAura(auraId)
    if not state or not aura then
        return
    end

    if state.data.Aura == aura.Id then
        state.data.Aura = ""
        state.dirty = true
        self:_applyVisuals(player)
        return
    end
    if not self:_checkUnlocked(player, aura, function()
        self:setAura(player, auraId)
    end) then
        return
    end

    state.data.Aura = aura.Id
    state.dirty = true
    self:_applyVisuals(player)
    self.playerService:notify(player, aura.Name .. " aura equipped! x" .. aura.Multiplier .. " Speed", aura.Color)
end

function ProgressionService:claim(player, index)
    local state = self.playerService:get(player)
    local reward = Catalog.FreeRewards[index]
    if not state or not reward then
        return
    end
    -- String keys so the table survives remote serialization
    local key = tostring(index)
    if state.claimedRewards[key] then
        return
    end
    if os.clock() - state.joinTime + PLAYTIME_TOLERANCE < reward.Minutes * 60 then
        self.playerService:notify(player, "Not ready yet!", RED)
        return
    end

    state.claimedRewards[key] = true
    if reward.Speed then
        self.playerService:addSpeed(player, reward.Speed, false)
        self.playerService:notify(player, "+" .. Format.abbreviate(reward.Speed) .. " Speed!", GREEN)
    end
    if reward.Wins then
        self.playerService:addWins(player, reward.Wins, false)
        self.playerService:notify(player, "+" .. reward.Wins .. " Wins!", Color3.fromRGB(255, 215, 40))
    end
    state.dirty = true
end

function ProgressionService:_bindRemotes()
    self.rebirthRequest.OnServerEvent:Connect(function(player)
        self:rebirth(player)
    end)
    self.auraRequest.OnServerEvent:Connect(function(player, auraId)
        if type(auraId) == "string" then
            self:setAura(player, auraId)
        end
    end)
    self.claimReward.OnServerEvent:Connect(function(player, index)
        if type(index) == "number" then
            self:claim(player, index)
        end
    end)
end

return ProgressionService
