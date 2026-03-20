--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")
local AnimationConfig = require(Modules:WaitForChild("AnimationConfig"))

local AnimationController = {}

local currentTrack: AnimationTrack? = nil
local currentAnimator: Animator? = nil

local function loadRightPunchTrack(character: Model)
	currentTrack = nil
	currentAnimator = nil

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		warn("AnimationController: Humanoid not found")
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	currentAnimator = animator

	local animationId = AnimationConfig.IDS.RightPunch
	if type(animationId) ~= "string" or animationId == "" then
		warn("AnimationController: RightPunch animation id missing")
		return
	end

	local animation = Instance.new("Animation")
	animation.Name = "RightPunch"
	animation.AnimationId = animationId

	local ok, trackOrError = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if not ok then
		warn("AnimationController: failed to load animation track:", trackOrError)
		return
	end

	currentTrack = trackOrError :: AnimationTrack
	currentTrack.Priority = Enum.AnimationPriority.Action
end

local function onCharacterAdded(character: Model)
	loadRightPunchTrack(character)
end

function AnimationController.PlayRightPunch()
	if currentTrack == nil then
		return
	end

	if currentTrack.IsPlaying then
		currentTrack:Stop(0.05)
	end

	currentTrack:Play(0.05, 1, 1)
end

function AnimationController.Init()

	if localPlayer.Character then
		onCharacterAdded(localPlayer.Character)
	end

	localPlayer.CharacterAdded:Connect(onCharacterAdded)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		if input.KeyCode == Enum.KeyCode.Q then
			AnimationController.PlayRightPunch()
		end
	end)
end

return AnimationController