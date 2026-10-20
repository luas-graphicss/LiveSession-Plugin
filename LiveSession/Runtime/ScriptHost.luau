local Constants = require(script.Parent.Parent.Core.Constants)

local ScriptHost = {}
ScriptHost.__index = ScriptHost

local DEAD = Constants.COROUTINE_STATUS_DEAD

local function startupError(thread)
	if coroutine.status(thread) ~= DEAD then
		return nil
	end
	local finished, runtimeError = coroutine.close(thread)
	if finished then
		return nil
	end
	return runtimeError
end

function ScriptHost.new(environment, tracker, registry, readSource, policy, costKey, context)
	return setmetatable({
		environment = environment,
		tracker = tracker,
		registry = registry,
		readSource = readSource,
		policy = policy,
		costKey = costKey,
		context = context,
		running = {},
		moduleTokens = {},
		originalByClone = {},
		clonesByOriginal = {},
	}, ScriptHost)
end

function ScriptHost:compile(instance, source)
	return loadstring(source, Constants.CHUNK_NAME_PREFIX .. instance:GetFullName())
end

function ScriptHost:sourceOf(instance)
	return self.readSource(self.originalByClone[instance] or instance)
end

function ScriptHost:bindClone(clone, original)
	self.originalByClone[clone] = original
	local clones = self.clonesByOriginal[original]
	if not clones then
		clones = {}
		self.clonesByOriginal[original] = clones
	end
	table.insert(clones, clone)
end

function ScriptHost:originalOf(instance)
	return self.originalByClone[instance]
end

function ScriptHost:runnersOf(instance)
	local clones = self.clonesByOriginal[instance]
	if not clones then
		return { instance }
	end
	local alive = {}
	for index = #clones, 1, -1 do
		local clone = clones[index]
		if clone.Parent == nil then
			table.remove(clones, index)
			self.originalByClone[clone] = nil
		else
			table.insert(alive, 1, clone)
		end
	end
	return alive
end

function ScriptHost:runModule(module)
	local source = self:sourceOf(module)
	local chunk, compileError = self:compile(module, source)
	if not chunk then
		error(compileError, 0)
	end
	local token = { instance = module, costKey = self.costKey, context = self.context }
	self.moduleTokens[module] = token
	setfenv(chunk, self.environment:build(module, token))
	local thread = coroutine.running()
	local previousOwner = self.tracker:ownerOf(thread)
	self.tracker:adopt(thread, token)
	local results = table.pack(pcall(chunk))
	self.tracker:adopt(thread, previousOwner)
	if not results[1] then
		error(results[2], 0)
	end
	return results[2]
end

function ScriptHost:shouldRun(instance)
	return self.policy(instance)
end

function ScriptHost:start(instance)
	local source = self:sourceOf(instance)
	local chunk, compileError = self:compile(instance, source)
	if not chunk then
		return nil, compileError
	end
	local token = { instance = instance, costKey = self.costKey, context = self.context }
	setfenv(chunk, self.environment:build(instance, token))
	local thread = coroutine.create(chunk)
	self.tracker:addThread(token, thread)
	task.spawn(thread)
	return token, startupError(thread)
end

function ScriptHost:activate(instance, token)
	self.running[instance] = token
end

function ScriptHost:isRunning(instance)
	return self.running[instance] ~= nil
end

function ScriptHost:deactivate(instance)
	local token = self.running[instance]
	self.running[instance] = nil
	self.registry:forget(instance)
	return token
end

function ScriptHost:stop(instance)
	local token = self:deactivate(instance)
	if token then
		return self.tracker:stop(token)
	end
	return nil
end

function ScriptHost:release(instance)
	local token = self:deactivate(instance)
	if token then
		return self:releaseToken(token)
	end
	return nil
end

function ScriptHost:releaseToken(token)
	self.environment:notifyRelease(token)
	return self.tracker:release(token)
end

function ScriptHost:releaseModule(module)
	local token = self.moduleTokens[module]
	self.moduleTokens[module] = nil
	if token then
		return self:releaseToken(token)
	end
	return nil
end

function ScriptHost:stopAll()
	for instance in pairs(self.running) do
		self:release(instance)
	end
	for module in pairs(self.moduleTokens) do
		self:releaseModule(module)
	end
	self.registry:clear()
	self.originalByClone = {}
	self.clonesByOriginal = {}
	return self.tracker:releaseAll()
end

function ScriptHost:runningCount()
	local count = 0
	for _ in pairs(self.running) do
		count += 1
	end
	return count
end

return ScriptHost
