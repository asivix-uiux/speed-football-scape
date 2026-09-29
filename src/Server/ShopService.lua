local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Config = require(SharedFolder:WaitForChild("Config"))
local Remotes = require(SharedFolder:WaitForChild("Remotes"))

local ShopService = {}
ShopService.__index = ShopService

local GREEN = Color3.fromRGB(80, 255, 100)

function ShopService.new(playerService, courseService)
    local self = setmetatable({}, ShopService)

    self.playerService = playerService
    self.courseService = courseService
    self.pending = {}

    self.productKeysById = {}
    for key, product in pairs(Config.Products) do
        if product.Id ~= 0 then
            self.productKeysById[product.Id] = key
        end
    end
    self.passKeysById = {}
    for key, pass in pairs(Config.Passes) do
        if pass.Id ~= 0 then
            self.passKeysById[pass.Id] = key
        end
    end

    local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
    self.purchaseRequest = remotesFolder:WaitForChild(Remotes.EventNames.PurchaseRequest)

    self:_bindPurchases()
    self:_bindOwnership()

    return self
end

function ShopService:_grantProduct(player, key)
    if key == "Revive" then
        self.courseService:revive(player)
        return
    end
    if key == "SpeedBoost" then
        self.playerService:addBoost(player, Config.SpeedBoost.Minutes * 60)
        self.playerService:notify(player, "SPEED BOOST! x" .. Config.SpeedBoost.Multiplier .. " Speed for " .. Config.SpeedBoost.Minutes .. " min", Color3.fromRGB(40, 200, 255))
        return
    end

    local product = Config.Products[key]
    local grant = product and product.Grant
    if not grant then
        return
    end
    if grant.Speed then
        self.playerService:addSpeed(player, grant.Speed, false)
    end
    if grant.Wins then
        self.playerService:addWins(player, grant.Wins, false)
    end
end

function ShopService:_finish(player, purchased)
    local pending = self.pending[player]
    self.pending[player] = nil
    if pending and pending.callback then
        pending.callback(purchased)
    end
end

-- kind: "Product" | "Pass"; callback(purchased) is optional
function ShopService:prompt(player, kind, key, callback)
    local definition = (kind == "Pass") and Config.Passes[key] or Config.Products[key]
    if not definition then
        return
    end

    if kind == "Pass" and self.playerService:hasPass(player, key) then
        self.playerService:notify(player, "Already owned!", Color3.fromRGB(255, 40, 40))
        if callback then
            callback(false)
        end
        return
    end

    -- Placeholder ID: free test grant in Studio, "coming soon" in live servers
    if definition.Id == 0 then
        if RunService:IsStudio() then
            if kind == "Pass" then
                self.playerService:grantPass(player, key, false)
            else
                self:_grantProduct(player, key)
            end
            self.playerService:notify(player, "[Studio] Test purchase: " .. key, GREEN)
            if callback then
                callback(true)
            end
        else
            self.playerService:notify(player, "Coming soon!", Color3.fromRGB(255, 200, 40))
            if callback then
                callback(false)
            end
        end
        return
    end

    -- A newer prompt replaces an unfinished one; let the old caller clean up
    self:_finish(player, false)
    self.pending[player] = { kind = kind, key = key, callback = callback }
    if kind == "Pass" then
        MarketplaceService:PromptGamePassPurchase(player, definition.Id)
    else
        MarketplaceService:PromptProductPurchase(player, definition.Id)
    end
end

function ShopService:_bindPurchases()
    self.purchaseRequest.OnServerEvent:Connect(function(player, kind, key)
        if (kind ~= "Product" and kind ~= "Pass") or type(key) ~= "string" or key == "Revive" then
            return
        end
        self:prompt(player, kind, key)
    end)

    MarketplaceService.ProcessReceipt = function(receipt)
        local player = Players:GetPlayerByUserId(receipt.PlayerId)
        local key = self.productKeysById[receipt.ProductId]
        if not player or not key or not self.playerService:get(player) then
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end

        self:_grantProduct(player, key)
        local pending = self.pending[player]
        if pending and pending.key == key then
            self:_finish(player, true)
        end
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _, isPurchased)
        local player = Players:GetPlayerByUserId(userId)
        if player and not isPurchased then
            self:_finish(player, false)
        end
    end)

    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
        local key = self.passKeysById[passId]
        if purchased and key then
            self.playerService:grantPass(player, key, false)
            self.playerService:notify(player, "Thanks for buying " .. key .. "!", GREEN)
        end
        self:_finish(player, purchased and key ~= nil)
    end)

    Players.PlayerRemoving:Connect(function(player)
        self.pending[player] = nil
    end)
end

function ShopService:_bindOwnership()
    local function check(player)
        -- PlayerService loads data asynchronously; wait for the state to exist
        while player.Parent and not self.playerService:get(player) do
            task.wait(0.5)
        end
        for passId, key in pairs(self.passKeysById) do
            local ok, owns = pcall(function()
                return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
            end)
            if ok and owns then
                self.playerService:grantPass(player, key, false)
            end
        end
    end

    Players.PlayerAdded:Connect(check)
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(check, player)
    end
end

return ShopService
