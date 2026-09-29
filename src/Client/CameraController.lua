local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ClientState = require(script.Parent:WaitForChild("ClientState"))

-- Keeps Roblox's default follow camera and widens the FOV while sprinting
local CameraController = {}
CameraController.__index = CameraController

local BASE_FOV = 70
local SPRINT_FOV = 82

function CameraController.new()
    local self = setmetatable({}, CameraController)

    self.targetFov = BASE_FOV

    ClientState.Changed:Connect(function(stats)
        self.targetFov = stats.Sprinting and SPRINT_FOV or BASE_FOV
    end)

    RunService.RenderStepped:Connect(function(dt)
        local camera = Workspace.CurrentCamera
        if camera then
            local alpha = math.min(1, dt * 8)
            camera.FieldOfView = camera.FieldOfView + (self.targetFov - camera.FieldOfView) * alpha
        end
    end)

    return self
end

return CameraController
