--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local EquipmentController = {}

local TEST_WEAPON_ID = "WoodenSword"

local remotesFolder = ReplicatedStorage:WaitForChild("GameRemotes")
local equipWeaponRemote = remotesFolder:WaitForChild("RequestEquipWeapon") :: RemoteEvent

function EquipmentController.Init(): ()
	print("Client: EquipmentController.Init start")

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		if input.KeyCode == Enum.KeyCode.One then
			print("Client: Equip test weapon", TEST_WEAPON_ID)
			equipWeaponRemote:FireServer(TEST_WEAPON_ID)
		elseif input.KeyCode == Enum.KeyCode.Zero then
			print("Client: Unequip weapon")
			equipWeaponRemote:FireServer("")
		end
	end)

	print("Client: EquipmentController.Init connected")
end

return EquipmentController