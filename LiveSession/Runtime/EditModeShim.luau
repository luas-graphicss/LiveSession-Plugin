local Constants = require(script.Parent.Parent.Core.Constants)
local HostedSignal = require(script.Parent.HostedSignal)

local EditModeShim = {}
EditModeShim.__index = EditModeShim

local SHIM = Constants.EDIT_MODE_SHIM
local TYPES = Constants.TYPE_NAMES

local function noOp()
	return nil
end

local function constantMethod(value)
	return function()
		return value
	end
end

local function valueMethod(value)
	if type(value) == TYPES.TABLE then
		return function()
			return table.clone(value)
		end
	end
	return constantMethod(value)
end

local function passthroughMethod(_, first)
	return first
end

local function guardedMethod(proxy, service, name, fallback)
	local method = service[name]
	return function(_, ...)
		local ok, value = pcall(method, service, proxy:unwrapArguments(table.pack(...)))
		if ok then
			return proxy:wrap(value)
		end
		return fallback()
	end
end

local function silentFallback(service)
	return {
		read = function(key)
			local ok, member = pcall(function()
				return service[key]
			end)
			if ok and typeof(member) == TYPES.FUNCTION then
				return true, noOp
			end
			return false, nil
		end,
		write = function()
			return true
		end,
	}
end

function EditModeShim.new(proxy, tracker, localeId)
	return setmetatable({
		proxy = proxy,
		tracker = tracker,
		localeId = localeId,
		closeCallbacks = {},
		serviceGetters = {},
		serviceSignals = {},
	}, EditModeShim)
end

function EditModeShim:gettersFor(serviceName)
	local getters = self.serviceGetters[serviceName]
	if not getters then
		getters = {}
		self.serviceGetters[serviceName] = getters
	end
	return getters
end

function EditModeShim:signalsFor(serviceName)
	local signals = self.serviceSignals[serviceName]
	if not signals then
		signals = {}
		self.serviceSignals[serviceName] = signals
	end
	return signals
end

function EditModeShim:installCloseBinding()
	self.proxy:override(game, {
		[SHIM.BIND_TO_CLOSE] = function()
			return function(_, callback)
				table.insert(self.closeCallbacks, callback)
			end
		end,
	})
end

function EditModeShim:collectGuardedMethods()
	for serviceName, defaults in pairs(SHIM.SERVICE_GUARDED_DEFAULTS) do
		local service = game:GetService(serviceName)
		local getters = self:gettersFor(serviceName)
		for name, default in pairs(defaults) do
			getters[name] = constantMethod(guardedMethod(self.proxy, service, name, valueMethod(default)))
		end
	end
end

function EditModeShim:collectServiceMembers()
	for serviceName, names in pairs(SHIM.SERVICE_NO_OP_METHODS) do
		local getters = self:gettersFor(serviceName)
		for _, name in ipairs(names) do
			getters[name] = constantMethod(noOp)
		end
	end
	for serviceName, names in pairs(SHIM.SERVICE_PASSTHROUGH_METHODS) do
		local getters = self:gettersFor(serviceName)
		for _, name in ipairs(names) do
			getters[name] = constantMethod(passthroughMethod)
		end
	end
	for serviceName, values in pairs(SHIM.SERVICE_CONSTANT_METHODS) do
		local getters = self:gettersFor(serviceName)
		for name, value in pairs(values) do
			getters[name] = constantMethod(valueMethod(value))
		end
	end
	for serviceName, names in pairs(SHIM.SERVICE_SIGNALS) do
		local getters = self:gettersFor(serviceName)
		local signals = self:signalsFor(serviceName)
		for _, name in ipairs(names) do
			local signal = HostedSignal.new(self.tracker)
			signals[name] = signal
			getters[name] = function()
				return signal:interface()
			end
		end
	end
	for serviceName, methods in pairs(SHIM.SERVICE_SIGNAL_METHODS) do
		local getters = self:gettersFor(serviceName)
		local signals = self:signalsFor(serviceName)
		for name, signalName in pairs(methods) do
			local signal = signals[signalName]
			getters[name] = constantMethod(function(_, ...)
				signal:fire(...)
			end)
		end
	end
end

function EditModeShim:collectLocaleMethods()
	for serviceName, names in pairs(SHIM.PLAYER_LOCALE_METHODS) do
		local service = game:GetService(serviceName)
		local getters = self:gettersFor(serviceName)
		local translator = function()
			return self.proxy:wrap(service[SHIM.LOCALE_METHOD](service, self.localeId()))
		end
		for _, name in ipairs(names) do
			getters[name] = constantMethod(translator)
		end
	end
end

function EditModeShim:installServiceGetters()
	for serviceName, getters in pairs(self.serviceGetters) do
		self.proxy:override(game:GetService(serviceName), getters)
	end
	for _, serviceName in ipairs(SHIM.SILENT_SERVICES) do
		local service = game:GetService(serviceName)
		self.proxy:overrideFallback(service, silentFallback(service))
	end
end

function EditModeShim:installMethodOverrides()
	for _, name in ipairs(SHIM.NO_OP_METHODS) do
		self.proxy:overrideMethod(name, noOp)
	end
	for name, value in pairs(SHIM.CONSTANT_METHODS) do
		self.proxy:overrideMethod(name, constantMethod(value))
	end
end

function EditModeShim:install()
	self:installCloseBinding()
	self:collectGuardedMethods()
	self:collectServiceMembers()
	self:collectLocaleMethods()
	self:installServiceGetters()
	self:installMethodOverrides()
end

function EditModeShim:runCloseCallbacks()
	local callbacks = self.closeCallbacks
	self.closeCallbacks = {}
	for _, callback in ipairs(callbacks) do
		task.spawn(pcall, callback)
	end
end

return EditModeShim
