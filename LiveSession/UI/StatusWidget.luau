local Constants = require(script.Parent.Parent.Core.Constants)
local Widgets = require(script.Parent.Widgets)
local FidelityMatrix = require(script.Parent.FidelityMatrix)

local StatusWidget = {}
StatusWidget.__index = StatusWidget

local UI = Constants.UI
local STATES = Constants.STATES
local STATE_LABELS = Constants.STATE_LABELS
local ENABLED = Constants.PROPERTY_NAMES.ENABLED
local KINDS = Constants.OUTPUT.KINDS

local function toggleText(format, enabled)
	return string.format(format, enabled and UI.TOGGLE_ON or UI.TOGGLE_OFF)
end

function StatusWidget.new(plugin)
	local widget, root = Widgets.dockWidget(plugin, UI.WIDGET_ID, UI.WIDGET_TITLE, UI.WIDGET_WIDTH, UI.WIDGET_HEIGHT, UI.WIDGET_MIN_WIDTH, UI.WIDGET_MIN_HEIGHT)
	local self = setmetatable({
		widget = widget,
		root = root,
		values = {},
		errors = {},
		alerts = {},
		freezeOnStop = false,
		compatibilityEngine = false,
		onEngineToggle = nil,
		sessionState = STATES.IDLE,
		onSessionToggle = nil,
		onOpenOutput = nil,
		sink = nil,
	}, StatusWidget)
	self.sessionButton = Widgets.button(root, UI.SESSION_START_TEXT, UI.COLORS.ACCENT, function()
		self:requestSessionToggle()
	end, 0)
	self.sessionButton.Size = UDim2.new(1, 0, 0, UI.PRIMARY_BUTTON_HEIGHT)
	self.sessionButton.TextSize = UI.TITLE_TEXT_SIZE
	local body = Widgets.scroll(root, 1)
	body.Size = UDim2.new(1, 0, 1, -(UI.PRIMARY_BUTTON_HEIGHT + UI.GAP))
	self.body = body
	for order, row in ipairs(UI.STATUS_ROWS) do
		self.values[row.key] = Widgets.row(body, row.label, order)
	end
	local order = #UI.STATUS_ROWS + 1
	self.freezeButton = Widgets.button(body, toggleText(UI.FREEZE_TOGGLE_FORMAT, false), UI.COLORS.PANEL_ALT, function()
		self.freezeOnStop = not self.freezeOnStop
		self.freezeButton.Text = toggleText(UI.FREEZE_TOGGLE_FORMAT, self.freezeOnStop)
	end, order)
	self.engineButton = Widgets.button(body, toggleText(UI.ENGINE_TOGGLE_FORMAT, false), UI.COLORS.PANEL_ALT, function()
		self:toggleEngine()
	end, order + 1)
	Widgets.label(body, UI.ERRORS_LABEL, { bold = true, color = UI.COLORS.DANGER, order = order + 2 })
	self.errorsLabel = Widgets.label(body, UI.EMPTY_VALUE, { autoHeight = true, size = UDim2.new(1, 0, 0, 0), order = order + 3 })
	Widgets.label(body, UI.WARNINGS_LABEL, { bold = true, color = UI.COLORS.ACCENT, order = order + 4 })
	self.alertsLabel = Widgets.label(body, UI.EMPTY_VALUE, { autoHeight = true, size = UDim2.new(1, 0, 0, 0), order = order + 5 })
	self.outputButton = Widgets.button(body, UI.OUTPUT_OPEN_TEXT, UI.COLORS.PANEL_ALT, function()
		if self.onOpenOutput then
			self.onOpenOutput()
		end
	end, order + 6)
	self.fidelity = FidelityMatrix.new(body, order + 7)
	return self
end

function StatusWidget:bindSession(onSessionToggle)
	self.onSessionToggle = onSessionToggle
end

function StatusWidget:bindOutput(onOpenOutput)
	self.onOpenOutput = onOpenOutput
end

function StatusWidget:setSink(sink)
	self.sink = sink
end

function StatusWidget:requestSessionToggle()
	local state = self.sessionState
	if self.onSessionToggle and (state == STATES.IDLE or state == STATES.RUNNING) then
		self.onSessionToggle()
	end
end

function StatusWidget:setSessionState(state)
	self.sessionState = state
	local button = self.sessionButton
	button.AutoButtonColor = state == STATES.IDLE or state == STATES.RUNNING
	if state == STATES.IDLE then
		button.Text = UI.SESSION_START_TEXT
		button.BackgroundColor3 = UI.COLORS.ACCENT
	elseif state == STATES.RUNNING then
		button.Text = UI.SESSION_STOP_TEXT
		button.BackgroundColor3 = UI.COLORS.DANGER
	else
		button.Text = string.format(UI.SESSION_BUSY_FORMAT, STATE_LABELS[state] or state)
		button.BackgroundColor3 = UI.COLORS.PANEL_ALT
	end
end

function StatusWidget:bindEngine(compatibilityEngine, onEngineToggle)
	self.onEngineToggle = onEngineToggle
	self:setEngine(compatibilityEngine)
end

function StatusWidget:setEngine(compatibilityEngine)
	self.compatibilityEngine = compatibilityEngine
	self.engineButton.Text = toggleText(UI.ENGINE_TOGGLE_FORMAT, compatibilityEngine)
end

function StatusWidget:toggleEngine()
	if not self.onEngineToggle then
		return
	end
	self:setEngine(self.onEngineToggle(not self.compatibilityEngine))
end

function StatusWidget:set(key, value)
	local label = self.values[key]
	if label then
		label.Text = value == nil and UI.EMPTY_VALUE or tostring(value)
	end
end

local function pushLimited(list, text, label)
	table.insert(list, 1, text)
	while #list > Constants.STATUS_MAX_ERRORS do
		table.remove(list)
	end
	label.Text = table.concat(list, UI.LINE_SEPARATOR)
end

function StatusWidget:emit(kind, text)
	if self.sink then
		self.sink(kind, text)
	end
end

function StatusWidget:pushError(text)
	pushLimited(self.errors, text, self.errorsLabel)
	self:emit(KINDS.ERROR, text)
end

function StatusWidget:pushAlert(text)
	pushLimited(self.alerts, text, self.alertsLabel)
	self:emit(KINDS.WARN, text)
end

function StatusWidget:addFinding(text)
	self.fidelity:addFinding(text)
end

function StatusWidget:clearLists()
	self.errors = {}
	self.alerts = {}
	self.errorsLabel.Text = UI.EMPTY_VALUE
	self.alertsLabel.Text = UI.EMPTY_VALUE
	self.fidelity:clearFindings()
end

function StatusWidget:wantsFreeze()
	return self.freezeOnStop
end

function StatusWidget:show()
	self.widget.Enabled = true
end

function StatusWidget:togglePanel()
	self.widget.Enabled = not self.widget.Enabled
end

function StatusWidget:isVisible()
	return self.widget.Enabled
end

function StatusWidget:onVisibilityChanged(callback)
	self.widget:GetPropertyChangedSignal(ENABLED):Connect(function()
		callback(self.widget.Enabled)
	end)
end

return StatusWidget
