--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")
local StatsConfig = require(Modules:WaitForChild("StatsConfig"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

type BaseStats = StatsConfig.BaseStats

local CharacterService = {}

local function getOrCreateStatsFolder(character: Model): Folder
	local existing = character:FindFirstChild("Stats")
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = "Stats"
	folder.Parent = character
	return folder
end

local function setNumberValue(parent: Instance, name: string, value: number): ()
	local existing = parent:FindFirstChild(name)

	if existing == nil then
		local object = Instance.new("NumberValue")
		object.Name = name
		object.Value = value
		object.Parent = parent
		return
	end

	if existing:IsA("NumberValue") then
		existing.Value = value
	end
end

function CharacterService.CreateLeaderstats(player: Player): ()
	local existing = player:FindFirstChild("leaderstats")
	if existing then
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local levelValue = Instance.new("IntValue")
	levelValue.Name = "Level"
	levelValue.Value = 1
	levelValue.Parent = leaderstats
end

function CharacterService.SyncPlayerState(player: Player): ()
	local profile = PlayerDataService.GetOrCreateProfile(player)

	player:SetAttribute("Level", profile.Level)
	player:SetAttribute("Exp", profile.Exp)
	player:SetAttribute("ExpNeeded", StatsConfig.GetExpNeeded(profile.Level))
end

function CharacterService.RefreshLeaderstats(player: Player): ()
	local profile = PlayerDataService.GetOrCreateProfile(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats == nil then
		return
	end

	local levelValue = leaderstats:FindFirstChild("Level")
	if levelValue and levelValue:IsA("IntValue") then
		levelValue.Value = profile.Level
	end
end

function CharacterService.ApplyStatsToCharacter(player: Player, character: Model): ()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end

	local stats: BaseStats = PlayerDataService.GetCurrentStats(player)

	humanoid.MaxHealth = stats.MaxHP
	humanoid.Health = stats.MaxHP
	humanoid.WalkSpeed = stats.WalkSpeed

	local statsFolder = getOrCreateStatsFolder(character)
	setNumberValue(statsFolder, "MaxHP", stats.MaxHP)
	setNumberValue(statsFolder, "Attack", stats.Attack)
	setNumberValue(statsFolder, "Defense", stats.Defense)
end

function CharacterService.SetupPlayer(player: Player): ()
	PlayerDataService.GetOrCreateProfile(player)
	CharacterService.CreateLeaderstats(player)
	CharacterService.RefreshLeaderstats(player)
	CharacterService.SyncPlayerState(player)

	player.CharacterAdded:Connect(function(character: Model)
		CharacterService.ApplyStatsToCharacter(player, character)
	end)

	if player.Character then
		CharacterService.ApplyStatsToCharacter(player, player.Character)
	end
end

function CharacterService.Init(): ()
	for _, player in Players:GetPlayers() do
		CharacterService.SetupPlayer(player)
	end

	Players.PlayerAdded:Connect(function(player: Player)
		CharacterService.SetupPlayer(player)
	end)
end

return CharacterService