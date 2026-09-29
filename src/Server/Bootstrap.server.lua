local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Config = require(SharedFolder:WaitForChild("Config"))
local Remotes = require(SharedFolder:WaitForChild("Remotes"))

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = ReplicatedStorage

for _, eventName in pairs(Remotes.EventNames) do
    if not remotesFolder:FindFirstChild(eventName) then
        local remoteEvent = Instance.new("RemoteEvent")
        remoteEvent.Name = eventName
        remoteEvent.Parent = remotesFolder
    end
end

local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PlayerService = require(script.Parent:WaitForChild("PlayerService"))
local CourseService = require(script.Parent:WaitForChild("CourseService"))
local ShopService = require(script.Parent:WaitForChild("ShopService"))
local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))

local map = MapBuilder.build()
local dataService = DataService.new()
local playerService = PlayerService.new(dataService)
local courseService = CourseService.new(playerService, map)
local shopService = ShopService.new(playerService, courseService)
courseService:setShopService(shopService)
ProgressionService.new(playerService, shopService, map)
LeaderboardService.new(playerService, map)

print(("[%s] Server bootstrap loaded. Build %s"):format(Config.Name, Config.Version))
