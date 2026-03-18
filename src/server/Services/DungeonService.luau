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
local DUNGEON_ID_ATTRIBUTE_NAME = "DungeonId"

local DEFAULT_TEST_DUNGEON_ID = "SlimeDungeon"

local currentDungeonByPlayer: {[Player]: string} = {}
local clearedDungeons: {[string]: boolean} = {}
local bossDeathConnections: {[Humanoid]: RBXScriptConnection} = {}

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

local function clearDungeon(dungeonId: string): ()
	if clearedDungeons[dungeonId] == true then
		return
	end

	local dungeonData = DungeonConfig.GetDungeon(dungeonId)
	if dungeonData == nil then
		return
	end

	clearedDungeons[dungeonId] = true

	for _, player in Players:GetPlayers() do
		local currentDungeonId = currentDungeonByPlayer[player]
		if currentDungeonId ~= dungeonId then
			continue
		end

		setPlayerDungeonAttributes(player, dungeonId, true, true)
		rewardDungeonClear(player, dungeonData.ClearExpReward)
	end

	print(("DungeonService: Cleared dungeon '%s'"):format(dungeonId))
end

local function cleanupBossConnection(humanoid: Humanoid): ()
	local connection = bossDeathConnections[humanoid]
	if connection ~= nil then
		connection:Disconnect()
		bossDeathConnections[humanoid] = nil
	end
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

	if monsterModel.Name ~= dungeonData.BossMonsterName then
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

	print(("DungeonService: Bound dungeon boss '%s' for dungeon '%s'"):format(monsterModel.Name, dungeonIdValue))
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
	setPlayerDungeonAttributes(player, targetDungeonId, true, false)

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

	print(("DungeonService: Player '%s' left dungeon '%s'"):format(player.Name, dungeonId))
end

function DungeonService.Init(): ()
	local remotesFolder = getOrCreateFolder(ReplicatedStorage, REMOTES_FOLDER_NAME)
	local enterDungeonRemote = getOrCreateRemoteEvent(remotesFolder, ENTER_DUNGEON_REMOTE_NAME)
	local leaveDungeonRemote = getOrCreateRemoteEvent(remotesFolder, LEAVE_DUNGEON_REMOTE_NAME)

	getOrCreateFolder(Workspace, DUNGEONS_FOLDER_NAME)

	local monstersFolder = getOrCreateFolder(Workspace, MONSTERS_FOLDER_NAME)

	for _, child in monstersFolder:GetChildren() do
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
		currentDungeonByPlayer[player] = nil
	end)
end

return DungeonService