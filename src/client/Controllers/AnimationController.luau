--!strict

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")
local AnimationConfig = require(Modules:WaitForChild("AnimationConfig"))

type AnimationSet = AnimationConfig.AnimationSet

type LoadedTracks = {
	TestAction: AnimationTrack?,
}

local AnimationController = {}

local currentTracks: LoadedTracks = {
	TestAction = nil,
}

local inputConnection: RBXScriptConnection? = nil

local function createAnimation(animationId: string): Animation
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	return animation
end

local function stopCurrentTracks(): ()
	for _, track in currentTracks do
		if track ~= nil then
			track:Stop(0.1)
		end
	end

	currentTracks = {
		TestAction = nil,
	}
end

local function loadTracks(character: Model): ()
	stopCurrentTracks()

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local ids: AnimationSet = AnimationConfig.IDS

	if ids.TestAction ~= "" and ids.TestAction ~= "rbxassetid://PUT_YOUR_ANIMATION_ID_HERE" then
		local animation = createAnimation(ids.TestAction)
		currentTracks.TestAction = animator:LoadAnimation(animation)
		currentTracks.TestAction.Priority = Enum.AnimationPriority.Action
	end
end

function AnimationController.PlayTestAction(): ()
	local track = currentTracks.TestAction
	if track == nil then
		return
	end

	track:Play(0.1, 1, 1)
end

function AnimationController.BindCharacter(character: Model): ()
	loadTracks(character)
end

function AnimationController.Init(): ()
	if inputConnection ~= nil then
		inputConnection:Disconnect()
		inputConnection = nil
	end

	inputConnection = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Q then
			AnimationController.PlayTestAction()
		end
	end)

	localPlayer.CharacterAdded:Connect(function(character: Model)
		AnimationController.BindCharacter(character)
	end)

	if localPlayer.Character then
		AnimationController.BindCharacter(localPlayer.Character)
	end
end

return AnimationController