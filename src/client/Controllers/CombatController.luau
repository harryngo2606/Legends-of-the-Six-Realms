--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local CombatController = {}

local remotesFolder = ReplicatedStorage:WaitForChild("GameRemotes")
local basicAttackRemote = remotesFolder:WaitForChild("RequestBasicAttack") :: RemoteEvent

function CombatController.TryBasicAttack(): ()
	basicAttackRemote:FireServer()
end

function CombatController.Init(): ()
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			CombatController.TryBasicAttack()
		end
	end)
end

return CombatController