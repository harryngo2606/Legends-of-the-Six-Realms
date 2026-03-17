--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")
local StatsConfig = require(Modules:WaitForChild("StatsConfig"))

type BaseStats = StatsConfig.BaseStats
type PlayerData = StatsConfig.PlayerData

local PlayerDataService = {}

local profiles: {[Player]: PlayerData} = {}

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end

	local copy = table.clone(value :: any)

	for key, innerValue in copy do
		if type(innerValue) == "table" then
			copy[key] = deepCopy(innerValue)
		end
	end

	return copy
end

local function syncProfileToPlayer(player: Player, profile: PlayerData): ()
	player:SetAttribute("Level", profile.Level)
	player:SetAttribute("Exp", profile.Exp)
	player:SetAttribute("ExpNeeded", StatsConfig.GetExpNeeded(profile.Level))

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats ~= nil then
		local levelValue = leaderstats:FindFirstChild("Level")
		if levelValue ~= nil and levelValue:IsA("IntValue") then
			levelValue.Value = profile.Level
		end
	end
end

function PlayerDataService.Init(): ()
	Players.PlayerRemoving:Connect(function(player: Player)
		profiles[player] = nil
	end)
end

function PlayerDataService.CreateProfile(player: Player): PlayerData
	local profile = deepCopy(StatsConfig.DEFAULT_DATA)
	profiles[player] = profile
	syncProfileToPlayer(player, profile)
	return profile
end

function PlayerDataService.GetProfile(player: Player): PlayerData?
	return profiles[player]
end

function PlayerDataService.GetOrCreateProfile(player: Player): PlayerData
	local profile = profiles[player]
	if profile ~= nil then
		return profile
	end

	return PlayerDataService.CreateProfile(player)
end

function PlayerDataService.GetCurrentStats(player: Player): BaseStats
	local profile = PlayerDataService.GetOrCreateProfile(player)
	return StatsConfig.GetStatsForLevel(profile.Level)
end

function PlayerDataService.AddExp(player: Player, amount: number): ()
	if amount <= 0 then
		return
	end

	local profile = PlayerDataService.GetOrCreateProfile(player)
	profile.Exp += amount

	while profile.Exp >= StatsConfig.GetExpNeeded(profile.Level) do
		profile.Exp -= StatsConfig.GetExpNeeded(profile.Level)
		profile.Level += 1
	end

	syncProfileToPlayer(player, profile)
end

return PlayerDataService