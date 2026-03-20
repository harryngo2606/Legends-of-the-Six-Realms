--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local EquipmentController = {}

local TEST_WEAPON_ID = "WoodenSword"

local remotesFolder = ReplicatedStorage:WaitForChild("GameRemotes")
local equipWeaponRemote = remotesFolder:WaitForChild("RequestEquipWeapon") :: RemoteEvent

function EquipmentController.Init(): ()

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		if input.KeyCode == Enum.KeyCode.One or input.KeyCode == Enum.KeyCode.KeypadOne then
			equipWeaponRemote:FireServer(TEST_WEAPON_ID)
		elseif input.KeyCode == Enum.KeyCode.Zero or input.KeyCode == Enum.KeyCode.KeypadZero then
			equipWeaponRemote:FireServer("")
		end
	end)

end

return EquipmentController