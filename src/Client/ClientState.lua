local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(SharedFolder:WaitForChild("Remotes"))

-- Latest server stats plus a Changed signal shared by the client controllers
local ClientState = {}

local changedEvent = Instance.new("BindableEvent")
ClientState.stats = nil
ClientState.Changed = changedEvent.Event

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

function ClientState.getRemote(name)
    return remotesFolder:WaitForChild(Remotes.EventNames[name])
end

ClientState.getRemote("StatsUpdated").OnClientEvent:Connect(function(stats)
    ClientState.stats = stats
    ClientState.receivedAt = os.clock()
    changedEvent:Fire(stats)
end)

-- Session playtime in seconds, extrapolated since the last stats update
function ClientState.getPlayTime()
    local stats = ClientState.stats
    if not stats then
        return 0
    end
    return stats.PlayTime + (os.clock() - ClientState.receivedAt)
end

return ClientState
