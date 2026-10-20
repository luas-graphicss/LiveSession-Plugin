local Constants = require(script.Parent.Parent.Core.Constants)

local EditorAttribution = {}
EditorAttribution.__index = EditorAttribution

local CLASSIFICATIONS = Constants.CLASSIFICATIONS
local ORIGINS = Constants.ORIGINS
local KINEMATIC = Constants.ATTRIBUTION.KINEMATIC_PROPERTIES
local IGNORED = Constants.ATTRIBUTION.IGNORED_PROPERTIES
local ENGINE_CLASSES = Constants.ATTRIBUTION.ENGINE_CLASSES
local ENGINE_NAMES = Constants.ATTRIBUTION.ENGINE_NAMES
local CLASSES = Constants.CLASS_NAMES

function EditorAttribution.new(tracker, touched, isTopContainer, othersPresent)
	return setmetatable({
		tracker = tracker,
		touched = touched,
		isTopContainer = isTopContainer,
		othersPresent = othersPresent,
	}, EditorAttribution)
end

function EditorAttribution:origin()
	return self.othersPresent() and ORIGINS.COLLABORATOR or ORIGINS.STUDIO
end

function EditorAttribution:isHosted(instance)
	local current = instance
	while current and current ~= game do
		if self.tracker:isHostedInstance(current) then
			return true
		end
		current = current.Parent
	end
	return false
end

local function isEngineMade(instance)
	return ENGINE_CLASSES[instance.ClassName] == true or ENGINE_NAMES[instance.Name] == true
end

local function isWritable(instance, property)
	return pcall(function()
		instance[property] = instance[property]
	end)
end

local function isPivotOfBody(instance)
	if not instance:IsA(CLASSES.MODEL) then
		return false
	end
	local primary = instance.PrimaryPart
	return primary ~= nil and not primary.Anchored
end

function EditorAttribution:classifyCreate(instance)
	local parent = instance.Parent
	if isEngineMade(instance) then
		return CLASSIFICATIONS.RUNTIME
	end
	if parent and not self.isTopContainer(parent) and self.touched:isRuntimeTouched(parent) then
		return CLASSIFICATIONS.RUNTIME
	end
	return CLASSIFICATIONS.AUTHORING, self:origin()
end

function EditorAttribution:classifyDestroy(instance)
	if isEngineMade(instance) or self.touched:isRuntimeTree(instance) or self.touched:isUnderBody(instance) then
		return CLASSIFICATIONS.RUNTIME
	end
	return CLASSIFICATIONS.AUTHORING, self:origin()
end

function EditorAttribution:classifyProperty(instance, property)
	if IGNORED[property] or isEngineMade(instance) or self:isHosted(instance) or self.touched:isRuntimeTouched(instance) then
		return CLASSIFICATIONS.RUNTIME
	end
	if KINEMATIC[property]
		and (self.touched:isUnderBody(instance) or self.touched:isRuntimeTree(instance) or isPivotOfBody(instance)) then
		return CLASSIFICATIONS.RUNTIME
	end
	if not isWritable(instance, property) then
		return CLASSIFICATIONS.RUNTIME
	end
	return CLASSIFICATIONS.AUTHORING, self:origin()
end

return EditorAttribution
