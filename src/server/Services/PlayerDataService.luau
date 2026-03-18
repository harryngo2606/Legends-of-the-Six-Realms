--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")
local StatsConfig = require(Modules:WaitForChild("StatsConfig"))
local EquipmentConfig = require(Modules:WaitForChild("EquipmentConfig"))

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

local function buildCurrentStats(profile: PlayerData): BaseStats
	local levelStats = StatsConfig.GetStatsForLevel(profile.Level)
	local weaponId = profile.Equipment.WeaponId

	if weaponId == "" then
		return levelStats
	end

	local weapon = EquipmentConfig.GetWeapon(weaponId)
	if weapon == nil then
		return levelStats
	end

	return {
		MaxHP = levelStats.MaxHP + weapon.StatBonus.MaxHP,
		Attack = levelStats.Attack + weapon.StatBonus.Attack,
		Defense = levelStats.Defense + weapon.StatBonus.Defense,
		WalkSpeed = levelStats.WalkSpeed + weapon.StatBonus.WalkSpeed,
	}
end

local function syncProfileToPlayer(player: Player, profile: PlayerData): ()
	player:SetAttribute("Level", profile.Level)
	player:SetAttribute("Exp", profile.Exp)
	player:SetAttribute("ExpNeeded", StatsConfig.GetExpNeeded(profile.Level))

	local weaponId = profile.Equipment.WeaponId
	local weapon = if weaponId ~= "" then EquipmentConfig.GetWeapon(weaponId) else nil

	player:SetAttribute("EquippedWeaponId", weaponId)
	player:SetAttribute("EquippedWeaponName", if weapon ~= nil then weapon.Name else "")

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
	return buildCurrentStats(profile)
end

function PlayerDataService.GetEquippedWeaponId(player: Player): string
	local profile = PlayerDataService.GetOrCreateProfile(player)
	return profile.Equipment.WeaponId
end

function PlayerDataService.EquipWeapon(player: Player, weaponId: string): boolean
	local weapon = EquipmentConfig.GetWeapon(weaponId)
	if weapon == nil then
		return false
	end

	local profile = PlayerDataService.GetOrCreateProfile(player)
	profile.Equipment.WeaponId = weaponId
	syncProfileToPlayer(player, profile)
	return true
end

function PlayerDataService.UnequipWeapon(player: Player): ()
	local profile = PlayerDataService.GetOrCreateProfile(player)
	profile.Equipment.WeaponId = ""
	syncProfileToPlayer(player, profile)
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