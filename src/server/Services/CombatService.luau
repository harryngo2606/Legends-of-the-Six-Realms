--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")

local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local CombatService = {}

local REMOTES_FOLDER_NAME = "GameRemotes"
local BASIC_ATTACK_REMOTE_NAME = "RequestBasicAttack"
local TEST_TARGETS_FOLDER_NAME = "TestTargets"

local playerCooldowns: {[Player]: number} = {}
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

local function isOnCooldown(player: Player): boolean
	local lastAttackTime = playerCooldowns[player]
	if lastAttackTime == nil then
		return false
	end

	return os.clock() - lastAttackTime < CombatConfig.BASIC_ATTACK_COOLDOWN
end

local function markAttackUsed(player: Player): ()
	playerCooldowns[player] = os.clock()
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

	local targetsFolder = Workspace:FindFirstChild(TEST_TARGETS_FOLDER_NAME)
	if targetsFolder == nil or not targetsFolder:IsA("Folder") then
		return nil
	end

	local bestHumanoid: Humanoid? = nil
	local bestDistance = math.huge

	for _, candidate in targetsFolder:GetChildren() do
		if not candidate:IsA("Model") then
			continue
		end

		local targetHumanoid, targetRoot = getAliveCharacterParts(candidate)
		if targetHumanoid == nil or targetRoot == nil then
			continue
		end

		local offset = targetRoot.Position - attackerRoot.Position
		local distance = offset.Magnitude

		if distance > CombatConfig.BASIC_ATTACK_RANGE then
			continue
		end

		if distance <= 0 then
			continue
		end

		local direction = offset.Unit
		local dot = attackerRoot.CFrame.LookVector:Dot(direction)

		if dot < CombatConfig.BASIC_ATTACK_DOT_THRESHOLD then
			continue
		end

		if distance < bestDistance then
			bestDistance = distance
			bestHumanoid = targetHumanoid
		end
	end

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

	local stats = PlayerDataService.GetCurrentStats(player)
	local damage = math.max(CombatConfig.BASIC_ATTACK_DAMAGE, stats.Attack)

	targetHumanoid:TakeDamage(damage)
end

function CombatService.Init(): ()
	local remotesFolder = getOrCreateFolder(ReplicatedStorage, REMOTES_FOLDER_NAME)
	basicAttackRemote = getOrCreateRemoteEvent(remotesFolder, BASIC_ATTACK_REMOTE_NAME)

	getOrCreateFolder(Workspace, TEST_TARGETS_FOLDER_NAME)

	basicAttackRemote.OnServerEvent:Connect(function(player: Player)
		CombatService.HandleBasicAttack(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		playerCooldowns[player] = nil
	end)
end

return CombatService