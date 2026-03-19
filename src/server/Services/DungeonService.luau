--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")

local DungeonConfig = require(Modules:WaitForChild("DungeonConfig"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local CharacterService = require(script.Parent:WaitForChild("CharacterService"))

local DungeonService = {}

local REMOTES_FOLDER_NAME = "GameRemotes"
local ENTER_DUNGEON_REMOTE_NAME = "RequestEnterDungeon"
local LEAVE_DUNGEON_REMOTE_NAME = "RequestLeaveDungeon"

local DUNGEONS_FOLDER_NAME = "Dungeons"
local MONSTERS_FOLDER_NAME = "Monsters"
local TEMPLATES_FOLDER_NAME = "Templates"
local DUNGEON_ID_ATTRIBUTE_NAME = "DungeonId"
local BOSS_ID_ATTRIBUTE_NAME = "BossId"
local MONSTER_ID_ATTRIBUTE_NAME = "MonsterId"

local DEFAULT_TEST_DUNGEON_ID = "SlimeDungeon"
local MAX_ATTEMPTS_PER_MOB = 20

local currentDungeonByPlayer: {[Player]: string} = {}
local clearedDungeons: {[string]: boolean} = {}
local bossSpawnedByDungeon: {[string]: boolean} = {}
local bossDeathConnections: {[Humanoid]: RBXScriptConnection} = {}
local mobDeathConnections: {[Humanoid]: RBXScriptConnection} = {}

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

local function setPlayerDungeonAttributes(player: Player, dungeonId: string, inDungeon: boolean, dungeonCleared: boolean): ()
	player:SetAttribute("CurrentDungeonId", dungeonId)
	player:SetAttribute("InDungeon", inDungeon)
	player:SetAttribute("DungeonCleared", dungeonCleared)
end

local function getDungeonContainer(dungeonId: string): Instance?
	local dungeonsFolder = Workspace:FindFirstChild(DUNGEONS_FOLDER_NAME)
	if dungeonsFolder == nil then
		return nil
	end

	return dungeonsFolder:FindFirstChild(dungeonId)
end

local function getDungeonSpawnPart(dungeonId: string, spawnName: string): BasePart?
	local dungeonContainer = getDungeonContainer(dungeonId)
	if dungeonContainer == nil then
		return nil
	end

	local spawnPart = dungeonContainer:FindFirstChild(spawnName)
	if spawnPart == nil or not spawnPart:IsA("BasePart") then
		return nil
	end

	return spawnPart
end

local function getMonstersFolder(): Folder
	return getOrCreateFolder(Workspace, MONSTERS_FOLDER_NAME)
end

local function getMonsterTemplatesFolder(): Folder
	local monstersFolder = getMonstersFolder()
	return getOrCreateFolder(monstersFolder, TEMPLATES_FOLDER_NAME)
end

local function getMonsterTemplate(templateName: string): Model?
	local templatesFolder = getMonsterTemplatesFolder()
	local template = templatesFolder:FindFirstChild(templateName)
	if template == nil or not template:IsA("Model") then
		return nil
	end

	return template
end

local function pivotModelToPart(model: Model, targetPart: BasePart): boolean
	local rootPart = model:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		warn(("DungeonService: Model '%s' is missing HumanoidRootPart"):format(model.Name))
		return false
	end

	model:PivotTo(targetPart.CFrame + Vector3.new(0, 3, 0))
	return true
end

local function pivotModelToPosition(model: Model, position: Vector3): boolean
	local rootPart = model:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		warn(("DungeonService: Model '%s' is missing HumanoidRootPart"):format(model.Name))
		return false
	end

	model:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)))
	return true
end

local function teleportPlayerToPart(player: Player, targetPart: BasePart): boolean
	local character = player.Character
	if character == nil then
		return false
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return false
	end

	character:PivotTo(targetPart.CFrame + Vector3.new(0, 3, 0))
	return true
end

local function rewardDungeonClear(player: Player, clearExpReward: number): ()
	if clearExpReward <= 0 then
		return
	end

	PlayerDataService.AddExp(player, clearExpReward)
	CharacterService.RefreshPlayer(player)
end

local function cleanupBossConnection(humanoid: Humanoid): ()
	local connection = bossDeathConnections[humanoid]
	if connection ~= nil then
		connection:Disconnect()
		bossDeathConnections[humanoid] = nil
	end
end

local function cleanupMobConnection(humanoid: Humanoid): ()
	local connection = mobDeathConnections[humanoid]
	if connection ~= nil then
		connection:Disconnect()
		mobDeathConnections[humanoid] = nil
	end
end

local function hasPlayersInDungeon(dungeonId: string): boolean
	for _, currentDungeonId in pairs(currentDungeonByPlayer) do
		if currentDungeonId == dungeonId then
			return true
		end
	end

	return false
end

local function clearDungeonRuntimeMonsters(dungeonId: string): ()
	local monstersFolder = Workspace:FindFirstChild(MONSTERS_FOLDER_NAME)
	if monstersFolder == nil or not monstersFolder:IsA("Folder") then
		return
	end

	for _, child in monstersFolder:GetChildren() do
		if not child:IsA("Model") then
			continue
		end

		local childDungeonId = child:GetAttribute(DUNGEON_ID_ATTRIBUTE_NAME)
		if childDungeonId ~= dungeonId then
			continue
		end

		local humanoid = child:FindFirstChildOfClass("Humanoid")
		if humanoid ~= nil then
			cleanupBossConnection(humanoid)
			cleanupMobConnection(humanoid)
		end

		child:Destroy()
	end
end

local function resetDungeonRunState(dungeonId: string): ()
	clearDungeonRuntimeMonsters(dungeonId)
	clearedDungeons[dungeonId] = false
	bossSpawnedByDungeon[dungeonId] = false
end

local function clearDungeon(dungeonId: string): ()
	if clearedDungeons[dungeonId] == true then
		return
	end

	local dungeonData = DungeonConfig.GetDungeon(dungeonId)
	if dungeonData == nil then
		return
	end

	clearedDungeons[dungeonId] = true

	for _, player in ipairs(Players:GetPlayers()) do
		local currentDungeonId = currentDungeonByPlayer[player]
		if currentDungeonId ~= dungeonId then
			continue
		end

		setPlayerDungeonAttributes(player, dungeonId, true, true)
		rewardDungeonClear(player, dungeonData.ClearExpReward)
	end

	print(("DungeonService: Cleared dungeon '%s'"):format(dungeonId))
end

local function tryBindDungeonBoss(monsterModel: Model): ()
	local dungeonIdValue = monsterModel:GetAttribute(DUNGEON_ID_ATTRIBUTE_NAME)
	if typeof(dungeonIdValue) ~= "string" or dungeonIdValue == "" then
		return
	end

	local dungeonData = DungeonConfig.GetDungeon(dungeonIdValue)
	if dungeonData == nil then
		return
	end

	local bossIdValue = monsterModel:GetAttribute(BOSS_ID_ATTRIBUTE_NAME)
	if bossIdValue ~= dungeonData.BossId then
		return
	end

	local humanoid = monsterModel:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		warn(("DungeonService: Boss model '%s' has no Humanoid"):format(monsterModel.Name))
		return
	end

	if bossDeathConnections[humanoid] ~= nil then
		return
	end

	bossDeathConnections[humanoid] = humanoid.Died:Connect(function()
		clearDungeon(dungeonIdValue)
		cleanupBossConnection(humanoid)
	end)

	print(("DungeonService: Bound dungeon boss '%s' (%s) for dungeon '%s'"):format(monsterModel.Name, dungeonData.BossId, dungeonIdValue))
end

local function hasAliveDungeonMobs(dungeonId: string): boolean
	local monstersFolder = Workspace:FindFirstChild(MONSTERS_FOLDER_NAME)
	if monstersFolder == nil or not monstersFolder:IsA("Folder") then
		return false
	end

	local dungeonData = DungeonConfig.GetDungeon(dungeonId)
	if dungeonData == nil then
		return false
	end

	for _, child in monstersFolder:GetChildren() do
		if not child:IsA("Model") then
			continue
		end

		local childDungeonId = child:GetAttribute(DUNGEON_ID_ATTRIBUTE_NAME)
		if childDungeonId ~= dungeonId then
			continue
		end

		local childBossId = child:GetAttribute(BOSS_ID_ATTRIBUTE_NAME)
		if childBossId == dungeonData.BossId then
			continue
		end

		local humanoid = child:FindFirstChildOfClass("Humanoid")
		if humanoid ~= nil and humanoid.Health > 0 then
			return true
		end
	end

	return false
end

local function spawnBossForDungeon(dungeonId: string): ()
	if bossSpawnedByDungeon[dungeonId] == true then
		return
	end

	local dungeonData = DungeonConfig.GetDungeon(dungeonId)
	if dungeonData == nil then
		return
	end

	local bossSpawn = getDungeonSpawnPart(dungeonId, dungeonData.BossSpawnName)
	if bossSpawn == nil then
		warn(("DungeonService: Missing boss spawn '%s' for dungeon '%s'"):format(dungeonData.BossSpawnName, dungeonId))
		return
	end

	local bossTemplate = getMonsterTemplate(dungeonData.BossTemplateName)
	if bossTemplate == nil then
		warn(("DungeonService: Missing boss template '%s' for dungeon '%s'"):format(dungeonData.BossTemplateName, dungeonId))
		return
	end

	local bossClone = bossTemplate:Clone()
	bossClone.Name = dungeonData.BossMonsterName
	bossClone:SetAttribute(DUNGEON_ID_ATTRIBUTE_NAME, dungeonId)
	bossClone:SetAttribute(BOSS_ID_ATTRIBUTE_NAME, dungeonData.BossId)

	if not pivotModelToPart(bossClone, bossSpawn) then
		bossClone:Destroy()
		return
	end

	bossClone.Parent = getMonstersFolder()
	tryBindDungeonBoss(bossClone)

	bossSpawnedByDungeon[dungeonId] = true

	print(("DungeonService: Spawned boss '%s' (%s) for dungeon '%s'"):format(bossClone.Name, dungeonData.BossId, dungeonId))
end

local function getXZDistance(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function isFarEnough(position: Vector3, placedPositions: {Vector3}, minSpacing: number): boolean
	for _, placedPosition in ipairs(placedPositions) do
		if getXZDistance(position, placedPosition) < minSpacing then
			return false
		end
	end

	return true
end

local function getRandomPointAround(center: Vector3, radius: number): Vector3
	local angle = math.random() * math.pi * 2
	local distance = math.sqrt(math.random()) * radius
	local offsetX = math.cos(angle) * distance
	local offsetZ = math.sin(angle) * distance

	return Vector3.new(center.X + offsetX, center.Y, center.Z + offsetZ)
end

local function bindDungeonMob(monsterModel: Model): ()
	local dungeonIdValue = monsterModel:GetAttribute(DUNGEON_ID_ATTRIBUTE_NAME)
	if typeof(dungeonIdValue) ~= "string" or dungeonIdValue == "" then
		return
	end

	local humanoid = monsterModel:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		warn(("DungeonService: Dungeon mob '%s' has no Humanoid"):format(monsterModel.Name))
		return
	end

	if mobDeathConnections[humanoid] ~= nil then
		return
	end

	mobDeathConnections[humanoid] = humanoid.Died:Connect(function()
		cleanupMobConnection(humanoid)

		task.defer(function()
			if clearedDungeons[dungeonIdValue] == true then
				return
			end

			if bossSpawnedByDungeon[dungeonIdValue] == true then
				return
			end

			if hasAliveDungeonMobs(dungeonIdValue) then
				return
			end

			spawnBossForDungeon(dungeonIdValue)
		end)
	end)
end

local function spawnDungeonMobs(dungeonId: string): ()
	local dungeonData = DungeonConfig.GetDungeon(dungeonId)
	if dungeonData == nil then
		return
	end

	local monsterSpawn = getDungeonSpawnPart(dungeonId, dungeonData.MonsterSpawnName)
	if monsterSpawn == nil then
		warn(("DungeonService: Missing monster spawn '%s' for dungeon '%s'"):format(dungeonData.MonsterSpawnName, dungeonId))
		return
	end

	local monsterTemplate = getMonsterTemplate(dungeonData.MonsterTemplateName)
	if monsterTemplate == nil then
		warn(("DungeonService: Missing monster template '%s' for dungeon '%s'"):format(dungeonData.MonsterTemplateName, dungeonId))
		return
	end

	resetDungeonRunState(dungeonId)

	local placedPositions: {Vector3} = {}
	local spawnCount = 0
	local targetCount = math.max(dungeonData.MonsterCount, 0)
	local spreadRadius = math.max(dungeonData.MonsterSpreadRadius, 0)
	local minSpacing = math.max(dungeonData.MonsterMinSpacing, 0)
	local spawnCenter = monsterSpawn.Position

	for _ = 1, targetCount do
		local chosenPosition: Vector3? = nil

		for _ = 1, MAX_ATTEMPTS_PER_MOB do
			local candidate = getRandomPointAround(spawnCenter, spreadRadius)
			if isFarEnough(candidate, placedPositions, minSpacing) then
				chosenPosition = candidate
				break
			end
		end

		if chosenPosition == nil then
			warn(("DungeonService: Could not find valid spawn position for dungeon '%s'"):format(dungeonId))
			continue
		end

		local monsterClone = monsterTemplate:Clone()
		monsterClone.Name = dungeonData.MonsterId
		monsterClone:SetAttribute(DUNGEON_ID_ATTRIBUTE_NAME, dungeonId)
		monsterClone:SetAttribute(MONSTER_ID_ATTRIBUTE_NAME, dungeonData.MonsterId)

		if not pivotModelToPosition(monsterClone, chosenPosition) then
			monsterClone:Destroy()
			continue
		end

		monsterClone.Parent = getMonstersFolder()

		table.insert(placedPositions, chosenPosition)
		bindDungeonMob(monsterClone)
		spawnCount += 1
	end

	if spawnCount <= 0 then
		warn(("DungeonService: No dungeon mobs spawned for '%s'"):format(dungeonId))
		return
	end

	print(("DungeonService: Spawned %d dungeon mobs for '%s'"):format(spawnCount, dungeonId))
end

function DungeonService.HandleEnterDungeon(player: Player, dungeonId: string?): ()
	local targetDungeonId = dungeonId
	if typeof(targetDungeonId) ~= "string" or targetDungeonId == "" then
		targetDungeonId = DEFAULT_TEST_DUNGEON_ID
	end

	local dungeonData = DungeonConfig.GetDungeon(targetDungeonId)
	if dungeonData == nil then
		warn(("DungeonService: Invalid dungeon id '%s'"):format(targetDungeonId))
		return
	end

	local enterSpawn = getDungeonSpawnPart(targetDungeonId, dungeonData.EnterSpawnName)
	if enterSpawn == nil then
		warn(("DungeonService: Missing EnterSpawn for dungeon '%s'"):format(targetDungeonId))
		return
	end

	local teleported = teleportPlayerToPart(player, enterSpawn)
	if not teleported then
		return
	end

	currentDungeonByPlayer[player] = targetDungeonId
	setPlayerDungeonAttributes(player, targetDungeonId, true, clearedDungeons[targetDungeonId] == true)

	if not hasAliveDungeonMobs(targetDungeonId) and bossSpawnedByDungeon[targetDungeonId] ~= true and clearedDungeons[targetDungeonId] ~= true then
		spawnDungeonMobs(targetDungeonId)
	end

	print(("DungeonService: Player '%s' entered dungeon '%s'"):format(player.Name, targetDungeonId))
end

function DungeonService.HandleLeaveDungeon(player: Player): ()
	local dungeonId = currentDungeonByPlayer[player]
	if dungeonId == nil then
		return
	end

	local dungeonData = DungeonConfig.GetDungeon(dungeonId)
	if dungeonData == nil then
		currentDungeonByPlayer[player] = nil
		setPlayerDungeonAttributes(player, "", false, false)
		return
	end

	local exitSpawn = getDungeonSpawnPart(dungeonId, dungeonData.ExitSpawnName)
	if exitSpawn ~= nil then
		teleportPlayerToPart(player, exitSpawn)
	end

	currentDungeonByPlayer[player] = nil
	setPlayerDungeonAttributes(player, "", false, false)

	if not hasPlayersInDungeon(dungeonId) then
		resetDungeonRunState(dungeonId)
	end

	print(("DungeonService: Player '%s' left dungeon '%s'"):format(player.Name, dungeonId))
end

function DungeonService.Init(): ()
	local remotesFolder = getOrCreateFolder(ReplicatedStorage, REMOTES_FOLDER_NAME)
	local enterDungeonRemote = getOrCreateRemoteEvent(remotesFolder, ENTER_DUNGEON_REMOTE_NAME)
	local leaveDungeonRemote = getOrCreateRemoteEvent(remotesFolder, LEAVE_DUNGEON_REMOTE_NAME)

	getOrCreateFolder(Workspace, DUNGEONS_FOLDER_NAME)

	local monstersFolder = getMonstersFolder()
	getMonsterTemplatesFolder()

	for _, child in ipairs(monstersFolder:GetChildren()) do
		if child:IsA("Model") then
			tryBindDungeonBoss(child)
		end
	end

	monstersFolder.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Model") then
			task.defer(function()
				tryBindDungeonBoss(child)
			end)
		end
	end)

	enterDungeonRemote.OnServerEvent:Connect(function(player: Player, dungeonId: string?)
		DungeonService.HandleEnterDungeon(player, dungeonId)
	end)

	leaveDungeonRemote.OnServerEvent:Connect(function(player: Player)
		DungeonService.HandleLeaveDungeon(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		local dungeonId = currentDungeonByPlayer[player]
		currentDungeonByPlayer[player] = nil

		if dungeonId ~= nil and not hasPlayersInDungeon(dungeonId) then
			resetDungeonRunState(dungeonId)
		end
	end)
end

return DungeonService