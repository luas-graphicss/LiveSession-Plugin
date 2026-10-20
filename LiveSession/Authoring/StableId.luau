local Constants = require(script.Parent.Parent.Core.Constants)

local StableId = {}
StableId.__index = StableId

local ATTRIBUTE = Constants.STABLE_ID_ATTRIBUTE
local PREFIX = Constants.STABLE_ID_PREFIX

function StableId.new()
	return setmetatable({
		counter = 0,
		byId = {},
		idByInstance = setmetatable({}, { __mode = "k" }),
	}, StableId)
end

local function existingId(instance)
	local value = instance:GetAttribute(ATTRIBUTE)
	if type(value) == Constants.TYPE_NAMES.STRING and string.sub(value, 1, #PREFIX) == PREFIX then
		return value
	end
	return nil
end

function StableId:register(instance, id)
	self.byId[id] = instance
	self.idByInstance[instance] = id
	local number = tonumber(string.sub(id, #PREFIX + 1))
	if number and number > self.counter then
		self.counter = number
	end
end

function StableId:assign(instance)
	local id = existingId(instance)
	if not id then
		self.counter += 1
		id = string.format(Constants.STABLE_ID_FORMAT, self.counter)
		instance:SetAttribute(ATTRIBUTE, id)
	end
	self:register(instance, id)
	return id
end

function StableId:adopt(instance, id)
	instance:SetAttribute(ATTRIBUTE, id)
	self:register(instance, id)
end

function StableId:index(instance)
	local id = existingId(instance)
	if id then
		self:register(instance, id)
	end
	return id
end

function StableId:idOf(instance)
	return self.idByInstance[instance] or existingId(instance)
end

function StableId:resolve(id, path)
	local instance = self.byId[id]
	if instance and instance.Parent ~= nil and instance:GetAttribute(ATTRIBUTE) == id then
		return instance
	end
	if type(path) ~= Constants.TYPE_NAMES.STRING then
		return nil
	end
	local found = StableId.resolvePath(path)
	if found == nil then
		return nil
	end
	local foundId = existingId(found)
	if foundId ~= nil and foundId ~= id then
		return nil
	end
	return found
end

function StableId:lookup(id)
	local instance = self.byId[id]
	if instance and instance.Parent ~= nil then
		return instance
	end
	return nil
end

function StableId.resolvePath(path)
	local current = game
	for segment in string.gmatch(path, "[^%.]+") do
		if current == game then
			local ok, service = pcall(game.GetService, game, segment)
			current = ok and service or game:FindFirstChild(segment)
		else
			current = current:FindFirstChild(segment)
		end
		if not current then
			return nil
		end
	end
	return current
end

function StableId:forget(instance)
	local id = self.idByInstance[instance]
	if id then
		self.idByInstance[instance] = nil
		if self.byId[id] == instance then
			self.byId[id] = nil
		end
	end
end

function StableId:clear(instance)
	self:forget(instance)
	if instance:GetAttribute(ATTRIBUTE) ~= nil then
		instance:SetAttribute(ATTRIBUTE, nil)
	end
end

function StableId:resetIndex()
	self.byId = {}
	self.idByInstance = setmetatable({}, { __mode = "k" })
end

return StableId
