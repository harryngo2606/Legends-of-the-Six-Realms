--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local CombatController = {}

local remotesFolder = ReplicatedStorage:WaitForChild("GameRemotes")
local basicAttackRemote = remotesFolder:WaitForChild("RequestBasicAttack") :: RemoteEvent

print("Client: CombatController module loaded")

function CombatController.TryBasicAttack(): ()
	print("Client: TryBasicAttack -> FireServer")
	basicAttackRemote:FireServer()
end

function CombatController.Init(): ()
	print("Client: CombatController.Init start")

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		print("Client: InputBegan", input.UserInputType.Name, "processed =", gameProcessed)

		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			print("Client: MouseButton1 detected")
			CombatController.TryBasicAttack()
		end
	end)

	print("Client: CombatController.Init connected")
end

return CombatController