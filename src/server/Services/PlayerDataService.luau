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

function PlayerDataService.Init(): ()
	Players.PlayerRemoving:Connect(function(player: Player)
		profiles[player] = nil
	end)
end

function PlayerDataService.CreateProfile(player: Player): PlayerData
	local profile = deepCopy(StatsConfig.DEFAULT_DATA)
	profiles[player] = profile
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
	local profile = PlayerDataService.GetOrCreateProfile(player)
	profile.Exp += amount

	while profile.Exp >= StatsConfig.GetExpNeeded(profile.Level) do
		profile.Exp -= StatsConfig.GetExpNeeded(profile.Level)
		profile.Level += 1
	end
end

return PlayerDataService