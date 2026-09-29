local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Config = require(SharedFolder:WaitForChild("Config"))
local Format = require(SharedFolder:WaitForChild("Format"))

local LeaderboardService = {}
LeaderboardService.__index = LeaderboardService

local REFRESH_INTERVAL = 60
local ROWS = 10
local RANK_COLORS = {
    Color3.fromRGB(255, 200, 30),
    Color3.fromRGB(190, 200, 215),
    Color3.fromRGB(215, 130, 60),
}

function LeaderboardService.new(playerService, map)
    local self = setmetatable({}, LeaderboardService)

    self.playerService = playerService
    self.boards = {
        { stat = "Speed", list = map.leaderboards.Speed },
        { stat = "Wins", list = map.leaderboards.Wins },
    }
    self.nameCache = {}

    for _, board in ipairs(self.boards) do
        local ok, store = pcall(function()
            return DataStoreService:GetOrderedDataStore(Config.DataStoreName .. "_Top" .. board.stat)
        end)
        board.store = ok and store or nil
    end

    task.spawn(function()
        task.wait(5)
        while true do
            self:refresh()
            task.wait(REFRESH_INTERVAL)
        end
    end)

    return self
end

function LeaderboardService:_getName(userId)
    if self.nameCache[userId] then
        return self.nameCache[userId]
    end
    local player = Players:GetPlayerByUserId(userId)
    local name = player and player.Name
    if not name then
        local ok, result = pcall(function()
            return Players:GetNameFromUserIdAsync(userId)
        end)
        name = ok and result or ("User " .. userId)
    end
    self.nameCache[userId] = name
    return name
end

function LeaderboardService:_fetch(board)
    -- Push current players' values, then read the global top list
    local entries = nil
    if board.store then
        for player, state in pairs(self.playerService.states) do
            pcall(function()
                board.store:SetAsync(tostring(player.UserId), math.floor(state.data[board.stat]))
            end)
        end

        local ok, pages = pcall(function()
            return board.store:GetSortedAsync(false, ROWS)
        end)
        if ok then
            entries = {}
            for _, entry in ipairs(pages:GetCurrentPage()) do
                table.insert(entries, { userId = tonumber(entry.key), value = entry.value })
            end
        end
    end

    -- Fallback (e.g. Studio without API access): current server only
    if not entries then
        entries = {}
        for player, state in pairs(self.playerService.states) do
            table.insert(entries, { userId = player.UserId, value = state.data[board.stat] })
        end
        table.sort(entries, function(a, b)
            return a.value > b.value
        end)
    end

    return entries
end

function LeaderboardService:_render(board, entries)
    for _, child in ipairs(board.list:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    for rank = 1, math.min(ROWS, #entries) do
        local entry = entries[rank]
        local row = Instance.new("Frame")
        row.LayoutOrder = rank
        row.Size = UDim2.fromScale(1, 0.09)
        row.BackgroundColor3 = rank % 2 == 0 and Color3.fromRGB(228, 232, 240) or Color3.fromRGB(240, 242, 248)
        row.BorderSizePixel = 0
        row.Parent = board.list

        local function label(text, x, width, color, alignment)
            local textLabel = Instance.new("TextLabel")
            textLabel.Size = UDim2.fromScale(width, 1)
            textLabel.Position = UDim2.fromScale(x, 0)
            textLabel.BackgroundTransparency = 1
            textLabel.Font = Enum.Font.FredokaOne
            textLabel.TextScaled = true
            textLabel.Text = text
            textLabel.TextColor3 = color
            textLabel.TextXAlignment = alignment
            textLabel.Parent = row
            return textLabel
        end

        label("#" .. rank, 0.02, 0.14, RANK_COLORS[rank] or Color3.fromRGB(60, 60, 80), Enum.TextXAlignment.Left)
        label(self:_getName(entry.userId), 0.17, 0.55, Color3.fromRGB(40, 40, 60), Enum.TextXAlignment.Left)
        label(Format.scientific(entry.value), 0.72, 0.26, Color3.fromRGB(30, 170, 60), Enum.TextXAlignment.Right)
    end
end

function LeaderboardService:refresh()
    for _, board in ipairs(self.boards) do
        self:_render(board, self:_fetch(board))
    end
end

return LeaderboardService
