local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Config = require(SharedFolder:WaitForChild("Config"))

local CameraController = require(script.Parent:WaitForChild("CameraController"))
local EffectsController = require(script.Parent:WaitForChild("EffectsController"))
local FollowerController = require(script.Parent:WaitForChild("FollowerController"))
local HUDController = require(script.Parent:WaitForChild("HUDController"))
local InputController = require(script.Parent:WaitForChild("InputController"))
local PanelController = require(script.Parent:WaitForChild("PanelController"))

CameraController.new()
EffectsController.new()
FollowerController.new()
local hud = HUDController.new()
hud.panels = PanelController.new(hud)
InputController.new()

print(("[%s] Client bootstrap loaded. Version %s"):format(Config.Name, Config.Version))
