--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")

local MonsterConfig = require(Modules:WaitForChild("MonsterConfig"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

type AggroByPlayer = {[Player]: number}
type MonsterState = {
	SpawnPosition: Vector3,
	DamageByPlayer: AggroByPlayer,
	LastAttackAt: number,
}

local MonsterAIService = {}

local MONSTERS_FOLDER_NAME = "Monsters"
local TEMPLATES_FOLDER_NAME = "Templates"
local MONSTER_ID_ATTRIBUTE_NAME = "MonsterId"
local BOSS_ID_ATTRIBUTE_NAME = "BossId"
local ATTACK_ATTRIBUTE_NAME = "Attack"
local ATTACK_COOLDOWN_ATTRIBUTE_NAME = "AttackCooldown"
local DETECT_RANGE_ATTRIBUTE_NAME = "DetectRange"
local ATTACK_RANGE_ATTRIBUTE_NAME = "AttackRange"
local CHASE_RANGE_ATTRIBUTE_NAME = "ChaseRange"
local LEASH_RANGE_ATTRIBUTE_NAME = "LeashRange"
local TARGET_MODE_ATTRIBUTE_NAME = "TargetMode"
local EXP_REWARD_ATTRIBUTE_NAME = "ExpReward"
local CURRENT_DUNGEON_ID_ATTRIBUTE_NAME = "CurrentDungeonId"
local IN_DUNGEON_ATTRIBUTE_NAME = "InDungeon"

local AI_TICK_RATE = 0.2
local HOME_REACHED_DISTANCE = 3

local monsterStates: {[Model]: MonsterState} = {}
local heartbeatConnection: RBXScriptConnection? = nil
local heartbeatAccumulator = 0

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

local function getModelParts(model: Model): (Humanoid?, BasePart?)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return nil, nil
	end

	local rootPart = model:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return nil, nil
	end

	return humanoid, rootPart
end

local function getAliveModelParts(model: Model): (Humanoid?, BasePart?)
	local humanoid, rootPart = getModelParts(model)
	if humanoid == nil or rootPart == nil then
		return nil, nil
	end

	if humanoid.Health <= 0 then
		return nil, nil
	end

	return humanoid, rootPart
end

local function getNumberAttribute(instance: Instance, attributeName: string, defaultValue: number): number
	local value = instance:GetAttribute(attributeName)
	if typeof(value) == "number" then
		return value
	end

	return defaultValue
end

local function getStringAttribute(instance: Instance, attributeName: string, defaultValue: string): string
	local value = instance:GetAttribute(attributeName)
	if typeof(value) == "string" and value ~= "" then
		return value
	end

	return defaultValue
end

local function getMonstersFolder(): Folder
	return getOrCreateFolder(Workspace, MONSTERS_FOLDER_NAME)
end

local function getTemplatesFolder(monstersFolder: Folder): Folder?
	local templatesFolder = monstersFolder:FindFirstChild(TEMPLATES_FOLDER_NAME)
	if templatesFolder ~= nil and templatesFolder:IsA("Folder") then
		return templatesFolder
	end

	return nil
end

local function isTemplateDescendant(instance: Instance, templatesFolder: Folder?): boolean
	if templatesFolder == nil then
		return false
	end

	return instance:IsDescendantOf(templatesFolder)
end

local function forEachRuntimeMonster(callback: (Model) -> ()): ()
	local monstersFolder = getMonstersFolder()
	local templatesFolder = getTemplatesFolder(monstersFolder)

	for _, descendant in ipairs(monstersFolder:GetDescendants()) do
		if descendant:IsA("Model") and not isTemplateDescendant(descendant, templatesFolder) then
			callback(descendant)
		end
	end
end

local function resolveMonsterId(monsterModel: Model): string?
	local monsterIdValue = monsterModel:GetAttribute(MONSTER_ID_ATTRIBUTE_NAME)
	if typeof(monsterIdValue) == "string" and monsterIdValue ~= "" then
		return monsterIdValue
	end

	local monsterData = MonsterConfig.GetMonster(monsterModel.Name)
	if monsterData ~= nil then
		return monsterData.Id
	end

	return nil
end

local function isBossModel(monsterModel: Model): boolean
	local bossIdValue = monsterModel:GetAttribute(BOSS_ID_ATTRIBUTE_NAME)
	return typeof(bossIdValue) == "string" and bossIdValue ~= ""
end

local function hasAttackData(monsterModel: Model): boolean
	local attackValue = monsterModel:GetAttribute(ATTACK_ATTRIBUTE_NAME)
	return typeof(attackValue) == "number" and attackValue > 0
end

local function applyMonsterConfig(monsterModel: Model): ()
	if isBossModel(monsterModel) then
		return
	end

	local monsterId = resolveMonsterId(monsterModel)
	if monsterId == nil then
		return
	end

	local monsterData = MonsterConfig.GetMonster(monsterId)
	if monsterData == nil then
		warn(("MonsterAIService: Missing monster config for MonsterId '%s' on model '%s'"):format(monsterId, monsterModel.Name))
		return
	end

	local humanoid, rootPart = getModelParts(monsterModel)
	if humanoid == nil or rootPart == nil then
		warn(("MonsterAIService: Model '%s' has MonsterId but missing Humanoid/HumanoidRootPart"):format(monsterModel.Name))
		return
	end

	monsterModel:SetAttribute(MONSTER_ID_ATTRIBUTE_NAME, monsterData.Id)
	monsterModel:SetAttribute(EXP_REWARD_ATTRIBUTE_NAME, monsterData.ExpReward)
	monsterModel:SetAttribute(ATTACK_ATTRIBUTE_NAME, monsterData.Attack)
	monsterModel:SetAttribute(ATTACK_COOLDOWN_ATTRIBUTE_NAME, monsterData.AttackCooldown)
	monsterModel:SetAttribute(DETECT_RANGE_ATTRIBUTE_NAME, monsterData.DetectRange)
	monsterModel:SetAttribute(ATTACK_RANGE_ATTRIBUTE_NAME, monsterData.AttackRange)
	monsterModel:SetAttribute(CHASE_RANGE_ATTRIBUTE_NAME, monsterData.ChaseRange)
	monsterModel:SetAttribute(LEASH_RANGE_ATTRIBUTE_NAME, monsterData.LeashRange)
	monsterModel:SetAttribute(TARGET_MODE_ATTRIBUTE_NAME, monsterData.TargetMode)

	local firstInit = monsterModel:GetAttribute("AIStatsApplied") ~= true

	humanoid.MaxHealth = monsterData.MaxHP
	humanoid.WalkSpeed = monsterData.WalkSpeed
	humanoid.DisplayName = monsterData.Name

	if firstInit then
		humanoid.Health = monsterData.MaxHP
		monsterModel:SetAttribute("AIStatsApplied", true)
	end

	pcall(function()
		rootPart:SetNetworkOwner(nil)
	end)
end

local function getOrCreateMonsterState(monsterModel: Model): MonsterState?
	local existing = monsterStates[monsterModel]
	if existing ~= nil then
		return existing
	end

	if not hasAttackData(monsterModel) then
		return nil
	end

	local _, rootPart = getModelParts(monsterModel)
	if rootPart == nil then
		return nil
	end

	local state: MonsterState = {
		SpawnPosition = rootPart.Position,
		DamageByPlayer = {},
		LastAttackAt = 0,
	}

	monsterStates[monsterModel] = state
	return state
end

local function clearMonsterState(monsterModel: Model): ()
	monsterStates[monsterModel] = nil
end

local function getTargetCharacter(monsterModel: Model, player: Player): (Humanoid?, BasePart?)
	local monsterDungeonId = monsterModel:GetAttribute("DungeonId")
	if typeof(monsterDungeonId) == "string" and monsterDungeonId ~= "" then
		local playerDungeonId = player:GetAttribute(CURRENT_DUNGEON_ID_ATTRIBUTE_NAME)
		local inDungeon = player:GetAttribute(IN_DUNGEON_ATTRIBUTE_NAME)
		if playerDungeonId ~= monsterDungeonId or inDungeon ~= true then
			return nil, nil
		end
	end

	local character = player.Character
	if character == nil then
		return nil, nil
	end

	return getAliveModelParts(character)
end

local function getNearestPlayerInRange(monsterModel: Model, maxDistance: number): Player?
	local _, monsterRoot = getAliveModelParts(monsterModel)
	if monsterRoot == nil then
		return nil
	end

	local bestPlayer: Player? = nil
	local bestDistance = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		local _, targetRoot = getTargetCharacter(monsterModel, player)
		if targetRoot == nil then
			continue
		end

		local distance = (targetRoot.Position - monsterRoot.Position).Magnitude
		if distance > maxDistance then
			continue
		end

		if distance < bestDistance then
			bestDistance = distance
			bestPlayer = player
		end
	end

	return bestPlayer
end

local function selectTarget(monsterModel: Model, state: MonsterState): Player?
	local _, monsterRoot = getAliveModelParts(monsterModel)
	if monsterRoot == nil then
		return nil
	end

	local detectRange = math.max(getNumberAttribute(monsterModel, DETECT_RANGE_ATTRIBUTE_NAME, 30), 0)
	local chaseRange = math.max(getNumberAttribute(monsterModel, CHASE_RANGE_ATTRIBUTE_NAME, detectRange), detectRange)
	local targetMode = getStringAttribute(monsterModel, TARGET_MODE_ATTRIBUTE_NAME, "Nearest")

	if targetMode == "HighestDamage" then
		local bestPlayer: Player? = nil
		local bestDamage = 0
		local bestDistance = math.huge

		for _, player in ipairs(Players:GetPlayers()) do
			local _, targetRoot = getTargetCharacter(monsterModel, player)
			if targetRoot == nil then
				continue
			end

			local distance = (targetRoot.Position - monsterRoot.Position).Magnitude
			if distance > chaseRange then
				continue
			end

			local totalDamage = state.DamageByPlayer[player] or 0
			if totalDamage <= 0 then
				continue
			end

			if totalDamage > bestDamage or (totalDamage == bestDamage and distance < bestDistance) then
				bestPlayer = player
				bestDamage = totalDamage
				bestDistance = distance
			end
		end

		if bestPlayer ~= nil then
			return bestPlayer
		end

		return getNearestPlayerInRange(monsterModel, detectRange)
	end

	local bestPlayer: Player? = nil
	local bestDistance = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		local _, targetRoot = getTargetCharacter(monsterModel, player)
		if targetRoot == nil then
			continue
		end

		local distance = (targetRoot.Position - monsterRoot.Position).Magnitude
		local totalDamage = state.DamageByPlayer[player] or 0

		if distance > detectRange and (totalDamage <= 0 or distance > chaseRange) then
			continue
		end

		if distance < bestDistance then
			bestPlayer = player
			bestDistance = distance
		end
	end

	return bestPlayer
end

local function moveMonsterTo(humanoid: Humanoid, targetPosition: Vector3): ()
	humanoid:MoveTo(targetPosition)
end

local function clearAggroIfHome(state: MonsterState, rootPart: BasePart): ()
	if (rootPart.Position - state.SpawnPosition).Magnitude <= HOME_REACHED_DISTANCE then
		table.clear(state.DamageByPlayer)
	end
end

local function tryAttackTarget(monsterModel: Model, targetPlayer: Player, state: MonsterState): boolean
	local _, monsterRoot = getAliveModelParts(monsterModel)
	if monsterRoot == nil then
		return false
	end

	local targetHumanoid, targetRoot = getTargetCharacter(monsterModel, targetPlayer)
	if targetHumanoid == nil or targetRoot == nil then
		return false
	end

	local attackRange = math.max(getNumberAttribute(monsterModel, ATTACK_RANGE_ATTRIBUTE_NAME, 6), 0)
	local distance = (targetRoot.Position - monsterRoot.Position).Magnitude
	if distance > attackRange then
		return false
	end

	local attackCooldown = math.max(getNumberAttribute(monsterModel, ATTACK_COOLDOWN_ATTRIBUTE_NAME, 1), 0.1)
	local now = os.clock()
	if now - state.LastAttackAt < attackCooldown then
		return false
	end

	local attack = math.max(getNumberAttribute(monsterModel, ATTACK_ATTRIBUTE_NAME, 1), 1)
	local targetStats = PlayerDataService.GetCurrentStats(targetPlayer)
	local finalDamage = math.max(1, math.floor(attack - targetStats.Defense))

	state.LastAttackAt = now
	targetHumanoid:TakeDamage(finalDamage)
	return true
end

local function updateMonster(monsterModel: Model): ()
	if monsterModel.Parent == nil or not monsterModel:IsDescendantOf(Workspace) then
		clearMonsterState(monsterModel)
		return
	end

	if not hasAttackData(monsterModel) then
		clearMonsterState(monsterModel)
		return
	end

	local humanoid, rootPart = getAliveModelParts(monsterModel)
	if humanoid == nil or rootPart == nil then
		return
	end

	local state = getOrCreateMonsterState(monsterModel)
	if state == nil then
		return
	end

	local leashRange = math.max(getNumberAttribute(monsterModel, LEASH_RANGE_ATTRIBUTE_NAME, 45), 0)
	local chaseRange = math.max(getNumberAttribute(monsterModel, CHASE_RANGE_ATTRIBUTE_NAME, 30), 0)
	local distanceFromSpawn = (rootPart.Position - state.SpawnPosition).Magnitude

	if distanceFromSpawn > leashRange then
		moveMonsterTo(humanoid, state.SpawnPosition)
		return
	end

	local targetPlayer = selectTarget(monsterModel, state)
	if targetPlayer == nil then
		if distanceFromSpawn > HOME_REACHED_DISTANCE then
			moveMonsterTo(humanoid, state.SpawnPosition)
		else
			clearAggroIfHome(state, rootPart)
		end
		return
	end

	local _, targetRoot = getTargetCharacter(monsterModel, targetPlayer)
	if targetRoot == nil then
		return
	end

	local distanceToTarget = (targetRoot.Position - rootPart.Position).Magnitude
	if distanceToTarget > chaseRange then
		moveMonsterTo(humanoid, state.SpawnPosition)
		return
	end

	if tryAttackTarget(monsterModel, targetPlayer, state) then
		return
	end

	moveMonsterTo(humanoid, targetRoot.Position)
end

function MonsterAIService.RegisterDamage(monsterModel: Model, player: Player, damage: number): ()
	if damage <= 0 then
		return
	end

	local humanoid = monsterModel:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return
	end

	local state = getOrCreateMonsterState(monsterModel)
	if state == nil then
		return
	end

	state.DamageByPlayer[player] = (state.DamageByPlayer[player] or 0) + damage
end

function MonsterAIService.Init(): ()
	local monstersFolder = getMonstersFolder()

	forEachRuntimeMonster(function(monsterModel: Model)
		applyMonsterConfig(monsterModel)
		getOrCreateMonsterState(monsterModel)
	end)

	monstersFolder.DescendantAdded:Connect(function(descendant: Instance)
		if descendant:IsA("Model") and not isTemplateDescendant(descendant, getTemplatesFolder(monstersFolder)) then
			task.defer(function()
				applyMonsterConfig(descendant)
				getOrCreateMonsterState(descendant)
			end)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		for _, state in monsterStates do
			state.DamageByPlayer[player] = nil
		end
	end)

	if heartbeatConnection == nil then
		heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime: number)
			heartbeatAccumulator += deltaTime
			if heartbeatAccumulator < AI_TICK_RATE then
				return
			end

			heartbeatAccumulator = 0

			forEachRuntimeMonster(function(monsterModel: Model)
				if monsterStates[monsterModel] == nil then
					applyMonsterConfig(monsterModel)
					getOrCreateMonsterState(monsterModel)
				end
			end)

			for monsterModel, _ in monsterStates do
				updateMonster(monsterModel)
			end
		end)
	end
end

return MonsterAIService