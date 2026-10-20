local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Root = script.Parent.Parent
local Constants = require(Root.Core.Constants)
local Capabilities = require(Root.Core:FindFirstChild(Constants.MODULE_NAMES.CAPABILITIES))
local Slicer = require(Root.Core.Slicer)
local Traversal = require(Root.Core.Traversal)
local TeamLock = require(Root.Core.TeamLock)
local TeamMonitor = require(Root.Core.TeamMonitor)
local Logger = require(Root.Diagnostics.Logger)
local Budget = require(Root.Diagnostics.Budget)
local LoadAudit = require(Root.Diagnostics.LoadAudit)
local Journal = require(Root.Journal.Journal)
local JournalStore = require(Root.Journal.JournalStore)
local Recovery = require(Root.Journal.Recovery)
local Replay = require(Root.Journal.Replay)
local ValueCodec = require(Root.Journal.ValueCodec)
local StableId = require(Root.Authoring.StableId)
local SourceWatcher = require(Root.Authoring.SourceWatcher)
local InstanceWatcher = require(Root.Authoring.InstanceWatcher)
local AuthoringChannel = require(Root.Authoring.AuthoringChannel)
local EditorAttribution = require(Root.Authoring.EditorAttribution)
local WorldSnapshot = require(Root.World.WorldSnapshot)
local WorldRestore = require(Root.World.WorldRestore)
local PhysicsDriver = require(Root.World.PhysicsDriver)
local TouchedSet = require(Root.World.TouchedSet)
local Relink = require(Root.World.Relink)
local ResourceTracker = require(Root.Runtime.ResourceTracker)
local InstanceProxy = require(Root.Runtime.InstanceProxy)
local Environment = require(Root.Runtime.Environment)
local ModuleRegistry = require(Root.Runtime.ModuleRegistry)
local ScriptHost = require(Root.Runtime.ScriptHost)
local HotReload = require(Root.Runtime.HotReload)
local ScriptStateWatcher = require(Root.Runtime.ScriptStateWatcher)
local RunPolicy = require(Root.Runtime.RunPolicy)
local RunServiceShim = require(Root.Runtime.RunServiceShim)
local SimulationSignals = require(Root.Runtime.SimulationSignals)
local FrameLoop = require(Root.Runtime.FrameLoop)
local AnimationDriver = require(Root.Runtime.AnimationDriver)
local EditModeShim = require(Root.Runtime.EditModeShim)
local MessagingShim = require(Root.Runtime.MessagingShim)
local TeleportShim = require(Root.Runtime.TeleportShim)
local MarketplaceShim = require(Root.Runtime.MarketplaceShim)
local TextChatShim = require(Root.Runtime.TextChatShim)
local RemoteBridge = require(Root.Runtime.RemoteBridge)
local LiveSessionApi = require(Root.Runtime.LiveSessionApi)
local ApiScan = require(Root.Runtime.ApiScan)
local CompatibilityRuntime = require(Root.Runtime.CompatibilityRuntime)
local VirtualPlayer = require(Root.Client.VirtualPlayer)
local InputBridge = require(Root.Client.InputBridge)
local CharacterController = require(Root.Client.CharacterController)
local VirtualCamera = require(Root.Client.VirtualCamera)
local ProximityPromptDriver = require(Root.Client.ProximityPromptDriver)
local InputSignals = require(Root.Client.InputSignals)
local MouseRay = require(Root.Client.MouseRay)
local KickOverlay = require(Root.Client.KickOverlay)
local ChatWindow = require(Root.Client.ChatWindow)
local ContextActionShim = require(Root.Client.ContextActionShim)
local ClickDetectorDriver = require(Root.Client.ClickDetectorDriver)
local ToolDriver = require(Root.Client.ToolDriver)
local Hotbar = require(Root.Client.Hotbar)
local CoreGuiShim = require(Root.Client.CoreGuiShim)
local StarterGuiSync = require(Root.Client.StarterGuiSync)

local Session = {}
Session.__index = Session

local STATES = Constants.STATES
local WARNINGS = Constants.WARNINGS
local OPTIONS = Constants.OPTIONS
local TEXTS = Constants.TEXTS
local UI = Constants.UI
local KINDS = Constants.ENTRY_KINDS
local CLASSIFICATIONS = Constants.CLASSIFICATIONS
local ORIGINS = Constants.ORIGINS
local PROPERTIES = Constants.PROPERTY_NAMES
local STATUS_KEYS = Constants.STATUS_KEYS
local ENGINES = Constants.ENGINES
local LEVELS = Constants.DEGRADATION_LEVELS
local COST_KEYS = Constants.COST_KEYS
local CONTEXTS = Constants.CONTEXTS
local TEAM = Constants.TEAM_CREATE
local PLAYER_MEMBERS = Constants.PLAYER_MEMBERS
local PRIORITIES = Constants.INPUT.PRIORITIES
local LIFECYCLE = Constants.LIFECYCLE
local FIRST_START_WARNINGS = { WARNINGS.SAVE_WARNING_FIRST_START, WARNINGS.EXTERNAL_API_RISK }

local function listText(items)
	local shown = {}
	for index = 1, math.min(#items, TEXTS.LIST_MAX_ITEMS) do
		table.insert(shown, items[index])
	end
	local text = table.concat(shown, TEXTS.LIST_SEPARATOR)
	if #items > TEXTS.LIST_MAX_ITEMS then
		text ..= string.format(TEXTS.LIST_TRUNCATED, #items - TEXTS.LIST_MAX_ITEMS)
	end
	return text
end

local function resolveContainers()
	local containers = {}
	for _, name in ipairs(Constants.GAME_CONTAINERS) do
		local ok, service = pcall(game.GetService, game, name)
		if ok and service then
			table.insert(containers, service)
		end
	end
	return containers
end

function Session.new(deps)
	local store = JournalStore.new(deps.plugin)
	local self = setmetatable({
		deps = deps,
		state = STATES.IDLE,
		listeners = {},
		logger = Logger.new(Constants.PLUGIN_NAME),
		store = store,
		engine = store:readEngine(game.PlaceId),
		stableId = StableId.new(),
		containers = resolveContainers(),
		transitioning = false,
		pluginFolder = nil,
		team = deps.team,
		teamActive = false,
		collaboratorEntries = 0,
		watchingAll = false,
		lastForeign = nil,
		mcpListeners = {},
		mcpReloads = {},
		mcpReloadSeq = 0,
		mcpApplied = setmetatable({}, { __mode = "k" }),
	}, Session)
	if self.team then
		self.team:onSummary(function(summary, previous)
			self:onTeamSummary(summary, previous)
		end)
	end
	return self
end

function Session:isTeamCreate()
	return self.teamActive
end

function Session:teamUserId()
	return self.team.identity.userId
end

function Session:onStateChanged(callback)
	table.insert(self.listeners, callback)
end

function Session:setState(state)
	self.state = state
	for _, listener in ipairs(self.listeners) do
		listener(state)
	end
end

function Session:toggle()
	if self.state == STATES.IDLE then
		self:start()
	elseif self.state == STATES.RUNNING then
		self:stop()
	end
end

function Session:isCompatibility()
	return self.engine == ENGINES.COMPATIBILITY
end

function Session:setEngine(engine)
	if self.state == STATES.IDLE then
		self.store:writeEngine(game.PlaceId, engine)
		self.engine = engine
	end
	return self.engine
end

function Session:isPluginFolder(instance)
	return instance == self.pluginFolder or (self:isTeamCreate() and TeamLock.isLockFolder(instance))
end

 
 
function Session:isToolRoot(instance)
	return instance.Parent == ServerStorage and Constants.MCP_BRIDGE.IGNORED_TOOL_FOLDERS[instance.Name] == true
end

function Session:isToolFolder(instance)
	local root = instance
	while root.Parent and root.Parent ~= ServerStorage and root.Parent ~= game do
		root = root.Parent
	end
	return self:isToolRoot(root)
end

function Session:onMcpEvent(callback)
	table.insert(self.mcpListeners, callback)
end

function Session:emitMcp(kind, data)
	for _, listener in ipairs(self.mcpListeners) do
		task.spawn(function()
			pcall(listener, kind, data)
		end)
	end
end

function Session:isObserved(instance)
	local folder = self.pluginFolder
	if folder ~= nil and (instance == folder or instance:IsDescendantOf(folder)) then
		return false
	end
	if self:isToolFolder(instance) then
		return false
	end
	if self:isTeamCreate() then
		local root = instance
		while root.Parent and root.Parent ~= ServerStorage and root.Parent ~= game do
			root = root.Parent
		end
		if TeamLock.isLockFolder(root) then
			return false
		end
	end
	return true
end

local function topContainerName(instance)
	local container = instance
	while container.Parent and container.Parent ~= game do
		container = container.Parent
	end
	return container.Parent == game and container.Name or nil
end

function Session:isServerContainer(instance)
	if Constants.SERVER_SCRIPT_CONTAINERS[topContainerName(instance)] == true then
		return true
	end
	return self.virtualPlayer ~= nil and self.virtualPlayer:ownsServerContainer(instance)
end

function Session:isReplicatedContainer(instance)
	if Constants.CLIENT.RUN_CONTEXT_CONTAINERS[topContainerName(instance)] == true then
		return self:isObserved(instance)
	end
	return self.virtualPlayer ~= nil and self.virtualPlayer:owns(instance)
end

function Session:isClientPlace(instance)
	if Constants.CLIENT.LOCAL_SCRIPT_CONTAINERS[topContainerName(instance)] == true then
		return true
	end
	return self.virtualPlayer ~= nil and self.virtualPlayer:owns(instance)
end

function Session:createPluginFolder()
	local folder = ServerStorage:FindFirstChild(Constants.PLUGIN_FOLDER_NAME)
	if not folder then
		folder = Instance.new(Constants.CLASS_NAMES.FOLDER)
		folder.Name = Constants.PLUGIN_FOLDER_NAME
		folder.Parent = ServerStorage
	end
	return folder
end

function Session:progress(label, done, total)
	self.deps.status:set(STATUS_KEYS.PROGRESS, string.format(TEXTS.PROGRESS_FORMAT, label, done, total))
end

function Session:runSliced(budget, work)
	Slicer.new(budget):run(work, function(label, done, total)
		self:progress(label, done, total)
	end)
	self.deps.status:set(STATUS_KEYS.PROGRESS, nil)
end

function Session:start()
	if self.transitioning or self.state ~= STATES.IDLE then
		return
	end
	self.transitioning = true
	task.spawn(function()
		local ok, err = pcall(self.runStart, self)
		if not ok then
			self.logger:error(tostring(err))
			pcall(self.rollback, self)
			self.deps.gate:raise(WARNINGS.START_FAILED, tostring(err))
			self:setState(STATES.IDLE)
		end
		self.transitioning = false
	end)
end

function Session:runStart()
	self:setState(STATES.PREFLIGHT)
	if not self:preflight() then
		self:setState(STATES.IDLE)
		return
	end
	self:setState(STATES.STARTING)
	self:prepare()
	if not self:claimTeamLock() then
		self:setState(STATES.IDLE)
		return
	end
	self:assignIdsAndWatch()
	if self:isCompatibility() then
		self:startWatchers()
		self.compatibility:start()
	else
		self:takeSnapshot()
		self:startWatchers()
		self.frameLoop:start()
		self:startScripts()
		if self.capabilities.stepPhysics then
			self.physics:start()
		end
	end
	self:setState(STATES.RUNNING)
	self.deps.status:set(STATUS_KEYS.SESSION, self.sessionId)
	self.deps.status:set(STATUS_KEYS.ENGINE, TEXTS.ENGINE_LABELS[self.engine])
	self:startLoop()
	self.logger:info(TEXTS.SESSION_STARTED, self.sessionId)
end

function Session:preflight()
	local gate = self.deps.gate
	self.teamActive = self.team ~= nil and self.team:isActive()
	self.capabilities = Capabilities.detect(self.deps.plugin)
	local missing = Capabilities.missingRequired(self.capabilities)
	if #missing > 0 then
		gate:raiseAndWait(WARNINGS.MISSING_CAPABILITY, table.concat(missing, TEXTS.LIST_SEPARATOR))
		return false
	end
	for _, text in ipairs(self.capabilities.fallbacks) do
		gate:raise(WARNINGS.CAPABILITY_FALLBACK, text)
	end
	if self:isCompatibility() and not self.capabilities.runMode then
		self.engine = ENGINES.HOSTED
	end
	if self:isTeamCreate() and self:isCompatibility() then
		self.engine = ENGINES.HOSTED
		gate:raise(WARNINGS.CAPABILITY_FALLBACK, TEXTS.TEAM_NO_COMPAT)
	end
	if self:isTeamCreate() and not self:checkForeignLock() then
		return false
	end
	local lock = self.store:readLock()
	if lock and lock.alive then
		gate:raiseAndWait(WARNINGS.LOCK_ALIVE, lock.sessionId)
		return false
	end
	local detection = Recovery.detect(self.store)
	if detection then
		self:describeTeamOwner(detection)
		self:recover(detection)
		return false
	end
	local warnings = table.clone(FIRST_START_WARNINGS)
	if self:isTeamCreate() then
		table.insert(warnings, WARNINGS.TEAM_CREATE)
	end
	if self:isCompatibility() then
		table.insert(warnings, WARNINGS.COMPAT_MODE)
	end
	for _, warning in ipairs(warnings) do
		if not self.store:isAcknowledged(warning.code) then
			gate:raiseAndWait(warning)
			self.store:acknowledge(warning.code)
		end
	end
	return true
end

function Session:checkForeignLock()
	local foreign = TeamLock.foreign(self:teamUserId())
	if foreign then
		local detail = TeamLock.describe(foreign) .. UI.LINE_SEPARATOR .. string.format(TEXTS.TEAM_STALE_HINT, TEAM.STALE_SECONDS)
		self.deps.gate:raiseAndWait(WARNINGS.TEAM_SESSION_ACTIVE, detail)
		return false
	end
	return true
end

function Session:describeTeamOwner(detection)
	if not self:isTeamCreate() or not detection.pluginFolder then
		return
	end
	local lock = TeamLock.read(detection.pluginFolder, self:teamUserId())
	if lock then
		detection.ownerText = string.format(TEXTS.RECOVERY_OWNER_FORMAT, TeamLock.describe(lock))
	end
end

function Session:claimTeamLock()
	if not self:isTeamCreate() then
		return true
	end
	TeamLock.write(self.pluginFolder, self.team.identity, self.sessionId, self.startedAt)
	if not self.team:othersPresent() then
		return true
	end
	task.wait(TEAM.CLAIM_SETTLE_SECONDS)
	local winner = TeamLock.pickWinner(TeamLock.all(self:teamUserId()))
	if winner and winner.mine and winner.folder == self.pluginFolder then
		return true
	end
	if winner and winner.folder == self.pluginFolder then
		self:detachSharedFolder()
	end
	self:rollback()
	if winner then
		self.deps.gate:raise(WARNINGS.TEAM_CLAIM_LOST, TeamLock.describe(winner))
	else
		self.deps.gate:raise(WARNINGS.TEAM_LOCK_LOST, string.format(TEXTS.TEAM_FOLDER_REMOVED, Constants.PLUGIN_FOLDER_NAME))
	end
	return false
end

function Session:detachSharedFolder()
	self.pluginFolder = nil
	self.snapshot = nil
	self.restore = nil
	self.store:setMirrorParent(nil)
end

function Session:verifyTeamLock()
	local folder = self.pluginFolder
	if folder.Parent ~= ServerStorage then
		return string.format(TEXTS.TEAM_FOLDER_REMOVED, Constants.PLUGIN_FOLDER_NAME)
	end
	local lock = TeamLock.read(folder, self:teamUserId())
	if lock and not lock.mine then
		return string.format(TEXTS.TEAM_TAKEN_BY, TeamLock.describe(lock))
	end
	TeamLock.heartbeat(folder)
	return nil
end

function Session:abandon(detail)
	self.transitioning = true
	self:setState(STATES.STOPPING)
	pcall(self.stopRuntime, self)
	self.journal:close()
	self.store:setMirrorParent(nil)
	pcall(self.flushJournal, self)
	pcall(self.store.archive, self.store, self.journal)
	self.store:clearLock()
	self.pluginFolder = nil
	self.stableId:resetIndex()
	self.deps.gate:raise(WARNINGS.TEAM_LOCK_LOST, detail)
	self.logger:warn(detail)
	self:setState(STATES.IDLE)
	self.transitioning = false
end

function Session:teamText()
	local summary = self.team:current()
	if not summary then
		return nil
	end
	return TeamMonitor.describe(summary, self.collaboratorEntries)
end

function Session:teamThrottled()
	return self:isTeamCreate() and self.team:othersPresent()
end

function Session:onTeamSummary(summary, previous)
	self.deps.status:set(STATUS_KEYS.TEAM, TeamMonitor.describe(summary, self.collaboratorEntries))
	local foreign = TeamMonitor.foreignOf(summary)
	local foreignUserId = foreign and foreign.userId or nil
	if foreignUserId ~= self.lastForeign then
		if foreign then
			self.deps.status:pushAlert(string.format(TEXTS.TEAM_FOREIGN_STARTED, foreign.name))
		elseif previous and previous.lock then
			self.deps.status:pushAlert(string.format(TEXTS.TEAM_FOREIGN_ENDED, previous.lock.name))
		end
		self.lastForeign = foreignUserId
	end
	if self.state ~= STATES.RUNNING then
		return
	end
	local joined = previous == nil or #summary.collaborators > #previous.collaborators
	if joined and #summary.collaborators > 0 then
		self:reportCollaborators(summary)
	end
	self:applyDegradation(self.budget:degradationLevel())
	if #summary.collaborators > 0 and not self.watchingAll then
		task.spawn(function()
			self:watchAllProperties()
		end)
	end
end

function Session:reportCollaborators(summary)
	local names = listText(TeamMonitor.namesOf(summary))
	self.deps.gate:raise(WARNINGS.TEAM_COLLABORATORS, string.format(TEXTS.TEAM_COLLABORATORS_FORMAT, #summary.collaborators, names, summary.withPlugin))
end

function Session:recordAuthoring(kind, entry)
	self.journal:append(kind, entry)
	if entry.origin == ORIGINS.COLLABORATOR then
		self.collaboratorEntries += 1
	end
	self:scheduleFlush()
end

function Session:scheduleFlush()
	if self.flushPending then
		return
	end
	self.flushPending = true
	task.defer(function()
		self.flushPending = false
		if self:isLive() then
			self:flushJournal()
		end
	end)
end

function Session:isLive()
	return self.state == STATES.RUNNING or self.state == STATES.STARTING
end

function Session:watchAllProperties()
	if self.watchingAll or not self:isLive() then
		return
	end
	self.watchingAll = true
	if self.observedCount > TEAM.WATCH_MAX_INSTANCES then
		self.deps.gate:raise(WARNINGS.TEAM_WATCH_LIMIT, string.format(TEXTS.TEAM_WATCH_LIMIT_FORMAT, self.observedCount, TEAM.WATCH_MAX_INSTANCES))
		return
	end
	self:runSliced(self.budget, function(job)
		Traversal.descendants(self.containers, function(instance)
			return self:isPluginFolder(instance) or self:isToolRoot(instance)
		end, function(instance)
			if self:isLive() and not self.tracker:isHostedInstance(instance) then
				self.instanceWatcher:watchProperties(instance)
			end
		end, job, TEXTS.PROGRESS_WATCH)
	end)
end

function Session:recover(detection)
	if self:isTeamCreate() and not self:checkForeignLock() then
		return
	end
	self:setState(STATES.RECOVERING)
	local gate = self.deps.gate
	local warning = detection.savedMidSession and WARNINGS.PLACE_SAVED_MID_SESSION or WARNINGS.UNFINISHED_JOURNAL
	local choice = gate:ask(warning, Recovery.describe(detection), { OPTIONS.RECOVER_NOW, OPTIONS.KEEP_FOR_LATER })
	if choice ~= OPTIONS.RECOVER_NOW then
		return
	end
	local journal = detection.journal
	local pluginFolder = detection.pluginFolder or self:createPluginFolder()
	local restore = WorldRestore.new(pluginFolder, self.containers, self.stableId)
	local snapshot = WorldSnapshot.existing(pluginFolder, self.containers)
	local budget = Budget.new(Constants.SLICE_BUDGET_MS)
	local report = nil
	local relinkReport = nil
	self:runSliced(budget, function(job)
		if journal then
			report = restore:run(snapshot, journal, job)
		end
		relinkReport = restore:cleanup(job)
	end)
	if journal then
		journal:close()
		pcall(self.store.archive, self.store, journal)
	else
		self.store:clear()
	end
	self.store:clearLock()
	pluginFolder:Destroy()
	self.stableId:resetIndex()
	gate:raiseAndWait(WARNINGS.RECOVERY_DONE, Recovery.describe(detection, report))
	if report and report.unresolvedFolder then
		gate:raise(WARNINGS.UNRESOLVED_AUTHORING, string.format(TEXTS.UNRESOLVED_FORMAT, report.unresolvedCount, report.unresolvedFolder:GetFullName()))
	end
	self:reportRelink(relinkReport)
end

function Session:prepareHosts()
	self.tracker = ResourceTracker.new()
	self.touched = TouchedSet.new(self.containers)
	self.proxy = InstanceProxy.new(self.tracker, self.budget, function(instance)
		self.touched:markRuntime(instance)
	end)
	self.api = LiveSessionApi.new(self.tracker, function(owner, err)
		self.deps.status:pushError(string.format(TEXTS.RELOAD_CALLBACK_FAILED, owner.instance and owner.instance:GetFullName() or tostring(owner.name), tostring(err)))
	end)
	self.registry = ModuleRegistry.new()
	self.clientRegistry = ModuleRegistry.new()
	self.environment = Environment.new(self.tracker, self.proxy, self.registry, self.api)
	self.clientEnvironment = Environment.new(self.tracker, self.proxy, self.clientRegistry, self.api)
	self.host = ScriptHost.new(self.environment, self.tracker, self.registry, SourceWatcher.readSource, RunPolicy.server(function(instance)
		return self:isServerContainer(instance)
	end), COST_KEYS.SERVER, CONTEXTS.SERVER)
	self.clientHost = ScriptHost.new(self.clientEnvironment, self.tracker, self.clientRegistry, SourceWatcher.readSource, RunPolicy.client(function(instance)
		return self:isClientPlace(instance)
	end, function(instance)
		return self:isReplicatedContainer(instance)
	end), COST_KEYS.CLIENT, CONTEXTS.CLIENT)
	self.hosts = { self.host, self.clientHost }
	self.simulationSignals = SimulationSignals.new(self.tracker)
	RunServiceShim.install(self.proxy, self.simulationSignals)
	self.editModeShim = EditModeShim.new(self.proxy, self.tracker, function()
		return self.virtualPlayer:property(PLAYER_MEMBERS.LOCALE_ID)
	end)
	self.editModeShim:install()
	self.messagingShim = MessagingShim.new(self.proxy, self.tracker)
	self.messagingShim:install()
	self.animationDriver = AnimationDriver.new(function(message)
		self.deps.status:pushError(message)
	end)
	self.proxy:addBridge(self.animationDriver:bridge())
	self.registry:setHost(self.host)
	self.clientRegistry:setHost(self.clientHost)
end

function Session:prepareClient()
	local getPlayer = function()
		return self.virtualPlayer.playerProxy
	end
	local getCharacter = function()
		return self.virtualPlayer.character
	end
	local getMouse = function()
		return self.deps.plugin:GetMouse()
	end
	self.remoteBridge = RemoteBridge.new(self.tracker, self.proxy, getPlayer, function(remote)
		self.deps.status:pushError(string.format(TEXTS.REMOTE_TIMEOUT_STATUS, remote:GetFullName()))
	end)
	self.proxy:addBridge(self.remoteBridge:bridge())
	self.kickOverlay = KickOverlay.new(function()
		return self.virtualPlayer.root
	end)
	self.virtualPlayer = VirtualPlayer.new({
		plugin = self.deps.plugin,
		proxy = self.proxy,
		tracker = self.tracker,
		onScripts = function(pairs_)
			self:launchClones(pairs_)
		end,
		onError = function(message)
			self.deps.status:pushError(message)
		end,
		onKick = function(message)
			self.kickOverlay:show(message)
		end,
	})
	self.teleportShim = TeleportShim.new(self.proxy, self.tracker, getPlayer, function(message)
		self.deps.output:error(string.format(TEXTS.TELEPORT_STUDIO_FAILED, message))
	end)
	self.teleportShim:install()
	self.marketplaceShim = MarketplaceShim.new(self.proxy, self.tracker, {
		getPlayer = getPlayer,
		getUserId = function()
			return self.virtualPlayer.userId
		end,
		confirm = function(detail)
			return self.deps.gate:ask(WARNINGS.TEST_PURCHASE, detail, { OPTIONS.BUY_TEST, OPTIONS.CANCEL }) == OPTIONS.BUY_TEST
		end,
		setMembership = function(membership)
			self.virtualPlayer.members.write(PLAYER_MEMBERS.MEMBERSHIP_TYPE, membership)
		end,
		warn = function(text)
			self.deps.output:warn(text)
		end,
	})
	self.marketplaceShim:install()
	self.textChatShim = TextChatShim.new(self.tracker, self.proxy, getPlayer, function(message)
		self.virtualPlayer:chat(message)
	end)
	self.inputBridge = InputBridge.new(self.deps.plugin, function()
		self.deps.status:pushAlert(TEXTS.INPUT_RELEASED)
	end)
	self.inputSignals = InputSignals.new(self.tracker, self.proxy)
	self.inputSignals:install()
	self.inputBridge:addListener(PRIORITIES.GAME_SIGNALS, self.inputSignals:listener())
	self.contextActions = ContextActionShim.new(self.tracker, self.proxy)
	self.contextActions:install()
	self.inputBridge:addListener(PRIORITIES.CONTEXT_ACTIONS, self.contextActions:listener())
	self.coreGuiShim = CoreGuiShim.new(self.tracker, self.proxy, { textChat = self.textChatShim })
	self.coreGuiShim:install()
	self:prepareDrivers(getPlayer, getCharacter, getMouse)
end

function Session:prepareDrivers(getPlayer, getCharacter, getMouse)
	self.mouseRay = MouseRay.new(getCharacter)
	self.virtualCamera = VirtualCamera.new(self.proxy)
	self.controller = CharacterController.new(self.inputBridge, self.capabilities, self.virtualCamera)
	self.promptDriver = ProximityPromptDriver.new({
		proxy = self.proxy,
		tracker = self.tracker,
		input = self.inputBridge,
		getPlayer = getPlayer,
		getCharacter = getCharacter,
	})
	self.promptDriver:install()
	self.clickDetectorDriver = ClickDetectorDriver.new({
		proxy = self.proxy,
		tracker = self.tracker,
		input = self.inputBridge,
		mouseRay = self.mouseRay,
		getCharacter = getCharacter,
		getPlayer = getPlayer,
		getMouse = getMouse,
	})
	self.clickDetectorDriver:install()
	self.hotbar = Hotbar.new({ coreGui = self.coreGuiShim })
	self.toolDriver = ToolDriver.new({
		proxy = self.proxy,
		tracker = self.tracker,
		input = self.inputBridge,
		getCharacter = getCharacter,
		getPlayer = getPlayer,
		getMouse = getMouse,
		getBackpack = function()
			return self.virtualPlayer.backpack
		end,
		onCharacterChanged = function(callback)
			self.virtualPlayer:onCharacterChanged(callback)
		end,
		hotbar = self.hotbar,
		contextActions = self.contextActions,
		capabilities = self.capabilities,
	})
	self.toolDriver:install()
	self.chatWindow = ChatWindow.new({
		textChat = self.textChatShim,
		coreGui = self.coreGuiShim,
		input = self.inputBridge,
	})
end

function Session:prepareHotReload()
	self.hotReload = HotReload.new(self:isCompatibility() and {} or self.hosts, SourceWatcher.readSource, {
		beforeApply = function(instance, source, afterHash, beforeHash)
			self.loadIssues[instance] = nil
			self:journalSource(instance, source, afterHash, beforeHash)
		end,
		onStatus = function(instance, status, detail)
			local issue = string.format(TEXTS.LOAD_ERROR_FORMAT, status, tostring(detail))
			self.loadIssues[instance] = issue
			self.deps.status:pushError(string.format(TEXTS.RELOAD_STATUS_FORMAT, instance:GetFullName(), issue))
		end,
		onReport = function(report)
			self:reportReload(report)
		end,
		onBrokenTooLong = function(instance, compileError, seconds)
			self.deps.gate:raise(WARNINGS.BROKEN_SCRIPT, string.format(TEXTS.BROKEN_FORMAT, instance:GetFullName(), seconds, tostring(compileError)))
		end,
		onApiFindings = function(instance, findings)
			self:reportApiFindings(instance, findings)
		end,
	})
end

function Session:prepareWorld()
	local isObserved = function(instance)
		return self:isObserved(instance)
	end
	self.sourceWatcher = SourceWatcher.new(isObserved, self.capabilities)
	self.scriptStateWatcher = ScriptStateWatcher.new(isObserved)
	self.instanceWatcher = InstanceWatcher.new(self.containers, isObserved)
	self.attribution = EditorAttribution.new(self.tracker, self.touched, function(instance)
		return instance.Parent == game
	end, function()
		return self.team ~= nil and self.team:othersPresent()
	end)
	self.channel = AuthoringChannel.new(self.tracker, self.touched, function(instance)
		return self.instanceWatcher:isSelected(instance)
	end, self.capabilities, self.attribution)
	self.snapshot = WorldSnapshot.new(self.pluginFolder, self.containers)
	self.restore = WorldRestore.new(self.pluginFolder, self.containers, self.stableId)
	self.compatibility = CompatibilityRuntime.new(self.pluginFolder)
	self.physics = PhysicsDriver.new(function(message)
		self.deps.status:pushError(message)
	end, function(milliseconds)
		self.budget:addCost(COST_KEYS.PHYSICS, milliseconds)
	end)
	self.frameLoop = FrameLoop.new(self.simulationSignals, self.physics, self.animationDriver)
	self.budget:onDegradationChanged(function(level)
		self:applyDegradation(level)
	end)
end

function Session:prepare()
	self.sessionId = string.format(Constants.SESSION_ID_FORMAT, os.date(Constants.SESSION_ID_DATE_FORMAT), math.random(0, Constants.SESSION_ID_RANDOM_MAX))
	self.startedAt = os.time()
	self.journal = Journal.new({ sessionId = self.sessionId, placeId = game.PlaceId, startedAt = self.startedAt })
	self.pluginFolder = self:createPluginFolder()
	self.store:setMirrorParent(self.pluginFolder)
	self.store:setMirrorInterval(self:isTeamCreate() and TEAM.MIRROR_INTERVAL_SECONDS or 0)
	self.store:writeLock(self.sessionId, game.PlaceId)
	self.collaboratorEntries = 0
	self.flushPending = false
	self.watchingAll = false
	self.observedCount = 0
	self.degraded = false
	self.journalChars = 0
	self.journalLargeWarned = false
	self.memoryWarned = false
	self.memoryBaselineKb = gcinfo()
	self.apiFindings = {}
	self.ambiguous = {}
	self.ambiguousByKey = {}
	self.undoWarned = false
	self.lastOrigin = {}
	self.runtimeScripts = setmetatable({}, { __mode = "k" })
	self.scriptsToStart = {}
	self.loadIssues = {}
	self.cloneOrigins = {}
	self.cloneEdits = {}
	self.runtimeEdits = setmetatable({}, { __mode = "k" })
	self.nonArchivable = {}
	self.mcpReloads = {}
	self.mcpReloadSeq = 0
	self.mcpApplied = setmetatable({}, { __mode = "k" })
	self.fps = 0
	self.statusRefreshSeconds = Constants.STATUS_REFRESH_SECONDS
	self.budget = Budget.new(Constants.SLICE_BUDGET_MS)
	self:prepareHosts()
	self:prepareClient()
	self:prepareHotReload()
	self:prepareWorld()
	self.deps.status:clearLists()
	self.deps.output:clear()
	self.deps.output:capture()
	self:flushJournal()
end

function Session:assignIdsAndWatch()
	self:runSliced(self.budget, function(job)
		Traversal.descendants(self.containers, function(instance)
			return self:isPluginFolder(instance) or self:isToolRoot(instance)
		end, function(instance)
			self.observedCount += 1
			self.stableId:assign(instance)
			self.touched:registerBody(instance)
			if not instance[PROPERTIES.ARCHIVABLE] then
				table.insert(self.nonArchivable, instance:GetFullName())
			end
			if Constants.SCRIPT_CLASSES[instance.ClassName] then
				self.sourceWatcher:watch(instance)
				self.scriptStateWatcher:watch(instance)
				self.hotReload:seed(instance, SourceWatcher.readSource(instance))
				if instance:IsA(Constants.CLASS_NAMES.BASE_SCRIPT) then
					table.insert(self.scriptsToStart, instance)
				end
			end
		end, job, TEXTS.PROGRESS_IDS)
	end)
end

function Session:takeSnapshot()
	self:runSliced(self.budget, function(job)
		self.snapshot:capture(job)
	end)
	if #self.nonArchivable > 0 then
		self.deps.gate:raise(WARNINGS.NON_ARCHIVABLE, string.format(TEXTS.NON_ARCHIVABLE_LIST, #self.nonArchivable, listText(self.nonArchivable)))
	end
end

function Session:measured(callback)
	return function(...)
		return self.budget:measure(COST_KEYS.WATCHERS, callback, ...)
	end
end

function Session:startWatchers()
	self.channel:start(function(label)
		if not self.undoWarned then
			self.undoWarned = true
			self.deps.gate:raise(WARNINGS.UNDO_DURING_SESSION, label)
		end
	end)
	self.sourceWatcher:start(self:measured(function(instance, origin)
		local original = self.cloneOrigins[instance]
		if original then
			self:reportCloneEdit(instance, original)
			return
		end
		if self.runtimeScripts[instance] then
			self:reportRuntimeEdit(instance)
		end
		self.lastOrigin[instance] = origin
		self.hotReload:schedule(instance)
	end))
	self.scriptStateWatcher:start(self:measured(function(instance, property)
		local classification = self.channel:classifyProperty(instance, property)
		self.hotReload:refresh(instance, classification ~= CLASSIFICATIONS.RUNTIME)
	end))
	self.instanceWatcher:start({
		onAdded = self:measured(function(instance)
			self:onInstanceAdded(instance)
		end),
		onRemoving = self:measured(function(instance)
			self:onInstanceRemoving(instance)
		end),
		onPropertyChanged = self:measured(function(instance, property)
			self:onPropertyChanged(instance, property)
		end),
	})
	if self:isTeamCreate() then
		local summary = self.team:current()
		if summary and #summary.collaborators > 0 then
			self:reportCollaborators(summary)
		end
		if self.team:othersPresent() then
			self:watchAllProperties()
		end
	end
end

function Session:startScripts()
	self.virtualPlayer:prepare()
	self.textChatShim:install()
	self:runSliced(self.budget, function(job)
		local total = #self.scriptsToStart * #self.hosts
		local done = 0
		for _, host in ipairs(self.hosts) do
			for _, instance in ipairs(self.scriptsToStart) do
				if instance.Parent ~= nil and not host:isRunning(instance) and host:shouldRun(instance) then
					self.hotReload:launch(host, instance)
				end
				done += 1
				job.checkpoint(TEXTS.PROGRESS_SCRIPTS, done, total)
			end
		end
	end)
	task.wait(Constants.CLIENT_JOIN_DELAY_SECONDS)
	self:startClient()
	self:auditLoad()
end

function Session:launchClones(pairs_)
	for _, pair in ipairs(pairs_) do
		for _, host in ipairs(self.hosts) do
			host:bindClone(pair.clone, pair.original)
		end
		self.cloneOrigins[pair.clone] = pair.original
		self.sourceWatcher:watch(pair.clone)
	end
	for _, pair in ipairs(pairs_) do
		for _, host in ipairs(self.hosts) do
			if host:shouldRun(pair.clone) and not host:isRunning(pair.clone) then
				self.hotReload:launch(host, pair.clone)
			end
		end
	end
end

function Session:auditLoad()
	local audit = LoadAudit.new(self.hosts, function(instance)
		return self.loadIssues[instance]
	end)
	for _, instance in ipairs(self.scriptsToStart) do
		if instance.Parent ~= nil then
			audit:add(instance)
		end
	end
	local output = self.deps.output
	local counts = audit.counts
	local summary = string.format(TEXTS.LOAD_SUMMARY, counts.running, counts[CONTEXTS.SERVER], counts[CONTEXTS.CLIENT], counts.failed, counts.disabled, counts.skipped)
	if counts.failed > 0 then
		output:warn(summary)
	else
		output:info(summary)
	end
	for _, item in ipairs(audit.failed) do
		output:error(string.format(TEXTS.LOAD_FAILED_FORMAT, item.path, item.detail))
	end
	for _, item in ipairs(audit.notStarted) do
		output:error(string.format(TEXTS.LOAD_NOT_STARTED_FORMAT, item.path, item.detail))
	end
	if #audit.skipped > 0 then
		output:info(string.format(TEXTS.LOAD_SKIPPED_LIST, listText(audit.skipped)))
	end
	if counts.failed > 0 then
		output:attention()
	end
end

function Session:reportRuntimeEdit(instance)
	if self.runtimeEdits[instance] then
		return
	end
	self.runtimeEdits[instance] = true
	self.deps.output:warn(string.format(TEXTS.RUNTIME_EDIT_FORMAT, instance:GetFullName()))
	self.deps.output:attention()
end

function Session:reportCloneEdit(clone, original)
	if self.cloneEdits[clone] then
		return
	end
	self.cloneEdits[clone] = original
	self.deps.output:warn(string.format(TEXTS.CLONE_EDIT_FORMAT, clone:GetFullName(), original:GetFullName()))
	self.deps.output:attention()
end

function Session:collectCloneEdits()
	local edits = {}
	for clone, original in pairs(self.cloneEdits) do
		if clone.Parent ~= nil and original.Parent ~= nil then
			local source = SourceWatcher.readSource(clone)
			if source ~= SourceWatcher.readSource(original) then
				table.insert(edits, { original = original, source = source, path = original:GetFullName() })
			end
		end
	end
	table.sort(edits, function(left, right)
		return left.path < right.path
	end)
	return edits
end

function Session:chooseCloneEdits(edits)
	if #edits == 0 then
		return edits
	end
	local paths = {}
	for _, edit in ipairs(edits) do
		table.insert(paths, edit.path)
	end
	local detail = string.format(TEXTS.CLONE_EDITS_DETAIL, #edits, listText(paths))
	local choice = self.deps.gate:ask(WARNINGS.CLONE_EDITS, detail, { OPTIONS.COPY_TO_ORIGINALS, OPTIONS.DISCARD })
	if choice == OPTIONS.COPY_TO_ORIGINALS then
		return edits
	end
	self.deps.output:warn(string.format(TEXTS.CLONE_EDITS_DISCARDED, #edits))
	return {}
end

function Session:applyCloneEdits(edits)
	if #edits == 0 then
		return
	end
	for _, edit in ipairs(edits) do
		if edit.original.Parent ~= nil then
			SourceWatcher.writeSource(edit.original, edit.source)
		end
	end
	self.deps.output:info(string.format(TEXTS.CLONE_EDITS_COPIED, #edits))
end

function Session:startClient()
	self.inputBridge:start()
	self.controller:start(self.virtualPlayer)
	self.kickOverlay:hide()
	self.virtualPlayer:spawn()
	local root = self.virtualPlayer.root
	self.coreGuiShim:start(root)
	self.hotbar:start(root)
	self.chatWindow:start(root)
	self.promptDriver:start(root)
	self.clickDetectorDriver:start()
	self.toolDriver:start()
	self:startGuiSync()
end

function Session:startGuiSync()
	if self.guiSync then
		self.guiSync:stop()
	end
	self.guiSync = StarterGuiSync.new({
		tracker = self.tracker,
		guiMount = self.virtualPlayer.guiMount,
		hosts = self.hosts,
		isRuntime = function(instance)
			return self.tracker:currentOwner() ~= nil or self.tracker:isHostedInstance(instance)
		end,
		onScripts = function(pairs_)
			self:launchClones(pairs_)
		end,
		onSynced = function(original, mode)
			local path = original:GetFullName()
			self.deps.output:info(string.format(TEXTS.GUI_SYNC_FORMAT, path, mode))
			self:emitMcp(Constants.MCP_BRIDGE.EVENTS.GUI_SYNC, { path = path, mode = mode })
		end,
		onRemoved = function(original)
			local path = original:GetFullName()
			self.deps.output:info(string.format(TEXTS.GUI_SYNC_REMOVED_FORMAT, path))
			self:emitMcp(Constants.MCP_BRIDGE.EVENTS.GUI_SYNC, { path = path, removed = true })
		end,
		onError = function(message)
			self.deps.output:warn(message)
		end,
	})
	self.guiSync:start()
end

function Session:shutdown(module, methodName)
	if module == nil then
		return
	end
	local ok, err = pcall(module[methodName], module)
	if not ok then
		self.deps.output:error(string.format(TEXTS.SHUTDOWN_FAILED, tostring(err)))
	end
end

function Session:stopClient()
	if self.guiSync then
		self:shutdown(self.guiSync, LIFECYCLE.STOP)
		self.guiSync = nil
	end
	self:shutdown(self.toolDriver, LIFECYCLE.STOP)
	self:shutdown(self.clickDetectorDriver, LIFECYCLE.STOP)
	self:shutdown(self.promptDriver, LIFECYCLE.STOP)
	self:shutdown(self.chatWindow, LIFECYCLE.STOP)
	self:shutdown(self.hotbar, LIFECYCLE.STOP)
	self:shutdown(self.coreGuiShim, LIFECYCLE.CLEAR)
	self:shutdown(self.controller, LIFECYCLE.STOP)
	self:shutdown(self.inputBridge, LIFECYCLE.STOP)
	self:shutdown(self.kickOverlay, LIFECYCLE.HIDE)
	self:shutdown(self.virtualPlayer, LIFECYCLE.DESTROY)
	self:shutdown(self.contextActions, LIFECYCLE.CLEAR)
	self:shutdown(self.inputSignals, LIFECYCLE.CLEAR)
	self:shutdown(self.textChatShim, LIFECYCLE.CLEAR)
	self:shutdown(self.remoteBridge, LIFECYCLE.CLEAR)
	self:shutdown(self.teleportShim, LIFECYCLE.CLEAR)
	self:shutdown(self.marketplaceShim, LIFECYCLE.CLEAR)
	self:shutdown(self.messagingShim, LIFECYCLE.CLEAR)
	self:shutdown(self.api, LIFECYCLE.CLEAR)
	self:shutdown(self.proxy, LIFECYCLE.CLEAR_BRIDGES)
end

function Session:startLoop()
	task.spawn(function()
		local lastLock = os.clock()
		local lastStatus = os.clock()
		local fpsWindow = os.clock()
		local frames = 0
		while self.state == STATES.RUNNING do
			local deltaSeconds = RunService.Heartbeat:Wait()
			if self.state ~= STATES.RUNNING then
				break
			end
			self.budget:observeFrame(deltaSeconds)
			frames += 1
			local now = os.clock()
			if now - fpsWindow >= Constants.FPS_SAMPLE_SECONDS then
				self.fps = frames
				frames = 0
				fpsWindow = now
			end
			if now - lastLock >= Constants.LOCK_HEARTBEAT_SECONDS then
				pcall(self.store.writeLock, self.store, self.sessionId, game.PlaceId)
				lastLock = now
				if self:isTeamCreate() and not self.transitioning then
					local lost = self:verifyTeamLock()
					if lost then
						self:abandon(lost)
						break
					end
				end
			end
			if now - lastStatus >= self.statusRefreshSeconds then
				self:refreshStatus()
				lastStatus = now
			end
		end
	end)
end

function Session:physicsText()
	if self:isCompatibility() then
		return TEXTS.PHYSICS_NATIVE
	end
	if self.physics:isRunning() then
		return string.format(TEXTS.PHYSICS_FORMAT, self.physics:rate())
	end
	return TEXTS.PHYSICS_OFF
end

function Session:refreshStatus()
	local status = self.deps.status
	local counts = self.tracker:counts()
	local costs = self.budget:costReport()
	status:set(STATUS_KEYS.FPS, self.fps)
	status:set(STATUS_KEYS.PHYSICS, self:physicsText())
	status:set(STATUS_KEYS.SCRIPTS, self.host:runningCount() + self.clientHost:runningCount())
	status:set(STATUS_KEYS.RELOADS, self.hotReload.count)
	status:set(STATUS_KEYS.RESOURCES, string.format(TEXTS.RESOURCES_FORMAT, counts.connections, counts.threads, counts.instances))
	status:set(STATUS_KEYS.JOURNAL, string.format(TEXTS.JOURNAL_FORMAT, self.journal:count(), math.floor(self.journalChars / Constants.KILOBYTES_PER_MEGABYTE), self.degraded and TEXTS.JOURNAL_DEGRADED_SUFFIX or UI.EMPTY_TEXT))
	status:set(STATUS_KEYS.CLIENT, self.virtualPlayer.active and self.virtualPlayer:status() or TEXTS.CLIENT_OFF)
	local remotes = self.remoteBridge:counts()
	status:set(STATUS_KEYS.REMOTES, string.format(TEXTS.REMOTES_FORMAT, remotes.remotes, remotes.handlers, remotes.timeouts))
	status:set(STATUS_KEYS.COSTS, string.format(TEXTS.COSTS_FORMAT, costs[COST_KEYS.PHYSICS], costs[COST_KEYS.SERVER], costs[COST_KEYS.CLIENT], costs[COST_KEYS.WATCHERS]))
	if self:isTeamCreate() then
		status:set(STATUS_KEYS.TEAM, self:teamText())
	end
	self:refreshMemory()
end

function Session:refreshMemory()
	local usedKb = gcinfo()
	local growthMb = math.floor((usedKb - self.memoryBaselineKb) / Constants.KILOBYTES_PER_MEGABYTE)
	self.deps.status:set(STATUS_KEYS.MEMORY, string.format(TEXTS.MEMORY_FORMAT, math.floor(usedKb / Constants.KILOBYTES_PER_MEGABYTE), growthMb))
	if growthMb > Constants.MEMORY_GROWTH_WARN_MB and not self.memoryWarned then
		self.memoryWarned = true
		self.deps.gate:raise(WARNINGS.MEMORY_GROWTH, string.format(TEXTS.MEMORY_WARN_FORMAT, growthMb, Constants.MEMORY_GROWTH_WARN_MB))
	end
end

function Session:degradationText(level)
	if level == LEVELS.NONE then
		if self:teamThrottled() then
			return string.format(TEXTS.DEGRADATION_TEAM, self.physics:rate())
		end
		return TEXTS.DEGRADATION_NONE
	end
	local prefix = string.format(TEXTS.DEGRADATION_PREFIX, Constants.DEGRADE_FRAME_MS, Constants.DEGRADE_WINDOW_SECONDS)
	return prefix .. string.format(TEXTS.DEGRADATION_LEVELS[level], self.physics:rate(), Constants.RELOAD_DEBOUNCE_DEGRADED_SECONDS, Constants.STATUS_REFRESH_DEGRADED_SECONDS)
end

function Session:applyDegradation(level)
	self.physics:setDegraded(level >= LEVELS.PHYSICS or self:teamThrottled())
	self.hotReload:setDebounce(level >= LEVELS.RELOAD and Constants.RELOAD_DEBOUNCE_DEGRADED_SECONDS or Constants.RELOAD_DEBOUNCE_SECONDS)
	self.statusRefreshSeconds = level >= LEVELS.GUI and Constants.STATUS_REFRESH_DEGRADED_SECONDS or Constants.STATUS_REFRESH_SECONDS
	self.deps.status:set(STATUS_KEYS.DEGRADATION, self:degradationText(level))
end

function Session:reportReload(report)
	local label = #report.instances == 1 and report.instances[1].Name or string.format(TEXTS.BATCH_LABEL_FORMAT, #report.instances)
	local released = report.released.connections + report.released.threads + report.released.instances
	self.budget:addCost(COST_KEYS.WATCHERS, report.elapsedMs)
	self.deps.status:set(STATUS_KEYS.LAST_RELOAD, string.format(TEXTS.RELOAD_REPORT, label, report.affected, report.elapsedMs, released))
	self:rememberReload(report, label)
end

 
 
function Session:rememberReload(report, label)
	local now = os.clock()
	local paths = {}
	for index, instance in ipairs(report.instances) do
		self.mcpApplied[instance] = now
		if index <= Constants.MCP_BRIDGE.LIST_MAX then
			table.insert(paths, instance:GetFullName())
		end
	end
	self.mcpReloadSeq += 1
	local summary = {
		seq = self.mcpReloadSeq,
		at = os.time(),
		label = label,
		paths = paths,
		count = #report.instances,
		affected = report.affected,
		swapped = report.swapped,
		elapsedMs = math.floor(report.elapsedMs * 10 + 0.5) / 10,
		released = {
			connections = report.released.connections,
			threads = report.released.threads,
			instances = report.released.instances,
		},
		restart = report.restart == true,
	}
	table.insert(self.mcpReloads, summary)
	if #self.mcpReloads > Constants.MCP_BRIDGE.RELOAD_HISTORY then
		table.remove(self.mcpReloads, 1)
	end
	self:emitMcp(Constants.MCP_BRIDGE.EVENTS.RELOAD, summary)
end

function Session:reportApiFindings(instance, findings)
	if self:isCompatibility() then
		return
	end
	for _, finding in ipairs(findings) do
		local key = instance:GetFullName() .. finding.api
		if not self.apiFindings[key] then
			self.apiFindings[key] = true
			local text = ApiScan.describe(instance, finding)
			self.deps.output:warn(text)
			self.deps.output:attention()
			self.deps.status:addFinding(text)
			self.deps.gate:raise(WARNINGS.UNSUPPORTED_API, text)
		end
	end
end

function Session:flushJournal()
	local settingsOk, settingsError, mirrorOk, mirrorError, chars = self.store:write(self.journal)
	self.journalChars = chars or 0
	if not settingsOk and self.capabilities.pluginSettings and not self.degraded then
		self.degraded = true
		self.deps.gate:raise(WARNINGS.SETTINGS_WRITE_FAILED, tostring(settingsError))
	end
	if not mirrorOk then
		self.logger:warn(tostring(mirrorError))
	end
	if self.journalChars > Constants.JOURNAL_WARN_CHARS and not self.journalLargeWarned then
		self.journalLargeWarned = true
		local kilobytes = Constants.KILOBYTES_PER_MEGABYTE
		self.deps.gate:raise(WARNINGS.JOURNAL_LARGE, string.format(TEXTS.JOURNAL_LARGE_FORMAT, math.floor(self.journalChars / kilobytes), math.floor(Constants.JOURNAL_WARN_CHARS / kilobytes)))
	end
end

function Session:idFor(instance)
	return self.stableId:idOf(instance) or self.stableId:assign(instance)
end

function Session:raiseSourceConflict(instance, recorded, source, afterHash, beforeHash)
	self.deps.gate:raise(WARNINGS.SOURCE_CONFLICT, string.format(TEXTS.CONFLICT_FORMAT, instance:GetFullName(), recorded.afterHash, beforeHash), {
		left = { title = string.format(UI.CONFLICT_LEFT_TITLE, recorded.afterHash), text = recorded.source or TEXTS.SOURCE_COMPACTED },
		right = { title = string.format(UI.CONFLICT_RIGHT_TITLE, afterHash), text = source },
	})
end

function Session:journalSource(instance, source, afterHash, beforeHash)
	if self.runtimeScripts[instance] then
		return
	end
	local id = self:idFor(instance)
	local recorded = self.journal:lastSourceEntry(id)
	if recorded and beforeHash and recorded.afterHash ~= beforeHash then
		self:raiseSourceConflict(instance, recorded, source, afterHash, beforeHash)
	end
	self.journal:append(KINDS.SOURCE, {
		id = id,
		path = instance:GetFullName(),
		beforeHash = beforeHash,
		afterHash = afterHash,
		source = source,
		origin = self.lastOrigin[instance] or ORIGINS.SOURCE,
	})
	self:flushJournal()
end

function Session:recordCreate(instance, origin)
	local parent = instance.Parent
	self:recordAuthoring(KINDS.CREATE, {
		id = self:idFor(instance),
		path = instance:GetFullName(),
		parentId = parent and self.stableId:idOf(parent),
		parentPath = parent and parent:GetFullName(),
		className = instance.ClassName,
		name = instance.Name,
		origin = origin,
	})
	if self.watchingAll then
		self.instanceWatcher:watchProperties(instance)
	end
end

function Session:onInstanceAdded(instance)
	local classification, origin = self.channel:classifyCreate(instance)
	local authoring = classification == CLASSIFICATIONS.AUTHORING
	local isScript = Constants.SCRIPT_CLASSES[instance.ClassName] == true
	if authoring then
		self:recordCreate(instance, origin)
	elseif isScript then
		self.runtimeScripts[instance] = true
	end
	self.touched:mark(instance)
	if isScript then
		self.sourceWatcher:watch(instance)
		self.scriptStateWatcher:watch(instance)
		self.lastOrigin[instance] = origin or ORIGINS.SOURCE
		if authoring then
			self.hotReload:schedule(instance)
		else
			self:launchRuntimeScript(instance)
		end
	end
end

function Session:launchRuntimeScript(instance)
	self.hotReload:seed(instance, SourceWatcher.readSource(instance))
	task.defer(function()
		self.hotReload:refresh(instance)
	end)
end

function Session:onInstanceRemoving(instance)
	local classification, origin = self.channel:classifyDestroy(instance)
	local authoring = classification == CLASSIFICATIONS.AUTHORING
	self.touched:mark(instance)
	if Constants.SCRIPT_CLASSES[instance.ClassName] then
		self.sourceWatcher:unwatch(instance)
		self.scriptStateWatcher:unwatch(instance)
		for _, host in ipairs(self.hosts) do
			if host:isRunning(instance) then
				if authoring then
					host:release(instance)
				else
					host:stop(instance)
				end
			end
		end
	end
	local id = self.stableId:idOf(instance)
	if not id then
		return
	end
	local path = instance:GetFullName()
	if authoring then
		self:recordAuthoring(KINDS.DESTROY, { id = id, path = path, origin = origin })
	elseif classification == CLASSIFICATIONS.AMBIGUOUS then
		table.insert(self.ambiguous, {
			kind = KINDS.DESTROY,
			entry = { id = id, path = path, origin = ORIGINS.REVIEW },
			description = string.format(TEXTS.REVIEW_ITEM_DESTROY, path),
		})
	end
end

function Session:onPropertyChanged(instance, property)
	if property == PROPERTIES.SOURCE then
		return
	end
	self.touched:mark(instance)
	local classification, origin = self.channel:classifyProperty(instance, property)
	if classification == CLASSIFICATIONS.RUNTIME then
		return
	end
	local readOk, value = pcall(function()
		return instance[property]
	end)
	if not readOk then
		return
	end
	local encoded, encodeError = ValueCodec.encode(value, function(target)
		return self.stableId:idOf(target)
	end)
	if not encoded then
		self.logger:warn(tostring(encodeError))
		return
	end
	local id = self:idFor(instance)
	local path = instance:GetFullName()
	local entry = { id = id, path = path, property = property, value = encoded, origin = origin }
	if classification == CLASSIFICATIONS.AUTHORING then
		self:recordAuthoring(KINDS.PROPERTY, entry)
		return
	end
	local key = id .. property
	local existing = self.ambiguousByKey[key]
	if existing then
		existing.entry = entry
	else
		local item = { kind = KINDS.PROPERTY, entry = entry, description = string.format(TEXTS.REVIEW_ITEM_PROPERTY, path, property) }
		self.ambiguousByKey[key] = item
		table.insert(self.ambiguous, item)
	end
end

function Session:stop()
	if self.transitioning or self.state ~= STATES.RUNNING then
		return
	end
	self.transitioning = true
	task.spawn(function()
		local ok, err = pcall(self.runStop, self)
		if not ok then
			self.logger:error(tostring(err))
			self.deps.gate:raise(WARNINGS.STOP_FAILED, tostring(err))
			self:setState(STATES.IDLE)
		end
		self.transitioning = false
	end)
end

function Session:stopRuntime()
	if self.editModeShim then
		self.editModeShim:runCloseCallbacks()
	end
	if self.frameLoop then
		self.frameLoop:stop()
	end
	if self.physics then
		self.physics:stop()
	end
	if self.hotReload then
		self.hotReload:stop()
	end
	if self.sourceWatcher then
		self.sourceWatcher:stop()
	end
	if self.scriptStateWatcher then
		self.scriptStateWatcher:stop()
	end
	if self.instanceWatcher then
		self.instanceWatcher:stop()
	end
	if self.channel then
		self.channel:stop()
	end
	self:stopClient()
	if self.hosts then
		for _, host in ipairs(self.hosts) do
			host:stopAll()
		end
	end
	if self.simulationSignals then
		self.simulationSignals:clear()
	end
	if self.animationDriver then
		self.animationDriver:clear()
	end
	self.deps.output:release()
end

function Session:reviewAmbiguous()
	local kept = self.deps.review:ask(self.ambiguous)
	for _, item in ipairs(kept) do
		item.entry.origin = ORIGINS.REVIEW
		self.journal:append(item.kind, item.entry)
	end
	if #kept > 0 then
		self:flushJournal()
	end
end

function Session:chooseStopMode()
	if self:isCompatibility() or not self.deps.status:wantsFreeze() then
		return Constants.STOP_MODES.REVERT
	end
	local choice = self.deps.gate:ask(WARNINGS.FREEZE_CONFIRM, nil, { OPTIONS.FREEZE, OPTIONS.REVERT })
	return choice == OPTIONS.FREEZE and Constants.STOP_MODES.FREEZE or Constants.STOP_MODES.REVERT
end

function Session:restoreAfterRunMode(job)
	local holder = CompatibilityRuntime.detachedHolder()
	self.restore:quarantineAuthoring(self.journal, holder, job)
	if not self.compatibility:stop() then
		self.deps.gate:raise(WARNINGS.COMPAT_REVERT_FAILED, string.format(Constants.ERRORS.COMPAT_REVERT_TIMEOUT, Constants.COMPAT.REVERT_TIMEOUT_SECONDS))
	end
	return self.restore:replay(self.journal, holder, job)
end

function Session:restoreWorld(mode, job)
	if self:isCompatibility() then
		return self:restoreAfterRunMode(job)
	end
	if mode ~= Constants.STOP_MODES.REVERT then
		return nil
	end
	self.touched:markMovedBodies(job)
	return self.restore:run(self.snapshot, self.journal, job, self.touched)
end

function Session:reportRelink(relinkReport)
	if not relinkReport then
		return
	end
	self.deps.status:pushAlert(Relink.describe(relinkReport))
	if #relinkReport.unresolved > 0 then
		self.deps.gate:raise(WARNINGS.CROSS_REFERENCES, listText(relinkReport.unresolved))
	end
end

function Session:reportStop(report, relinkReport)
	if report then
		if report.swapText then
			self.deps.status:pushAlert(report.swapText)
		end
		self.deps.status:pushAlert(Replay.describe(report))
		if report.unresolvedFolder then
			self.deps.gate:raise(WARNINGS.UNRESOLVED_AUTHORING, string.format(TEXTS.UNRESOLVED_FORMAT, report.unresolvedCount, report.unresolvedFolder:GetFullName()))
		end
	end
	self:reportRelink(relinkReport)
end

function Session:runStop()
	self:setState(STATES.STOPPING)
	local cloneEdits = self:collectCloneEdits()
	self:stopRuntime()
	self:reviewAmbiguous()
	cloneEdits = self:chooseCloneEdits(cloneEdits)
	for _, broken in ipairs(self.hotReload:brokenScripts()) do
		self.deps.gate:raise(WARNINGS.BROKEN_SCRIPT, string.format(TEXTS.LOAD_ERROR_FORMAT, broken.instance:GetFullName(), tostring(broken.compileError)))
	end
	local mode = self:chooseStopMode()
	local report = nil
	local relinkReport = nil
	self:runSliced(self.budget, function(job)
		report = self:restoreWorld(mode, job)
		relinkReport = self.restore:cleanup(job)
	end)
	self:applyCloneEdits(cloneEdits)
	self.journal:close()
	self:flushJournal()
	pcall(self.store.archive, self.store, self.journal)
	self.store:clearLock()
	self.store:setMirrorParent(nil)
	self.pluginFolder:Destroy()
	self.pluginFolder = nil
	self.stableId:resetIndex()
	self:reportStop(report, relinkReport)
	self.logger:info(TEXTS.SESSION_STOPPED, self.sessionId)
	self:setState(STATES.IDLE)
end

function Session:rollback()
	self:stopRuntime()
	if self.compatibility then
		self.compatibility:stop()
	end
	if self.snapshot then
		self.snapshot:discard()
	end
	if self.restore and self.budget then
		self:runSliced(self.budget, function(job)
			self.restore:cleanup(job)
		end)
	end
	self.store:clear()
	self.store:clearLock()
	self.store:setMirrorParent(nil)
	if self.pluginFolder then
		self.pluginFolder:Destroy()
		self.pluginFolder = nil
	end
	self.stableId:resetIndex()
end

function Session:unload()
	if self.state == STATES.RUNNING then
		self:stopRuntime()
		if self.compatibility then
			self.compatibility:stop()
		end
	end
end

return Session
