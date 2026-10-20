local Root = script.Parent
local Constants = require(Root.Core.Constants)
local Session = require(Root.Core.Session)
local TeamCreate = require(Root.Core.TeamCreate)
local TeamMonitor = require(Root.Core.TeamMonitor)
local OutputLog = require(Root.Diagnostics.OutputLog)
local Toolbar = require(Root.UI.Toolbar)
local StatusWidget = require(Root.UI.StatusWidget)
local OutputWidget = require(Root.UI.OutputWidget)
local WarningGate = require(Root.UI.WarningGate)
local StopReview = require(Root.UI.StopReview)
local McpBridge = require(Root.Integration.McpBridge)

local UI = Constants.UI
local STATES = Constants.STATES
local STATE_LABELS = Constants.STATE_LABELS
local STATUS_KEYS = Constants.STATUS_KEYS
local ENGINES = Constants.ENGINES
local TEXTS = Constants.TEXTS
local KINDS = Constants.OUTPUT.KINDS

local outputLog = OutputLog.new()
local statusWidget = StatusWidget.new(plugin)
local outputWidget = OutputWidget.new(plugin, outputLog)
local stopReview = StopReview.new(plugin)

statusWidget:setSink(function(kind, text)
	outputLog:push(kind, text)
end)
statusWidget:bindOutput(function()
	outputWidget:show()
end)

local warningGate = WarningGate.new(function(warning, detail)
	local text = string.format(UI.GATE_TITLE_FORMAT, warning.code, warning.title)
	if detail and detail ~= UI.EMPTY_TEXT then
		text ..= UI.LINE_SEPARATOR .. tostring(detail)
	end
	statusWidget:pushAlert(text)
end)

local team = TeamMonitor.new(TeamCreate.identity())

local session = Session.new({
	plugin = plugin,
	status = statusWidget,
	output = outputLog,
	gate = warningGate,
	review = stopReview,
	team = team,
})

local toolbar = Toolbar.new(plugin, function()
	statusWidget:show()
	session:toggle()
end, function()
	statusWidget:togglePanel()
end, function()
	outputWidget:togglePanel()
end)

statusWidget:bindSession(function()
	session:toggle()
end)

statusWidget:onVisibilityChanged(function(visible)
	toolbar:setPanelActive(visible)
end)

outputWidget:onVisibilityChanged(function(visible)
	toolbar:setOutputActive(visible)
end)

local function refreshOutputRow()
	statusWidget:set(STATUS_KEYS.OUTPUT, string.format(TEXTS.OUTPUT_STATUS_FORMAT, outputLog:count(KINDS.ERROR), outputLog:count(KINDS.WARN)))
end

outputLog:onEntry(refreshOutputRow)
outputLog:onCleared(refreshOutputRow)

session:onStateChanged(function(state)
	toolbar:setState(state)
	statusWidget:setSessionState(state)
	statusWidget:set(STATUS_KEYS.STATE, STATE_LABELS[state] or state)
end)

statusWidget:bindEngine(session:isCompatibility(), function(compatibility)
	return session:setEngine(compatibility and ENGINES.COMPATIBILITY or ENGINES.HOSTED) == ENGINES.COMPATIBILITY
end)

toolbar:setState(STATES.IDLE)
toolbar:setPanelActive(statusWidget:isVisible())
toolbar:setOutputActive(outputWidget:isVisible())
statusWidget:setSessionState(STATES.IDLE)
statusWidget:set(STATUS_KEYS.STATE, STATE_LABELS[STATES.IDLE])
statusWidget:set(STATUS_KEYS.ENGINE, TEXTS.ENGINE_LABELS[session.engine])
statusWidget:set(STATUS_KEYS.TEAM, TEXTS.TEAM_OFF)
refreshOutputRow()
team:start()

 
local bridge = McpBridge.new(session)
local bridgeOk, bridgeError = pcall(bridge.start, bridge)
if not bridgeOk then
	warn("LiveSession: ponte MCP indisponivel -> " .. tostring(bridgeError))
end

plugin.Unloading:Connect(function()
	bridge:stop()
	session:unload()
	outputLog:release()
	team:stop()
end)
