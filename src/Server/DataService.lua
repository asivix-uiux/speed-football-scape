local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Config = require(SharedFolder:WaitForChild("Config"))

local DataService = {}
DataService.__index = DataService

local DEFAULT_DATA = {
    Speed = 0,
    Wins = 0,
    Level = 1,
    XP = 0,
    CustomSpeed = 0, -- 0 = follow max speed automatically
    Passes = {},
    Rebirths = 0,
    Equipped = "", -- soccer player id, "" = none
    Aura = "", -- aura id, "" = none
    BoostUntil = 0, -- os.time() when the bought speed boost ends
}

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, inner in pairs(value) do
        copy[key] = deepCopy(inner)
    end
    return copy
end

local function reconcile(data)
    for key, value in pairs(DEFAULT_DATA) do
        if data[key] == nil then
            data[key] = deepCopy(value)
        end
    end
    return data
end

function DataService.new()
    local self = setmetatable({}, DataService)

    self.cache = {}
    self.canSave = {}

    local ok, store = pcall(function()
        return DataStoreService:GetDataStore(Config.DataStoreName)
    end)
    self.store = ok and store or nil
    if not ok then
        warn("[DataService] DataStore unavailable, progress will not be saved:", store)
    end

    task.spawn(function()
        while true do
            task.wait(Config.AutoSaveInterval)
            for _, player in ipairs(Players:GetPlayers()) do
                self:save(player)
            end
        end
    end)

    game:BindToClose(function()
        for _, player in ipairs(Players:GetPlayers()) do
            self:save(player)
        end
    end)

    return self
end

function DataService:load(player)
    local key = "Player_" .. player.UserId
    local data = nil
    local loaded = false

    if self.store then
        for _ = 1, 3 do
            local ok, result = pcall(function()
                return self.store:GetAsync(key)
            end)
            if ok then
                data = result
                loaded = true
                break
            end
            warn("[DataService] Load failed for", player.Name, result)
            task.wait(1)
        end
    end

    if type(data) ~= "table" then
        data = deepCopy(DEFAULT_DATA)
    end

    self.cache[player] = reconcile(data)
    -- Never overwrite saved progress with defaults when loading failed
    self.canSave[player] = loaded
    return self.cache[player]
end

function DataService:get(player)
    return self.cache[player]
end

function DataService:save(player)
    local data = self.cache[player]
    if not data or not self.store or not self.canSave[player] then
        return
    end

    local ok, err = pcall(function()
        self.store:SetAsync("Player_" .. player.UserId, data)
    end)
    if not ok then
        warn("[DataService] Save failed for", player.Name, err)
    end
end

function DataService:release(player)
    self:save(player)
    self.cache[player] = nil
    self.canSave[player] = nil
end

return DataService
