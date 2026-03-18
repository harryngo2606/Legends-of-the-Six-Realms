--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")
local EquipmentConfig = require(Modules:WaitForChild("EquipmentConfig"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local CharacterService = require(script.Parent:WaitForChild("CharacterService"))

local EquipmentService = {}

local REMOTES_FOLDER_NAME = "GameRemotes"
local EQUIP_WEAPON_REMOTE_NAME = "RequestEquipWeapon"

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

function EquipmentService.HandleEquipWeapon(player: Player, weaponId: string): ()
	if type(weaponId) ~= "string" then
		return
	end

	if weaponId == "" then
		PlayerDataService.UnequipWeapon(player)
		CharacterService.RefreshPlayer(player)
		return
	end

	local weapon = EquipmentConfig.GetWeapon(weaponId)
	if weapon == nil then
		return
	end

	if PlayerDataService.GetEquippedWeaponId(player) == weaponId then
		return
	end

	local success = PlayerDataService.EquipWeapon(player, weaponId)
	if not success then
		return
	end

	CharacterService.RefreshPlayer(player)
end

function EquipmentService.Init(): ()
	local remotesFolder = getOrCreateFolder(ReplicatedStorage, REMOTES_FOLDER_NAME)
	local equipWeaponRemote = getOrCreateRemoteEvent(remotesFolder, EQUIP_WEAPON_REMOTE_NAME)

	equipWeaponRemote.OnServerEvent:Connect(function(player: Player, weaponId: string)
		EquipmentService.HandleEquipWeapon(player, weaponId)
	end)
end

return EquipmentService