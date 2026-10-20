local HttpService = game:GetService("HttpService")

local Root = script.Parent.Parent
local Constants = require(Root.Core.Constants)
local Hash = require(Root.Core.Hash)
local SourceWatcher = require(Root.Authoring.SourceWatcher)
local ValueCodec = require(Root.Journal.ValueCodec)

 
 
 
local McpFacade = {}

local STATES = Constants.STATES
local BRIDGE = Constants.MCP_BRIDGE
local TEXTS = Constants.TEXTS
local KINDS = Constants.ENTRY_KINDS
local ORIGINS = Constants.ORIGINS
local SCRIPT_CLASSES = Constants.SCRIPT_CLASSES
local OUTPUT_KINDS = Constants.OUTPUT.KINDS
local LIST_MAX = BRIDGE.LIST_MAX

local function alive(instance)
	if typeof(instance) ~= "Instance" then
		return false
	end
	local ok, inside = pcall(function()
		return instance == game or instance:IsDescendantOf(game)
	end)
	return ok and inside == true
end

local function pathOf(instance)
	local ok, name = pcall(function()
		return instance:GetFullName()
	end)
	if ok and type(name) == "string" then
		return name
	end
	return tostring(instance)
end

local function number(value, default, minimum, maximum)
	local n = tonumber(value)
	if n == nil or n ~= n then
		return default
	end
	return math.clamp(n, minimum, maximum)
end

local function integer(value, default, minimum, maximum)
	return math.floor(number(value, default, minimum, maximum))
end

local function preview(value)
	local text = tostring(value)
	if #text > BRIDGE.VALUE_PREVIEW then
		text = string.sub(text, 1, BRIDGE.VALUE_PREVIEW) .. "..."
	end
	return text
end

local function round(value, places)
	local factor = 10 ^ (places or 1)
	return math.floor((tonumber(value) or 0) * factor + 0.5) / factor
end

function McpFacade.isLive(session)
	local state = session.state
	return state == STATES.RUNNING or state == STATES.STARTING or state == STATES.STOPPING
end

function McpFacade.stateSummary(session)
	local live = McpFacade.isLive(session)
	return {
		protocol = BRIDGE.PROTOCOL,
		version = BRIDGE.VERSION,
		state = session.state,
		stateLabel = Constants.STATE_LABELS[session.state] or session.state,
		running = session.state == STATES.RUNNING,
		live = live,
		transitioning = session.transitioning == true,
		engine = session.engine,
		compatibility = session:isCompatibility(),
		sessionId = live and session.sessionId or nil,
		startedAt = live and session.startedAt or nil,
		uptimeSeconds = live and session.startedAt and (os.time() - session.startedAt) or nil,
	}
end

local function sortedByPath(list)
	table.sort(list, function(left, right)
		return tostring(left.path) < tostring(right.path)
	end)
	return list
end

function McpFacade.status(session, args)
	local status = McpFacade.stateSummary(session)
	if not status.live then
		return status
	end
	local detail = args and args.detail == "full"
	status.fps = session.fps
	status.physics = session.physics and session:physicsText() or nil
	status.scripts = {
		server = session.host and session.host:runningCount() or 0,
		client = session.clientHost and session.clientHost:runningCount() or 0,
	}
	local hot = session.hotReload
	if hot then
		local pending = 0
		for _ in pairs(hot.pending) do
			pending += 1
		end
		local broken = {}
		for _, item in ipairs(hot:brokenScripts()) do
			if #broken >= LIST_MAX then
				break
			end
			table.insert(broken, { instance = item.instance, path = pathOf(item.instance), error = tostring(item.compileError) })
		end
		local history = {}
		local reloads = session.mcpReloads or {}
		local first = detail and 1 or math.max(1, #reloads - 4)
		for index = first, #reloads do
			table.insert(history, reloads[index])
		end
		status.hotReload = {
			active = hot.active == true,
			granular = not session:isCompatibility(),
			reloads = hot.count,
			pending = pending,
			debounceSeconds = hot.debounceSeconds,
			broken = sortedByPath(broken),
			last = reloads[#reloads],
			history = history,
		}
	end
	local journal = session.journal
	if journal then
		local byKind, byOrigin = {}, {}
		for _, entry in ipairs(journal.entries) do
			byKind[entry.kind] = (byKind[entry.kind] or 0) + 1
			local origin = entry.origin or "none"
			byOrigin[origin] = (byOrigin[origin] or 0) + 1
		end
		status.journal = {
			entries = journal:count(),
			chars = session.journalChars or 0,
			degraded = session.degraded == true,
			byKind = byKind,
			byOrigin = byOrigin,
			nextSeq = journal.nextSeq,
		}
	end
	local issues = {}
	for instance, issue in pairs(session.loadIssues or {}) do
		if #issues >= LIST_MAX then
			break
		end
		table.insert(issues, { instance = instance, path = pathOf(instance), issue = tostring(issue) })
	end
	status.loadIssues = sortedByPath(issues)
	local cloneEdits = {}
	for clone, original in pairs(session.cloneEdits or {}) do
		if #cloneEdits >= LIST_MAX then
			break
		end
		table.insert(cloneEdits, { path = pathOf(clone), original = pathOf(original), instance = original })
	end
	local runtimeEdits = {}
	for instance in pairs(session.runtimeEdits or {}) do
		if #runtimeEdits >= LIST_MAX then
			break
		end
		table.insert(runtimeEdits, { path = pathOf(instance) })
	end
	status.unpersisted = {
		cloneEdits = sortedByPath(cloneEdits),
		runtimeEdits = sortedByPath(runtimeEdits),
		ambiguous = session.ambiguous and #session.ambiguous or 0,
	}
	local player = session.virtualPlayer
	if player then
		status.client = {
			active = player.active == true,
			status = player.active and player:status() or nil,
			guiMounted = player.guiMount and player.guiMount:count() or 0,
			guiSync = session.guiSync ~= nil,
		}
	end
	if session.remoteBridge then
		local ok, counts = pcall(session.remoteBridge.counts, session.remoteBridge)
		if ok then
			status.remotes = counts
		end
	end
	local output = session.deps.output
	status.output = {
		errors = output:count(OUTPUT_KINDS.ERROR),
		warnings = output:count(OUTPUT_KINDS.WARN),
		size = output:size(),
		lastSeq = output.nextSeq and (output.nextSeq - 1) or nil,
	}
	status.team = { active = session:isTeamCreate() }
	status.observed = session.observedCount
	return status
end

local function journalFacts(session, id)
	local facts = { created = false, destroyed = false, properties = 0, lastSource = nil }
	if not id or not session.journal then
		return facts
	end
	for _, entry in ipairs(session.journal.entries) do
		if entry.id == id then
			if entry.kind == KINDS.CREATE then
				facts.created = true
				facts.destroyed = false
			elseif entry.kind == KINDS.DESTROY then
				facts.destroyed = true
			elseif entry.kind == KINDS.PROPERTY then
				facts.properties += 1
			elseif entry.kind == KINDS.SOURCE then
				facts.lastSource = entry
			end
		end
	end
	return facts
end

function McpFacade.scriptState(session, target, facts, result)
	local source = SourceWatcher.readSource(target)
	local hot = session.hotReload
	local digest = Hash.text(source)
	result.sourceHash = digest
	result.sourceLength = #source
	result.synced = hot ~= nil and hot.lastSource[target] == source
	result.pending = hot ~= nil and hot.pending[target] ~= nil
	local broken = hot and hot.broken[target]
	result.compileError = broken and tostring(broken.compileError) or nil
	result.loadIssue = session.loadIssues and session.loadIssues[target] or nil
	local running = { server = 0, client = 0 }
	local runners = 0
	local shouldRun = false
	for _, host in ipairs(session.hosts or {}) do
		for _, runner in ipairs(host:runnersOf(target)) do
			if host:shouldRun(runner) then
				shouldRun = true
				runners += 1
				if host:isRunning(runner) then
					local context = tostring(host.context)
					running[context] = (running[context] or 0) + 1
				end
			end
		end
	end
	result.shouldRun = shouldRun
	result.runners = runners
	result.running = running
	local entry = facts.lastSource
	result.edited = entry ~= nil
	result.journaled = entry ~= nil and entry.afterHash == digest
	local appliedAt = session.mcpApplied and session.mcpApplied[target]
	result.appliedSecondsAgo = appliedAt and round(os.clock() - appliedAt, 2) or nil
	result.granular = not session:isCompatibility()
	if not result.granular then
		result.live = false
		result.liveReason = TEXTS.MCP_REASON_COMPAT
		return
	end
	local total = 0
	for _, count in pairs(running) do
		total += count
	end
	local isModule = target:IsA(Constants.CLASS_NAMES.MODULE_SCRIPT)
	result.live = result.synced and not result.pending and result.compileError == nil and (isModule or not shouldRun or total > 0)
	if not result.live then
		if result.compileError then
			result.liveReason = "erro de compilacao: " .. result.compileError
		elseif result.pending or not result.synced then
			result.liveReason = TEXTS.MCP_REASON_PENDING
		elseif shouldRun and total == 0 then
			result.liveReason = result.loadIssue or "deveria rodar mas nao esta em execucao"
		end
	end
end

function McpFacade.verifyOne(session, target)
	local result = { instance = target }
	if typeof(target) ~= "Instance" then
		result.exists = false
		result.reason = "alvo invalido"
		return result
	end
	result.path = pathOf(target)
	result.className = target.ClassName
	result.exists = alive(target)
	local live = McpFacade.isLive(session)
	if not live then
		result.reason = TEXTS.NOT_RUNNING
		return result
	end
	local id = session.stableId:idOf(target)
	local facts = journalFacts(session, id)
	result.stableId = id
	result.createdInSession = facts.created
	result.propertyEntries = facts.properties
	if not result.exists then
		result.destroyJournaled = facts.destroyed
		result.persist = facts.destroyed or facts.created
		result.reason = facts.destroyed and "remocao registrada no journal: persiste ao encerrar" or (facts.created and "criada e removida nesta sessao" or "removida fora do journal")
		return result
	end
	local isScript = SCRIPT_CLASSES[target.ClassName] == true
	local observed = session:isObserved(target)
	local player = session.virtualPlayer
	local inClient = player ~= nil and player.prepared and player:owns(target) or false
	local hosted = session.channel ~= nil and session.channel:isHostedInstance(target) or false
	local runtimeScript = session.runtimeScripts ~= nil and session.runtimeScripts[target] == true
	local original = session.cloneOrigins and session.cloneOrigins[target] or nil
	result.observed = observed
	result.runtime = inClient or hosted or runtimeScript
	if original then
		result.cloneOf = pathOf(original)
		result.original = original
	end
	if isScript then
		McpFacade.scriptState(session, target, facts, result)
	end
	if original then
		result.persist = false
		result.reason = string.format(TEXTS.MCP_REASON_CLONE, pathOf(original))
	elseif runtimeScript then
		result.persist = false
		result.reason = TEXTS.MCP_REASON_RUNTIME_SCRIPT
	elseif result.runtime then
		result.persist = false
		result.reason = TEXTS.MCP_REASON_RUNTIME_INSTANCE
	elseif not observed then
		result.persist = true
		result.reason = TEXTS.MCP_REASON_IGNORED
	elseif isScript then
		if result.journaled then
			result.persist = true
			result.reason = TEXTS.MCP_REASON_JOURNALED
		elseif not result.edited and result.synced then
			result.persist = true
			result.reason = TEXTS.MCP_REASON_UNCHANGED
		else
			result.persist = false
			result.reason = TEXTS.MCP_REASON_PENDING
		end
	elseif facts.created then
		result.persist = true
		result.reason = TEXTS.MCP_REASON_CREATED
	else
		result.persist = true
		result.reason = TEXTS.MCP_REASON_PREEXISTING
	end
	return result
end

local function waitsForReload(session, target)
	if typeof(target) ~= "Instance" or not SCRIPT_CLASSES[target.ClassName] or not alive(target) then
		return false
	end
	if not session:isObserved(target) or (session.cloneOrigins and session.cloneOrigins[target]) then
		return false
	end
	local hot = session.hotReload
	if not hot or not hot.active then
		return false
	end
	if hot.pending[target] ~= nil then
		return true
	end
	return hot.lastSource[target] ~= SourceWatcher.readSource(target)
end

function McpFacade.await(session, targets, seconds)
	local started = os.clock()
	local deadline = started + seconds
	while os.clock() < deadline and session.state == STATES.RUNNING do
		local waiting = false
		for _, target in ipairs(targets) do
			if waitsForReload(session, target) then
				waiting = true
				break
			end
		end
		if not waiting then
			break
		end
		task.wait(BRIDGE.AWAIT_POLL_SECONDS)
	end
	return os.clock() - started
end

function McpFacade.verify(session, args, shouldAwait)
	local targets = type(args.targets) == "table" and args.targets or {}
	local waited = 0
	if shouldAwait and session.state == STATES.RUNNING then
		waited = McpFacade.await(session, targets, number(args.timeout, BRIDGE.AWAIT_DEFAULT_SECONDS, 0, BRIDGE.AWAIT_MAX_SECONDS))
	end
	local results = {}
	for index, target in ipairs(targets) do
		if index > LIST_MAX then
			break
		end
		results[index] = McpFacade.verifyOne(session, target)
	end
	local summary = McpFacade.stateSummary(session)
	summary.results = results
	summary.waitedMs = math.floor(waited * 1000)
	if summary.live and session.hotReload then
		summary.reloads = session.hotReload.count
		local reloads = session.mcpReloads or {}
		summary.lastReload = reloads[#reloads]
	end
	return summary
end

local function waitState(session, seconds, done)
	local deadline = os.clock() + seconds
	task.wait()
	while os.clock() < deadline and not done() do
		task.wait(0.1)
	end
end

function McpFacade.start(session, args)
	local requested = false
	if session.state == STATES.IDLE and not session.transitioning then
		requested = true
		session:start()
	end
	local seconds = number(args.wait, 0, 0, BRIDGE.AWAIT_MAX_SECONDS)
	if requested and seconds > 0 then
		waitState(session, seconds, function()
			return session.state == STATES.RUNNING or (session.state == STATES.IDLE and not session.transitioning)
		end)
	end
	local summary = McpFacade.stateSummary(session)
	summary.requested = requested
	summary.waitingUser = session.state == STATES.PREFLIGHT or session.state == STATES.RECOVERING
	return summary
end

function McpFacade.stop(session, args)
	local requested = false
	if session.state == STATES.RUNNING and not session.transitioning then
		requested = true
		session:stop()
	end
	local seconds = number(args.wait, 0, 0, BRIDGE.AWAIT_MAX_SECONDS)
	if requested and seconds > 0 then
		waitState(session, seconds, function()
			return session.state == STATES.IDLE and not session.transitioning
		end)
	end
	local summary = McpFacade.stateSummary(session)
	summary.requested = requested
	summary.waitingUser = session.state == STATES.STOPPING
	return summary
end

function McpFacade.restart(session, args)
	local summary = McpFacade.stateSummary(session)
	if session.state ~= STATES.RUNNING or not session.hotReload or session:isCompatibility() then
		summary.ok = false
		summary.reason = session:isCompatibility() and TEXTS.MCP_REASON_COMPAT or TEXTS.NOT_RUNNING
		return summary
	end
	local scripts, seen = {}, {}
	for _, target in ipairs(type(args.targets) == "table" and args.targets or {}) do
		if typeof(target) == "Instance" and alive(target) and SCRIPT_CLASSES[target.ClassName] then
			local original = session.cloneOrigins and session.cloneOrigins[target] or target
			if not seen[original] then
				seen[original] = true
				table.insert(scripts, original)
			end
		end
	end
	local report = session.hotReload:restart(scripts)
	local reloads = session.mcpReloads or {}
	summary.ok = report ~= nil
	summary.requested = #scripts
	summary.restarted = report and #report.instances or 0
	summary.lastReload = reloads[#reloads]
	local broken = {}
	for _, instance in ipairs(scripts) do
		local entry = session.hotReload.broken[instance]
		if entry then
			table.insert(broken, { instance = instance, path = pathOf(instance), error = tostring(entry.compileError) })
		end
	end
	summary.broken = broken
	return summary
end

local function encodeValue(session, value)
	return ValueCodec.encode(value, function(reference)
		local id = session.stableId:idOf(reference)
		if id == nil and alive(reference) and session:isObserved(reference) then
			id = session:idFor(reference)
		end
		return id
	end)
end

function McpFacade.record(session, args)
	local summary = McpFacade.stateSummary(session)
	summary.recorded = 0
	summary.failed = {}
	summary.skipped = {}
	if session.state ~= STATES.RUNNING and session.state ~= STATES.STARTING then
		summary.ok = false
		summary.reason = TEXTS.NOT_RUNNING
		return summary
	end
	for _, item in ipairs(type(args.items) == "table" and args.items or {}) do
		local target = type(item) == "table" and item.target or nil
		if not alive(target) then
			table.insert(summary.skipped, { path = target and pathOf(target) or "?", reason = "instancia nao existe" })
		else
			local verdict = McpFacade.verifyOne(session, target)
			if verdict.runtime or verdict.cloneOf then
				table.insert(summary.skipped, { path = verdict.path, reason = verdict.reason })
			elseif verdict.observed == false then
				table.insert(summary.skipped, { path = verdict.path, reason = TEXTS.MCP_REASON_IGNORED })
			else
				local id = session:idFor(target)
				local path = pathOf(target)
				for _, property in ipairs(type(item.properties) == "table" and item.properties or {}) do
					property = tostring(property)
					if property ~= Constants.PROPERTY_NAMES.SOURCE and property ~= "Parent" then
						local okRead, value = pcall(function()
							return target[property]
						end)
						local encoded, encodeError = nil, nil
						if okRead then
							encoded, encodeError = encodeValue(session, value)
						else
							encodeError = value
						end
						if encoded then
							session:recordAuthoring(KINDS.PROPERTY, { id = id, path = path, property = property, value = encoded, origin = ORIGINS.MCP })
							summary.recorded += 1
						else
							table.insert(summary.failed, { path = path, property = property, reason = tostring(encodeError) })
						end
					end
				end
				for _, name in ipairs(type(item.attributes) == "table" and item.attributes or {}) do
					name = tostring(name)
					if name ~= Constants.STABLE_ID_ATTRIBUTE then
						local encoded, encodeError = encodeValue(session, target:GetAttribute(name))
						if encoded then
							session:recordAuthoring(KINDS.PROPERTY, { id = id, path = path, property = name, attribute = true, value = encoded, origin = ORIGINS.MCP })
							summary.recorded += 1
						else
							table.insert(summary.failed, { path = path, attribute = name, reason = tostring(encodeError) })
						end
					end
				end
			end
		end
	end
	summary.ok = #summary.failed == 0
	if summary.recorded > 0 then
		session:emitMcp(BRIDGE.EVENTS.RECORD, { recorded = summary.recorded })
	end
	return summary
end

local function encodePreview(value)
	if value == nil then
		return nil
	end
	local ok, text = pcall(function()
		return HttpService:JSONEncode(value)
	end)
	return preview(ok and text or tostring(value))
end

function McpFacade.journal(session, args)
	local summary = McpFacade.stateSummary(session)
	local journal = session.journal
	if not journal or not summary.live then
		summary.entries = {}
		summary.total = 0
		summary.nextSince = integer(args.since, 0, 0, 2 ^ 31)
		return summary
	end
	local since = integer(args.since, 0, 0, 2 ^ 31)
	local limit = integer(args.limit, BRIDGE.JOURNAL_DEFAULT_LIMIT, 1, BRIDGE.JOURNAL_MAX_LIMIT)
	local kind = type(args.kind) == "string" and args.kind ~= "all" and args.kind or nil
	local origin = type(args.origin) == "string" and args.origin ~= "all" and args.origin or nil
	local contains = type(args.contains) == "string" and args.contains ~= "" and string.lower(args.contains) or nil
	local matched = {}
	for _, entry in ipairs(journal.entries) do
		if entry.seq > since and (kind == nil or entry.kind == kind) and (origin == nil or entry.origin == origin) then
			if contains == nil or string.find(string.lower(tostring(entry.path)), contains, 1, true) then
				table.insert(matched, entry)
			end
		end
	end
	local first = since > 0 and 1 or math.max(1, #matched - limit + 1)
	local out = {}
	for index = first, math.min(#matched, first + limit - 1) do
		local entry = matched[index]
		table.insert(out, {
			seq = entry.seq,
			kind = entry.kind,
			at = entry.at,
			id = entry.id,
			path = entry.path,
			origin = entry.origin,
			property = entry.property,
			attribute = entry.attribute == true or nil,
			className = entry.className,
			value = encodePreview(entry.value),
			sourceLength = entry.source and #entry.source or entry.sourceLength,
			beforeHash = entry.beforeHash,
			afterHash = entry.afterHash,
		})
	end
	local last = out[#out]
	summary.entries = out
	summary.total = journal:count()
	summary.matched = #matched
	summary.nextSince = last and last.seq or since
	summary.closed = journal.closed == true
	return summary
end

function McpFacade.output(session, args)
	local summary = McpFacade.stateSummary(session)
	local log = session.deps.output
	local since = integer(args.since, 0, 0, 2 ^ 31)
	local limit = integer(args.limit, BRIDGE.OUTPUT_DEFAULT_LIMIT, 1, BRIDGE.OUTPUT_MAX_LIMIT)
	local level = type(args.level) == "string" and args.level ~= "all" and args.level or nil
	local contains = type(args.contains) == "string" and args.contains ~= "" and string.lower(args.contains) or nil
	local matched = {}
	for _, entry in ipairs(log:all()) do
		local seq = entry.seq or 0
		if seq > since and (level == nil or entry.kind == level) then
			if contains == nil or string.find(string.lower(entry.text), contains, 1, true) then
				table.insert(matched, entry)
			end
		end
	end
	local first = since > 0 and 1 or math.max(1, #matched - limit + 1)
	local out = {}
	for index = first, math.min(#matched, first + limit - 1) do
		local entry = matched[index]
		table.insert(out, { seq = entry.seq, kind = entry.kind, time = entry.time, text = entry.text })
	end
	local last = out[#out]
	summary.entries = out
	summary.nextSince = last and last.seq or since
	summary.errors = log:count(OUTPUT_KINDS.ERROR)
	summary.warnings = log:count(OUTPUT_KINDS.WARN)
	return summary
end

function McpFacade.resyncGui(session)
	local summary = McpFacade.stateSummary(session)
	if not session.guiSync then
		summary.ok = false
		summary.reason = "sem jogador virtual ativo (sessao parada ou Modo Compatibilidade)"
		return summary
	end
	summary.ok = true
	summary.remounted = session.guiSync:remountAll()
	return summary
end

return McpFacade
