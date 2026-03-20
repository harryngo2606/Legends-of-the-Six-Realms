--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local DungeonController = {}

local TEST_DUNGEON_ID = "SlimeDungeon"

local remotesFolder = ReplicatedStorage:WaitForChild("GameRemotes")
local enterDungeonRemote = remotesFolder:WaitForChild("RequestEnterDungeon") :: RemoteEvent
local leaveDungeonRemote = remotesFolder:WaitForChild("RequestLeaveDungeon") :: RemoteEvent

function DungeonController.Init(): ()

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		if input.KeyCode == Enum.KeyCode.F then
			enterDungeonRemote:FireServer(TEST_DUNGEON_ID)
		elseif input.KeyCode == Enum.KeyCode.G then
			leaveDungeonRemote:FireServer()
		end
	end)

end

return DungeonController