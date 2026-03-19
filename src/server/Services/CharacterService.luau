--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")
local StatsConfig = require(Modules:WaitForChild("StatsConfig"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

type BaseStats = StatsConfig.BaseStats
type CoreStats = StatsConfig.CoreStats

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

local function getPlayerMana(player: Player, maxMana: number): number
	local manaAttribute = player:GetAttribute("Mana")
	if typeof(manaAttribute) ~= "number" then
		return maxMana
	end

	return math.clamp(manaAttribute, 0, maxMana)
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
	local coreStats: CoreStats = PlayerDataService.GetCoreStats(player)
	local currentStats: BaseStats = PlayerDataService.GetCurrentStats(player)

	player:SetAttribute("Level", profile.Level)
	player:SetAttribute("Exp", profile.Exp)
	player:SetAttribute("ExpNeeded", StatsConfig.GetExpNeeded(profile.Level))

	player:SetAttribute("STR", coreStats.STR)
	player:SetAttribute("AGI", coreStats.AGI)
	player:SetAttribute("HP", coreStats.HP)
	player:SetAttribute("MP", coreStats.MP)

	player:SetAttribute("MaxHP", currentStats.MaxHP)
	player:SetAttribute("MaxMana", currentStats.MaxMana)
	player:SetAttribute("Attack", currentStats.Attack)
	player:SetAttribute("AttackSpeed", currentStats.AttackSpeed)
	player:SetAttribute("Defense", currentStats.Defense)
	player:SetAttribute("WalkSpeed", currentStats.WalkSpeed)

	local currentMana = getPlayerMana(player, currentStats.MaxMana)
	player:SetAttribute("Mana", currentMana)
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

	local coreStats: CoreStats = PlayerDataService.GetCoreStats(player)
	local stats: BaseStats = PlayerDataService.GetCurrentStats(player)

	humanoid.MaxHealth = stats.MaxHP
	humanoid.Health = math.min(humanoid.Health > 0 and humanoid.Health or stats.MaxHP, stats.MaxHP)
	humanoid.WalkSpeed = stats.WalkSpeed

	local currentMana = getPlayerMana(player, stats.MaxMana)
	player:SetAttribute("Mana", currentMana)

	local statsFolder = getOrCreateStatsFolder(character)
	setNumberValue(statsFolder, "STR", coreStats.STR)
	setNumberValue(statsFolder, "AGI", coreStats.AGI)
	setNumberValue(statsFolder, "HP", coreStats.HP)
	setNumberValue(statsFolder, "MP", coreStats.MP)

	setNumberValue(statsFolder, "MaxHP", stats.MaxHP)
	setNumberValue(statsFolder, "MaxMana", stats.MaxMana)
	setNumberValue(statsFolder, "Mana", currentMana)
	setNumberValue(statsFolder, "WalkSpeed", stats.WalkSpeed)
	setNumberValue(statsFolder, "Attack", stats.Attack)
	setNumberValue(statsFolder, "AttackSpeed", stats.AttackSpeed)
	setNumberValue(statsFolder, "Defense", stats.Defense)
end

function CharacterService.RefreshPlayer(player: Player): ()
	CharacterService.RefreshLeaderstats(player)
	CharacterService.SyncPlayerState(player)

	local character = player.Character
	if character ~= nil then
		CharacterService.ApplyStatsToCharacter(player, character)
	end
end

function CharacterService.SetupPlayer(player: Player): ()
	PlayerDataService.GetOrCreateProfile(player)
	CharacterService.CreateLeaderstats(player)
	CharacterService.RefreshPlayer(player)

	player.CharacterAdded:Connect(function(character: Model)
		local maxManaAttribute = player:GetAttribute("MaxMana")
		local maxMana = if typeof(maxManaAttribute) == "number" then maxManaAttribute else 0
		player:SetAttribute("Mana", maxMana)

		CharacterService.ApplyStatsToCharacter(player, character)
	end)
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