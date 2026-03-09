--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))

local localPlayer = Players.LocalPlayer

local CombatController = {}

local remotesFolder = ReplicatedStorage:WaitForChild("GameRemotes")
local basicAttackRemote = remotesFolder:WaitForChild("RequestBasicAttack") :: RemoteEvent

local nextAttackTime = 0

function CombatController.TryBasicAttack(): ()
	local now = os.clock()

	if now < nextAttackTime then
		return
	end

	nextAttackTime = now + CombatConfig.BASIC_ATTACK_COOLDOWN
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