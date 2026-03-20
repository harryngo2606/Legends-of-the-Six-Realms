--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")
local BossConfig = require(Modules:WaitForChild("BossConfig"))

local BossService = {}

local MONSTERS_FOLDER_NAME = "Monsters"
local TEMPLATES_FOLDER_NAME = "Templates"
local BOSS_ID_ATTRIBUTE_NAME = "BossId"
local IS_BOSS_ATTRIBUTE_NAME = "IsBoss"
local EXP_REWARD_ATTRIBUTE_NAME = "ExpReward"
local BOSS_NAME_ATTRIBUTE_NAME = "BossName"
local AI_ENABLED_ATTRIBUTE_NAME = "AIEnabled"

local ATTACK_ATTRIBUTE_NAME = "Attack"
local ATTACK_COOLDOWN_ATTRIBUTE_NAME = "AttackCooldown"
local DETECT_RANGE_ATTRIBUTE_NAME = "DetectRange"
local ATTACK_RANGE_ATTRIBUTE_NAME = "AttackRange"
local CHASE_RANGE_ATTRIBUTE_NAME = "ChaseRange"
local LEASH_RANGE_ATTRIBUTE_NAME = "LeashRange"
local ASSIST_RADIUS_ATTRIBUTE_NAME = "AssistRadius"
local TARGET_MODE_ATTRIBUTE_NAME = "TargetMode"
local AGGRO_MODE_ATTRIBUTE_NAME = "AggroMode"

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

local function getMonstersFolder(): Folder
	return getOrCreateFolder(Workspace, MONSTERS_FOLDER_NAME)
end

local function getTemplatesFolder(): Folder
	local monstersFolder = getMonstersFolder()
	return getOrCreateFolder(monstersFolder, TEMPLATES_FOLDER_NAME)
end

local function isTemplateDescendant(instance: Instance): boolean
	local templatesFolder = getTemplatesFolder()
	return instance:IsDescendantOf(templatesFolder)
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
	monsterModel:SetAttribute(AI_ENABLED_ATTRIBUTE_NAME, true)

	monsterModel:SetAttribute(ATTACK_ATTRIBUTE_NAME, bossData.Attack)
	monsterModel:SetAttribute(ATTACK_COOLDOWN_ATTRIBUTE_NAME, bossData.AttackCooldown)
	monsterModel:SetAttribute(DETECT_RANGE_ATTRIBUTE_NAME, bossData.DetectRange)
	monsterModel:SetAttribute(ATTACK_RANGE_ATTRIBUTE_NAME, bossData.AttackRange)
	monsterModel:SetAttribute(CHASE_RANGE_ATTRIBUTE_NAME, bossData.ChaseRange)
	monsterModel:SetAttribute(LEASH_RANGE_ATTRIBUTE_NAME, bossData.LeashRange)
	monsterModel:SetAttribute(ASSIST_RADIUS_ATTRIBUTE_NAME, bossData.AssistRadius)
	monsterModel:SetAttribute(TARGET_MODE_ATTRIBUTE_NAME, bossData.TargetMode)
	monsterModel:SetAttribute(AGGRO_MODE_ATTRIBUTE_NAME, bossData.AggroMode)

	local firstInit = monsterModel:GetAttribute("BossStatsApplied") ~= true

	humanoid.MaxHealth = bossData.MaxHP
	humanoid.WalkSpeed = bossData.WalkSpeed
	humanoid.DisplayName = bossData.Name

	if firstInit then
		humanoid.Health = bossData.MaxHP
		monsterModel:SetAttribute("BossStatsApplied", true)
	end

	pcall(function()
		rootPart:SetNetworkOwner(nil)
	end)
end

function BossService.Init(): ()
	local monstersFolder = getMonstersFolder()
	getTemplatesFolder()

	for _, descendant in ipairs(monstersFolder:GetDescendants()) do
		if descendant:IsA("Model") and not isTemplateDescendant(descendant) then
			applyBossConfig(descendant)
		end
	end

	monstersFolder.DescendantAdded:Connect(function(descendant: Instance)
		if descendant:IsA("Model") and not isTemplateDescendant(descendant) then
			task.defer(function()
				applyBossConfig(descendant)
			end)
		end
	end)
end

return BossService