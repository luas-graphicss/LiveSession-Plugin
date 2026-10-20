local CoreGui = game:GetService("CoreGui")

local Root = script.Parent.Parent
local Constants = require(Root.Core.Constants)
local McpFacade = require(script.Parent.McpFacade)

 
 
 
 
 
 
 
local McpBridge = {}
McpBridge.__index = McpBridge

local BRIDGE = Constants.MCP_BRIDGE
local COMMANDS = BRIDGE.COMMANDS
local EVENTS = BRIDGE.EVENTS
local STATES = Constants.STATES

function McpBridge.new(session)
	return setmetatable({
		session = session,
		folder = nil,
		invoke = nil,
		event = nil,
		alive = false,
	}, McpBridge)
end

local function create(className, name, parent)
	local instance = Instance.new(className)
	instance.Name = name
	instance.Archivable = false
	instance.Parent = parent
	return instance
end

function McpBridge:start()
	if self.alive then
		return
	end
	local stale = CoreGui:FindFirstChild(BRIDGE.FOLDER_NAME)
	if stale then
		stale:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = BRIDGE.FOLDER_NAME
	folder.Archivable = false
	self.invoke = create("BindableFunction", BRIDGE.INVOKE_NAME, folder)
	self.event = create("BindableEvent", BRIDGE.EVENT_NAME, folder)
	folder:SetAttribute("Protocol", BRIDGE.PROTOCOL)
	folder:SetAttribute("Version", BRIDGE.VERSION)
	folder:SetAttribute("Plugin", Constants.PLUGIN_NAME)
	self.folder = folder
	self.alive = true
	self.invoke.OnInvoke = function(command, args)
		return self:handle(command, args)
	end
	self:publishState(self.session.state)
	folder.Parent = CoreGui
	self.session:onStateChanged(function(state)
		if not self.alive then
			return
		end
		self:publishState(state)
		self:fire(EVENTS.STATE, McpFacade.stateSummary(self.session))
	end)
	self.session:onMcpEvent(function(kind, data)
		if not self.alive then
			return
		end
		if kind == EVENTS.RELOAD then
			self:publishReloads()
		end
		self:fire(kind, data)
	end)
	task.spawn(function()
		while self.alive do
			local current = self.folder
			if current then
				current:SetAttribute("Heartbeat", os.time())
			end
			task.wait(BRIDGE.HEARTBEAT_SECONDS)
		end
	end)
end

function McpBridge:publishState(state)
	local folder = self.folder
	if not folder then
		return
	end
	local session = self.session
	local live = state == STATES.RUNNING or state == STATES.STARTING or state == STATES.STOPPING
	folder:SetAttribute("State", state)
	folder:SetAttribute("Running", state == STATES.RUNNING)
	folder:SetAttribute("Engine", session.engine)
	folder:SetAttribute("SessionId", live and session.sessionId or nil)
	folder:SetAttribute("StartedAt", live and session.startedAt or nil)
	folder:SetAttribute("ChangedAt", os.time())
	if not live then
		folder:SetAttribute("Reloads", nil)
	end
end

function McpBridge:publishReloads()
	local folder = self.folder
	local hot = self.session.hotReload
	if folder and hot then
		folder:SetAttribute("Reloads", hot.count)
	end
end

function McpBridge:fire(kind, data)
	local event = self.event
	if event then
		pcall(event.Fire, event, kind, data)
	end
end

function McpBridge:handle(command, args)
	args = type(args) == "table" and args or {}
	local session = self.session
	if command == COMMANDS.PING then
		return { ok = true, protocol = BRIDGE.PROTOCOL, version = BRIDGE.VERSION, state = session.state }
	elseif command == COMMANDS.STATUS then
		return McpFacade.status(session, args)
	elseif command == COMMANDS.START then
		return McpFacade.start(session, args)
	elseif command == COMMANDS.STOP then
		return McpFacade.stop(session, args)
	elseif command == COMMANDS.VERIFY then
		return McpFacade.verify(session, args, false)
	elseif command == COMMANDS.AWAIT then
		return McpFacade.verify(session, args, true)
	elseif command == COMMANDS.RESTART then
		return McpFacade.restart(session, args)
	elseif command == COMMANDS.RECORD then
		return McpFacade.record(session, args)
	elseif command == COMMANDS.JOURNAL then
		return McpFacade.journal(session, args)
	elseif command == COMMANDS.OUTPUT then
		return McpFacade.output(session, args)
	elseif command == COMMANDS.RESYNC_GUI then
		return McpFacade.resyncGui(session, args)
	end
	error(string.format(Constants.TEXTS.MCP_UNKNOWN_COMMAND, tostring(command)), 0)
end

function McpBridge:stop()
	self.alive = false
	if self.invoke then
		self.invoke.OnInvoke = nil
	end
	if self.folder then
		pcall(self.folder.Destroy, self.folder)
	end
	self.folder = nil
	self.invoke = nil
	self.event = nil
end

return McpBridge
