local Constants = require(script.Parent.Parent.Core.Constants)

local InstanceProxy = {}
InstanceProxy.__index = InstanceProxy

local TYPES = Constants.TYPE_NAMES
local METHODS = Constants.INSTANCE_METHODS
local CONNECT_METHODS = Constants.SIGNAL_CONNECT_METHODS
local TRACKED_METHODS = Constants.TRACKED_METHODS
local MUTATING_METHODS = Constants.MUTATING_METHODS
local VALUE_PROXY_TYPES = Constants.VALUE_PROXY_TYPES
local BRIDGES = Constants.BRIDGES

local function weakKeyed()
	return setmetatable({}, { __mode = "k" })
end

local function traceback(message)
	return debug.traceback(tostring(message), 2)
end

local function isValidBridge(bridge)
	if type(bridge) ~= TYPES.TABLE or type(bridge.name) ~= TYPES.STRING or type(bridge.matches) ~= TYPES.FUNCTION then
		return false
	end
	for _, hook in ipairs(BRIDGES.HOOKS) do
		local handler = bridge[hook]
		if handler ~= nil and type(handler) ~= TYPES.FUNCTION then
			return false
		end
	end
	return true
end

function InstanceProxy.new(tracker, meter, onMutation)
	local self = setmetatable({
		tracker = tracker,
		meter = meter,
		onMutation = onMutation,
		bridges = {},
		bridgesByInstance = weakKeyed(),
		getters = weakKeyed(),
		setters = weakKeyed(),
		fallbacks = weakKeyed(),
		contextual = weakKeyed(),
		contextGetters = {},
		methodOverrides = {},
		proxyByInstance = weakKeyed(),
		instanceByProxy = weakKeyed(),
		signalProxies = weakKeyed(),
		methodWrappers = weakKeyed(),
	}, InstanceProxy)
	for _, context in pairs(Constants.CONTEXTS) do
		self.contextGetters[context] = weakKeyed()
	end
	self.metatable = {
		__index = function(proxy, key)
			return self:readMember(self.instanceByProxy[proxy], key)
		end,
		__newindex = function(proxy, key, value)
			self:writeMember(self.instanceByProxy[proxy], key, value)
		end,
		__tostring = function(proxy)
			return tostring(self.instanceByProxy[proxy])
		end,
		__metatable = Constants.LOCKED_METATABLE_MESSAGE,
	}
	self.valueMetatable = {
		__index = function(proxy, key)
			return self:readValueMember(self.instanceByProxy[proxy], key)
		end,
		__newindex = function(proxy, key, value)
			self:writeValueMember(self.instanceByProxy[proxy], key, value)
		end,
		__tostring = function(proxy)
			return tostring(self.instanceByProxy[proxy])
		end,
		__metatable = Constants.LOCKED_METATABLE_MESSAGE,
	}
	return self
end

function InstanceProxy:isProxy(value)
	return self.instanceByProxy[value] ~= nil
end

function InstanceProxy:typeOf(value)
	local target = self.instanceByProxy[value]
	if target ~= nil then
		return typeof(target)
	end
	return typeof(value)
end

function InstanceProxy:proxyFor(value, metatable)
	local proxy = self.proxyByInstance[value]
	if not proxy then
		proxy = setmetatable({}, metatable)
		self.proxyByInstance[value] = proxy
		self.instanceByProxy[proxy] = value
	end
	return proxy
end

function InstanceProxy:wrap(value)
	local kind = typeof(value)
	if kind == TYPES.INSTANCE then
		return self:proxyFor(value, self.metatable)
	elseif kind == TYPES.SIGNAL then
		return self:signalProxy(value)
	elseif VALUE_PROXY_TYPES[kind] then
		return self:proxyFor(value, self.valueMetatable)
	elseif kind == TYPES.TABLE and getmetatable(value) == nil then
		local copy = {}
		for key, item in pairs(value) do
			copy[key] = self:wrap(item)
		end
		return copy
	end
	return value
end

function InstanceProxy:unwrap(value)
	local instance = self.instanceByProxy[value]
	if instance then
		return instance
	end
	if type(value) == TYPES.TABLE and getmetatable(value) == nil then
		local copy = {}
		for key, item in pairs(value) do
			copy[key] = self:unwrap(item)
		end
		return copy
	end
	return value
end

function InstanceProxy:wrapPack(packed)
	for index = 1, packed.n do
		packed[index] = self:wrap(packed[index])
	end
	return table.unpack(packed, 1, packed.n)
end

function InstanceProxy:addBridge(bridge)
	if not isValidBridge(bridge) then
		error(BRIDGES.INVALID_MESSAGE, 2)
	end
	table.insert(self.bridges, bridge)
	self.bridgesByInstance = weakKeyed()
end

function InstanceProxy:clearBridges()
	self.bridges = {}
	self.bridgesByInstance = weakKeyed()
end

function InstanceProxy:bridgesFor(instance)
	local matched = self.bridgesByInstance[instance]
	if matched then
		return matched
	end
	matched = BRIDGES.NONE
	for _, bridge in ipairs(self.bridges) do
		if bridge.matches(instance) then
			if matched == BRIDGES.NONE then
				matched = {}
			end
			table.insert(matched, bridge)
		end
	end
	self.bridgesByInstance[instance] = matched
	return matched
end

function InstanceProxy:override(instance, getters, setters)
	self.getters[instance] = getters
	self.setters[instance] = setters
end

function InstanceProxy:overrideFallback(instance, fallback)
	self.fallbacks[instance] = fallback
end

function InstanceProxy:overrideForContext(context, instance, getters)
	self.contextGetters[context][instance] = getters
	self.contextual[instance] = true
end

function InstanceProxy:overrideMethod(name, handler)
	self.methodOverrides[name] = handler
end

function InstanceProxy:clearOverrides(instance)
	self.getters[instance] = nil
	self.setters[instance] = nil
	self.fallbacks[instance] = nil
	self.contextual[instance] = nil
	for _, getters in pairs(self.contextGetters) do
		getters[instance] = nil
	end
end

function InstanceProxy:currentContext()
	local owner = self.tracker:currentOwner()
	return owner and owner.context
end

function InstanceProxy:getterFor(instance, key)
	if self.contextual[instance] then
		local context = self:currentContext()
		local getters = context and self.contextGetters[context][instance]
		local getter = getters and getters[key]
		if getter then
			return getter
		end
	end
	local getters = self.getters[instance]
	return getters and getters[key]
end

function InstanceProxy:readMember(instance, key)
	local getter = self:getterFor(instance, key)
	if getter then
		return getter()
	end
	local fallback = self.fallbacks[instance]
	if fallback then
		local handled, value = fallback.read(key)
		if handled then
			return self:wrap(value)
		end
	end
	for _, bridge in ipairs(self:bridgesFor(instance)) do
		if bridge.read then
			local handled, value = bridge.read(instance, key)
			if handled then
				return value
			end
		end
	end
	local value = instance[key]
	local kind = typeof(value)
	if kind == TYPES.FUNCTION then
		return self:methodWrapper(value, key)
	elseif kind == TYPES.INSTANCE or kind == TYPES.SIGNAL then
		return self:wrap(value)
	end
	return value
end

function InstanceProxy:writeMember(instance, key, value)
	local unwrapped = self:hostedArgument(value, self.tracker:currentOwner())
	local setters = self.setters[instance]
	local setter = setters and setters[key]
	if setter then
		setter(unwrapped)
		return
	end
	local fallback = self.fallbacks[instance]
	if fallback and fallback.write(key, unwrapped) then
		return
	end
	for _, bridge in ipairs(self:bridgesFor(instance)) do
		if bridge.write and bridge.write(instance, key, unwrapped) then
			return
		end
	end
	self.onMutation(instance)
	instance[key] = unwrapped
end

function InstanceProxy:readValueMember(target, key)
	local value = target[key]
	if typeof(value) == TYPES.FUNCTION then
		return self:methodWrapper(value, key)
	end
	return self:wrap(value)
end

function InstanceProxy:writeValueMember(target, key, value)
	target[key] = self:unwrap(value)
end

function InstanceProxy:hostedArgument(value, owner)
	local unwrapped = self:unwrap(value)
	if type(unwrapped) == TYPES.FUNCTION then
		return self:hostedCallback(unwrapped, owner)
	end
	return unwrapped
end

function InstanceProxy:hostedCallback(callback, owner)
	local costKey = owner and owner.costKey
	return function(...)
		local thread = coroutine.running()
		local previousOwner = self.tracker:ownerOf(thread)
		self.tracker:adopt(thread, owner)
		local results = table.pack(xpcall(self.meter.measure, traceback, self.meter, costKey, callback, self:wrapPack(table.pack(...))))
		self.tracker:adopt(thread, previousOwner)
		if not results[1] then
			error(results[2], 0)
		end
		return self:unwrapResults(results)
	end
end

function InstanceProxy:unwrapResults(packed)
	for index = 2, packed.n do
		packed[index] = self:unwrap(packed[index])
	end
	return table.unpack(packed, 2, packed.n)
end

function InstanceProxy:unwrapArguments(packed)
	local owner = self.tracker:currentOwner()
	for index = 1, packed.n do
		packed[index] = self:hostedArgument(packed[index], owner)
	end
	return table.unpack(packed, 1, packed.n)
end

function InstanceProxy:isFreshInstance(target, value)
	if typeof(value) ~= TYPES.INSTANCE or value == game or value == target or value.Parent ~= nil then
		return false
	end
	if self.tracker:isHostedInstance(value) then
		return false
	end
	return typeof(target) ~= TYPES.INSTANCE or not target:IsDescendantOf(value)
end

function InstanceProxy:trackCall(name, instance, results, firstArgument)
	local owner = self.tracker:currentOwner()
	if not owner then
		return
	end
	for index = 1, results.n do
		if self:isFreshInstance(instance, results[index]) then
			self.tracker:addInstance(owner, results[index])
		end
	end
	if TRACKED_METHODS[name] and type(firstArgument) == TYPES.STRING then
		self.tracker:addNamedBinding(owner, TRACKED_METHODS[name], instance, firstArgument)
	end
end

function InstanceProxy:afterCall(name, instance, arguments, results)
	for _, bridge in ipairs(self:bridgesFor(instance)) do
		if bridge.afterCall then
			bridge.afterCall(name, instance, arguments, results)
		end
	end
end

function InstanceProxy:overriddenWrapper(handler)
	return function(target, ...)
		local arguments = table.pack(...)
		return self:wrapPack(table.pack(handler(self:unwrap(target), self:unwrapArguments(arguments))))
	end
end

function InstanceProxy:methodWrapper(method, name)
	local wrapper = self.methodWrappers[method]
	if wrapper then
		return wrapper
	end
	local override = self.methodOverrides[name]
	if override then
		wrapper = self:overriddenWrapper(override)
		self.methodWrappers[method] = wrapper
		return wrapper
	end
	wrapper = function(target, ...)
		local instance = self:unwrap(target)
		local isInstance = typeof(instance) == TYPES.INSTANCE
		if name == METHODS.DESTROY and isInstance then
			self.tracker:markDestroying(instance)
		end
		local arguments = table.pack(...)
		local firstArgument = arguments[1]
		if MUTATING_METHODS[name] and isInstance then
			self:markMutation(instance, arguments)
		end
		local results = table.pack(method(instance, self:unwrapArguments(arguments)))
		self:trackCall(name, instance, results, firstArgument)
		if isInstance then
			self:afterCall(name, instance, arguments, results)
		end
		return self:wrapPack(results)
	end
	self.methodWrappers[method] = wrapper
	return wrapper
end

function InstanceProxy:markMutation(instance, arguments)
	self.onMutation(instance)
	for index = 1, arguments.n do
		local argument = self:unwrap(arguments[index])
		if typeof(argument) == TYPES.INSTANCE then
			self.onMutation(argument)
		end
	end
end

function InstanceProxy:connect(signal, methodName, callback)
	local owner = self.tracker:currentOwner()
	local connection = signal[methodName](signal, self:hostedCallback(callback, owner))
	if owner then
		self.tracker:addConnection(owner, connection)
	end
	return connection
end

function InstanceProxy:signalProxy(signal)
	local proxy = self.signalProxies[signal]
	if proxy then
		return proxy
	end
	proxy = setmetatable({}, {
		__index = function(_, member)
			local methodName = CONNECT_METHODS[member]
			if methodName then
				return function(_, callback)
					return self:connect(signal, methodName, callback)
				end
			elseif member == Constants.SIGNAL_WAIT_METHOD then
				return function()
					return self:wrapPack(table.pack(signal:Wait()))
				end
			end
			error(string.format(Constants.ERRORS.INVALID_SIGNAL_MEMBER, tostring(member)), 2)
		end,
		__tostring = function()
			return tostring(signal)
		end,
		__metatable = Constants.LOCKED_METATABLE_MESSAGE,
	})
	self.signalProxies[signal] = proxy
	return proxy
end

return InstanceProxy
