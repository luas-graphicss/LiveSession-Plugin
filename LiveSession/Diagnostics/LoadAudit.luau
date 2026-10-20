local Constants = require(script.Parent.Parent.Core.Constants)
local RunPolicy = require(script.Parent.Parent.Runtime.RunPolicy)

local LoadAudit = {}
LoadAudit.__index = LoadAudit

local STATES = Constants.LOAD_STATES
local CLASSES = Constants.CLASS_NAMES
local PROPERTIES = Constants.PROPERTY_NAMES
local TEXTS = Constants.TEXTS
local CLIENT = Constants.CLIENT
local CONTEXTS = Constants.CONTEXTS

local function topContainerName(instance)
	local container = instance
	while container.Parent and container.Parent ~= game do
		container = container.Parent
	end
	return container.Parent == game and container.Name or nil
end

local function expectedInClone(instance, top)
	if not CLIENT.STARTER_CONTAINERS[top] then
		return false
	end
	if instance.ClassName == CLASSES.LOCAL_SCRIPT then
		return true
	end
	local runContext = instance[PROPERTIES.RUN_CONTEXT]
	if runContext == Enum.RunContext.Client or runContext == Enum.RunContext.Server then
		return true
	end
	if runContext == Enum.RunContext.Legacy then
		return instance:FindFirstAncestor(CLIENT.STARTER_PLAYER_SCRIPTS) == nil
	end
	return false
end

function LoadAudit.reason(instance)
	if instance.ClassName == CLASSES.LOCAL_SCRIPT then
		return TEXTS.LOAD_REASON_LOCAL_SCRIPT
	end
	local runContext = instance[PROPERTIES.RUN_CONTEXT]
	if runContext == Enum.RunContext.Client then
		return TEXTS.LOAD_REASON_CLIENT_CONTEXT
	elseif runContext == Enum.RunContext.Plugin then
		return TEXTS.LOAD_REASON_PLUGIN_CONTEXT
	elseif runContext == Enum.RunContext.Legacy then
		return TEXTS.LOAD_REASON_LEGACY
	end
	return TEXTS.LOAD_REASON_UNKNOWN
end

function LoadAudit.new(hosts, issueOf)
	return setmetatable({
		hosts = hosts,
		issueOf = issueOf,
		counts = { running = 0, [CONTEXTS.SERVER] = 0, [CONTEXTS.CLIENT] = 0, failed = 0, disabled = 0, skipped = 0 },
		failed = {},
		notStarted = {},
		skipped = {},
	}, LoadAudit)
end

function LoadAudit:runnersOf(instance)
	local seen = {}
	local runners = {}
	for _, host in ipairs(self.hosts) do
		for _, runner in ipairs(host:runnersOf(instance)) do
			if not seen[runner] then
				seen[runner] = true
				table.insert(runners, runner)
			end
		end
	end
	return runners
end

function LoadAudit:runningContext(runner)
	for _, host in ipairs(self.hosts) do
		if host:isRunning(runner) then
			return host.context
		end
	end
	return nil
end

function LoadAudit:add(instance)
	local runners = self:runnersOf(instance)
	local path = instance:GetFullName()
	for _, runner in ipairs(runners) do
		local issue = self.issueOf(runner) or self.issueOf(instance)
		if issue then
			self.counts.failed += 1
			table.insert(self.failed, { path = path, detail = issue })
			return STATES.FAILED
		end
	end
	for _, runner in ipairs(runners) do
		local context = self:runningContext(runner)
		if context then
			self.counts.running += 1
			self.counts[context] += 1
			return STATES.RUNNING
		end
	end
	if not RunPolicy.isEnabled(instance) then
		self.counts.disabled += 1
		return STATES.DISABLED
	end
	local top = topContainerName(instance)
	if expectedInClone(instance, top) then
		self.counts.failed += 1
		table.insert(self.notStarted, { path = path, detail = TEXTS.LOAD_REASON_NO_CLONE })
		return STATES.NOT_STARTED
	end
	self.counts.skipped += 1
	table.insert(self.skipped, string.format(TEXTS.LOAD_SKIPPED_ITEM, path, LoadAudit.reason(instance)))
	return STATES.SKIPPED
end

return LoadAudit
