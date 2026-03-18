--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local DungeonController = {}

local TEST_DUNGEON_ID = "SlimeDungeon"

local remotesFolder = ReplicatedStorage:WaitForChild("GameRemotes")
local enterDungeonRemote = remotesFolder:WaitForChild("RequestEnterDungeon") :: RemoteEvent
local leaveDungeonRemote = remotesFolder:WaitForChild("RequestLeaveDungeon") :: RemoteEvent

function DungeonController.Init(): ()
	print("Client: DungeonController.Init start")

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		if input.KeyCode == Enum.KeyCode.F then
			print("Client: Request enter dungeon", TEST_DUNGEON_ID)
			enterDungeonRemote:FireServer(TEST_DUNGEON_ID)
		elseif input.KeyCode == Enum.KeyCode.G then
			print("Client: Request leave dungeon")
			leaveDungeonRemote:FireServer()
		end
	end)

	print("Client: DungeonController.Init connected")
end

return DungeonController