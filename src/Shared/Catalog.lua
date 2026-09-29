-- Soccer players, auras, rebirths and free rewards
local Catalog = {}

-- Bonus = extra Speed per running step. Values from the reference video; Ramos/Palmer requirements are estimates.
-- Row 1 = front row of the shop, Row 2 = raised back row. Special = Robux player shown on its own pedestal.
Catalog.SoccerPlayers = {
    {
        Id = "Yamal", Name = "LAMINE YAMAL", Bonus = 3, RequiredWins = 0, Number = 19, Row = 1,
        Shirt = Color3.fromRGB(215, 25, 35), Shorts = Color3.fromRGB(25, 35, 110), Socks = Color3.fromRGB(25, 35, 110),
        Skin = Color3.fromRGB(200, 140, 95), Hair = Color3.fromRGB(45, 30, 20), NumberColor = Color3.fromRGB(255, 205, 40),
    },
    {
        Id = "Saka", Name = "SAKA", Bonus = 2, RequiredWins = 3, Number = 7, Row = 1,
        Shirt = Color3.fromRGB(242, 242, 242), Shorts = Color3.fromRGB(25, 35, 90), Socks = Color3.fromRGB(242, 242, 242),
        Skin = Color3.fromRGB(95, 60, 40), Hair = Color3.fromRGB(20, 15, 10), NumberColor = Color3.fromRGB(25, 35, 90),
    },
    {
        Id = "Dembele", Name = "DEMBELE", Bonus = 5, RequiredWins = 15, Number = 11, Row = 1,
        Shirt = Color3.fromRGB(35, 70, 200), Shorts = Color3.fromRGB(242, 242, 242), Socks = Color3.fromRGB(215, 30, 45),
        Skin = Color3.fromRGB(90, 55, 35), Hair = Color3.fromRGB(20, 15, 10), NumberColor = Color3.fromRGB(255, 255, 255),
    },
    {
        Id = "Ramos", Name = "RAMOS", Bonus = 25, RequiredWins = 50, Number = 93, Row = 1,
        Shirt = Color3.fromRGB(30, 130, 80), Shorts = Color3.fromRGB(20, 20, 30), Socks = Color3.fromRGB(20, 20, 30),
        Skin = Color3.fromRGB(215, 165, 120), Hair = Color3.fromRGB(35, 25, 20), NumberColor = Color3.fromRGB(255, 255, 255),
    },
    {
        Id = "Palmer", Name = "PALMER", Bonus = 50, RequiredWins = 100, Number = 20, Row = 1,
        Shirt = Color3.fromRGB(242, 242, 242), Shorts = Color3.fromRGB(242, 242, 242), Socks = Color3.fromRGB(215, 30, 45),
        Skin = Color3.fromRGB(235, 190, 150), Hair = Color3.fromRGB(190, 120, 60), NumberColor = Color3.fromRGB(215, 30, 45),
        Stripes = Color3.fromRGB(215, 30, 45),
    },
    {
        Id = "Lewandowski", Name = "LEWANDOWSKI", Bonus = 100, RequiredWins = 1000, Number = 9, Row = 2,
        Shirt = Color3.fromRGB(165, 20, 55), Shorts = Color3.fromRGB(25, 35, 100), Socks = Color3.fromRGB(25, 35, 100),
        Skin = Color3.fromRGB(225, 180, 140), Hair = Color3.fromRGB(40, 30, 25), NumberColor = Color3.fromRGB(255, 205, 40),
        Stripes = Color3.fromRGB(25, 40, 140),
    },
    {
        Id = "Neymar", Name = "NEYMAR JR.", Bonus = 250, RequiredWins = 5000, Number = 10, Row = 2,
        Shirt = Color3.fromRGB(250, 220, 40), Shorts = Color3.fromRGB(30, 70, 200), Socks = Color3.fromRGB(242, 242, 242),
        Skin = Color3.fromRGB(190, 135, 95), Hair = Color3.fromRGB(230, 200, 120), NumberColor = Color3.fromRGB(20, 120, 60),
    },
    {
        Id = "Mbappe", Name = "MBAPPE", Bonus = 500, RequiredWins = 10000, Number = 10, Row = 2,
        Shirt = Color3.fromRGB(245, 245, 245), Shorts = Color3.fromRGB(245, 245, 245), Socks = Color3.fromRGB(245, 245, 245),
        Skin = Color3.fromRGB(110, 70, 45), Hair = Color3.fromRGB(20, 15, 10), NumberColor = Color3.fromRGB(40, 40, 60),
    },
    {
        Id = "Messi", Name = "MESSI", Bonus = 1000, RequiredWins = 20000, Number = 10, Row = 2,
        Shirt = Color3.fromRGB(245, 170, 200), Shorts = Color3.fromRGB(245, 170, 200), Socks = Color3.fromRGB(245, 170, 200),
        Skin = Color3.fromRGB(225, 175, 135), Hair = Color3.fromRGB(70, 45, 25), NumberColor = Color3.fromRGB(20, 20, 30),
    },
    {
        Id = "Ronaldo", Name = "RONALDO", Bonus = 2000, RequiredWins = 50000, Number = 7, Row = 2,
        Shirt = Color3.fromRGB(250, 215, 40), Shorts = Color3.fromRGB(30, 60, 170), Socks = Color3.fromRGB(250, 215, 40),
        Skin = Color3.fromRGB(215, 165, 120), Hair = Color3.fromRGB(25, 20, 15), NumberColor = Color3.fromRGB(30, 60, 170),
    },
    {
        Id = "PrimeMessi", Name = "Prime Messi", Bonus = 10000, Pass = "PrimeMessi", Number = 10, Special = true,
        Tagline = "*X10 VALUE*", AuraColor = Color3.fromRGB(40, 140, 255),
        Shirt = Color3.fromRGB(245, 245, 250), Shorts = Color3.fromRGB(20, 20, 30), Socks = Color3.fromRGB(245, 245, 250),
        Skin = Color3.fromRGB(225, 175, 135), Hair = Color3.fromRGB(70, 45, 25), NumberColor = Color3.fromRGB(20, 20, 30),
        Stripes = Color3.fromRGB(120, 190, 240),
    },
    {
        Id = "PrimeRonaldo", Name = "Prime Ronaldo", Bonus = 25000, Pass = "PrimeRonaldo", Number = 7, Special = true,
        Tagline = "*INSANE VALUE*", AuraColor = Color3.fromRGB(255, 50, 60),
        Shirt = Color3.fromRGB(210, 20, 30), Shorts = Color3.fromRGB(245, 245, 245), Socks = Color3.fromRGB(20, 20, 25),
        Skin = Color3.fromRGB(215, 165, 120), Hair = Color3.fromRGB(25, 20, 15), NumberColor = Color3.fromRGB(255, 255, 255),
    },
}

-- Lobby decoration NPCs
Catalog.Goalkeeper = {
    Name = "KEEPER", Number = 1,
    Shirt = Color3.fromRGB(25, 40, 140), Shorts = Color3.fromRGB(25, 40, 140), Socks = Color3.fromRGB(25, 40, 140),
    Skin = Color3.fromRGB(215, 165, 120), Hair = Color3.fromRGB(60, 40, 25), NumberColor = Color3.fromRGB(255, 205, 40),
    Stripes = Color3.fromRGB(165, 20, 55), Gloves = Color3.fromRGB(245, 245, 245),
}
Catalog.StageKeeper = {
    Name = "KEEPER", Number = 7,
    Shirt = Color3.fromRGB(210, 20, 30), Shorts = Color3.fromRGB(245, 245, 245), Socks = Color3.fromRGB(20, 20, 25),
    Skin = Color3.fromRGB(215, 165, 120), Hair = Color3.fromRGB(35, 25, 20), NumberColor = Color3.fromRGB(255, 255, 255),
    Gloves = Color3.fromRGB(245, 245, 245),
}
Catalog.GoldStatue = {
    Name = "SPEED BOOST", Number = 1, Material = Enum.Material.Foil,
    Shirt = Color3.fromRGB(255, 205, 50), Shorts = Color3.fromRGB(255, 205, 50), Socks = Color3.fromRGB(255, 205, 50),
    Skin = Color3.fromRGB(255, 215, 70), Hair = Color3.fromRGB(255, 195, 40), NumberColor = Color3.fromRGB(255, 255, 255),
    Shoes = Color3.fromRGB(255, 195, 40),
}

-- Multiplier applies to all Speed earned from running and pickups
Catalog.Auras = {
    { Id = "Sparkle", Name = "Sparkle", RequiredWins = 10, Multiplier = 1.1, Color = Color3.fromRGB(255, 255, 255), Effect = "Sparkles" },
    { Id = "BlueFlame", Name = "Blue Flame", RequiredWins = 50, Multiplier = 1.25, Color = Color3.fromRGB(40, 140, 255), Effect = "Fire" },
    { Id = "Inferno", Name = "Inferno", RequiredWins = 250, Multiplier = 1.5, Color = Color3.fromRGB(255, 110, 20), Effect = "Fire" },
    { Id = "Lightning", Name = "Lightning", RequiredWins = 1000, Multiplier = 2, Color = Color3.fromRGB(90, 230, 255), Effect = "Particles" },
    { Id = "Galaxy", Name = "Galaxy", RequiredWins = 5000, Multiplier = 3, Color = Color3.fromRGB(170, 70, 255), Effect = "Particles" },
    { Id = "Rainbow", Name = "Rainbow", Pass = "RainbowAura", Multiplier = 5, Color = Color3.fromRGB(255, 80, 200), Effect = "Rainbow" },
}

Catalog.Rebirth = {
    -- Each rebirth adds +50% to all Speed earned; level resets to 1, Speed and Wins are kept
    MultiplierPerRebirth = 0.5,
}

-- Session playtime rewards (minutes since joining)
Catalog.FreeRewards = {
    { Minutes = 2, Speed = 500 },
    { Minutes = 5, Wins = 2 },
    { Minutes = 10, Speed = 5000 },
    { Minutes = 15, Wins = 5 },
    { Minutes = 25, Speed = 25000 },
    { Minutes = 40, Wins = 15 },
}

local playersById = {}
for index, definition in ipairs(Catalog.SoccerPlayers) do
    definition.Order = index
    playersById[definition.Id] = definition
end

local aurasById = {}
for index, definition in ipairs(Catalog.Auras) do
    definition.Order = index
    aurasById[definition.Id] = definition
end

function Catalog.getPlayer(id)
    return id and playersById[id] or nil
end

function Catalog.getAura(id)
    return id and aurasById[id] or nil
end

function Catalog.rebirthMultiplier(rebirths)
    return 1 + (rebirths or 0) * Catalog.Rebirth.MultiplierPerRebirth
end

return Catalog
