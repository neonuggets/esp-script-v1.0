local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
if not PlayerGui then
    warn("❌ FAILED: PlayerGui not found. Script terminating.")
    return
end
local Camera = Workspace.CurrentCamera or Workspace:GetPropertyChangedSignal("CurrentCamera"):Wait()

-- CONFIG
local SHOW_USERNAMES   = true
local BOX_THICKNESS    = 1.5
local HEALTHBAR_WIDTH  = 6
local HEALTHBAR_OFFSET = 4
local BOX_COLOR        = Color3.new(1, 1, 1)
local MIN_BOX_HEIGHT   = 20
local MAX_DISTANCE     = 500

local espElements = {}

local function getScreenGui()
    local gui = PlayerGui:FindFirstChild("EspGui")
    if not gui then
        gui = Instance.new("ScreenGui")
        gui.Name = "EspGui"
        gui.ResetOnSpawn = false
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.DisplayOrder = 1000
        gui.IgnoreGuiInset = true
        gui.Parent = PlayerGui
    end
    return gui
end

local function createEspElements(player)
    if not PlayerGui or not PlayerGui.Parent then return end

    local screenGui = getScreenGui()

    local container = Instance.new("Frame")
    container.BackgroundTransparency = 1
    container.BorderSizePixel = 0
    container.Parent = screenGui

    local box = {}
    for _, side in ipairs({"top", "bottom", "left", "right"}) do
        local f = Instance.new("Frame")
        f.BackgroundColor3 = BOX_COLOR
        f.BorderSizePixel = 0
        f.Parent = container
        box[side] = f
    end

    box.top.Size        = UDim2.new(1, 0, 0, BOX_THICKNESS)
    box.bottom.Size     = UDim2.new(1, 0, 0, BOX_THICKNESS)
    box.left.Size       = UDim2.new(0, BOX_THICKNESS, 1, 0)
    box.right.Size      = UDim2.new(0, BOX_THICKNESS, 1, 0)
    box.top.Position    = UDim2.new(0, 0, 0, 0)
    box.bottom.Position = UDim2.new(0, 0, 1, -BOX_THICKNESS)
    box.left.Position   = UDim2.new(0, 0, 0, 0)
    box.right.Position  = UDim2.new(1, -BOX_THICKNESS, 0, 0)

    local healthBarBg = Instance.new("Frame")
    healthBarBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    healthBarBg.BorderSizePixel = 0
    healthBarBg.Size = UDim2.new(0, HEALTHBAR_WIDTH, 1, 0)
    healthBarBg.Position = UDim2.new(1, HEALTHBAR_OFFSET, 0, 0)
    healthBarBg.Parent = container

    local healthBarFill = Instance.new("Frame")
    healthBarFill.BackgroundColor3 = Color3.new(0, 1, 0)
    healthBarFill.BorderSizePixel = 0
    healthBarFill.AnchorPoint = Vector2.new(0, 1)
    healthBarFill.Size = UDim2.new(1, 0, 1, 0)
    healthBarFill.Position = UDim2.new(0, 0, 1, 0)
    healthBarFill.Parent = healthBarBg

    local nameTag = nil
    if SHOW_USERNAMES then
        nameTag = Instance.new("TextLabel")
        nameTag.BackgroundTransparency = 1
        nameTag.Text = player.DisplayName
        nameTag.TextColor3 = Color3.new(1, 1, 1)
        nameTag.TextStrokeTransparency = 0.5
        nameTag.TextScaled = true
        nameTag.Font = Enum.Font.GothamBold
        nameTag.Size = UDim2.new(1, 0, 0, 16)
        nameTag.Position = UDim2.new(0, 0, 0, -20)
        nameTag.Parent = container
    end

    espElements[player] = {
        container     = container,
        healthBarFill = healthBarFill,
        nameTag       = nameTag,
        lastValid     = tick(),
    }
end

local function getScreenBoundingBox(character)
    local primary = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
    if not primary then return nil end

    local distance = (primary.Position - Camera.CFrame.Position).Magnitude
    if distance > MAX_DISTANCE then return nil end

    local success, cframe, size = pcall(function()
        return character:GetBoundingBox()
    end)
    if not success or not cframe then return nil end

    local half = size / 2

    local corners = {
        cframe:PointToWorldSpace(Vector3.new(-half.X, -half.Y, -half.Z)),
        cframe:PointToWorldSpace(Vector3.new( half.X, -half.Y, -half.Z)),
        cframe:PointToWorldSpace(Vector3.new(-half.X,  half.Y, -half.Z)),
        cframe:PointToWorldSpace(Vector3.new( half.X,  half.Y, -half.Z)),
        cframe:PointToWorldSpace(Vector3.new(-half.X, -half.Y,  half.Z)),
        cframe:PointToWorldSpace(Vector3.new( half.X, -half.Y,  half.Z)),
        cframe:PointToWorldSpace(Vector3.new(-half.X,  half.Y,  half.Z)),
        cframe:PointToWorldSpace(Vector3.new( half.X,  half.Y,  half.Z)),
    }

    local minX, minY =  math.huge,  math.huge
    local maxX, maxY = -math.huge, -math.huge
    local anyVisible = false

    for _, corner in ipairs(corners) do
        local screenPos = Camera:WorldToViewportPoint(corner)
        if screenPos.Z > 0 then
            anyVisible = true
            minX = math.min(minX, screenPos.X)
            minY = math.min(minY, screenPos.Y)
            maxX = math.max(maxX, screenPos.X)
            maxY = math.max(maxY, screenPos.Y)
        end
    end

    if not anyVisible then return nil end

    local w = maxX - minX
    local h = maxY - minY
    if w < 1 or h < 1 then return nil end

    return { x = minX, y = minY, width = w, height = h }
end

local function updateEsp(player, character)
    local esp = espElements[player]
    if not esp or not character then return end

    local bounds = getScreenBoundingBox(character)
    if not bounds or bounds.height < MIN_BOX_HEIGHT then
        esp.container.Visible = false
        return
    end

    esp.container.Visible  = true
    esp.container.Position = UDim2.new(0, bounds.x, 0, bounds.y)
    esp.container.Size     = UDim2.new(0, bounds.width, 0, bounds.height)
    esp.lastValid = tick()

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.MaxHealth > 0 then
        local ratio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
        esp.healthBarFill.Size = UDim2.new(1, 0, ratio, 0)

        if ratio > 0.7 then
            esp.healthBarFill.BackgroundColor3 = Color3.new(0, 1, 0)
        elseif ratio > 0.3 then
            esp.healthBarFill.BackgroundColor3 = Color3.new(1, 1, 0)
        else
            esp.healthBarFill.BackgroundColor3 = Color3.new(1, 0, 0)
        end
    else
        esp.healthBarFill.Size = UDim2.new(1, 0, 0, 0)
    end
end

local function destroyEsp(player)
    local esp = espElements[player]
    if esp then
        if esp.container and esp.container.Parent then
            esp.container:Destroy()
        end
        espElements[player] = nil
    end
end

local function onCharacterAdded(player, character)
    task.wait(0.15)
    if player.Parent == Players and character.Parent then
        destroyEsp(player)
        createEspElements(player)
    end
end

local function setupPlayer(player)
    if player == LocalPlayer then return end

    if player.Character then
        onCharacterAdded(player, player.Character)
    end

    player.CharacterAdded:Connect(function(char)
        onCharacterAdded(player, char)
    end)

    player.CharacterRemoving:Connect(function()
        destroyEsp(player)
    end)
end

for _, player in ipairs(Players:GetPlayers()) do
    setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(player)
    destroyEsp(player)
end)

RunService.RenderStepped:Connect(function()
    Camera = Workspace.CurrentCamera -- refresh camera reference each frame
    for player, esp in pairs(espElements) do
        local character = player.Character
        if not character or not character.Parent then
            if tick() - esp.lastValid > 0.3 then
                destroyEsp(player)
            end
        else
            updateEsp(player, character)
        end
    end
end)

LocalPlayer.AncestryChanged:Connect(function(_, parent)
    if parent then return end
    for player in pairs(espElements) do
        destroyEsp(player)
    end
    local gui = PlayerGui:FindFirstChild("EspGui")
    if gui then gui:Destroy() end
end)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local TOAST_WIDTH   = 260
local TOAST_HEIGHT  = 54
local PADDING_RIGHT = 16
local PADDING_BOT   = 16
local DISPLAY_TIME  = 3.5
local TWEEN_IN      = 0.45
local TWEEN_OUT     = 0.4


local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NBHubToast"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 9999
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = PlayerGui

local card = Instance.new("Frame")
card.Name = "ToastCard"
card.Size = UDim2.new(0, TOAST_WIDTH, 0, TOAST_HEIGHT)
card.BackgroundTransparency = 1
card.BorderSizePixel = 0
card.AnchorPoint = Vector2.new(1, 1)
card.Position = UDim2.new(1, TOAST_WIDTH + PADDING_RIGHT, 1, -PADDING_BOT)
card.Parent = screenGui


local bg = Instance.new("Frame")
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
bg.BackgroundTransparency = 0 
bg.BorderSizePixel = 0
bg.ZIndex = 1
bg.Parent = card
Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

-- Left accent bar (softer green)
local accent = Instance.new("Frame")
accent.Size = UDim2.new(0, 3, 0.7, 0)
accent.Position = UDim2.new(0, 0, 0.15, 0)
accent.BackgroundColor3 = Color3.fromRGB(60, 210, 120)
accent.BorderSizePixel = 0
accent.ZIndex = 3
accent.Parent = card
Instance.new("UICorner", accent).CornerRadius = UDim.new(1, 0)

-- Content container
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -16, 1, 0)
content.Position = UDim2.new(0, 13, 0, 0)
content.BackgroundTransparency = 1
content.ZIndex = 3
content.Parent = card

-- "NB"
local nbLabel = Instance.new("TextLabel")
nbLabel.Size = UDim2.new(0, 28, 0, 18)
nbLabel.Position = UDim2.new(0, 0, 0, 9)
nbLabel.BackgroundTransparency = 1
nbLabel.Text = "NB"
nbLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
nbLabel.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
nbLabel.TextStrokeTransparency = 0.7
nbLabel.Font = Enum.Font.GothamBold
nbLabel.TextSize = 13
nbLabel.TextXAlignment = Enum.TextXAlignment.Left
nbLabel.ZIndex = 4
nbLabel.Parent = content

-- "Hub"
local hubLabel = Instance.new("TextLabel")
hubLabel.Size = UDim2.new(0, 80, 0, 18)
hubLabel.Position = UDim2.new(0, 26, 0, 9)
hubLabel.BackgroundTransparency = 1
hubLabel.Text = " Hub"
hubLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
hubLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
hubLabel.TextStrokeTransparency = 0.6
hubLabel.Font = Enum.Font.GothamBold
hubLabel.TextSize = 13
hubLabel.TextXAlignment = Enum.TextXAlignment.Left
hubLabel.ZIndex = 4
hubLabel.Parent = content

-- Message
local msgLabel = Instance.new("TextLabel")
msgLabel.Size = UDim2.new(1, -4, 0, 16)
msgLabel.Position = UDim2.new(0, 0, 0, 29)
msgLabel.BackgroundTransparency = 1
msgLabel.Text = "Activated ESP Script, enjoy!"
msgLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
msgLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
msgLabel.TextStrokeTransparency = 0.5
msgLabel.Font = Enum.Font.Gotham
msgLabel.TextSize = 11
msgLabel.TextXAlignment = Enum.TextXAlignment.Left
msgLabel.ZIndex = 4
msgLabel.Parent = content


local rainbowRunning = true
task.spawn(function()
    local hue = 0
    while rainbowRunning do
        hue = (hue + 0.008) % 1
   
        nbLabel.TextColor3 = Color3.fromHSV(hue, 0.55, 1)
        nbLabel.TextStrokeColor3 = Color3.fromHSV(hue, 0.4, 1)
        RunService.Heartbeat:Wait()
    end
end)

local tweenIn = TweenService:Create(card,
    TweenInfo.new(TWEEN_IN, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    { Position = UDim2.new(1, -PADDING_RIGHT, 1, -PADDING_BOT) }
)
tweenIn:Play()


task.delay(DISPLAY_TIME, function()
    rainbowRunning = false
    local tweenOut = TweenService:Create(card,
        TweenInfo.new(TWEEN_OUT, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
        { Position = UDim2.new(1, TOAST_WIDTH + PADDING_RIGHT, 1, -PADDING_BOT) }
    )
    tweenOut:Play()
    tweenOut.Completed:Connect(function()
        screenGui:Destroy()
    end)
end)
