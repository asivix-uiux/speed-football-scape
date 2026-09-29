-- Blocky R6-style footballer built from parts (no assets), used for shop pedestals, lobby NPCs and followers
local RigBuilder = {}

local DEFAULT_SHOES = Color3.fromRGB(25, 25, 30)

-- name, size, joint offset from the root (feet) CFrame, part offset from the joint, color key, swing group
local PIECES = {
    { "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), Vector3.new(), "Shirt" },
    { "Head", Vector3.new(2, 1, 1), Vector3.new(0, 4.5, 0), Vector3.new(), "Skin" },
    { "Hair", Vector3.new(2.1, 0.45, 1.1), Vector3.new(0, 5.05, 0.05), Vector3.new(), "Hair" },
    { "LeftSleeve", Vector3.new(1, 0.9, 1), Vector3.new(-1.5, 4, 0), Vector3.new(0, -0.45, 0), "Shirt", "LeftArm" },
    { "LeftHand", Vector3.new(1, 1.1, 1), Vector3.new(-1.5, 4, 0), Vector3.new(0, -1.45, 0), "Hands", "LeftArm" },
    { "RightSleeve", Vector3.new(1, 0.9, 1), Vector3.new(1.5, 4, 0), Vector3.new(0, -0.45, 0), "Shirt", "RightArm" },
    { "RightHand", Vector3.new(1, 1.1, 1), Vector3.new(1.5, 4, 0), Vector3.new(0, -1.45, 0), "Hands", "RightArm" },
    { "LeftShorts", Vector3.new(1, 0.9, 1), Vector3.new(-0.5, 2, 0), Vector3.new(0, -0.45, 0), "Shorts", "LeftLeg" },
    { "LeftSock", Vector3.new(1, 0.8, 1), Vector3.new(-0.5, 2, 0), Vector3.new(0, -1.3, 0), "Socks", "LeftLeg" },
    { "LeftShoe", Vector3.new(1.05, 0.3, 1.2), Vector3.new(-0.5, 2, 0), Vector3.new(0, -1.85, -0.08), "Shoes", "LeftLeg" },
    { "RightShorts", Vector3.new(1, 0.9, 1), Vector3.new(0.5, 2, 0), Vector3.new(0, -0.45, 0), "Shorts", "RightLeg" },
    { "RightSock", Vector3.new(1, 0.8, 1), Vector3.new(0.5, 2, 0), Vector3.new(0, -1.3, 0), "Socks", "RightLeg" },
    { "RightShoe", Vector3.new(1.05, 0.3, 1.2), Vector3.new(0.5, 2, 0), Vector3.new(0, -1.85, -0.08), "Shoes", "RightLeg" },
}

local STRIPES = {
    { "StripeLeft", Vector3.new(0.4, 2, 0.06), Vector3.new(0, 3, 0), Vector3.new(-0.5, 0, -0.52), "Stripes" },
    { "StripeRight", Vector3.new(0.4, 2, 0.06), Vector3.new(0, 3, 0), Vector3.new(0.5, 0, -0.52), "Stripes" },
}

local SWING = {
    LeftArm = 1,
    RightArm = -1,
    LeftLeg = -1,
    RightLeg = 1,
}

local function pieceColor(key, definition)
    if key == "Hands" then
        return definition.Gloves or definition.Skin
    elseif key == "Socks" then
        return definition.Socks or definition.Shorts
    elseif key == "Shoes" then
        return definition.Shoes or DEFAULT_SHOES
    end
    return definition[key]
end

-- Name above the number on the back of the shirt
local function addBackPrint(torso, definition)
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Back
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 60
    gui.LightInfluence = 0.5
    gui.Parent = torso

    local color = definition.NumberColor or Color3.new(1, 1, 1)
    local function label(text, y, height)
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(0.9, 0, height, 0)
        textLabel.Position = UDim2.new(0.05, 0, y, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Font = Enum.Font.FredokaOne
        textLabel.TextScaled = true
        textLabel.Text = text
        textLabel.TextColor3 = color
        textLabel.Parent = gui
    end
    label(string.upper(definition.Name), 0.06, 0.2)
    label(tostring(definition.Number), 0.26, 0.66)
end

-- Returns a rig table { model, parts }. collide = whether the parts can be bumped into.
function RigBuilder.build(definition, collide)
    local model = Instance.new("Model")
    model.Name = definition.Name

    local pieces = {}
    for _, piece in ipairs(PIECES) do
        table.insert(pieces, piece)
    end
    if definition.Stripes then
        for _, piece in ipairs(STRIPES) do
            table.insert(pieces, piece)
        end
    end

    local parts = {}
    for _, piece in ipairs(pieces) do
        local part = Instance.new("Part")
        part.Name = piece[1]
        part.Size = piece[2]
        part.Anchored = true
        part.CanCollide = collide == true
        part.CanQuery = false
        part.CanTouch = false
        part.Material = definition.Material or Enum.Material.SmoothPlastic
        part.TopSurface = Enum.SurfaceType.Smooth
        part.BottomSurface = Enum.SurfaceType.Smooth
        part.Color = pieceColor(piece[5], definition)
        part.Parent = model
        parts[piece[1]] = part
    end

    local headMesh = Instance.new("SpecialMesh")
    headMesh.MeshType = Enum.MeshType.Head
    headMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
    headMesh.Parent = parts.Head

    local face = Instance.new("Decal")
    face.Texture = "rbxasset://textures/face.png"
    face.Face = Enum.NormalId.Front
    face.Parent = parts.Head

    addBackPrint(parts.Torso, definition)
    model.PrimaryPart = parts.Torso

    local rig = { model = model, parts = parts, pieces = pieces }
    RigBuilder.pose(rig, CFrame.new(), 0)
    return rig
end

-- rootCFrame is at the feet; swing is the limb angle in radians; armsUp raises both arms (goalkeeper)
function RigBuilder.pose(rig, rootCFrame, swing, armsUp)
    for _, piece in ipairs(rig.pieces) do
        local group = piece[6]
        local angle = swing * (SWING[group] or 0)
        if armsUp and (group == "LeftArm" or group == "RightArm") then
            angle = math.rad(165)
        end
        rig.parts[piece[1]].CFrame = rootCFrame * CFrame.new(piece[3]) * CFrame.Angles(angle, 0, 0) * CFrame.new(piece[4])
    end
end

return RigBuilder
