--!strict

local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer

type UIRefs = {
	ScreenGui: ScreenGui,
	Root: Frame,
	LevelLabel: TextLabel,
	HPFill: Frame,
	HPText: TextLabel,
	EXPFill: Frame,
	EXPText: TextLabel,
}

local UIController = {}

local ui: UIRefs? = nil
local healthChangedConnection: RBXScriptConnection? = nil
local maxHealthChangedConnection: RBXScriptConnection? = nil

local function setBar(fill: Frame, currentValue: number, maxValue: number): ()
	local ratio = 0

	if maxValue > 0 then
		ratio = math.clamp(currentValue / maxValue, 0, 1)
	end

	fill.Size = UDim2.fromScale(ratio, 1)
end

local function createBar(
	parent: Instance,
	name: string,
	position: UDim2,
	size: UDim2,
	labelText: string
): (Frame, Frame, TextLabel)
	local container = Instance.new("Frame")
	container.Name = name
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Position = position
	container.Size = size
	container.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Position = UDim2.new(0, 0, 0, 0)
	label.Size = UDim2.new(1, 0, 0, 16)
	label.Font = Enum.Font.GothamSemibold
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container

	local barBackground = Instance.new("Frame")
	barBackground.Name = "Background"
	barBackground.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	barBackground.BorderSizePixel = 0
	barBackground.Position = UDim2.new(0, 0, 0, 20)
	barBackground.Size = UDim2.new(1, 0, 0, 18)
	barBackground.Parent = container

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 6)
	barCorner.Parent = barBackground

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(85, 170, 255)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = barBackground

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill

	local valueText = Instance.new("TextLabel")
	valueText.Name = "ValueText"
	valueText.BackgroundTransparency = 1
	valueText.BorderSizePixel = 0
	valueText.Size = UDim2.fromScale(1, 1)
	valueText.Font = Enum.Font.Gotham
	valueText.Text = ""
	valueText.TextColor3 = Color3.fromRGB(255, 255, 255)
	valueText.TextSize = 13
	valueText.Parent = barBackground

	return container, fill, valueText
end

local function createUI(): UIRefs
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("CoreUI")
	if existing and existing:IsA("ScreenGui") then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CoreUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0, 1)
	root.Position = UDim2.new(0, 16, 1, -16)
	root.Size = UDim2.new(0, 260, 0, 110)
	root.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
	root.BackgroundTransparency = 0.15
	root.BorderSizePixel = 0
	root.Parent = screenGui

	local rootCorner = Instance.new("UICorner")
	rootCorner.CornerRadius = UDim.new(0, 8)
	rootCorner.Parent = root

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.BackgroundTransparency = 1
	levelLabel.BorderSizePixel = 0
	levelLabel.Position = UDim2.new(0, 10, 0, 8)
	levelLabel.Size = UDim2.new(1, -20, 0, 18)
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.Text = "Level 1"
	levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	levelLabel.TextSize = 16
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.Parent = root

	local _, hpFill, hpText = createBar(
		root,
		"HPBar",
		UDim2.new(0, 10, 0, 32),
		UDim2.new(1, -20, 0, 40),
		"HP"
	)
	hpFill.BackgroundColor3 = Color3.fromRGB(80, 200, 120)

	local _, expFill, expText = createBar(
		root,
		"EXPBar",
		UDim2.new(0, 10, 0, 68),
		UDim2.new(1, -20, 0, 40),
		"EXP"
	)
	expFill.BackgroundColor3 = Color3.fromRGB(90, 140, 255)

	return {
		ScreenGui = screenGui,
		Root = root,
		LevelLabel = levelLabel,
		HPFill = hpFill,
		HPText = hpText,
		EXPFill = expFill,
		EXPText = expText,
	}
end

function UIController.UpdateLevelAndExp(): ()
	if ui == nil then
		return
	end

	local level = localPlayer:GetAttribute("Level")
	local exp = localPlayer:GetAttribute("Exp")
	local expNeeded = localPlayer:GetAttribute("ExpNeeded")

	local levelValue = if typeof(level) == "number" then level else 1
	local expValue = if typeof(exp) == "number" then exp else 0
	local expNeededValue = if typeof(expNeeded) == "number" then expNeeded else 50

	ui.LevelLabel.Text = string.format("Level %d", levelValue)
	ui.EXPText.Text = string.format("%d / %d", expValue, expNeededValue)
	setBar(ui.EXPFill, expValue, expNeededValue)
end

function UIController.UpdateHealth(): ()
	if ui == nil then
		return
	end

	local character = localPlayer.Character
	if character == nil then
		ui.HPText.Text = "0 / 0"
		setBar(ui.HPFill, 0, 0)
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		ui.HPText.Text = "0 / 0"
		setBar(ui.HPFill, 0, 0)
		return
	end

	ui.HPText.Text = string.format("%d / %d", math.floor(humanoid.Health), math.floor(humanoid.MaxHealth))
	setBar(ui.HPFill, humanoid.Health, humanoid.MaxHealth)
end

function UIController.BindCharacter(character: Model): ()
	if healthChangedConnection then
		healthChangedConnection:Disconnect()
		healthChangedConnection = nil
	end

	if maxHealthChangedConnection then
		maxHealthChangedConnection:Disconnect()
		maxHealthChangedConnection = nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		UIController.UpdateHealth()
		return
	end

	healthChangedConnection = humanoid.HealthChanged:Connect(function()
		UIController.UpdateHealth()
	end)

	maxHealthChangedConnection = humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		UIController.UpdateHealth()
	end)

	UIController.UpdateHealth()
end

function UIController.Init(): ()
	ui = createUI()

	localPlayer:GetAttributeChangedSignal("Level"):Connect(function()
		UIController.UpdateLevelAndExp()
	end)

	localPlayer:GetAttributeChangedSignal("Exp"):Connect(function()
		UIController.UpdateLevelAndExp()
	end)

	localPlayer:GetAttributeChangedSignal("ExpNeeded"):Connect(function()
		UIController.UpdateLevelAndExp()
	end)

	localPlayer.CharacterAdded:Connect(function(character: Model)
		UIController.BindCharacter(character)
	end)

	if localPlayer.Character then
		UIController.BindCharacter(localPlayer.Character)
	else
		UIController.UpdateHealth()
	end

	UIController.UpdateLevelAndExp()
end

return UIController