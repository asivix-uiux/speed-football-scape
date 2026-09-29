local UserInputService = game:GetService("UserInputService")

local ClientState = require(script.Parent:WaitForChild("ClientState"))

local InputController = {}
InputController.__index = InputController

local SPRINT_KEYS = {
    [Enum.KeyCode.LeftShift] = true,
    [Enum.KeyCode.RightShift] = true,
    [Enum.KeyCode.ButtonL3] = true,
}

function InputController.new()
    local self = setmetatable({}, InputController)

    self.sprintRequest = ClientState.getRemote("SprintRequest")
    self.held = {}

    self:_bindInput()
    return self
end

function InputController:_setHeld(keyCode, held)
    local wasHeld = next(self.held) ~= nil
    self.held[keyCode] = held or nil
    local isHeld = next(self.held) ~= nil
    if wasHeld ~= isHeld then
        self.sprintRequest:FireServer(isHeld)
    end
end

function InputController:_bindInput()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and SPRINT_KEYS[input.KeyCode] then
            self:_setHeld(input.KeyCode, true)
        end
    end)

    -- Always handle release, even if the key-up was consumed by a text box
    UserInputService.InputEnded:Connect(function(input)
        if SPRINT_KEYS[input.KeyCode] then
            self:_setHeld(input.KeyCode, false)
        end
    end)
end

return InputController
