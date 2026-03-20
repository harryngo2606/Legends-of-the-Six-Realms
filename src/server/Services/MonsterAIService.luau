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
	LastCombatAt: number,
	OriginalWalkSpeed: number,
}

local MonsterAIService = {}

local MONSTERS_FOLDER_NAME = "Monsters"
local TEMPLATES_FOLDER_NAME = "Templates"

local MONSTER_ID_ATTRIBUTE_NAME = "MonsterId"
local BOSS_ID_ATTRIBUTE_NAME = "BossId"
local FIELD_ID_ATTRIBUTE_NAME = "FieldId"
local DUNGEON_ID_ATTRIBUTE_NAME = "DungeonId"

local ATTACK_ATTRIBUTE_NAME = "Attack"
local ATTACK_COOLDOWN_ATTRIBUTE_NAME = "AttackCooldown"
local DETECT_RANGE_ATTRIBUTE_NAME = "DetectRange"
local ATTACK_RANGE_ATTRIBUTE_NAME = "AttackRange"
local CHASE_RANGE_ATTRIBUTE_NAME = "ChaseRange"
local LEASH_RANGE_ATTRIBUTE_NAME = "LeashRange"
local ASSIST_RADIUS_ATTRIBUTE_NAME = "AssistRadius"
local TARGET_MODE_ATTRIBUTE_NAME = "TargetMode"
local AGGRO_MODE_ATTRIBUTE_NAME = "AggroMode"
local EXP_REWARD_ATTRIBUTE_NAME = "ExpReward"
local AI_ENABLED_ATTRIBUTE_NAME = "AIEnabled"

local CURRENT_DUNGEON_ID_ATTRIBUTE_NAME = "CurrentDungeonId"
local IN_DUNGEON_ATTRIBUTE_NAME = "InDungeon"

local AI_STATS_APPLIED_ATTRIBUTE_NAME = "AIStatsApplied"

local AI_TICK_RATE = 0.2
local HOME_REACHED_DISTANCE = 3
local WORLD_COMBAT_RESET_TIME = 6
local DUNGEON_COMBAT_RESET_TIME = 6

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

local function isAIEnabled(monsterModel: Model): boolean
	local value = monsterModel:GetAttribute(AI_ENABLED_ATTRIBUTE_NAME)
	if typeof(value) == "boolean" then
		return value
	end

	return true
end

local function isDungeonMonster(monsterModel: Model): boolean
	local dungeonId = monsterModel:GetAttribute(DUNGEON_ID_ATTRIBUTE_NAME)
	return typeof(dungeonId) == "string" and dungeonId ~= ""
end

local function isWorldFieldMonster(monsterModel: Model): boolean
	local fieldId = monsterModel:GetAttribute(FIELD_ID_ATTRIBUTE_NAME)
	return typeof(fieldId) == "string" and fieldId ~= ""
end

local function getCombatResetTime(monsterModel: Model): number
	if isDungeonMonster(monsterModel) then
		return DUNGEON_COMBAT_RESET_TIME
	end

	if isWorldFieldMonster(monsterModel) then
		return WORLD_COMBAT_RESET_TIME
	end

	return WORLD_COMBAT_RESET_TIME
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
	monsterModel:SetAttribute(ASSIST_RADIUS_ATTRIBUTE_NAME, monsterData.AssistRadius)
	monsterModel:SetAttribute(TARGET_MODE_ATTRIBUTE_NAME, monsterData.TargetMode)
	monsterModel:SetAttribute(AGGRO_MODE_ATTRIBUTE_NAME, monsterData.AggroMode)

	local firstInit = monsterModel:GetAttribute(AI_STATS_APPLIED_ATTRIBUTE_NAME) ~= true

	humanoid.MaxHealth = monsterData.MaxHP
	humanoid.WalkSpeed = monsterData.WalkSpeed
	humanoid.DisplayName = monsterData.Name

	if firstInit then
		humanoid.Health = monsterData.MaxHP
		monsterModel:SetAttribute(AI_STATS_APPLIED_ATTRIBUTE_NAME, true)
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

	local humanoid, rootPart = getModelParts(monsterModel)
	if humanoid == nil or rootPart == nil then
		return nil
	end

	local state: MonsterState = {
		SpawnPosition = rootPart.Position,
		DamageByPlayer = {},
		LastAttackAt = 0,
		LastCombatAt = 0,
		OriginalWalkSpeed = humanoid.WalkSpeed,
	}

	monsterStates[monsterModel] = state
	return state
end

local function clearMonsterState(monsterModel: Model): ()
	monsterStates[monsterModel] = nil
end

local function getTargetCharacter(monsterModel: Model, player: Player): (Humanoid?, BasePart?)
	local monsterDungeonId = monsterModel:GetAttribute(DUNGEON_ID_ATTRIBUTE_NAME)
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

local function hasAggro(state: MonsterState): boolean
	for _, totalDamage in state.DamageByPlayer do
		if totalDamage > 0 then
			return true
		end
	end

	return false
end

local function selectPassiveTarget(monsterModel: Model, state: MonsterState): Player?
	local _, monsterRoot = getAliveModelParts(monsterModel)
	if monsterRoot == nil then
		return nil
	end

	local chaseRange = math.max(getNumberAttribute(monsterModel, CHASE_RANGE_ATTRIBUTE_NAME, 30), 0)
	local targetMode = getStringAttribute(monsterModel, TARGET_MODE_ATTRIBUTE_NAME, "Nearest")

	if targetMode == "HighestDamage" then
		local bestPlayer: Player? = nil
		local bestDamage = 0
		local bestDistance = math.huge

		for _, player in ipairs(Players:GetPlayers()) do
			local totalDamage = state.DamageByPlayer[player] or 0
			if totalDamage <= 0 then
				continue
			end

			local _, targetRoot = getTargetCharacter(monsterModel, player)
			if targetRoot == nil then
				continue
			end

			local distance = (targetRoot.Position - monsterRoot.Position).Magnitude
			if distance > chaseRange then
				continue
			end

			if totalDamage > bestDamage or (totalDamage == bestDamage and distance < bestDistance) then
				bestPlayer = player
				bestDamage = totalDamage
				bestDistance = distance
			end
		end

		return bestPlayer
	end

	local bestPlayer: Player? = nil
	local bestDistance = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		local totalDamage = state.DamageByPlayer[player] or 0
		if totalDamage <= 0 then
			continue
		end

		local _, targetRoot = getTargetCharacter(monsterModel, player)
		if targetRoot == nil then
			continue
		end

		local distance = (targetRoot.Position - monsterRoot.Position).Magnitude
		if distance > chaseRange then
			continue
		end

		if distance < bestDistance then
			bestPlayer = player
			bestDistance = distance
		end
	end

	return bestPlayer
end

local function selectAutoAggroTarget(monsterModel: Model, state: MonsterState): Player?
	local _, monsterRoot = getAliveModelParts(monsterModel)
	if monsterRoot == nil then
		return nil
	end

	local detectRange = math.max(getNumberAttribute(monsterModel, DETECT_RANGE_ATTRIBUTE_NAME, 30), 0)
	local chaseRange = math.max(getNumberAttribute(monsterModel, CHASE_RANGE_ATTRIBUTE_NAME, detectRange), detectRange)
	local targetMode = getStringAttribute(monsterModel, TARGET_MODE_ATTRIBUTE_NAME, "Nearest")

	if targetMode == "HighestDamage" then
		local bestPlayer: Player? = nil
		local bestDamage = -1
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

	return getNearestPlayerInRange(monsterModel, detectRange)
end

local function selectTarget(monsterModel: Model, state: MonsterState): Player?
	local aggroMode = getStringAttribute(monsterModel, AGGRO_MODE_ATTRIBUTE_NAME, "PassiveCounter")

	if aggroMode == "AutoAggro" then
		return selectAutoAggroTarget(monsterModel, state)
	end

	return selectPassiveTarget(monsterModel, state)
end

local function moveMonsterTo(humanoid: Humanoid, targetPosition: Vector3): ()
	humanoid:MoveTo(targetPosition)
end

local function clearAggro(state: MonsterState): ()
	table.clear(state.DamageByPlayer)
	state.LastCombatAt = 0
end

local function refreshCombatState(state: MonsterState): ()
	state.LastCombatAt = os.clock()
end

local function returnToSpawn(monsterModel: Model, humanoid: Humanoid, rootPart: BasePart, state: MonsterState): ()
	moveMonsterTo(humanoid, state.SpawnPosition)

	if (rootPart.Position - state.SpawnPosition).Magnitude <= HOME_REACHED_DISTANCE then
		if not isDungeonMonster(monsterModel) then
			humanoid.Health = humanoid.MaxHealth
		end

		clearAggro(state)
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
	refreshCombatState(state)
	targetHumanoid:TakeDamage(finalDamage)
	return true
end

local function isSameAggroGroup(sourceMonster: Model, otherMonster: Model): boolean
	local sourceDungeonId = sourceMonster:GetAttribute(DUNGEON_ID_ATTRIBUTE_NAME)
	local otherDungeonId = otherMonster:GetAttribute(DUNGEON_ID_ATTRIBUTE_NAME)

	if typeof(sourceDungeonId) == "string" and sourceDungeonId ~= "" then
		return sourceDungeonId == otherDungeonId
	end

	local sourceFieldId = sourceMonster:GetAttribute(FIELD_ID_ATTRIBUTE_NAME)
	local otherFieldId = otherMonster:GetAttribute(FIELD_ID_ATTRIBUTE_NAME)

	if typeof(sourceFieldId) == "string" and sourceFieldId ~= "" then
		return sourceFieldId == otherFieldId
	end

	return false
end

local function addAggro(monsterModel: Model, player: Player, threat: number): ()
	if threat <= 0 then
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

	state.DamageByPlayer[player] = (state.DamageByPlayer[player] or 0) + threat
	refreshCombatState(state)
end

local function aggroNearbyMonsters(sourceMonster: Model, player: Player): ()
	local assistRadius = math.max(getNumberAttribute(sourceMonster, ASSIST_RADIUS_ATTRIBUTE_NAME, 0), 0)
	if assistRadius <= 0 then
		return
	end

	local _, sourceRoot = getAliveModelParts(sourceMonster)
	if sourceRoot == nil then
		return
	end

	forEachRuntimeMonster(function(otherMonster: Model)
		if otherMonster == sourceMonster then
			return
		end

		if not isAIEnabled(otherMonster) then
			return
		end

		if not hasAttackData(otherMonster) then
			return
		end

		if not isSameAggroGroup(sourceMonster, otherMonster) then
			return
		end

		local _, otherRoot = getAliveModelParts(otherMonster)
		if otherRoot == nil then
			return
		end

		local distance = (otherRoot.Position - sourceRoot.Position).Magnitude
		if distance > assistRadius then
			return
		end

		addAggro(otherMonster, player, 1)
	end)
end

local function updateMonster(monsterModel: Model): ()
	if monsterModel.Parent == nil or not monsterModel:IsDescendantOf(Workspace) then
		clearMonsterState(monsterModel)
		return
	end

	if not isAIEnabled(monsterModel) then
		local state = monsterStates[monsterModel]
		if state ~= nil then
			clearAggro(state)
		end
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

	local aggroMode = getStringAttribute(monsterModel, AGGRO_MODE_ATTRIBUTE_NAME, "PassiveCounter")
	if aggroMode == "PassiveCounter" and not hasAggro(state) then
		if distanceFromSpawn > HOME_REACHED_DISTANCE then
			returnToSpawn(monsterModel, humanoid, rootPart, state)
		end
		return
	end

	if distanceFromSpawn > leashRange then
		returnToSpawn(monsterModel, humanoid, rootPart, state)
		return
	end

	local now = os.clock()
	local combatResetTime = getCombatResetTime(monsterModel)
	if state.LastCombatAt > 0 and now - state.LastCombatAt >= combatResetTime then
		returnToSpawn(monsterModel, humanoid, rootPart, state)
		return
	end

	local targetPlayer = selectTarget(monsterModel, state)
	if targetPlayer == nil then
		if state.LastCombatAt > 0 or distanceFromSpawn > HOME_REACHED_DISTANCE then
			returnToSpawn(monsterModel, humanoid, rootPart, state)
		end
		return
	end

	local _, targetRoot = getTargetCharacter(monsterModel, targetPlayer)
	if targetRoot == nil then
		return
	end

	local distanceToTarget = (targetRoot.Position - rootPart.Position).Magnitude
	if distanceToTarget > chaseRange then
		returnToSpawn(monsterModel, humanoid, rootPart, state)
		return
	end

	refreshCombatState(state)

	if tryAttackTarget(monsterModel, targetPlayer, state) then
		return
	end

	moveMonsterTo(humanoid, targetRoot.Position)
end

function MonsterAIService.RegisterDamage(monsterModel: Model, player: Player, damage: number): ()
	if damage <= 0 then
		return
	end

	addAggro(monsterModel, player, damage)
	aggroNearbyMonsters(monsterModel, player)
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