--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")

local FieldConfig = require(Modules:WaitForChild("FieldConfig"))

local FieldService = {}

local WORLD_FOLDER_NAME = "World"
local FIELDS_FOLDER_NAME = "Fields"
local SPAWNS_FOLDER_NAME = "Spawns"

local MONSTERS_FOLDER_NAME = "Monsters"
local TEMPLATES_FOLDER_NAME = "Templates"
local NORMAL_TEMPLATES_FOLDER_NAME = "Normal"
local RUNTIME_FOLDER_NAME = "Runtime"
local WORLD_RUNTIME_FOLDER_NAME = "World"

local FIELD_ID_ATTRIBUTE_NAME = "FieldId"
local MONSTER_ID_ATTRIBUTE_NAME = "MonsterId"
local SPAWN_NAME_ATTRIBUTE_NAME = "SpawnName"
local AI_ENABLED_ATTRIBUTE_NAME = "AIEnabled"

local deathConnections: {[Humanoid]: RBXScriptConnection} = {}
local occupiedSpawnKeys: {[string]: Model} = {}
local respawnPendingBySpawnKey: {[string]: boolean} = {}

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

local function getWorldFolder(): Folder
	return getOrCreateFolder(Workspace, WORLD_FOLDER_NAME)
end

local function getFieldsFolder(): Folder
	local worldFolder = getWorldFolder()
	return getOrCreateFolder(worldFolder, FIELDS_FOLDER_NAME)
end

local function getFieldContainer(fieldId: string): Instance?
	return getFieldsFolder():FindFirstChild(fieldId)
end

local function getFieldSpawnsContainer(fieldId: string): Instance?
	local fieldContainer = getFieldContainer(fieldId)
	if fieldContainer == nil then
		return nil
	end

	local spawnsFolder = fieldContainer:FindFirstChild(SPAWNS_FOLDER_NAME)
	if spawnsFolder ~= nil and spawnsFolder:IsA("Folder") then
		return spawnsFolder
	end

	return fieldContainer
end

local function getFieldSpawnPart(fieldId: string, spawnName: string): BasePart?
	local spawnsContainer = getFieldSpawnsContainer(fieldId)
	if spawnsContainer == nil then
		return nil
	end

	local spawnPart = spawnsContainer:FindFirstChild(spawnName)
	if spawnPart == nil or not spawnPart:IsA("BasePart") then
		return nil
	end

	return spawnPart
end

local function getMonstersFolder(): Folder
	return getOrCreateFolder(Workspace, MONSTERS_FOLDER_NAME)
end

local function getMonsterTemplatesFolder(): Folder
	local monstersFolder = getMonstersFolder()
	return getOrCreateFolder(monstersFolder, TEMPLATES_FOLDER_NAME)
end

local function getNormalTemplatesFolder(): Folder
	local templatesFolder = getMonsterTemplatesFolder()
	return getOrCreateFolder(templatesFolder, NORMAL_TEMPLATES_FOLDER_NAME)
end

local function getMonsterRuntimeFolder(): Folder
	local monstersFolder = getMonstersFolder()
	return getOrCreateFolder(monstersFolder, RUNTIME_FOLDER_NAME)
end

local function getWorldRuntimeFolder(): Folder
	local runtimeFolder = getMonsterRuntimeFolder()
	return getOrCreateFolder(runtimeFolder, WORLD_RUNTIME_FOLDER_NAME)
end

local function getMonsterTemplate(templateName: string): Model?
	local normalTemplatesFolder = getNormalTemplatesFolder()
	local template = normalTemplatesFolder:FindFirstChild(templateName)
	if template ~= nil and template:IsA("Model") then
		return template
	end

	local legacyTemplate = getMonsterTemplatesFolder():FindFirstChild(templateName)
	if legacyTemplate ~= nil and legacyTemplate:IsA("Model") then
		return legacyTemplate
	end

	return nil
end

local function pivotModelToPart(model: Model, targetPart: BasePart): boolean
	local rootPart = model:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		warn(("FieldService: Model '%s' is missing HumanoidRootPart"):format(model.Name))
		return false
	end

	model:PivotTo(targetPart.CFrame + Vector3.new(0, 3, 0))
	return true
end

local function makeSpawnKey(fieldId: string, spawnName: string): string
	return ("%s::%s"):format(fieldId, spawnName)
end

local function cleanupDeathConnection(humanoid: Humanoid): ()
	local connection = deathConnections[humanoid]
	if connection ~= nil then
		connection:Disconnect()
		deathConnections[humanoid] = nil
	end
end

local function scheduleRespawn(fieldId: string, spawnName: string, delaySeconds: number): ()
	local spawnKey = makeSpawnKey(fieldId, spawnName)
	if respawnPendingBySpawnKey[spawnKey] == true then
		return
	end

	respawnPendingBySpawnKey[spawnKey] = true

	task.delay(delaySeconds, function()
		respawnPendingBySpawnKey[spawnKey] = nil
		FieldService.SpawnFieldMonster(fieldId, spawnName)
	end)
end

local function bindFieldMonsterDeath(fieldId: string, spawnName: string, monsterModel: Model): ()
	local humanoid = monsterModel:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		warn(("FieldService: Field monster '%s' has no Humanoid"):format(monsterModel.Name))
		return
	end

	if deathConnections[humanoid] ~= nil then
		return
	end

	deathConnections[humanoid] = humanoid.Died:Connect(function()
		local spawnKey = makeSpawnKey(fieldId, spawnName)
		occupiedSpawnKeys[spawnKey] = nil
		cleanupDeathConnection(humanoid)

		local fieldData = FieldConfig.GetField(fieldId)
		if fieldData == nil then
			return
		end

		scheduleRespawn(fieldId, spawnName, math.max(fieldData.RespawnTime, 0))
	end)
end

function FieldService.SpawnFieldMonster(fieldId: string, spawnName: string): ()
	local fieldData = FieldConfig.GetField(fieldId)
	if fieldData == nil then
		warn(("FieldService: Missing field config for '%s'"):format(fieldId))
		return
	end

	local spawnPart = getFieldSpawnPart(fieldId, spawnName)
	if spawnPart == nil then
		warn(("FieldService: Missing spawn '%s' for field '%s'"):format(spawnName, fieldId))
		return
	end

	local spawnKey = makeSpawnKey(fieldId, spawnName)
	local existingModel = occupiedSpawnKeys[spawnKey]
	if existingModel ~= nil and existingModel.Parent ~= nil then
		return
	end

	local monsterTemplate = getMonsterTemplate(fieldData.MonsterTemplateName)
	if monsterTemplate == nil then
		warn(("FieldService: Missing monster template '%s' for field '%s'"):format(fieldData.MonsterTemplateName, fieldId))
		return
	end

	local monsterClone = monsterTemplate:Clone()
	monsterClone.Name = fieldData.MonsterId
	monsterClone:SetAttribute(FIELD_ID_ATTRIBUTE_NAME, fieldId)
	monsterClone:SetAttribute(MONSTER_ID_ATTRIBUTE_NAME, fieldData.MonsterId)
	monsterClone:SetAttribute(SPAWN_NAME_ATTRIBUTE_NAME, spawnName)
	monsterClone:SetAttribute(AI_ENABLED_ATTRIBUTE_NAME, true)
	monsterClone.Parent = getWorldRuntimeFolder()

	if not pivotModelToPart(monsterClone, spawnPart) then
		monsterClone:Destroy()
		return
	end

	occupiedSpawnKeys[spawnKey] = monsterClone
	bindFieldMonsterDeath(fieldId, spawnName, monsterClone)
end

local function initField(fieldId: string): ()
	local fieldData = FieldConfig.GetField(fieldId)
	if fieldData == nil then
		return
	end

	for _, spawnName in ipairs(fieldData.SpawnNames) do
		FieldService.SpawnFieldMonster(fieldId, spawnName)
	end
end

function FieldService.Init(): ()
	getFieldsFolder()
	getNormalTemplatesFolder()
	getWorldRuntimeFolder()

	for fieldId, _ in pairs(FieldConfig.Fields) do
		initField(fieldId)
	end
end

return FieldService