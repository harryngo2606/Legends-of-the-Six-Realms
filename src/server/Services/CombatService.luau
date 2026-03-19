--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")

local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local CharacterService = require(script.Parent:WaitForChild("CharacterService"))
local MonsterAIService = require(script.Parent:WaitForChild("MonsterAIService"))

local CombatService = {}

local REMOTES_FOLDER_NAME = "GameRemotes"
local BASIC_ATTACK_REMOTE_NAME = "RequestBasicAttack"
local MONSTERS_FOLDER_NAME = "Monsters"
local TEMPLATES_FOLDER_NAME = "Templates"
local RUNTIME_FOLDER_NAME = "Runtime"
local EXP_REWARD_ATTRIBUTE_NAME = "ExpReward"
local DEFAULT_EXP_REWARD = 10

local playerCooldowns: {[Player]: number} = {}
local lastHitByHumanoid: {[Humanoid]: Player} = {}
local deathConnections: {[Humanoid]: RBXScriptConnection} = {}

local basicAttackRemote: RemoteEvent? = nil

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

local function getOrCreateRemoteEvent(parent: Instance, name: string): RemoteEvent
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local function getAliveCharacterParts(character: Model): (Humanoid?, BasePart?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil, nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return nil, nil
	end

	return humanoid, rootPart
end

local function getAttackCooldown(player: Player): number
	local stats = PlayerDataService.GetCurrentStats(player)
	local attackSpeed = math.max(stats.AttackSpeed, 0.1)
	return CombatConfig.BASIC_ATTACK_COOLDOWN / attackSpeed
end

local function isOnCooldown(player: Player): boolean
	local lastAttackTime = playerCooldowns[player]
	if lastAttackTime == nil then
		return false
	end

	return os.clock() - lastAttackTime < getAttackCooldown(player)
end

local function markAttackUsed(player: Player): ()
	playerCooldowns[player] = os.clock()
end

local function getMonsterExpReward(monsterModel: Model): number
	local value = monsterModel:GetAttribute(EXP_REWARD_ATTRIBUTE_NAME)

	if typeof(value) == "number" and value > 0 then
		return value
	end

	return DEFAULT_EXP_REWARD
end

local function cleanupMonsterTracking(humanoid: Humanoid): ()
	local connection = deathConnections[humanoid]
	if connection ~= nil then
		connection:Disconnect()
		deathConnections[humanoid] = nil
	end

	lastHitByHumanoid[humanoid] = nil
end

local function rewardKill(player: Player, monsterModel: Model): ()
	local profileBefore = PlayerDataService.GetOrCreateProfile(player)
	local previousLevel = profileBefore.Level

	local expReward = getMonsterExpReward(monsterModel)
	PlayerDataService.AddExp(player, expReward)

	CharacterService.SyncPlayerState(player)
	CharacterService.RefreshLeaderstats(player)

	local profileAfter = PlayerDataService.GetOrCreateProfile(player)
	if profileAfter.Level > previousLevel then
		local character = player.Character
		if character ~= nil then
			CharacterService.ApplyStatsToCharacter(player, character)
		end
	end
end

local function bindMonsterDeath(monsterModel: Model, humanoid: Humanoid): ()
	if deathConnections[humanoid] ~= nil then
		return
	end

	deathConnections[humanoid] = humanoid.Died:Connect(function()
		local killer = lastHitByHumanoid[humanoid]
		if killer ~= nil then
			rewardKill(killer, monsterModel)
		end

		cleanupMonsterTracking(humanoid)
	end)
end

local function getMonstersFolder(): Folder?
	local monstersFolder = Workspace:FindFirstChild(MONSTERS_FOLDER_NAME)
	if monstersFolder ~= nil and monstersFolder:IsA("Folder") then
		return monstersFolder
	end

	return nil
end

local function getTemplatesFolder(monstersFolder: Folder): Folder?
	local templatesFolder = monstersFolder:FindFirstChild(TEMPLATES_FOLDER_NAME)
	if templatesFolder ~= nil and templatesFolder:IsA("Folder") then
		return templatesFolder
	end

	return nil
end

local function getRuntimeFolder(monstersFolder: Folder): Folder?
	local runtimeFolder = monstersFolder:FindFirstChild(RUNTIME_FOLDER_NAME)
	if runtimeFolder ~= nil and runtimeFolder:IsA("Folder") then
		return runtimeFolder
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
	if monstersFolder == nil then
		return
	end

	local templatesFolder = getTemplatesFolder(monstersFolder)
	local runtimeFolder = getRuntimeFolder(monstersFolder)

	if runtimeFolder ~= nil then
		for _, descendant in ipairs(runtimeFolder:GetDescendants()) do
			if descendant:IsA("Model") then
				callback(descendant)
			end
		end
		return
	end

	for _, child in ipairs(monstersFolder:GetChildren()) do
		if child:IsA("Model") and not isTemplateDescendant(child, templatesFolder) then
			callback(child)
		end
	end
end

local function findBestTarget(player: Player): Humanoid?
	local character = player.Character
	if character == nil then
		return nil
	end

	local _, attackerRoot = getAliveCharacterParts(character)
	if attackerRoot == nil then
		return nil
	end

	local bestHumanoid: Humanoid? = nil
	local bestDistance = math.huge

	forEachRuntimeMonster(function(candidate: Model)
		local targetHumanoid, targetRoot = getAliveCharacterParts(candidate)
		if targetHumanoid == nil or targetRoot == nil then
			return
		end

		local offset = targetRoot.Position - attackerRoot.Position
		local distance = offset.Magnitude

		if distance > CombatConfig.BASIC_ATTACK_RANGE then
			return
		end

		if distance <= 0 then
			return
		end

		local direction = offset.Unit
		local dot = attackerRoot.CFrame.LookVector:Dot(direction)

		if dot < CombatConfig.BASIC_ATTACK_DOT_THRESHOLD then
			return
		end

		if distance < bestDistance then
			bestDistance = distance
			bestHumanoid = targetHumanoid
			bindMonsterDeath(candidate, targetHumanoid)
		end
	end)

	return bestHumanoid
end

function CombatService.HandleBasicAttack(player: Player): ()
	if isOnCooldown(player) then
		return
	end

	local character = player.Character
	if character == nil then
		return
	end

	local attackerHumanoid, _ = getAliveCharacterParts(character)
	if attackerHumanoid == nil then
		return
	end

	local targetHumanoid = findBestTarget(player)
	if targetHumanoid == nil then
		return
	end

	markAttackUsed(player)
	lastHitByHumanoid[targetHumanoid] = player

	local stats = PlayerDataService.GetCurrentStats(player)
	local damage = math.max(CombatConfig.BASIC_ATTACK_DAMAGE, stats.Attack)

	local targetModel = targetHumanoid.Parent
	if targetModel ~= nil and targetModel:IsA("Model") then
		MonsterAIService.RegisterDamage(targetModel, player, damage)
	end

	targetHumanoid:TakeDamage(damage)
end

function CombatService.Init(): ()
	local remotesFolder = getOrCreateFolder(ReplicatedStorage, REMOTES_FOLDER_NAME)
	basicAttackRemote = getOrCreateRemoteEvent(remotesFolder, BASIC_ATTACK_REMOTE_NAME)

	getOrCreateFolder(Workspace, MONSTERS_FOLDER_NAME)

	basicAttackRemote.OnServerEvent:Connect(function(player: Player)
		CombatService.HandleBasicAttack(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		playerCooldowns[player] = nil

		for humanoid, lastPlayer in lastHitByHumanoid do
			if lastPlayer == player then
				lastHitByHumanoid[humanoid] = nil
			end
		end
	end)
end

return CombatService