local Constants = require(script.Parent.Parent.Core.Constants)
local HostedSignal = require(script.Parent.HostedSignal)

local Environment = {}
Environment.__index = Environment

local TYPES = Constants.TYPE_NAMES
local baseGlobals = getfenv()

function Environment.new(tracker, proxy, registry, api)
	return setmetatable({
		tracker = tracker,
		proxy = proxy,
		registry = registry,
		api = api,
		sharedTable = {},
		globalTable = {},
	}, Environment)
end

function Environment:notifyRelease(owner)
	self.api:beforeRelease(owner)
end

function Environment:ownerFor(fallback)
	return self.tracker:currentOwner() or fallback
end

function Environment:trackedThread(callable, owner)
	if type(callable) == TYPES.THREAD then
		self.tracker:addThread(owner, callable)
		return callable
	end
	local thread = coroutine.create(callable)
	self.tracker:addThread(owner, thread)
	return thread
end

function Environment:buildTask(defaultOwner)
	local hosted = {}
	hosted.spawn = function(callable, ...)
		return task.spawn(self:trackedThread(callable, self:ownerFor(defaultOwner)), ...)
	end
	hosted.defer = function(callable, ...)
		return task.defer(self:trackedThread(callable, self:ownerFor(defaultOwner)), ...)
	end
	hosted.delay = function(seconds, callable, ...)
		return task.delay(seconds, self:trackedThread(callable, self:ownerFor(defaultOwner)), ...)
	end
	return setmetatable(hosted, { __index = task })
end

function Environment:buildCoroutine(defaultOwner)
	local hosted = {}
	hosted.create = function(callable)
		return self:trackedThread(callable, self:ownerFor(defaultOwner))
	end
	hosted.wrap = function(callable)
		local thread = self:trackedThread(callable, self:ownerFor(defaultOwner))
		return function(...)
			local results = table.pack(coroutine.resume(thread, ...))
			if not results[1] then
				error(results[2], 2)
			end
			return table.unpack(results, 2, results.n)
		end
	end
	return setmetatable(hosted, { __index = coroutine })
end

function Environment:buildInstance(defaultOwner)
	local hosted = {}
	local function track(instance)
		self.tracker:addInstance(self:ownerFor(defaultOwner), instance)
		return instance
	end
	hosted.new = function(className, parent)
		local instance = track(Instance.new(className))
		if parent ~= nil then
			instance.Parent = self.proxy:unwrap(parent)
		end
		return self.proxy:wrap(instance)
	end
	hosted.fromExisting = function(existing)
		return self.proxy:wrap(track(Instance.fromExisting(self.proxy:unwrap(existing))))
	end
	return setmetatable(hosted, { __index = Instance })
end

function Environment:buildParams(library)
	local hosted = {}
	hosted.new = function(...)
		return self.proxy:wrap(library.new(...))
	end
	return setmetatable(hosted, { __index = library })
end

function Environment:build(scriptInstance, owner)
	local prefix = string.format(Constants.OUTPUT_PREFIX_FORMAT, scriptInstance:GetFullName())
	local proxy = self.proxy
	local environment = {
		script = proxy:wrap(scriptInstance),
		game = proxy:wrap(game),
		workspace = proxy:wrap(workspace),
		Game = proxy:wrap(game),
		Workspace = proxy:wrap(workspace),
		Instance = self:buildInstance(owner),
		RaycastParams = self:buildParams(RaycastParams),
		OverlapParams = self:buildParams(OverlapParams),
		task = self:buildTask(owner),
		coroutine = self:buildCoroutine(owner),
		shared = self.sharedTable,
		_G = self.globalTable,
		[Constants.LIVE_SESSION_GLOBAL] = self.api:build(owner),
		require = function(target)
			return self.registry:require(scriptInstance, proxy:unwrap(target))
		end,
		print = function(...)
			print(prefix, ...)
		end,
		warn = function(...)
			warn(prefix, ...)
		end,
		typeof = function(value)
			return HostedSignal.typeOf(value) or proxy:typeOf(value)
		end,
		type = function(value)
			if proxy:isProxy(value) or HostedSignal.typeOf(value) then
				return TYPES.USERDATA
			end
			return type(value)
		end,
	}
	environment.spawn = function(callable)
		return environment.task.defer(callable)
	end
	environment.delay = function(seconds, callable)
		return environment.task.delay(seconds, callable)
	end
	return setmetatable(environment, {
		__index = function(_, key)
			if Constants.HIDDEN_GLOBALS[key] then
				return nil
			end
			return baseGlobals[key]
		end,
	})
end

return Environment
