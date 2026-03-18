--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")
local BossConfig = require(Modules:WaitForChild("BossConfig"))

local BossService = {}

local MONSTERS_FOLDER_NAME = "Monsters"
local BOSS_ID_ATTRIBUTE_NAME = "BossId"
local IS_BOSS_ATTRIBUTE_NAME = "IsBoss"
local EXP_REWARD_ATTRIBUTE_NAME = "ExpReward"
local BOSS_NAME_ATTRIBUTE_NAME = "BossName"

local function getOrCreateFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function applyBossConfig(monsterModel: Model): ()
	local bossIdValue = monsterModel:GetAttribute(BOSS_ID_ATTRIBUTE_NAME)
	if typeof(bossIdValue) ~= "string" or bossIdValue == "" then
		return
	end

	local bossData = BossConfig.GetBoss(bossIdValue)
	if bossData == nil then
		warn(("BossService: Missing boss config for BossId '%s' on model '%s'"):format(bossIdValue, monsterModel.Name))
		return
	end

	local humanoid = monsterModel:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		warn(("BossService: Model '%s' has BossId but no Humanoid"):format(monsterModel.Name))
		return
	end

	local rootPart = monsterModel:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		warn(("BossService: Model '%s' has BossId but no HumanoidRootPart"):format(monsterModel.Name))
		return
	end

	monsterModel:SetAttribute(IS_BOSS_ATTRIBUTE_NAME, true)
	monsterModel:SetAttribute(BOSS_NAME_ATTRIBUTE_NAME, bossData.Name)
	monsterModel:SetAttribute(EXP_REWARD_ATTRIBUTE_NAME, bossData.ExpReward)

	humanoid.MaxHealth = bossData.MaxHP
	humanoid.Health = bossData.MaxHP
	humanoid.WalkSpeed = bossData.WalkSpeed
	humanoid.DisplayName = bossData.Name

	print(("BossService: Applied boss config '%s' to '%s'"):format(bossIdValue, monsterModel.Name))
end

function BossService.Init(): ()
	local monstersFolder = getOrCreateFolder(Workspace, MONSTERS_FOLDER_NAME)

	for _, child in monstersFolder:GetChildren() do
		if child:IsA("Model") then
			applyBossConfig(child)
		end
	end

	monstersFolder.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Model") then
			applyBossConfig(child)
		end
	end)
end

return BossService