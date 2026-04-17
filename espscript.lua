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