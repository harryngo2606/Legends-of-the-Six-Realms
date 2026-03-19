--!strict

local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer

type StatLabels = {
	STRValue: TextLabel,
	AGIValue: TextLabel,
	HPValue: TextLabel,
	MPValue: TextLabel,
	AttackValue: TextLabel,
	AttackSpeedValue: TextLabel,
	DefenseValue: TextLabel,
	WalkSpeedValue: TextLabel,
	MaxManaValue: TextLabel,
	WeaponValue: TextLabel,
}

type UIRefs = {
	ScreenGui: ScreenGui,
	Root: Frame,
	LeftPanel: Frame,
	RightPanel: Frame,
	LevelLabel: TextLabel,
	HPFill: Frame,
	HPText: TextLabel,
	MPFill: Frame,
	MPText: TextLabel,
	EXPFill: Frame,
	EXPText: TextLabel,
	Stats: StatLabels,
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

local function createCorner(target: Instance, radius: number): ()
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = target
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
	createCorner(barBackground, 6)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(85, 170, 255)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = barBackground
	createCorner(fill, 6)

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

local function createStatRow(parent: Instance, name: string, order: number, labelText: string): TextLabel
	local row = Instance.new("Frame")
	row.Name = name .. "Row"
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 18)
	row.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Position = UDim2.new(0, 0, 0, 0)
	label.Size = UDim2.new(0, 90, 1, 0)
	label.Font = Enum.Font.GothamSemibold
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(220, 220, 220)
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row

	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.BackgroundTransparency = 1
	value.BorderSizePixel = 0
	value.Position = UDim2.new(0, 95, 0, 0)
	value.Size = UDim2.new(1, -95, 1, 0)
	value.Font = Enum.Font.Gotham
	value.Text = "-"
	value.TextColor3 = Color3.fromRGB(255, 255, 255)
	value.TextSize = 13
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.Parent = row

	return value
end

local function getNumberAttribute(name: string, fallback: number): number
	local value = localPlayer:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end

	return fallback
end

local function getStringAttribute(name: string, fallback: string): string
	local value = localPlayer:GetAttribute(name)
	if typeof(value) == "string" then
		return value
	end

	return fallback
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
	root.Size = UDim2.new(0, 520, 0, 176)
	root.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
	root.BackgroundTransparency = 0.12
	root.BorderSizePixel = 0
	root.Parent = screenGui
	createCorner(root, 8)

	local leftPanel = Instance.new("Frame")
	leftPanel.Name = "LeftPanel"
	leftPanel.BackgroundTransparency = 1
	leftPanel.BorderSizePixel = 0
	leftPanel.Position = UDim2.new(0, 0, 0, 0)
	leftPanel.Size = UDim2.new(0, 270, 1, 0)
	leftPanel.Parent = root

	local rightPanel = Instance.new("Frame")
	rightPanel.Name = "RightPanel"
	rightPanel.BackgroundTransparency = 1
	rightPanel.BorderSizePixel = 0
	rightPanel.Position = UDim2.new(0, 280, 0, 8)
	rightPanel.Size = UDim2.new(0, 228, 1, -16)
	rightPanel.Parent = root

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
	levelLabel.Parent = leftPanel

	local _, hpFill, hpText = createBar(
		leftPanel,
		"HPBar",
		UDim2.new(0, 10, 0, 32),
		UDim2.new(1, -20, 0, 40),
		"HP"
	)
	hpFill.BackgroundColor3 = Color3.fromRGB(80, 200, 120)

	local _, mpFill, mpText = createBar(
		leftPanel,
		"MPBar",
		UDim2.new(0, 10, 0, 74),
		UDim2.new(1, -20, 0, 40),
		"MP"
	)
	mpFill.BackgroundColor3 = Color3.fromRGB(90, 140, 255)

	local _, expFill, expText = createBar(
		leftPanel,
		"EXPBar",
		UDim2.new(0, 10, 0, 116),
		UDim2.new(1, -20, 0, 40),
		"EXP"
	)
	expFill.BackgroundColor3 = Color3.fromRGB(255, 200, 90)

	local statsTitle = Instance.new("TextLabel")
	statsTitle.Name = "StatsTitle"
	statsTitle.BackgroundTransparency = 1
	statsTitle.BorderSizePixel = 0
	statsTitle.Position = UDim2.new(0, 0, 0, 0)
	statsTitle.Size = UDim2.new(1, 0, 0, 18)
	statsTitle.Font = Enum.Font.GothamBold
	statsTitle.Text = "Stats"
	statsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	statsTitle.TextSize = 15
	statsTitle.TextXAlignment = Enum.TextXAlignment.Left
	statsTitle.Parent = rightPanel

	local statsList = Instance.new("Frame")
	statsList.Name = "StatsList"
	statsList.BackgroundTransparency = 1
	statsList.BorderSizePixel = 0
	statsList.Position = UDim2.new(0, 0, 0, 22)
	statsList.Size = UDim2.new(1, 0, 1, -22)
	statsList.Parent = rightPanel

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 2)
	listLayout.Parent = statsList

	local stats: StatLabels = {
		STRValue = createStatRow(statsList, "STR", 1, "STR"),
		AGIValue = createStatRow(statsList, "AGI", 2, "AGI"),
		HPValue = createStatRow(statsList, "HP", 3, "HP"),
		MPValue = createStatRow(statsList, "MP", 4, "MP"),
		AttackValue = createStatRow(statsList, "Attack", 5, "Attack"),
		AttackSpeedValue = createStatRow(statsList, "AttackSpeed", 6, "Atk Speed"),
		DefenseValue = createStatRow(statsList, "Defense", 7, "Defense"),
		WalkSpeedValue = createStatRow(statsList, "WalkSpeed", 8, "WalkSpeed"),
		MaxManaValue = createStatRow(statsList, "MaxMana", 9, "MaxMana"),
		WeaponValue = createStatRow(statsList, "Weapon", 10, "Weapon"),
	}

	return {
		ScreenGui = screenGui,
		Root = root,
		LeftPanel = leftPanel,
		RightPanel = rightPanel,
		LevelLabel = levelLabel,
		HPFill = hpFill,
		HPText = hpText,
		MPFill = mpFill,
		MPText = mpText,
		EXPFill = expFill,
		EXPText = expText,
		Stats = stats,
	}
end

function UIController.UpdateLevelAndExp(): ()
	if ui == nil then
		return
	end

	local levelValue = getNumberAttribute("Level", 1)
	local expValue = getNumberAttribute("Exp", 0)
	local expNeededValue = getNumberAttribute("ExpNeeded", 50)

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

function UIController.UpdateMana(): ()
	if ui == nil then
		return
	end

	local manaValue = getNumberAttribute("Mana", 0)
	local maxManaValue = getNumberAttribute("MaxMana", 0)

	ui.MPText.Text = string.format("%d / %d", math.floor(manaValue), math.floor(maxManaValue))
	setBar(ui.MPFill, manaValue, maxManaValue)
end

function UIController.UpdateStats(): ()
	if ui == nil then
		return
	end

	local stats = ui.Stats

	stats.STRValue.Text = tostring(getNumberAttribute("STR", 0))
	stats.AGIValue.Text = tostring(getNumberAttribute("AGI", 0))
	stats.HPValue.Text = tostring(getNumberAttribute("HP", 0))
	stats.MPValue.Text = tostring(getNumberAttribute("MP", 0))

	stats.AttackValue.Text = tostring(getNumberAttribute("Attack", 0))
	stats.AttackSpeedValue.Text = string.format("%.2f", getNumberAttribute("AttackSpeed", 1))
	stats.DefenseValue.Text = tostring(getNumberAttribute("Defense", 0))
	stats.WalkSpeedValue.Text = tostring(getNumberAttribute("WalkSpeed", 16))
	stats.MaxManaValue.Text = tostring(getNumberAttribute("MaxMana", 0))

	local weaponName = getStringAttribute("EquippedWeaponName", "")
	stats.WeaponValue.Text = if weaponName ~= "" then weaponName else "None"
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

	local attributeNames = {
		"Level",
		"Exp",
		"ExpNeeded",
		"Mana",
		"MaxMana",
		"STR",
		"AGI",
		"HP",
		"MP",
		"Attack",
		"AttackSpeed",
		"Defense",
		"WalkSpeed",
		"EquippedWeaponName",
	}

	for _, attributeName in ipairs(attributeNames) do
		localPlayer:GetAttributeChangedSignal(attributeName):Connect(function()
			if attributeName == "Level" or attributeName == "Exp" or attributeName == "ExpNeeded" then
				UIController.UpdateLevelAndExp()
			end

			if attributeName == "Mana" or attributeName == "MaxMana" then
				UIController.UpdateMana()
			end

			if attributeName ~= "Exp" and attributeName ~= "ExpNeeded" and attributeName ~= "Mana" then
				UIController.UpdateStats()
			end
		end)
	end

	localPlayer.CharacterAdded:Connect(function(character: Model)
		UIController.BindCharacter(character)
		UIController.UpdateMana()
	end)

	if localPlayer.Character then
		UIController.BindCharacter(localPlayer.Character)
	else
		UIController.UpdateHealth()
	end

	UIController.UpdateLevelAndExp()
	UIController.UpdateMana()
	UIController.UpdateStats()
end

return UIController