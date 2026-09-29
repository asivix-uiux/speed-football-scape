local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(SharedFolder:WaitForChild("Catalog"))
local Config = require(SharedFolder:WaitForChild("Config"))
local RigBuilder = require(SharedFolder:WaitForChild("RigBuilder"))

local LobbyBuilder = require(script.Parent:WaitForChild("LobbyBuilder"))

local MapBuilder = {}

local COLORS = {
    courseFloor = Color3.fromRGB(70, 236, 80),
    courseRed = Color3.fromRGB(232, 36, 52),
    courseWall = Color3.fromRGB(84, 72, 112),
    courseWallDark = Color3.fromRGB(60, 52, 84),
    sidewalk = Color3.fromRGB(120, 112, 140),
    ceiling = Color3.fromRGB(48, 42, 66),
    pillar = Color3.fromRGB(255, 132, 24),
    lava = Color3.fromRGB(255, 196, 20),
    spike = Color3.fromRGB(96, 92, 110),
    fallingWall = Color3.fromRGB(150, 138, 168),
    padYellow = Color3.fromRGB(255, 208, 40),
    padPurple = Color3.fromRGB(196, 40, 255),
    white = Color3.fromRGB(255, 255, 255),
    black = Color3.fromRGB(20, 20, 24),
    navy = Color3.fromRGB(35, 30, 95),
    signPink = Color3.fromRGB(246, 216, 236),
    chaseFloor = Color3.fromRGB(110, 100, 140),
    ledge = Color3.fromRGB(118, 110, 138),
    plaque = Color3.fromRGB(125, 105, 175),
    darkWall = Color3.fromRGB(72, 68, 84),
}

-- Helpers ---------------------------------------------------------------

local function block(parent, name, size, cframe, color, material, props)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.CFrame = cframe
    part.Color = color
    part.Material = material or Enum.Material.Plastic
    part.Anchored = true
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    if props then
        for key, value in pairs(props) do
            part[key] = value
        end
    end
    part.Parent = parent
    return part
end

local function floor(parent, name, size, cframe, color)
    return block(parent, name, size, cframe, color, Enum.Material.Plastic, { TopSurface = Enum.SurfaceType.Studs })
end

local function decor(part)
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    return part
end

local function addStroke(label, thickness, color)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = thickness
    stroke.Color = color or COLORS.black
    stroke.Parent = label
    return stroke
end

-- A flat, invisible sign whose Front face (LookVector) points at the viewer
local function textSign(parent, cframe, size, text, color, strokeColor)
    local part = decor(block(parent, "Sign", Vector3.new(size.X, size.Y, 0.2), cframe, COLORS.white, Enum.Material.SmoothPlastic, {
        Transparency = 1,
    }))

    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 20
    gui.LightInfluence = 0
    gui.Parent = part

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.FredokaOne
    label.TextScaled = true
    label.Text = text
    label.TextColor3 = color
    label.Parent = gui
    addStroke(label, math.max(3, size.Y * 20 * 0.07), strokeColor)

    return part, label
end

local function billboard(parent, offset, width, lines)
    local gui = Instance.new("BillboardGui")
    gui.Size = UDim2.new(width, 0, #lines * 1.6, 0)
    gui.StudsOffsetWorldSpace = offset
    gui.LightInfluence = 0
    gui.MaxDistance = 180
    gui.Parent = parent

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Parent = gui

    for index, line in ipairs(lines) do
        local label = Instance.new("TextLabel")
        label.LayoutOrder = index
        label.Size = UDim2.fromScale(1, line.Scale or 1 / #lines)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.FredokaOne
        label.TextScaled = true
        label.Text = line.Text
        label.TextColor3 = line.Color or COLORS.white
        label.Parent = gui
        addStroke(label, 2, line.Stroke)
    end

    return gui
end

-- Stepped cone (no mesh assets needed)
local function spike(parent, position, height, radius)
    local tiers = 5
    local model = Instance.new("Model")
    model.Name = "Spike"
    for tier = 1, tiers do
        local fraction = 1 - (tier - 1) / tiers
        local tierHeight = height / tiers
        local part = block(model, "Tier", Vector3.new(tierHeight, radius * 2 * fraction, radius * 2 * fraction),
            CFrame.new(position + Vector3.new(0, tierHeight * (tier - 0.5), 0)) * CFrame.Angles(0, 0, math.rad(90)),
            COLORS.spike, Enum.Material.Slate, { Shape = Enum.PartType.Cylinder })
        CollectionService:AddTag(part, "KillPart")
    end
    model.Parent = parent
    return model
end

local function goal(parent, cframe)
    local model = Instance.new("Model")
    model.Name = "Goal"
    local width, height, depth = 14, 7, 5
    local function post(size, offset)
        return block(model, "Post", size, cframe * CFrame.new(offset), COLORS.white, Enum.Material.Neon)
    end
    post(Vector3.new(0.6, height, 0.6), Vector3.new(-width / 2, height / 2, 0))
    post(Vector3.new(0.6, height, 0.6), Vector3.new(width / 2, height / 2, 0))
    post(Vector3.new(width + 0.6, 0.6, 0.6), Vector3.new(0, height, 0))
    local net = block(model, "Net", Vector3.new(width, height, 0.2), cframe * CFrame.new(0, height / 2, depth), COLORS.white, Enum.Material.ForceField)
    net.Transparency = 0.5
    decor(net)
    model.Parent = parent
    return model
end

-- Footballs ---------------------------------------------------------------

local PHI = (1 + math.sqrt(5)) / 2
local ICOSAHEDRON = {
    Vector3.new(0, 1, PHI), Vector3.new(0, -1, PHI), Vector3.new(0, 1, -PHI), Vector3.new(0, -1, -PHI),
    Vector3.new(1, PHI, 0), Vector3.new(-1, PHI, 0), Vector3.new(1, -PHI, 0), Vector3.new(-1, -PHI, 0),
    Vector3.new(PHI, 0, 1), Vector3.new(-PHI, 0, 1), Vector3.new(PHI, 0, -1), Vector3.new(-PHI, 0, -1),
}

function MapBuilder.makeFootball(diameter, anchored)
    local ball = Instance.new("Part")
    ball.Name = "Football"
    ball.Shape = Enum.PartType.Ball
    ball.Size = Vector3.new(diameter, diameter, diameter)
    ball.Color = COLORS.white
    ball.Material = Enum.Material.SmoothPlastic
    ball.Anchored = anchored == true
    ball.TopSurface = Enum.SurfaceType.Smooth
    ball.BottomSurface = Enum.SurfaceType.Smooth

    local patchDiameter = diameter * 0.32
    local thickness = diameter * 0.06
    local distance = math.sqrt((diameter / 2) ^ 2 - (patchDiameter / 2) ^ 2) + thickness / 2
    for _, vertex in ipairs(ICOSAHEDRON) do
        local direction = vertex.Unit
        local position = direction * distance
        local patch = Instance.new("Part")
        patch.Name = "Patch"
        patch.Shape = Enum.PartType.Cylinder
        patch.Size = Vector3.new(thickness, patchDiameter, patchDiameter)
        -- Cylinder axis is local X; rotate so X aligns with the outward direction
        patch.CFrame = CFrame.lookAt(position, position + direction) * CFrame.Angles(0, math.rad(90), 0)
        patch.Color = COLORS.black
        patch.Material = Enum.Material.SmoothPlastic
        patch.CanCollide = false
        patch.CanQuery = false
        patch.CanTouch = false
        patch.Massless = true
        patch.Anchored = false
        patch.Parent = ball
    end

    return ball
end

-- Places a football (and its patches) at a CFrame and welds everything together
function MapBuilder.placeFootball(ball, cframe, parent)
    local offsets = {}
    for _, patch in ipairs(ball:GetChildren()) do
        if patch:IsA("BasePart") then
            offsets[patch] = patch.CFrame
        end
    end
    ball.CFrame = cframe
    for patch, offset in pairs(offsets) do
        patch.CFrame = cframe * offset
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = ball
        weld.Part1 = patch
        weld.Parent = patch
    end
    ball.Parent = parent
    return ball
end

-- Shared helpers for LobbyBuilder
MapBuilder.util = {
    block = block,
    floor = floor,
    decor = decor,
    textSign = textSign,
    billboard = billboard,
    goal = goal,
}

-- Pickups -------------------------------------------------------------------

local function shoePickup(parent, map, position, amount)
    map.pickupCount = map.pickupCount + 1
    local id = map.pickupCount

    local model = Instance.new("Model")
    model.Name = "ShoePickup"

    local hitbox = block(model, "Hitbox", Vector3.new(5, 5, 5), CFrame.new(position), COLORS.white, Enum.Material.SmoothPlastic, {
        Transparency = 1,
        CanCollide = false,
        CanQuery = false,
    })
    model.PrimaryPart = hitbox

    local red = Color3.fromRGB(230, 40, 70)
    decor(block(model, "Sole", Vector3.new(1.3, 0.4, 2.6), CFrame.new(position + Vector3.new(0, -0.7, 0)), COLORS.white, Enum.Material.SmoothPlastic))
    decor(block(model, "Upper", Vector3.new(1.2, 1.1, 1.5), CFrame.new(position + Vector3.new(0, 0, 0.5)), red, Enum.Material.SmoothPlastic))
    decor(block(model, "Toe", Vector3.new(1.2, 0.8, 1.2), CFrame.new(position + Vector3.new(0, -0.15, -0.7)), red, Enum.Material.SmoothPlastic, {
        Shape = Enum.PartType.Ball,
    }))
    decor(block(model, "Collar", Vector3.new(1.25, 0.25, 1.2), CFrame.new(position + Vector3.new(0, 0.6, 0.6)), COLORS.white, Enum.Material.SmoothPlastic))

    billboard(hitbox, Vector3.new(0, -2.2, 0), 5, {
        { Text = "+" .. amount .. " Speed", Color = Color3.fromRGB(40, 110, 255), Stroke = COLORS.white },
    })

    model:SetAttribute("PickupId", id)
    model:SetAttribute("Amount", amount)
    CollectionService:AddTag(model, "Pickup")
    model.Parent = parent

    table.insert(map.pickups, { id = id, model = model, hitbox = hitbox, amount = amount })
end

-- Course ------------------------------------------------------------------------

local function addKill(part)
    CollectionService:AddTag(part, "KillPart")
    return part
end

-- White "^" arrows on the floor pointing down the course
local function chevrons(folder, zFrom, count, spacing)
    for index = 0, count - 1 do
        local z = zFrom + index * spacing
        for _, side in ipairs({ -1, 1 }) do
            local arm = decor(block(folder, "Chevron", Vector3.new(0.9, 0.12, 5), CFrame.new(side * 1.6, 0.06, z) * CFrame.Angles(0, -side * math.rad(40), 0),
                COLORS.white, Enum.Material.SmoothPlastic))
            arm.Transparency = 0.15
        end
    end
end

-- Small purple "Recommended : Lvl : N" plaque on the right wall
local function recommendedPlaque(folder, z, level)
    local x = Config.Course.Width / 2 - 0.3
    local plaque = block(folder, "RecommendedPlaque", Vector3.new(9, 3.4, 0.4), CFrame.lookAt(Vector3.new(x, 5, z), Vector3.new(0, 5, z)), COLORS.plaque, Enum.Material.SmoothPlastic)
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 30
    gui.LightInfluence = 0
    gui.Parent = plaque
    local function label(text, y, height, color)
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(0.9, 0, height, 0)
        textLabel.Position = UDim2.new(0.05, 0, y, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Font = Enum.Font.FredokaOne
        textLabel.TextScaled = true
        textLabel.Text = text
        textLabel.TextColor3 = color
        textLabel.Parent = gui
        addStroke(textLabel, 2)
    end
    label("Recommended :", 0.08, 0.36, COLORS.white)
    label("👟 Lvl : " .. level, 0.48, 0.44, Color3.fromRGB(160, 205, 255))
end

-- Goal with a keeper holding a ball over his head, on the side of an end zone
local function keeperGoal(folder, cframe)
    goal(folder, cframe)
    local keeper = RigBuilder.build(Catalog.StageKeeper, false)
    RigBuilder.pose(keeper, cframe * CFrame.new(0, 0, 1.5), 0, true)
    keeper.model.Parent = folder
    MapBuilder.placeFootball(MapBuilder.makeFootball(2, true), cframe * CFrame.new(0, 7, 1.5), folder)
end

-- Green path over lava with side ledges, spikes and lava pillars (Stage 1 ESCAPE, Stage 5 Ball)
local function buildLavaPath(folder, map, stage, zStart, zEnd, contentEnd, stageData, rng)
    local width = Config.Course.Width
    local pathWidth = stage.PathWidth or 20
    local ledgeWidth = 4
    local length = zEnd - zStart

    local lava = addKill(block(folder, "Lava", Vector3.new(width, 2, length), CFrame.new(0, -2.5, (zStart + zEnd) / 2), COLORS.lava, Enum.Material.Neon))
    local lavaLight = Instance.new("SurfaceLight")
    lavaLight.Face = Enum.NormalId.Top
    lavaLight.Color = Color3.fromRGB(255, 150, 40)
    lavaLight.Range = 16
    lavaLight.Brightness = 1.5
    lavaLight.Parent = lava

    floor(folder, "StartFloor", Vector3.new(width, 4, 20), CFrame.new(0, -2, zStart + 10), COLORS.courseFloor)
    floor(folder, "Path", Vector3.new(pathWidth, 4, contentEnd - zStart - 20), CFrame.new(0, -2, (zStart + 20 + contentEnd) / 2), COLORS.courseFloor)
    for _, side in ipairs({ -1, 1 }) do
        floor(folder, "Ledge", Vector3.new(ledgeWidth, 6, length), CFrame.new(side * (width / 2 - ledgeWidth / 2), -1, (zStart + zEnd) / 2), COLORS.ledge)
    end
    chevrons(folder, zStart + 12, 3, 6)

    local channelCenter = (pathWidth / 2 + width / 2 - ledgeWidth) / 2
    local z = zStart + 34
    local index = 0
    while z < contentEnd - 6 do
        index = index + 1
        for _, side in ipairs({ -1, 1 }) do
            spike(folder, Vector3.new(side * channelCenter + rng:NextNumber(-1.5, 1.5), -1.5, z + rng:NextNumber(-4, 4)), 5, 1.8)
        end
        if index % 2 == 0 then
            local side = (index % 4 == 0) and 1 or -1
            local pillar = addKill(block(folder, "LavaPillar", Vector3.new(4, Config.Course.WallHeight + 1.5, 4),
                CFrame.new(side * channelCenter, (Config.Course.WallHeight - 1.5) / 2, z + 8), COLORS.lava, Enum.Material.Neon))
            local light = Instance.new("PointLight")
            light.Color = Color3.fromRGB(255, 170, 40)
            light.Range = 16
            light.Parent = pillar
        end
        if index % 3 == 0 then
            for _, side in ipairs({ -1, 1 }) do
                block(folder, "Pillar", Vector3.new(3, Config.Course.WallHeight, 3), CFrame.new(side * (width / 2 - 1.5), Config.Course.WallHeight / 2, z),
                    COLORS.pillar, Enum.Material.SmoothPlastic)
            end
        end
        if index % 2 == 1 then
            local halfPath = math.floor(pathWidth / 2 - 3)
            shoePickup(folder, map, Vector3.new(rng:NextInteger(-halfPath, halfPath), 3.5, z), stage.PickupAmount)
        end
        z = z + 22
    end

    return contentEnd
end

-- "RUN!": a red wall sweeps down the hall from behind (moved by CourseService)
local function buildChase(folder, map, stage, zStart, zEnd, contentEnd, stageData)
    local width = Config.Course.Width
    floor(folder, "Floor", Vector3.new(width, 2, zEnd - zStart), CFrame.new(0, -1, (zStart + zEnd) / 2), COLORS.chaseFloor)
    floor(folder, "SafeStrip", Vector3.new(width, 0.2, 24), CFrame.new(0, 0.1, contentEnd - 12), COLORS.courseFloor)
    chevrons(folder, zStart + 16, 6, 8)

    local lane = 0
    for z = zStart + 50, contentEnd - 30, 45 do
        lane = lane + 1
        shoePickup(folder, map, Vector3.new(((lane % 3) - 1) * 12, 3.5, z), stage.PickupAmount)
        for _, side in ipairs({ -1, 1 }) do
            block(folder, "Pillar", Vector3.new(3, Config.Course.WallHeight, 3), CFrame.new(side * (width / 2 - 1.5), Config.Course.WallHeight / 2, z),
                COLORS.darkWall, Enum.Material.SmoothPlastic)
        end
    end

    local wall = block(folder, "ChaseWall", Vector3.new(width, Config.Course.WallHeight, 4), CFrame.new(0, -200, zStart), Color3.fromRGB(255, 30, 40), Enum.Material.Neon, {
        CanCollide = false,
        CanQuery = false,
        Transparency = 0.3,
    })
    stageData.chase = {
        part = wall,
        fromZ = zStart + 2,
        toZ = contentEnd,
        speed = stage.ChaseSpeed or 45,
        wait = stage.ChaseWait or 4,
        z = nil,
        timer = 0,
    }

    return zEnd
end

local function buildFallingWalls(folder, map, stage, zStart, zEnd, contentEnd, stageData)
    local width = Config.Course.Width
    floor(folder, "Floor", Vector3.new(width, 2, zEnd - zStart), CFrame.new(0, -1, (zStart + zEnd) / 2), COLORS.courseFloor)

    local wallHeight = 24
    local raiseHeight = 20
    local z = zStart + 45
    local index = 0
    while z < contentEnd - 10 do
        local strip = floor(folder, "WallStrip", Vector3.new(width, 0.3, 8), CFrame.new(0, 0.1, z), COLORS.courseRed)
        local downCFrame = CFrame.new(0, wallHeight / 2, z)
        local upCFrame = downCFrame + Vector3.new(0, raiseHeight, 0)
        local wallPart = block(folder, "FallingWall", Vector3.new(width, wallHeight, 6), upCFrame, COLORS.fallingWall, Enum.Material.Plastic, {
            FrontSurface = Enum.SurfaceType.Studs,
            BackSurface = Enum.SurfaceType.Studs,
        })
        table.insert(stageData.fallingWalls, {
            part = wallPart,
            strip = strip,
            upCFrame = upCFrame,
            downCFrame = downCFrame,
            offset = index * 1.3,
        })

        shoePickup(folder, map, Vector3.new(((index % 3) - 1) * 12, 3.5, z + 26), stage.PickupAmount)
        z = z + 52
        index = index + 1
    end

    return zEnd
end

local function buildObby(folder, map, stage, zStart, zEnd, contentEnd, stageData, rng)
    local width = Config.Course.Width
    local colors = { COLORS.courseFloor, COLORS.courseRed }

    floor(folder, "StartPlatform", Vector3.new(width, 4, 24), CFrame.new(0, -2, zStart + 12), COLORS.courseFloor)

    local z = zStart + 24
    local count = 0
    while true do
        local gap = rng:NextInteger(7, 11)
        local length = rng:NextInteger(14, 22)
        if z + gap + length > contentEnd - 6 then
            break
        end
        count = count + 1
        local zFrom = z + gap
        local center = zFrom + length / 2
        local color = colors[(count % 2) + 1]
        local kind = rng:NextInteger(1, 4)

        if kind == 1 then
            floor(folder, "Platform", Vector3.new(width, 4, length), CFrame.new(0, -2, center), color)
            shoePickup(folder, map, Vector3.new(0, 3.5, center), stage.PickupAmount)
        elseif kind == 2 then
            for _, side in ipairs({ -1, 1 }) do
                floor(folder, "SidePlatform", Vector3.new(14, 4, length), CFrame.new(side * (width / 2 - 7), -2, center), color)
            end
            shoePickup(folder, map, Vector3.new((width / 2 - 7) * (count % 2 == 0 and 1 or -1), 3.5, center), stage.PickupAmount)
        elseif kind == 3 then
            local x = rng:NextInteger(-10, 10)
            floor(folder, "Beam", Vector3.new(8, 4, length), CFrame.new(x, -2, center), color)
        else
            floor(folder, "SweeperPlatform", Vector3.new(width, 4, length), CFrame.new(0, -2, center), color)
            local sweeperLength = width - 6
            block(folder, "SweeperPost", Vector3.new(2, 4, 2), CFrame.new(0, 2, center), COLORS.pillar, Enum.Material.SmoothPlastic)
            local bar = block(folder, "Sweeper", Vector3.new(sweeperLength, 1.5, 1.5), CFrame.new(0, 2.5, center), COLORS.pillar, Enum.Material.Neon, {
                CanCollide = false,
            })
            table.insert(stageData.sweepers, {
                part = bar,
                center = Vector3.new(0, 2.5, center),
                halfLength = sweeperLength / 2,
                angle = rng:NextNumber() * math.pi,
                speed = 1.6 + rng:NextNumber(),
            })
        end

        -- Orange pillars rising from the pit
        if count % 2 == 0 then
            for _, side in ipairs({ -1, 1 }) do
                block(folder, "Pillar", Vector3.new(3, Config.Course.WallHeight + 60, 3), CFrame.new(side * (width / 2 - 1.5), (Config.Course.WallHeight - 60) / 2, zFrom), COLORS.pillar, Enum.Material.SmoothPlastic)
            end
        end

        z = zFrom + length
    end

    return z + 9
end

-- Floating green platforms over lava with spikes and lava pillars (Stage 6 PLATFORMS)
local function buildPlatforms(folder, map, stage, zStart, zEnd, contentEnd, stageData, rng)
    local width = Config.Course.Width
    local lavaTop = -8

    local lava = addKill(block(folder, "Lava", Vector3.new(width, 4, zEnd - zStart), CFrame.new(0, lavaTop - 2, (zStart + zEnd) / 2), COLORS.lava, Enum.Material.Neon))
    local lavaLight = Instance.new("SurfaceLight")
    lavaLight.Face = Enum.NormalId.Top
    lavaLight.Color = Color3.fromRGB(255, 150, 40)
    lavaLight.Range = 20
    lavaLight.Brightness = 2
    lavaLight.Parent = lava

    floor(folder, "StartPlatform", Vector3.new(width, 8, 24), CFrame.new(0, -4, zStart + 12), COLORS.courseFloor)

    local z = zStart + 24
    local count = 0
    while true do
        local gap = rng:NextInteger(6, 9)
        local length = rng:NextInteger(12, 16)
        if z + gap + length > contentEnd - 6 then
            break
        end
        count = count + 1
        local zFrom = z + gap
        local center = zFrom + length / 2
        local islandWidth = rng:NextInteger(12, 18)
        local xRange = math.floor(width / 2 - islandWidth / 2 - 2)
        local x = rng:NextInteger(-xRange, xRange)

        floor(folder, "Island", Vector3.new(islandWidth, 8, length), CFrame.new(x, -4, center), COLORS.courseFloor)

        if count % 3 == 0 then
            -- Spikes on one half of the island, leaving a safe lane
            local side = (count % 2 == 0) and 1 or -1
            spike(folder, Vector3.new(x + side * islandWidth / 4, 0, center), 5, 1.6)
        elseif count % 3 == 1 then
            shoePickup(folder, map, Vector3.new(x, 3.5, center), stage.PickupAmount)
        end

        -- Lava pillars in the gaps
        if count % 2 == 0 then
            local pillarX = (rng:NextInteger(0, 1) == 0 and -1 or 1) * (width / 2 - 4)
            local pillar = addKill(block(folder, "LavaPillar", Vector3.new(4, Config.Course.WallHeight - lavaTop, 4),
                CFrame.new(pillarX, (Config.Course.WallHeight + lavaTop) / 2, z + gap / 2), COLORS.lava, Enum.Material.Neon))
            local light = Instance.new("PointLight")
            light.Color = Color3.fromRGB(255, 170, 40)
            light.Range = 16
            light.Parent = pillar
        end

        z = zFrom + length
    end

    return z + 8
end

local STAGE_BUILDERS = {
    LavaPath = buildLavaPath,
    FallingWalls = buildFallingWalls,
    Obby = buildObby,
    Chase = buildChase,
    Platforms = buildPlatforms,
}

local function buildReturnPad(folder, map, position, wins, isFinish)
    local pad = block(folder, "ReturnPad", Vector3.new(isFinish and 18 or 10, 1, 10), CFrame.new(position), COLORS.padYellow, Enum.Material.Neon, {
        CanCollide = false,
    })
    billboard(pad, Vector3.new(0, 4, 0), 8, {
        { Text = isFinish and "ESCAPED!" or ("+" .. wins .. " Wins"), Color = COLORS.padYellow },
        { Text = isFinish and ("+" .. wins .. " Wins") or "Return", Color = COLORS.white },
    })
    table.insert(map.returnPads, { part = pad, wins = wins })
end

local function buildDoubleWinsPad(folder, map, position)
    local pad = block(folder, "DoubleWinsPad", Vector3.new(10, 1, 10), CFrame.new(position), COLORS.padPurple, Enum.Material.Neon, {
        CanCollide = false,
    })
    billboard(pad, Vector3.new(0, 4.5, 0), 8, {
        { Text = "x2 Wins!", Color = Color3.fromRGB(255, 210, 40), Scale = 0.45 },
        { Text = "⏣" .. Config.Passes.DoubleWins.Price, Color = Color3.fromRGB(80, 235, 60), Scale = 0.3 },
        { Text = "Touch to Claim!", Color = COLORS.white, Scale = 0.25 },
    })
    table.insert(map.doubleWinsPads, pad)
end

local function buildCourse(root, map)
    local course = Config.Course
    local width = course.Width
    local rng = Random.new(20260928)
    local zStart = course.StartZ

    for index, stage in ipairs(course.Stages) do
        local folder = Instance.new("Folder")
        folder.Name = "Stage" .. index
        folder.Parent = root

        local zEnd = zStart + stage.Length
        local contentEnd = zEnd - course.EndZoneLength
        local stageData = {
            index = index,
            config = stage,
            startZ = zStart,
            endZ = zEnd,
            checkpoint = CFrame.lookAt(Vector3.new(0, 4, zStart + 10), Vector3.new(0, 4, zStart + 20)),
            fallingWalls = {},
            sweepers = {},
        }

        -- Hall: walls reach down into the pit, ceiling on top
        local wallTall = course.WallHeight + 60
        for _, side in ipairs({ -1, 1 }) do
            block(folder, "Wall", Vector3.new(4, wallTall, stage.Length), CFrame.new(side * (width / 2 + 2), (course.WallHeight - 60) / 2, (zStart + zEnd) / 2),
                index >= 4 and COLORS.darkWall or (index % 2 == 0 and COLORS.courseWallDark or COLORS.courseWall), Enum.Material.Plastic, {
                    LeftSurface = Enum.SurfaceType.Studs,
                    RightSurface = Enum.SurfaceType.Studs,
                })
            decor(block(folder, "WallGlow", Vector3.new(0.6, 0.6, stage.Length), CFrame.new(side * (width / 2 - 0.3), course.WallHeight - 1, (zStart + zEnd) / 2),
                stage.SubtitleColor, Enum.Material.Neon))
        end
        block(folder, "Ceiling", Vector3.new(width + 8, 4, stage.Length), CFrame.new(0, course.WallHeight + 2, (zStart + zEnd) / 2), COLORS.ceiling)
        for lightZ = zStart + 30, zEnd - 10, 60 do
            local lamp = decor(block(folder, "CeilingLamp", Vector3.new(10, 0.4, 3), CFrame.new(0, course.WallHeight - 0.2, lightZ), COLORS.white, Enum.Material.Neon))
            local light = Instance.new("SurfaceLight")
            light.Face = Enum.NormalId.Bottom
            light.Range = 60
            light.Angle = 120
            light.Brightness = 1.2
            light.Parent = lamp
        end

        local builder = STAGE_BUILDERS[stage.Type]
        local endFloorStart = builder(folder, map, stage, zStart, zEnd, contentEnd, stageData, rng)

        -- End zone: solid floor, goal, wins pads
        local endLength = zEnd - endFloorStart
        if endLength > 0 then
            floor(folder, "EndZone", Vector3.new(width, 8, endLength), CFrame.new(0, -4, endFloorStart + endLength / 2), COLORS.courseFloor)
        end
        local isFinish = index == #course.Stages
        local padZ = zEnd - 22
        if isFinish then
            buildReturnPad(folder, map, Vector3.new(-6, 0.5, padZ), stage.ReturnWins, true)
            buildDoubleWinsPad(folder, map, Vector3.new(14, 0.5, padZ))
            block(folder, "FinishWall", Vector3.new(width + 8, course.WallHeight + 4, 4), CFrame.new(0, course.WallHeight / 2, zEnd + 2), COLORS.courseWallDark)
            goal(folder, CFrame.lookAt(Vector3.new(0, 0, zEnd - 9), Vector3.new(0, 0, 0)))
            textSign(folder, CFrame.new(0, 26, zEnd - 1), Vector3.new(36, 9, 0), "YOU ESCAPED!", COLORS.padYellow)
        else
            buildReturnPad(folder, map, Vector3.new(-(width / 2 - 7), 0.5, padZ), stage.ReturnWins, false)
            buildDoubleWinsPad(folder, map, Vector3.new(width / 2 - 7, 0.5, padZ))
            keeperGoal(folder, CFrame.lookAt(Vector3.new(-(width / 2 - 2), 0, padZ + 16), Vector3.new(0, 0, padZ + 16)))
            for ballIndex = 1, 3 do
                MapBuilder.placeFootball(MapBuilder.makeFootball(2, true), CFrame.new(-(width / 2 - 8), 1, padZ + 6 + ballIndex * 2.5), folder)
            end
        end

        -- Stage entry trigger + big world signs (visible from the previous stage)
        local trigger = block(folder, "StageTrigger", Vector3.new(width, 30, 2), CFrame.new(0, 15, zStart + 4), COLORS.white, Enum.Material.SmoothPlastic, {
            Transparency = 1,
            CanCollide = false,
            CanQuery = false,
        })
        table.insert(map.stageTriggers, { part = trigger, index = index })

        local signFacing = CFrame.new(0, 0, zStart + 14)
        textSign(folder, signFacing * CFrame.new(0, 31, 0), Vector3.new(40, 12, 0), stage.Name, COLORS.signPink, COLORS.navy)
        textSign(folder, signFacing * CFrame.new(0, 21.5, 0), Vector3.new(34, 6.5, 0), stage.Subtitle, stage.SubtitleColor, COLORS.navy)
        recommendedPlaque(folder, zStart + 30, stage.RecommendedLevel)

        table.insert(map.stages, stageData)
        zStart = zEnd
    end
end

-- Lighting --------------------------------------------------------------------

local function setupLighting()
    Lighting.ClockTime = 14
    Lighting.Brightness = 2.2
    Lighting.Ambient = Color3.fromRGB(130, 118, 150)
    Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 170)
    Lighting.EnvironmentDiffuseScale = 0.5
    Lighting.GlobalShadows = true

    local function ensure(className, name)
        local effect = Lighting:FindFirstChild(name)
        if not effect then
            effect = Instance.new(className)
            effect.Name = name
            effect.Parent = Lighting
        end
        return effect
    end

    local bloom = ensure("BloomEffect", "SFS_Bloom")
    bloom.Intensity = 0.6
    bloom.Size = 30
    bloom.Threshold = 1.4

    local color = ensure("ColorCorrectionEffect", "SFS_Color")
    color.Saturation = 0.25
    color.Contrast = 0.05
    color.Brightness = 0.03
end

function MapBuilder.build()
    local existing = Workspace:FindFirstChild("SpeedFootballMap")
    if existing then
        existing:Destroy()
    end

    local root = Instance.new("Folder")
    root.Name = "SpeedFootballMap"

    local map = {
        root = root,
        lobbySpawn = nil,
        stages = {},
        pickups = {},
        pickupCount = 0,
        returnPads = {},
        doubleWinsPads = {},
        stageTriggers = {},
        treadmills = {},
        leaderboards = {},
        pedestals = {},
        stagePortals = {},
        speedBoostPads = {},
    }

    local ballsFolder = Instance.new("Folder")
    ballsFolder.Name = "RollingBalls"
    ballsFolder.Parent = root
    map.ballsFolder = ballsFolder

    LobbyBuilder.build(root, map, MapBuilder)
    buildCourse(root, map)
    setupLighting()

    root.Parent = Workspace
    return map
end

return MapBuilder
