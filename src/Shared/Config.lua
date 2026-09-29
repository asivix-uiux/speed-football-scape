local Config = {}

Config.Name = "Speed Football Scape"
Config.Version = "0.3.0"

Config.DataStoreName = "SpeedFootballScape_v1"
Config.AutoSaveInterval = 60

-- Progression (matched to the reference videos: L26 needs 255 XP, L27 286, L28 320, L29 358, L30 401;
-- max walk speed = 12 + 2 x Level + 20 x Rebirths, e.g. L29 = 70 with no rebirths, L26 = 84 after one rebirth;
-- XP is earned 1:1 with Speed and keeps filling at MAX level)
Config.Player = {
    MaxLevel = 30,
    MaxSpeedBase = 12,
    MaxSpeedPerLevel = 2,
    MaxSpeedPerRebirth = 20,
    MinWalkSpeed = 16,
    GainInterval = 0.5,
    SpeedPerTick = 1,
    StaminaMax = 12,
    StaminaDrain = 3,
    StaminaRegen = 2,
    StaminaRegenDelay = 1,
    SprintMultiplier = 1.35,
}

function Config.XpForLevel(level)
    return math.floor(15 * 1.12 ^ (level - 1))
end

function Config.MaxSpeedForLevel(level, rebirths)
    local speed = Config.Player.MaxSpeedBase + Config.Player.MaxSpeedPerLevel * level + Config.Player.MaxSpeedPerRebirth * (rebirths or 0)
    return math.max(Config.Player.MinWalkSpeed, speed)
end

Config.Lobby = {
    Size = Vector3.new(170, 2, 140),
    SpawnPosition = Vector3.new(0, 3, -14),
}

Config.Course = {
    StartZ = 70,
    Width = 44,
    WallHeight = 46,
    VoidY = -40,
    EndZoneLength = 50,
    PickupRespawn = 10,
    BallLifetime = 16,
    BallKnockback = 70,
    -- Stage types: LavaPath, FallingWalls, Obby, Chase, Platforms (see MapBuilder)
    Stages = {
        {
            Name = "Stage 1", Subtitle = "ESCAPE", SubtitleColor = Color3.fromRGB(40, 200, 255),
            Type = "LavaPath", Length = 420, PathWidth = 20,
            PickupAmount = 5, ReturnWins = 1, RecommendedLevel = 1,
            BallInterval = 4, BallSpeed = 34,
        },
        {
            Name = "Stage 2", Subtitle = "Falling Walls", SubtitleColor = Color3.fromRGB(255, 90, 30),
            Type = "FallingWalls", Length = 420,
            PickupAmount = 5, ReturnWins = 3, RecommendedLevel = 5,
            BallInterval = 5, BallSpeed = 38,
        },
        {
            Name = "Stage 3", Subtitle = "Obby", SubtitleColor = Color3.fromRGB(205, 175, 25),
            Type = "Obby", Length = 440,
            PickupAmount = 9, ReturnWins = 8, RecommendedLevel = 15,
            BallInterval = 6, BallSpeed = 40,
        },
        {
            Name = "Stage 4", Subtitle = "RUN!", SubtitleColor = Color3.fromRGB(40, 230, 40),
            Type = "Chase", Length = 460, ChaseSpeed = 48, ChaseWait = 4,
            PickupAmount = 9, ReturnWins = 20, RecommendedLevel = 35,
            BallInterval = 7, BallSpeed = 40,
        },
        {
            Name = "Stage 5", Subtitle = "Ball", SubtitleColor = Color3.fromRGB(40, 200, 255),
            Type = "LavaPath", Length = 460, PathWidth = 22,
            PickupAmount = 12, ReturnWins = 50, RecommendedLevel = 50,
            BallInterval = 1.8, BallSpeed = 46, BallSizeMin = 10, BallSizeMax = 16,
        },
        {
            Name = "Stage 6", Subtitle = "PLATFORMS", SubtitleColor = Color3.fromRGB(140, 40, 255),
            Type = "Platforms", Length = 480,
            PickupAmount = 15, ReturnWins = 100, RecommendedLevel = 60,
            BallInterval = 4, BallSpeed = 42,
        },
    },
}

Config.FallingWalls = {
    RaisedTime = 2.5,
    WarnTime = 0.8,
    FallTime = 0.25,
    DownTime = 1.5,
    RiseTime = 0.6,
}

-- Treadmills in lobby order (matches the reference: X25, X9, X3, four x1, X3)
Config.Treadmills = {
    { Multiplier = 25, Pass = "RunArea25x", Tag = "*SUPER OP*" },
    { Multiplier = 9, Pass = "RunArea9x" },
    { Multiplier = 3, RequiredWins = 5 },
    { Multiplier = 1 },
    { Multiplier = 1 },
    { Multiplier = 1 },
    { Multiplier = 1 },
    { Multiplier = 3, RequiredWins = 5 },
}

-- Yellow doors in the lobby that skip straight to a later stage
-- Same doors as the reference lobby; stages beyond the built course show "Coming soon!"
Config.StagePortals = {
    { Stage = 3, RequiredWins = 10 },
    { Stage = 6, RequiredWins = 100 },
    { Stage = 9, RequiredWins = 1000 },
    { Stage = 12, RequiredWins = 10000 },
    { Stage = 15, RequiredWins = 200000 },
}

-- Timed boost sold at the SPEED BOOST pad
Config.SpeedBoost = {
    Multiplier = 2,
    Minutes = 15,
}

Config.Revive = {
    Timeout = 10,
    ShieldTime = 3,
}

-- Placeholder IDs: replace 0 with real Developer Product / Game Pass IDs.
-- In Studio, a placeholder (Id = 0) purchase is granted for free so it can be tested.
Config.Products = {
    Speed10K = { Id = 0, Price = 29, Grant = { Speed = 10000 } },
    Speed100K = { Id = 0, Price = 79, Grant = { Speed = 100000 } },
    Speed1M = { Id = 0, Price = 149, Grant = { Speed = 1000000 } },
    StarterPack = { Id = 0, Price = 19, Grant = { Speed = 50000, Wins = 10 } },
    Revive = { Id = 0, Price = 9 },
    SpeedBoost = { Id = 0, Price = 49 },
}

Config.Passes = {
    DoubleSpeed = { Id = 0, Price = 3 },
    DoubleWins = { Id = 0, Price = 139 },
    RunArea9x = { Id = 0, Price = 279 },
    RunArea25x = { Id = 0, Price = 399 },
    PrimeRonaldo = { Id = 0, Price = 299 },
    PrimeMessi = { Id = 0, Price = 200 },
    RainbowAura = { Id = 0, Price = 99 },
}

-- Rotating offer shown at the top of the HUD
Config.Offers = {
    { Title = "Starter Pack", Kind = "Product", Key = "StarterPack" },
    { Title = "1M Speed", Kind = "Product", Key = "Speed1M" },
    { Title = "Prime Ronaldo", Kind = "Pass", Key = "PrimeRonaldo" },
    { Title = "9x Run Area", Kind = "Pass", Key = "RunArea9x" },
}
Config.OfferRotateTime = 45
Config.StarterPackDuration = 15 * 60

Config.MusicSoundId = 0

return Config
