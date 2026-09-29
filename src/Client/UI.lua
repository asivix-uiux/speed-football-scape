local TweenService = game:GetService("TweenService")

-- Small helpers for building the cartoon-style HUD in code
local UI = {}

UI.Font = Enum.Font.FredokaOne
UI.Black = Color3.fromRGB(15, 15, 20)
UI.White = Color3.fromRGB(255, 255, 255)

UI.Rainbow = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
    ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 40)),
    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(80, 230, 80)),
    ColorSequenceKeypoint.new(0.6, Color3.fromRGB(40, 190, 255)),
    ColorSequenceKeypoint.new(0.8, Color3.fromRGB(150, 70, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 200)),
})

function UI.create(className, props, parent)
    local instance = Instance.new(className)
    if props then
        for key, value in pairs(props) do
            instance[key] = value
        end
    end
    instance.Parent = parent
    return instance
end

function UI.stroke(parent, thickness, color, border)
    return UI.create("UIStroke", {
        Thickness = thickness or 2,
        Color = color or UI.Black,
        ApplyStrokeMode = border and Enum.ApplyStrokeMode.Border or Enum.ApplyStrokeMode.Contextual,
        LineJoinMode = Enum.LineJoinMode.Round,
    }, parent)
end

function UI.corner(parent, radius)
    return UI.create("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, parent)
end

function UI.gradient(parent, colors, rotation)
    return UI.create("UIGradient", {
        Color = typeof(colors) == "ColorSequence" and colors or ColorSequence.new(colors[1], colors[2]),
        Rotation = rotation or 90,
    }, parent)
end

-- Outlined cartoon text
function UI.label(parent, props)
    local label = UI.create("TextLabel", {
        BackgroundTransparency = 1,
        Font = UI.Font,
        TextColor3 = props.Color or UI.White,
        TextSize = props.TextSize or 24,
        TextScaled = props.TextScaled == true,
        Text = props.Text or "",
        Size = props.Size,
        Position = props.Position or UDim2.new(),
        AnchorPoint = props.AnchorPoint or Vector2.new(),
        TextXAlignment = props.XAlignment or Enum.TextXAlignment.Center,
        TextYAlignment = props.YAlignment or Enum.TextYAlignment.Center,
        ZIndex = props.ZIndex or 1,
        Name = props.Name or "Label",
    }, parent)
    if props.Stroke ~= false then
        UI.stroke(label, props.StrokeThickness or 2, props.StrokeColor)
    end
    return label
end

-- Colored panel button with an outlined label inside
function UI.button(parent, props)
    local button = UI.create("TextButton", {
        Name = props.Name or "Button",
        Text = "",
        AutoButtonColor = false,
        BackgroundColor3 = props.Background or UI.White,
        Size = props.Size,
        Position = props.Position or UDim2.new(),
        AnchorPoint = props.AnchorPoint or Vector2.new(),
        ZIndex = props.ZIndex or 1,
    }, parent)
    UI.corner(button, props.Corner or 4)
    UI.stroke(button, props.BorderThickness or 3, props.BorderColor, true)
    if props.Gradient then
        UI.gradient(button, props.Gradient, props.GradientRotation)
    end

    local label = nil
    if props.Text then
        label = UI.label(button, {
            Text = props.Text,
            Size = UDim2.fromScale(1, 1),
            TextSize = props.TextSize or 26,
            Color = props.TextColor,
            StrokeThickness = props.StrokeThickness or 2,
            ZIndex = (props.ZIndex or 1) + 1,
        })
    end

    local scale = UI.create("UIScale", { Scale = 1 }, button)
    local pressInfo = TweenInfo.new(0.08)
    button.MouseEnter:Connect(function()
        TweenService:Create(scale, pressInfo, { Scale = 1.05 }):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(scale, pressInfo, { Scale = 1 }):Play()
    end)
    button.MouseButton1Down:Connect(function()
        TweenService:Create(scale, pressInfo, { Scale = 0.93 }):Play()
    end)
    button.MouseButton1Up:Connect(function()
        TweenService:Create(scale, pressInfo, { Scale = 1.05 }):Play()
    end)

    return button, label
end

-- Small round badge (e.g. "87%" or "!")
function UI.badge(parent, text, color, position, size)
    local badge = UI.create("Frame", {
        BackgroundColor3 = color,
        Size = size or UDim2.fromOffset(26, 26),
        Position = position,
        AnchorPoint = Vector2.new(0.5, 0.5),
        ZIndex = 5,
    }, parent)
    UI.corner(badge, 100)
    UI.stroke(badge, 2, UI.White, true)
    local label = UI.label(badge, {
        Text = text,
        Size = UDim2.fromScale(1, 1),
        TextSize = 14,
        ZIndex = 6,
        StrokeThickness = 1.5,
    })
    return badge, label
end

return UI
