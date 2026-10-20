local Constants = require(script.Parent.Parent.Core.Constants)

local LiveSessionApi = {}
LiveSessionApi.__index = LiveSessionApi

local TYPES = Constants.TYPE_NAMES

function LiveSessionApi.new(tracker, onCallbackError)
	return setmetatable({
		tracker = tracker,
		onCallbackError = onCallbackError,
		preserved = {},
		callbacks = setmetatable({}, { __mode = "k" }),
	}, LiveSessionApi)
end

function LiveSessionApi:preserve(key, initializer)
	if type(key) ~= TYPES.STRING then
		error(Constants.ERRORS.PRESERVE_KEY, 3)
	end
	if type(initializer) ~= TYPES.FUNCTION then
		error(Constants.ERRORS.PRESERVE_INITIALIZER, 3)
	end
	local slot = self.preserved[key]
	if not slot then
		slot = { value = initializer() }
		self.preserved[key] = slot
	end
	return slot.value
end

function LiveSessionApi:onReload(owner, callback)
	if type(callback) ~= TYPES.FUNCTION then
		error(Constants.ERRORS.ON_RELOAD_CALLBACK, 3)
	end
	local list = self.callbacks[owner]
	if not list then
		list = {}
		self.callbacks[owner] = list
	end
	table.insert(list, callback)
end

function LiveSessionApi:build(fallbackOwner)
	return setmetatable({
		preserve = function(key, initializer)
			return self:preserve(key, initializer)
		end,
		onReload = function(callback)
			self:onReload(self.tracker:currentOwner() or fallbackOwner, callback)
		end,
	}, { __metatable = Constants.LOCKED_METATABLE_MESSAGE })
end

function LiveSessionApi:beforeRelease(owner)
	local list = self.callbacks[owner]
	if not list then
		return
	end
	self.callbacks[owner] = nil
	for index = #list, 1, -1 do
		local ok, err = pcall(list[index])
		if not ok then
			self.onCallbackError(owner, err)
		end
	end
end

function LiveSessionApi:clear()
	self.preserved = {}
	self.callbacks = setmetatable({}, { __mode = "k" })
end

return LiveSessionApi
