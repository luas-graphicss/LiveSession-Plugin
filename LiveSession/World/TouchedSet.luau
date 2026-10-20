local Constants = require(script.Parent.Parent.Core.Constants)

local TouchedSet = {}
TouchedSet.__index = TouchedSet

local ATTRIBUTE = Constants.STABLE_ID_ATTRIBUTE
local TEXTS = Constants.TEXTS

function TouchedSet.new(containers)
	local containerSet = {}
	for _, container in ipairs(containers) do
		containerSet[container] = true
	end
	return setmetatable({
		containerSet = containerSet,
		rootIds = {},
		rootCount = 0,
		bodies = {},
		bodyCount = 0,
		runtime = setmetatable({}, { __mode = "k" }),
	}, TouchedSet)
end

function TouchedSet:markRuntime(instance)
	if typeof(instance) ~= Constants.TYPE_NAMES.INSTANCE or self.runtime[instance] then
		return
	end
	self.runtime[instance] = true
	self:mark(instance)
end

function TouchedSet:isRuntimeTouched(instance)
	return self.runtime[instance] == true
end

function TouchedSet:isRuntimeTree(instance)
	local current = instance
	while current and not self.containerSet[current] do
		if self.runtime[current] then
			return true
		end
		current = current.Parent
	end
	return false
end

function TouchedSet:isUnderBody(instance)
	local current = instance
	while current and not self.containerSet[current] do
		if current:IsA(Constants.CLASS_NAMES.BASE_PART) and not current.Anchored then
			return true
		end
		current = current.Parent
	end
	return false
end

function TouchedSet:rootOf(instance)
	local current = instance
	while current do
		local parent = current.Parent
		if parent == nil then
			return nil
		end
		if self.containerSet[parent] then
			return current
		end
		current = parent
	end
	return nil
end

function TouchedSet:mark(instance)
	if typeof(instance) ~= Constants.TYPE_NAMES.INSTANCE then
		return
	end
	local root = self:rootOf(instance)
	local id = root and root:GetAttribute(ATTRIBUTE)
	if type(id) == Constants.TYPE_NAMES.STRING and not self.rootIds[id] then
		self.rootIds[id] = true
		self.rootCount += 1
	end
end

function TouchedSet:registerBody(instance)
	if instance:IsA(Constants.CLASS_NAMES.BASE_PART) and not instance.Anchored and self.bodies[instance] == nil then
		self.bodies[instance] = instance.CFrame
		self.bodyCount += 1
	end
end

function TouchedSet:markMovedBodies(job)
	local visited = 0
	for part, startCFrame in pairs(self.bodies) do
		if part.Parent ~= nil and not part.CFrame:FuzzyEq(startCFrame, Constants.MOVED_BODY_EPSILON) then
			self:mark(part)
		end
		visited += 1
		job.checkpoint(TEXTS.PROGRESS_BODIES, visited, self.bodyCount)
	end
end

function TouchedSet:ids()
	return self.rootIds
end

function TouchedSet:count()
	return self.rootCount
end

return TouchedSet
