local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(SharedFolder:WaitForChild("Catalog"))
local Config = require(SharedFolder:WaitForChild("Config"))
local Format = require(SharedFolder:WaitForChild("Format"))
local RigBuilder = require(SharedFolder:WaitForChild("RigBuilder"))

-- Builds the lobby to match reference/lobby.mp4:
-- north = Stage 1 gate + leaderboards, east = treadmills, west = soccer player shop,
-- south = stage portal doors + speed boost, spawn pad in the middle.
local LobbyBuilder = {}

local COLORS = {
    floor = Color3.fromRGB(205, 218, 238),
    green = Color3.fromRGB(60, 232, 60),
    platform = Color3.fromRGB(128, 118, 145),
    wallPink = Color3.fromRGB(228, 208, 228),
    pillar = Color3.fromRGB(206, 186, 210),
    frame = Color3.fromRGB(192, 170, 198),
    frameInner = Color3.fromRGB(165, 146, 172),
    brick = Color3.fromRGB(150, 52, 64),
    ceiling = Color3.fromRGB(98, 40, 46),
    vine = Color3.fromRGB(40, 230, 50),
    lavender = Color3.fromRGB(175, 140, 255),
    treadmillSign = Color3.fromRGB(228, 140, 118),
    shopSign = Color3.fromRGB(196, 108, 98),
    signBorder = Color3.fromRGB(120, 55, 45),
    pedestal = Color3.fromRGB(255, 205, 40),
    portal = Color3.fromRGB(255, 220, 40),
    belt = Color3.fromRGB(45, 45, 52),
    white = Color3.fromRGB(255, 255, 255),
    black = Color3.fromRGB(20, 20, 24),
}

local TREADMILL_STYLES = {
    [1] = { accent = Color3.fromRGB(165, 165, 175), material = Enum.Material.Metal },
    [3] = { accent = Color3.fromRGB(255, 150, 30), material = Enum.Material.Neon, label = Color3.fromRGB(255, 190, 40) },
    [9] = { accent = Color3.fromRGB(60, 200, 255), material = Enum.Material.Neon, label = Color3.fromRGB(60, 200, 255) },
    [25] = { accent = Color3.fromRGB(150, 90, 255), material = Enum.Material.Neon, label = Color3.fromRGB(35, 35, 40), stroke = COLORS.white },
}

local HALF_X, HALF_Z = 85, 70
local LOWER_HEIGHT, WALL_HEIGHT = 30, 46

local U -- MapBuilder.util, set in build()

local function studs(part)
    part.TopSurface = Enum.SurfaceType.Studs
    part.FrontSurface = Enum.SurfaceType.Studs
    part.BackSurface = Enum.SurfaceType.Studs
    part.LeftSurface = Enum.SurfaceType.Studs
    part.RightSurface = Enum.SurfaceType.Studs
    return part
end

local function facingCenter(position)
    local flat = Vector3.new(-position.X, 0, -position.Z)
    return flat.Magnitude > 0 and flat.Unit or Vector3.new(0, 0, 1)
end

-- A sign board on a wall: coloured board, darker border and outlined text. cframe faces the viewer.
local function signBoard(parent, cframe, size, text, boardColor, textColor, strokeColor)
    U.block(parent, "SignBorder", Vector3.new(size.X + 2, size.Y + 2, 0.4), cframe * CFrame.new(0, 0, 0.5), COLORS.signBorder, Enum.Material.SmoothPlastic)
    U.block(parent, "SignBoard", Vector3.new(size.X, size.Y, 0.4), cframe * CFrame.new(0, 0, 0.1), boardColor, Enum.Material.SmoothPlastic)
    U.textSign(parent, cframe * CFrame.new(0, 0, -0.2), Vector3.new(size.X - 2, size.Y - 1.5, 0), text, textColor, strokeColor)
end

-- Structure --------------------------------------------------------------------------------

local function buildShell(folder)
    local courseHalf = Config.Course.Width / 2

    local mainFloor = U.floor(folder, "LobbyFloor", Vector3.new(HALF_X * 2, 2, HALF_Z * 2), CFrame.new(0, -1, 0), COLORS.floor)
    mainFloor.Material = Enum.Material.Plastic

    -- Lime green zones: path to the gate, in front of the shop, in front of the treadmills
    U.floor(folder, "GreenGatePath", Vector3.new(Config.Course.Width, 0.2, 38), CFrame.new(0, 0.1, HALF_Z - 19), COLORS.green)
    U.floor(folder, "GreenShop", Vector3.new(28, 0.2, 76), CFrame.new(-44, 0.1, 0), COLORS.green)
    U.floor(folder, "GreenTreadmills", Vector3.new(28, 0.2, 96), CFrame.new(48, 0.1, 0), COLORS.green)

    -- Walls: pink lower band, dark red brick upper band. The south (portal) wall is brick all the way down.
    local function wall(name, size, position, lowerColor)
        local lowerSize = Vector3.new(size.X, LOWER_HEIGHT, size.Z)
        studs(U.block(folder, name, lowerSize, CFrame.new(position.X, LOWER_HEIGHT / 2, position.Z), lowerColor or COLORS.wallPink))
        local upperHeight = WALL_HEIGHT - LOWER_HEIGHT
        studs(U.block(folder, name .. "Upper", Vector3.new(size.X + 0.6, upperHeight, size.Z + 0.6),
            CFrame.new(position.X, LOWER_HEIGHT + upperHeight / 2, position.Z), COLORS.brick))
    end
    local segment = HALF_X - courseHalf
    wall("NorthWallLeft", Vector3.new(segment, 0, 2), Vector3.new(-(courseHalf + segment / 2), 0, HALF_Z + 1))
    wall("NorthWallRight", Vector3.new(segment, 0, 2), Vector3.new(courseHalf + segment / 2, 0, HALF_Z + 1))
    wall("SouthWall", Vector3.new(HALF_X * 2 + 4, 0, 2), Vector3.new(0, 0, -HALF_Z - 1), COLORS.brick)
    wall("WestWall", Vector3.new(2, 0, HALF_Z * 2), Vector3.new(-HALF_X - 1, 0, 0))
    wall("EastWall", Vector3.new(2, 0, HALF_Z * 2), Vector3.new(HALF_X + 1, 0, 0))

    -- Pillars and recessed door frames on the pink walls
    local function wallDecor(position, inward, alongAxis)
        U.block(folder, "Pillar", alongAxis == "X" and Vector3.new(4, LOWER_HEIGHT, 2.4) or Vector3.new(2.4, LOWER_HEIGHT, 4),
            CFrame.new(position + inward * 1.2 + Vector3.new(0, LOWER_HEIGHT / 2, 0)), COLORS.pillar)
    end
    local function doorFrame(position, inward)
        local cframe = CFrame.lookAt(position + inward * 0.2 + Vector3.new(0, 10, 0), position + inward * 5 + Vector3.new(0, 10, 0))
        U.block(folder, "DoorFrame", Vector3.new(11, 20, 0.4), cframe, COLORS.frame)
        U.block(folder, "DoorInner", Vector3.new(8, 17.5, 0.5), cframe * CFrame.new(0, -1.25, -0.1), COLORS.frameInner)
    end
    for x = -72, 72, 24 do
        if math.abs(x) > courseHalf + 4 then
            wallDecor(Vector3.new(x, 0, HALF_Z), Vector3.new(0, 0, -1), "X")
            if math.abs(x + 12) > courseHalf + 6 and x + 12 < HALF_X - 6 then
                doorFrame(Vector3.new(x + 12, 0, HALF_Z), Vector3.new(0, 0, -1))
            end
        end
    end
    for z = -60, 60, 20 do
        wallDecor(Vector3.new(-HALF_X, 0, z), Vector3.new(1, 0, 0), "Z")
        wallDecor(Vector3.new(HALF_X, 0, z), Vector3.new(-1, 0, 0), "Z")
        if z < 60 then
            doorFrame(Vector3.new(-HALF_X, 0, z + 10), Vector3.new(1, 0, 0))
        end
    end

    -- Dark maroon ceiling with glowing light panels
    U.block(folder, "Ceiling", Vector3.new(HALF_X * 2 + 6, 4, HALF_Z * 2 + 6), CFrame.new(0, WALL_HEIGHT + 2, 0), COLORS.ceiling)
    for _, x in ipairs({ -50, 0, 50 }) do
        for _, z in ipairs({ -40, 0, 40 }) do
            local panel = U.decor(U.block(folder, "CeilingLight", Vector3.new(9, 0.4, 9), CFrame.new(x, WALL_HEIGHT - 0.2, z), COLORS.white, Enum.Material.Neon))
            local light = Instance.new("SurfaceLight")
            light.Face = Enum.NormalId.Bottom
            light.Range = 45
            light.Angle = 150
            light.Brightness = 0.8
            light.Parent = panel
        end
    end

    -- Hanging green voxel vines along the top of the walls
    local rng = Random.new(7)
    local function vine(position)
        local y = WALL_HEIGHT
        for index = 1, rng:NextInteger(3, 5) do
            local height = rng:NextInteger(3, 5)
            y = y - height
            local offset = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
            U.decor(studs(U.block(folder, "Vine", Vector3.new(2.5, height, 2.5), CFrame.new(position + offset + Vector3.new(0, y + height / 2, 0)), COLORS.vine)))
            if index == 1 then
                U.decor(studs(U.block(folder, "VineTop", Vector3.new(5, 2, 5), CFrame.new(position + Vector3.new(0, WALL_HEIGHT - 1, 0)), COLORS.vine)))
            end
        end
    end
    for x = -70, 70, 28 do
        vine(Vector3.new(x, 0, HALF_Z - 3))
        vine(Vector3.new(x + 10, 0, -HALF_Z + 3))
    end
    for z = -56, 56, 28 do
        vine(Vector3.new(-HALF_X + 3, 0, z))
        vine(Vector3.new(HALF_X - 3, 0, z + 10))
    end

    -- Stage 1 gate: stepped voxel arch with vines hanging over the entrance
    local archColor = Color3.fromRGB(150, 135, 168)
    local gateZ = HALF_Z + 1
    for _, side in ipairs({ -1, 1 }) do
        studs(U.block(folder, "GateColumn", Vector3.new(6, WALL_HEIGHT, 7), CFrame.new(side * (courseHalf + 3), WALL_HEIGHT / 2, gateZ), archColor))
        studs(U.block(folder, "GateStep", Vector3.new(6, 5, 7), CFrame.new(side * (courseHalf - 3), 33.5, gateZ), archColor))
        studs(U.block(folder, "GateStep", Vector3.new(5, 4, 7), CFrame.new(side * (courseHalf - 8.5), 35, gateZ), archColor))
    end
    studs(U.block(folder, "GateLintel", Vector3.new(Config.Course.Width + 12, WALL_HEIGHT - 37, 7), CFrame.new(0, (WALL_HEIGHT + 37) / 2, gateZ), archColor))
    for _, x in ipairs({ -14, -4, 8, 16 }) do
        vine(Vector3.new(x, 0, HALF_Z - 3.5))
    end
end

local function stadiumLight(folder, position, height)
    U.decor(U.block(folder, "LightPole", Vector3.new(0.8, height, 0.8), CFrame.new(position + Vector3.new(0, height / 2, 0)), Color3.fromRGB(90, 90, 100), Enum.Material.Metal))
    local head = U.decor(U.block(folder, "LightHead", Vector3.new(6, 4, 1), CFrame.lookAt(position + Vector3.new(0, height + 2, 0), Vector3.new(0, height, 0)), Color3.fromRGB(70, 70, 80), Enum.Material.Metal))
    local bulbs = U.decor(U.block(folder, "LightBulbs", Vector3.new(5.4, 3.4, 0.2), head.CFrame * CFrame.new(0, 0, -0.55), Color3.fromRGB(255, 240, 190), Enum.Material.Neon))
    local light = Instance.new("SpotLight")
    light.Face = Enum.NormalId.Front
    light.Range = 50
    light.Angle = 70
    light.Brightness = 1.5
    light.Parent = bulbs
end

-- Goal with a goalkeeper (arms up) and a few balls, opening facing `facing`
local function goalWithKeeper(folder, MapBuilder, position, facing)
    local cframe = CFrame.lookAt(position, position + facing)
    U.goal(folder, cframe)

    local keeper = RigBuilder.build(Catalog.Goalkeeper, false)
    RigBuilder.pose(keeper, cframe * CFrame.new(0, 0, 1.5), 0, true)
    keeper.model.Parent = folder
    -- Ball held over the head
    MapBuilder.placeFootball(MapBuilder.makeFootball(2, true), cframe * CFrame.new(0, 7, 1.5), folder)

    for index = 1, 3 do
        local ballPosition = (cframe * CFrame.new(-5 + index * 3, 1, -4 - index % 2 * 2)).Position
        MapBuilder.placeFootball(MapBuilder.makeFootball(2, true), CFrame.new(ballPosition), folder)
    end
end

-- Leaderboards: voxel frame on two legs with a tilted "Most ..." header and a floating title
local function voxelLeaderboard(folder, position, title, subtitle, color, titleStroke)
    local cframe = CFrame.lookAt(position, position + facingCenter(position))
    local function piece(name, size, offset)
        return studs(U.block(folder, name, size, cframe * CFrame.new(offset), color))
    end
    piece("BoardLeg", Vector3.new(2.5, 22, 2.5), Vector3.new(-10, 11, 0))
    piece("BoardLeg", Vector3.new(2.5, 22, 2.5), Vector3.new(10, 11, 0))
    piece("BoardBase", Vector3.new(22.5, 2, 2.5), Vector3.new(0, 4.5, 0))
    piece("BoardHeaderBack", Vector3.new(24, 6, 1.6), Vector3.new(0, 22, 0.4))

    local header = U.block(folder, "BoardHeader", Vector3.new(21, 4.2, 0.4), cframe * CFrame.new(0, 22, -0.5), Color3.fromRGB(245, 245, 250), Enum.Material.SmoothPlastic)
    local headerGui = Instance.new("SurfaceGui")
    headerGui.Face = Enum.NormalId.Front
    headerGui.LightInfluence = 0
    headerGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    headerGui.PixelsPerStud = 25
    headerGui.Parent = header
    local headerLabel = Instance.new("TextLabel")
    headerLabel.Size = UDim2.fromScale(1, 1)
    headerLabel.BackgroundTransparency = 1
    headerLabel.Font = Enum.Font.FredokaOne
    headerLabel.TextScaled = true
    headerLabel.Text = subtitle
    headerLabel.TextColor3 = Color3.fromRGB(60, 60, 80)
    headerLabel.Parent = headerGui

    U.textSign(folder, cframe * CFrame.new(0, 27.5, 0), Vector3.new(18, 4, 0), title, color, titleStroke)

    local board = U.block(folder, "Leaderboard_" .. title, Vector3.new(17.5, 14, 0.5), cframe * CFrame.new(0, 12.5, 0), Color3.fromRGB(245, 245, 250), Enum.Material.SmoothPlastic)
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.LightInfluence = 0
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 25
    gui.Parent = board

    local list = Instance.new("Frame")
    list.Name = "List"
    list.Size = UDim2.fromScale(0.94, 0.94)
    list.Position = UDim2.fromScale(0.03, 0.03)
    list.BackgroundTransparency = 1
    list.Parent = gui
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0.01, 0)
    layout.Parent = list

    return list
end

-- Soccer player pedestals ----------------------------------------------------------------------

local function buildPedestal(folder, map, definition, position, facing)
    local special = definition.Special == true
    local pedestal = U.block(folder, "PlayerPedestal_" .. definition.Id, Vector3.new(7, 1, 8), CFrame.new(position + Vector3.new(0, 0.6, 0)),
        special and definition.AuraColor or COLORS.pedestal, special and Enum.Material.Neon or Enum.Material.Plastic)
    studs(pedestal)
    U.block(folder, "PedestalRim", Vector3.new(7.8, 0.5, 8.8), CFrame.new(position + Vector3.new(0, 0.25, 0)), Color3.fromRGB(235, 140, 30), Enum.Material.SmoothPlastic)

    local feet = position + Vector3.new(0, 1.1, 0)
    local rig = RigBuilder.build(definition, false)
    RigBuilder.pose(rig, CFrame.lookAt(feet, feet + facing), 0)
    rig.model.Parent = folder

    local lines
    if special then
        local pass = Config.Passes[definition.Pass]
        lines = {
            { Text = definition.Tagline, Color = Color3.fromRGB(80, 255, 120), Scale = 0.28 },
            { Text = definition.Name, Color = definition.AuraColor, Stroke = COLORS.white, Scale = 0.4 },
            { Text = "⏣" .. (pass and pass.Price or 0), Color = Color3.fromRGB(80, 235, 60), Scale = 0.32 },
        }
        local fire = Instance.new("Fire")
        fire.Color = definition.AuraColor
        fire.SecondaryColor = COLORS.white
        fire.Size = 8
        fire.Heat = 10
        fire.Parent = rig.parts.Torso
        local glow = U.decor(U.block(folder, "AuraRing", Vector3.new(0.3, 10, 10), CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
            definition.AuraColor, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, Transparency = 0.3 }))
        local light = Instance.new("PointLight")
        light.Color = definition.AuraColor
        light.Range = 16
        light.Brightness = 2
        light.Parent = glow
    else
        lines = {
            { Text = "+" .. Format.abbreviate(definition.Bonus) .. " Speed", Color = COLORS.white, Scale = 0.42 },
            { Text = Format.abbreviate(definition.RequiredWins) .. " Wins Required", Color = Color3.fromRGB(40, 110, 255), Stroke = COLORS.white, Scale = 0.33 },
            { Text = definition.Name, Color = COLORS.white, Scale = 0.25 },
        }
    end
    U.billboard(pedestal, Vector3.new(0, 8.5, 0), 9, lines)

    table.insert(map.pedestals, { part = pedestal, definition = definition })
end

local function buildShop(folder, map)
    -- Two stepped grey tiers: front row (cheap players) and a raised back row
    U.floor(folder, "ShopTierBack", Vector3.new(14, 5, 72), CFrame.new(-HALF_X + 7, 2.5, 0), COLORS.platform)
    U.floor(folder, "ShopTierFront", Vector3.new(12, 1.5, 72), CFrame.new(-HALF_X + 20, 0.75, 0), COLORS.platform)

    local rows = { {}, {} }
    for _, definition in ipairs(Catalog.SoccerPlayers) do
        if definition.Row then
            table.insert(rows[definition.Row], definition)
        end
    end
    local rowX = { -HALF_X + 20, -HALF_X + 7 }
    local rowY = { 1.5, 5 }
    for rowIndex, row in ipairs(rows) do
        for index, definition in ipairs(row) do
            local z = -24 + (index - 1) * 12
            buildPedestal(folder, map, definition, Vector3.new(rowX[rowIndex], rowY[rowIndex], z), Vector3.new(1, 0, 0))
        end
    end

    signBoard(folder, CFrame.lookAt(Vector3.new(-HALF_X + 0.4, 37, 0), Vector3.new(0, 37, 0)), Vector3.new(46, 11), "BUY SOCCER\nPLAYERS",
        COLORS.shopSign, Color3.fromRGB(215, 205, 255), Color3.fromRGB(70, 45, 140))
end

-- Treadmills -----------------------------------------------------------------------------------

local function buildTreadmill(folder, map, definition, center)
    local style = TREADMILL_STYLES[definition.Multiplier] or TREADMILL_STYLES[1]
    local length, width = 14, 6

    -- Players run toward +X (the wall); the belt pushes them back toward -X
    local belt = U.block(folder, "TreadmillBelt", Vector3.new(length, 0.6, width), CFrame.new(center + Vector3.new(0, 0.3, 0)), COLORS.belt, Enum.Material.DiamondPlate)
    belt.AssemblyLinearVelocity = Vector3.new(-12, 0, 0)
    belt:SetAttribute("SpeedMultiplier", definition.Multiplier)
    belt:SetAttribute("RequiredWins", definition.RequiredWins or 0)
    if definition.Pass then
        belt:SetAttribute("RequiredPass", definition.Pass)
    end

    for _, side in ipairs({ -1, 1 }) do
        U.block(folder, "TreadmillSide", Vector3.new(length, 0.9, 0.6), CFrame.new(center + Vector3.new(0, 0.45, side * (width / 2 + 0.3))), style.accent, style.material)
        U.block(folder, "TreadmillUpright", Vector3.new(0.6, 5, 0.6), CFrame.new(center + Vector3.new(length / 2 - 0.5, 2.5, side * (width / 2))), Color3.fromRGB(70, 70, 80), Enum.Material.Metal)
    end
    U.block(folder, "TreadmillHandle", Vector3.new(0.6, 0.6, width + 0.6), CFrame.new(center + Vector3.new(length / 2 - 0.5, 4.2, 0)), Color3.fromRGB(70, 70, 80), Enum.Material.Metal)
    local display = U.block(folder, "TreadmillDisplay", Vector3.new(1, 2.4, width - 0.4), CFrame.new(center + Vector3.new(length / 2, 5.8, 0)), Color3.fromRGB(35, 35, 42), Enum.Material.SmoothPlastic)
    U.textSign(folder, CFrame.lookAt(display.Position + Vector3.new(-0.6, 0, 0), display.Position + Vector3.new(-5, 0, 0)), Vector3.new(width - 1.2, 1.2, 0),
        "x" .. definition.Multiplier .. " Speed", style.label or COLORS.white)

    if definition.Multiplier > 1 then
        local light = Instance.new("PointLight")
        light.Color = style.accent
        light.Range = 14
        light.Brightness = 2
        light.Parent = belt

        local emitter = Instance.new("ParticleEmitter")
        emitter.Color = ColorSequence.new(style.accent)
        emitter.LightEmission = 1
        emitter.Rate = definition.Multiplier >= 9 and 30 or 12
        emitter.Lifetime = NumberRange.new(0.4, 0.8)
        emitter.Speed = NumberRange.new(4, 9)
        emitter.SpreadAngle = Vector2.new(40, 40)
        emitter.EmissionDirection = Enum.NormalId.Top
        emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
        emitter.Parent = display

        local lines = {}
        if definition.Tag then
            table.insert(lines, { Text = definition.Tag, Color = Color3.fromRGB(255, 50, 50), Scale = 0.3 })
        end
        table.insert(lines, {
            Text = "X" .. definition.Multiplier .. " Speed",
            Color = style.label,
            Stroke = style.stroke,
            Scale = definition.Tag and 0.7 or 1,
        })
        U.billboard(belt, Vector3.new(0, 10, 0), 10, lines)
    end

    table.insert(map.treadmills, belt)
end

local function buildTreadmills(folder, map)
    local platformTop = 1.2
    U.floor(folder, "TreadmillPlatform", Vector3.new(22, platformTop, 96), CFrame.new(HALF_X - 11, platformTop / 2, 0), COLORS.platform)
    U.decor(U.block(folder, "TreadmillGlow", Vector3.new(3, 0.3, 96), CFrame.new(HALF_X - 23.5, 0.15, 0), COLORS.lavender, Enum.Material.Neon))

    for index, definition in ipairs(Config.Treadmills) do
        local z = -38.5 + (index - 1) * 11
        buildTreadmill(folder, map, definition, Vector3.new(HALF_X - 12, platformTop, z))
    end

    signBoard(folder, CFrame.lookAt(Vector3.new(HALF_X - 0.4, 37, 0), Vector3.new(0, 37, 0)), Vector3.new(44, 10), "TREADMILLS",
        COLORS.treadmillSign, Color3.fromRGB(100, 110, 235), COLORS.white)
    local front = CFrame.lookAt(Vector3.new(HALF_X - 4, 0, 0), Vector3.new(0, 0, 0))
    U.textSign(folder, front * CFrame.new(0, 29.5, 0), Vector3.new(26, 3.6, 0), "TREADMILLS", COLORS.white)
    U.textSign(folder, front * CFrame.new(0, 26.8, 0), Vector3.new(32, 1.8, 0), "Automatically increases your speed!", Color3.fromRGB(255, 210, 40))
end

-- Stage portals + speed boost (south wall) -----------------------------------------------------

local function buildPortals(folder, map)
    local ledgeTop = 1.5
    U.floor(folder, "PortalLedge", Vector3.new(100, ledgeTop, 12), CFrame.new(0, ledgeTop / 2, -HALF_Z + 6), COLORS.platform)

    for index, portal in ipairs(Config.StagePortals) do
        local x = (index - (#Config.StagePortals + 1) / 2) * 18
        local wallZ = -HALF_Z + 0.6
        U.decor(U.block(folder, "PortalDoor", Vector3.new(10, 13, 1), CFrame.new(x, ledgeTop + 6.5, wallZ), COLORS.portal, Enum.Material.Neon))
        local arch = U.decor(U.block(folder, "PortalArch", Vector3.new(1, 10, 10), CFrame.new(x, ledgeTop + 13, wallZ) * CFrame.Angles(0, math.rad(90), 0),
            COLORS.portal, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder }))
        local light = Instance.new("PointLight")
        light.Color = COLORS.portal
        light.Range = 18
        light.Brightness = 2
        light.Parent = arch

        local hitbox = U.block(folder, "PortalHitbox", Vector3.new(10, 16, 4), CFrame.new(x, ledgeTop + 8, wallZ + 2.5), COLORS.white, Enum.Material.SmoothPlastic, {
            Transparency = 1,
            CanCollide = false,
            CanQuery = false,
        })
        U.billboard(hitbox, Vector3.new(0, 12, 0), 9, {
            { Text = "Stage " .. portal.Stage, Color = COLORS.portal, Scale = 0.6 },
            { Text = Format.abbreviate(portal.RequiredWins) .. " Wins Required", Color = COLORS.portal, Scale = 0.4 },
        })
        table.insert(map.stagePortals, { part = hitbox, stage = portal.Stage, requiredWins = portal.RequiredWins })
    end
end

local function buildSpeedBoost(folder, map)
    local position = Vector3.new(22, 0, -HALF_Z + 20)
    U.decor(U.block(folder, "SpeedBoostPad", Vector3.new(0.4, 12, 12), CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
        COLORS.portal, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder }))

    local statue = RigBuilder.build(Catalog.GoldStatue, true)
    RigBuilder.pose(statue, CFrame.lookAt(position + Vector3.new(0, 0.4, 0), position + Vector3.new(0, 0.4, 0) + facingCenter(position)), 0)
    statue.model.Parent = folder

    local hitbox = U.block(folder, "SpeedBoostHitbox", Vector3.new(12, 7, 12), CFrame.new(position + Vector3.new(0, 3.5, 0)), COLORS.white, Enum.Material.SmoothPlastic, {
        Transparency = 1,
        CanCollide = false,
        CanQuery = false,
    })
    local light = Instance.new("PointLight")
    light.Color = COLORS.portal
    light.Range = 18
    light.Parent = hitbox
    U.billboard(hitbox, Vector3.new(0, 9, 0), 16, {
        { Text = "SPEED BOOST", Color = Color3.fromRGB(40, 200, 255), Stroke = Color3.fromRGB(10, 40, 120), Scale = 0.6 },
        { Text = "Buy speed Boost!", Color = Color3.fromRGB(255, 80, 40), Scale = 0.4 },
    })
    table.insert(map.speedBoostPads, hitbox)
end

-- Spawn pad: white square with a black star crack -----------------------------------------------

local function buildSpawn(folder, map)
    local position = Config.Lobby.SpawnPosition
    local base = Vector3.new(position.X, 0, position.Z)
    U.block(folder, "SpawnPad", Vector3.new(14, 0.3, 14), CFrame.new(base + Vector3.new(0, 0.15, 0)), Color3.fromRGB(246, 246, 250), Enum.Material.SmoothPlastic)
    for index = 0, 7 do
        local angle = index * math.pi / 4
        local long = index % 2 == 0
        local length = long and 6.5 or 4
        U.decor(U.block(folder, "SpawnStar", Vector3.new(long and 0.7 or 0.5, 0.06, length),
            CFrame.new(base + Vector3.new(0, 0.32, 0)) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -length / 2), COLORS.black, Enum.Material.SmoothPlastic))
    end
    U.decor(U.block(folder, "SpawnRing", Vector3.new(0.06, 4, 4), CFrame.new(base + Vector3.new(0, 0.33, 0)) * CFrame.Angles(0, 0, math.rad(90)),
        COLORS.black, Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder }))
    U.decor(U.block(folder, "SpawnRingInner", Vector3.new(0.07, 3, 3), CFrame.new(base + Vector3.new(0, 0.33, 0)) * CFrame.Angles(0, 0, math.rad(90)),
        Color3.fromRGB(246, 246, 250), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder }))

    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "LobbySpawn"
    spawn.Size = Vector3.new(12, 1, 12)
    spawn.CFrame = CFrame.lookAt(base + Vector3.new(0, 0.5, 0), base + Vector3.new(0, 0.5, 10))
    spawn.Anchored = true
    spawn.Neutral = true
    spawn.Duration = 0
    spawn.Transparency = 1
    spawn.CanCollide = false
    spawn.Parent = folder
    map.lobbySpawn = CFrame.lookAt(position, position + Vector3.new(0, 0, 10))
end

function LobbyBuilder.build(root, map, MapBuilder)
    U = MapBuilder.util

    local folder = Instance.new("Folder")
    folder.Name = "Lobby"
    folder.Parent = root

    buildShell(folder)
    buildSpawn(folder, map)
    buildShop(folder, map)
    buildTreadmills(folder, map)
    buildPortals(folder, map)
    buildSpeedBoost(folder, map)

    -- Robux players on their own glowing pedestals
    for _, definition in ipairs(Catalog.SoccerPlayers) do
        if definition.Id == "PrimeMessi" then
            local position = Vector3.new(-14, 0, -HALF_Z + 22)
            buildPedestal(folder, map, definition, position, facingCenter(position))
        elseif definition.Id == "PrimeRonaldo" then
            local position = Vector3.new(44, 0, -34)
            buildPedestal(folder, map, definition, position, facingCenter(position))
        end
    end

    -- Leaderboards either side of the Stage 1 gate
    map.leaderboards.Speed = voxelLeaderboard(folder, Vector3.new(-36, 0, HALF_Z - 18), "Top Speed", "Most Speed", Color3.fromRGB(40, 110, 230), COLORS.white)
    map.leaderboards.Wins = voxelLeaderboard(folder, Vector3.new(36, 0, HALF_Z - 18), "Top Wins", "Most Wins", Color3.fromRGB(255, 140, 30), Color3.fromRGB(110, 50, 0))

    -- Goals with keepers and stadium lights in the west corners
    goalWithKeeper(folder, MapBuilder, Vector3.new(-62, 0, HALF_Z - 8), Vector3.new(0.6, 0, -1).Unit)
    goalWithKeeper(folder, MapBuilder, Vector3.new(-62, 0, -HALF_Z + 9), Vector3.new(0.6, 0, 1).Unit)
    stadiumLight(folder, Vector3.new(-48, 0, HALF_Z - 4), 24)
    stadiumLight(folder, Vector3.new(-48, 0, -HALF_Z + 5), 24)
    stadiumLight(folder, Vector3.new(26, 0, HALF_Z - 4), 24)
end

return LobbyBuilder
