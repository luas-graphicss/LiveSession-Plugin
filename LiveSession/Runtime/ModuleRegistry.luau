local Constants = require(script.Parent.Parent.Core.Constants)

local ModuleRegistry = {}
ModuleRegistry.__index = ModuleRegistry

local TYPES = Constants.TYPE_NAMES
local DEAD = Constants.COROUTINE_STATUS_DEAD

function ModuleRegistry.new()
	return setmetatable({
		host = nil,
		cache = {},
		dependents = {},
		dependencies = {},
	}, ModuleRegistry)
end

function ModuleRegistry:setHost(host)
	self.host = host
end

function ModuleRegistry:addEdge(requirer, module)
	self.dependents[module] = self.dependents[module] or {}
	self.dependents[module][requirer] = true
	self.dependencies[requirer] = self.dependencies[requirer] or {}
	self.dependencies[requirer][module] = true
end

function ModuleRegistry:awaitLoading(pending)
	if pending.thread == coroutine.running() then
		error(Constants.ERRORS.CYCLIC_REQUIRE, 2)
	end
	table.insert(pending.waiters, coroutine.running())
	local ok, result = coroutine.yield()
	if not ok then
		error(result, 2)
	end
	return result
end

function ModuleRegistry:load(target)
	local pending = { loading = true, thread = coroutine.running(), waiters = {} }
	self.cache[target] = pending
	local ok, result = pcall(self.host.runModule, self.host, target)
	if ok and result == nil then
		ok, result = false, Constants.ERRORS.MODULE_NO_VALUE
	end
	if ok then
		self.cache[target] = { result = result }
	elseif self.cache[target] == pending then
		self.cache[target] = nil
	end
	for _, waiter in ipairs(pending.waiters) do
		if coroutine.status(waiter) ~= DEAD then
			task.spawn(waiter, ok, result)
		end
	end
	if not ok then
		error(result, 0)
	end
	return result
end

function ModuleRegistry:require(requirer, target)
	if type(target) == TYPES.NUMBER then
		return require(target)
	end
	if typeof(target) ~= TYPES.INSTANCE or not target:IsA(Constants.CLASS_NAMES.MODULE_SCRIPT) then
		error(Constants.ERRORS.REQUIRE_NON_MODULE, 2)
	end
	self:addEdge(requirer, target)
	local cached = self.cache[target]
	if cached then
		if cached.loading then
			return self:awaitLoading(cached)
		end
		return cached.result
	end
	return self:load(target)
end

function ModuleRegistry:isCached(module)
	local cached = self.cache[module]
	return cached ~= nil and not cached.loading
end

function ModuleRegistry:forget(requirer)
	local modules = self.dependencies[requirer]
	if modules then
		for module in pairs(modules) do
			if self.dependents[module] then
				self.dependents[module][requirer] = nil
			end
		end
	end
	self.dependencies[requirer] = nil
end

function ModuleRegistry:affectedBy(changed)
	local order = { changed }
	local seen = { [changed] = true }
	local index = 1
	while index <= #order do
		local current = order[index]
		for dependent in pairs(self.dependents[current] or {}) do
			if not seen[dependent] then
				seen[dependent] = true
				table.insert(order, dependent)
			end
		end
		index += 1
	end
	return order
end

function ModuleRegistry:invalidate(changed)
	local affected = self:affectedBy(changed)
	for _, instance in ipairs(affected) do
		local cached = self.cache[instance]
		if cached and not cached.loading then
			self.cache[instance] = nil
		end
		self:forget(instance)
	end
	return affected
end

function ModuleRegistry:clear()
	self.cache = {}
	self.dependents = {}
	self.dependencies = {}
end

return ModuleRegistry
