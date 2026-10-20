local Constants = require(script.Parent.Parent.Core.Constants)
local Hash = require(script.Parent.Parent.Core.Hash)
local ApiScan = require(script.Parent.ApiScan)

local HotReload = {}
HotReload.__index = HotReload

local STATUS = Constants.RELOAD_STATUS
local CLASSES = Constants.CLASS_NAMES

local function accumulate(totals, counts)
	if not counts then
		return
	end
	for key, value in pairs(counts) do
		totals[key] = (totals[key] or 0) + value
	end
end

local function compile(instance, source)
	return loadstring(source, Constants.CHUNK_NAME_PREFIX .. instance:GetFullName())
end

local function byFullName(left, right)
	return left:GetFullName() < right:GetFullName()
end

function HotReload.new(hosts, readSource, callbacks)
	return setmetatable({
		hosts = hosts,
		readSource = readSource,
		callbacks = callbacks,
		pending = {},
		timer = nil,
		debounceSeconds = Constants.RELOAD_DEBOUNCE_SECONDS,
		lastSource = {},
		lastDigest = {},
		broken = {},
		count = 0,
		active = true,
	}, HotReload)
end

function HotReload:seed(instance, source)
	self.lastSource[instance] = source
	self.lastDigest[instance] = nil
	self.callbacks.onApiFindings(instance, ApiScan.find(source))
end

function HotReload:previousDigest(instance)
	local digest = self.lastDigest[instance]
	if digest then
		return digest
	end
	local source = self.lastSource[instance]
	if source == nil then
		return nil
	end
	return Hash.text(source)
end

function HotReload:setDebounce(seconds)
	self.debounceSeconds = seconds
end

function HotReload:schedule(instance)
	if not self.active then
		return
	end
	self.pending[instance] = os.clock()
	self:armTimer(self.debounceSeconds)
end

function HotReload:armTimer(delaySeconds)
	if self.timer then
		return
	end
	self.timer = task.delay(delaySeconds, function()
		self.timer = nil
		self:flush()
	end)
end

function HotReload:flush()
	if not self.active then
		return
	end
	local now = os.clock()
	local ready = {}
	local nextDelay = nil
	for instance, changedAt in pairs(self.pending) do
		local remaining = self.debounceSeconds - (now - changedAt)
		if remaining <= Constants.RELOAD_TIMER_TOLERANCE_SECONDS then
			self.pending[instance] = nil
			if instance.Parent ~= nil then
				table.insert(ready, instance)
			end
		else
			nextDelay = math.min(nextDelay or remaining, remaining)
		end
	end
	if nextDelay then
		self:armTimer(nextDelay)
	end
	if #ready > 0 then
		self:applyBatch(ready)
	end
end

function HotReload:markBroken(instance, compileError)
	local entry = self.broken[instance]
	if not entry then
		entry = { since = os.clock(), warned = false }
		self.broken[instance] = entry
		task.delay(Constants.BROKEN_SCRIPT_WARNING_SECONDS, function()
			local current = self.broken[instance]
			if current == entry and not current.warned and self.active then
				current.warned = true
				self.callbacks.onBrokenTooLong(instance, current.compileError, math.floor(os.clock() - current.since))
			end
		end)
	end
	entry.compileError = compileError
	self.callbacks.onStatus(instance, STATUS.WAITING_COMPILABLE, compileError)
end

function HotReload:clearBroken(instance)
	self.broken[instance] = nil
end

function HotReload:brokenScripts()
	local list = {}
	for instance, entry in pairs(self.broken) do
		table.insert(list, { instance = instance, compileError = entry.compileError })
	end
	return list
end

function HotReload:swap(host, target, released)
	accumulate(released, host:release(target))
	local token, loadError = host:start(target)
	if loadError then
		self.callbacks.onStatus(target, STATUS.LOAD_ERROR, loadError)
	end
	if token then
		host:activate(target, token)
	end
	return token ~= nil
end

function HotReload:applyRunners(host, target, released, report)
	for _, runner in ipairs(host:runnersOf(target)) do
		if host:shouldRun(runner) then
			if self:swap(host, runner, released) then
				report.swapped += 1
			end
		elseif host:isRunning(runner) then
			accumulate(released, host:release(runner))
		end
	end
end

function HotReload:affectedIn(host, instances)
	local order = {}
	local seen = {}
	local function add(target)
		if not seen[target] then
			seen[target] = true
			table.insert(order, target)
		end
	end
	for _, instance in ipairs(instances) do
		if instance:IsA(CLASSES.MODULE_SCRIPT) then
			for _, runner in ipairs(host:runnersOf(instance)) do
				for _, target in ipairs(host.registry:invalidate(runner)) do
					add(target)
				end
			end
		else
			add(instance)
		end
	end
	return order
end

function HotReload:applyHost(host, instances, released, report)
	local affected = self:affectedIn(host, instances)
	report.affected += #affected
	for _, target in ipairs(affected) do
		if target:IsA(CLASSES.MODULE_SCRIPT) then
			accumulate(released, host:releaseModule(target))
		else
			self:applyRunners(host, target, released, report)
		end
	end
end

function HotReload:journalChanges(instances)
	local changed = {}
	for _, instance in ipairs(instances) do
		local source = self.readSource(instance)
		if self.lastSource[instance] ~= source then
			local previousDigest = self:previousDigest(instance)
			local digest = Hash.text(source)
			self.lastSource[instance] = source
			self.lastDigest[instance] = digest
			self.callbacks.beforeApply(instance, source, digest, previousDigest)
			table.insert(changed, { instance = instance, source = source })
		end
	end
	return changed
end

function HotReload:compileChanges(changed)
	local compiled = {}
	for _, change in ipairs(changed) do
		local chunk, compileError = compile(change.instance, change.source)
		if chunk then
			self:clearBroken(change.instance)
			self.callbacks.onApiFindings(change.instance, ApiScan.find(change.source))
			table.insert(compiled, change.instance)
		else
			self:markBroken(change.instance, compileError)
		end
	end
	return compiled
end

function HotReload:applyBatch(instances)
	table.sort(instances, byFullName)
	local compiled = self:compileChanges(self:journalChanges(instances))
	if #compiled == 0 then
		return
	end
	local startedAt = os.clock()
	local released = { connections = 0, threads = 0, instances = 0 }
	local report = { instances = compiled, affected = 0, swapped = 0, released = released }
	for _, host in ipairs(self.hosts) do
		self:applyHost(host, compiled, released, report)
	end
	self.count += #compiled
	report.elapsedMs = (os.clock() - startedAt) * Constants.MILLISECONDS_PER_SECOND
	self.callbacks.onReport(report)
end

 
 
function HotReload:restart(instances)
	if not self.active then
		return nil
	end
	table.sort(instances, byFullName)
	local compiled = {}
	for _, instance in ipairs(instances) do
		if instance.Parent ~= nil then
			local chunk, compileError = compile(instance, self.readSource(instance))
			if chunk then
				self:clearBroken(instance)
				table.insert(compiled, instance)
			else
				self:markBroken(instance, compileError)
			end
		end
	end
	local released = { connections = 0, threads = 0, instances = 0 }
	local report = { instances = compiled, affected = 0, swapped = 0, released = released, restart = true, elapsedMs = 0 }
	if #compiled == 0 then
		return report
	end
	local startedAt = os.clock()
	for _, host in ipairs(self.hosts) do
		self:applyHost(host, compiled, released, report)
	end
	self.count += #compiled
	report.elapsedMs = (os.clock() - startedAt) * Constants.MILLISECONDS_PER_SECOND
	self.callbacks.onReport(report)
	return report
end

function HotReload:launch(host, instance)
	local token, loadError = host:start(instance)
	if not token then
		self:markBroken(host:originalOf(instance) or instance, loadError)
		return
	end
	host:activate(instance, token)
	if loadError then
		self.callbacks.onStatus(instance, STATUS.LOAD_ERROR, loadError)
	end
end

function HotReload:refresh(instance, byEditor)
	if not self.active or instance.Parent == nil or not instance:IsA(CLASSES.BASE_SCRIPT) then
		return
	end
	for _, host in ipairs(self.hosts) do
		for _, runner in ipairs(host:runnersOf(instance)) do
			local shouldRun = host:shouldRun(runner)
			if shouldRun and not host:isRunning(runner) then
				self:launch(host, runner)
			elseif not shouldRun and host:isRunning(runner) then
				if byEditor then
					host:release(runner)
				else
					host:stop(runner)
				end
			end
		end
	end
end

function HotReload:stop()
	self.active = false
	if self.timer then
		task.cancel(self.timer)
		self.timer = nil
	end
	self.pending = {}
end

return HotReload
