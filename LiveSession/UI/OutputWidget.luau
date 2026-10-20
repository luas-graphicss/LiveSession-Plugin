local Constants = require(script.Parent.Parent.Core.Constants)
local Widgets = require(script.Parent.Widgets)

local OutputWidget = {}
OutputWidget.__index = OutputWidget

local UI = Constants.UI
local OUTPUT = Constants.OUTPUT
local KINDS = OUTPUT.KINDS
local ENABLED = Constants.PROPERTY_NAMES.ENABLED
local FILTER_ORDER = { KINDS.ERROR, KINDS.WARN, KINDS.PRINT }
local FILTER_OF = {
	[KINDS.ERROR] = KINDS.ERROR,
	[KINDS.WARN] = KINDS.WARN,
	[KINDS.PRINT] = KINDS.PRINT,
	[KINDS.INFO] = KINDS.PRINT,
}
local COLOR_OF = {
	[KINDS.ERROR] = UI.COLORS.DANGER,
	[KINDS.WARN] = UI.COLORS.WARNING,
	[KINDS.PRINT] = UI.COLORS.TEXT,
	[KINDS.INFO] = UI.COLORS.TEXT_MUTED,
}

local function filterText(kind, enabled)
	return string.format(UI.OUTPUT_FILTER_FORMAT, enabled and UI.TOGGLE_ON or UI.TOGGLE_OFF, UI.OUTPUT_FILTER_LABELS[kind])
end

function OutputWidget.new(plugin, log)
	local widget, root = Widgets.dockWidget(plugin, UI.OUTPUT_WIDGET_ID, UI.OUTPUT_WIDGET_TITLE, UI.OUTPUT_WIDGET_WIDTH, UI.OUTPUT_WIDGET_HEIGHT, UI.OUTPUT_WIDGET_MIN_WIDTH, UI.OUTPUT_WIDGET_MIN_HEIGHT)
	local self = setmetatable({
		widget = widget,
		root = root,
		log = log,
		lines = {},
		filters = {},
		filterButtons = {},
		order = 0,
	}, OutputWidget)
	self:buildHeader()
	local bodySize = UDim2.new(1, 0, 1, -(UI.BUTTON_HEIGHT + UI.GAP))
	self.copyBox = Widgets.textArea(root, bodySize, 1)
	self.copyBox.Visible = false
	self.copyBox.FocusLost:Connect(function()
		self:endCopy()
	end)
	local body = Widgets.scroll(root, 2)
	body.Size = bodySize
	self.body = body
	self.emptyLabel = Widgets.label(body, UI.OUTPUT_EMPTY_TEXT, { color = UI.COLORS.TEXT_MUTED, order = 0 })
	for _, entry in ipairs(log:all()) do
		self:append(entry)
	end
	log:onEntry(function(entry)
		self:append(entry)
	end)
	log:onCleared(function()
		self:reset()
	end)
	log:onAttention(function()
		self:show()
	end)
	self:refreshSummary()
	return self
end

function OutputWidget:buildHeader()
	local header = Widgets.frame(self.root, UI.COLORS.PANEL, UDim2.new(1, 0, 0, UI.BUTTON_HEIGHT))
	header.BackgroundTransparency = 1
	header.LayoutOrder = 0
	Widgets.list(header, true)
	local controlsWidth = UI.OUTPUT_FILTER_WIDTH * #FILTER_ORDER + UI.OUTPUT_COPY_WIDTH + UI.OUTPUT_CLEAR_WIDTH + UI.GAP * (#FILTER_ORDER + 2)
	self.summary = Widgets.label(header, UI.OUTPUT_EMPTY_TEXT, { color = UI.COLORS.TEXT_MUTED, size = UDim2.new(1, -controlsWidth, 1, 0), order = 0 })
	self.summary.TextYAlignment = Enum.TextYAlignment.Center
	for index, kind in ipairs(FILTER_ORDER) do
		self.filters[kind] = true
		local button = Widgets.button(header, filterText(kind, true), UI.COLORS.PANEL_ALT, function()
			self:toggleFilter(kind)
		end, index)
		button.Size = UDim2.new(0, UI.OUTPUT_FILTER_WIDTH, 1, 0)
		self.filterButtons[kind] = button
	end
	local copyButton = Widgets.button(header, UI.OUTPUT_COPY_TEXT, UI.COLORS.PANEL_ALT, function()
		self:beginCopy()
	end, #FILTER_ORDER + 1)
	copyButton.Size = UDim2.new(0, UI.OUTPUT_COPY_WIDTH, 1, 0)
	local clearButton = Widgets.button(header, UI.OUTPUT_CLEAR_TEXT, UI.COLORS.PANEL_ALT, function()
		self.log:clear()
	end, #FILTER_ORDER + 2)
	clearButton.Size = UDim2.new(0, UI.OUTPUT_CLEAR_WIDTH, 1, 0)
end

function OutputWidget:visibleText()
	local lines = {}
	for _, line in ipairs(self.lines) do
		if line.label.Visible then
			table.insert(lines, line.label.Text)
		end
	end
	return table.concat(lines, UI.LINE_SEPARATOR)
end

function OutputWidget:beginCopy()
	local text = self:visibleText()
	if text == UI.EMPTY_TEXT then
		return
	end
	self.copyBox.Text = text
	self.body.Visible = false
	self.copyBox.Visible = true
	self.summary.Text = UI.OUTPUT_COPY_HINT
	task.defer(function()
		self.copyBox:CaptureFocus()
		self.copyBox.CursorPosition = #text + 1
		self.copyBox.SelectionStart = 1
	end)
end

function OutputWidget:endCopy()
	self.copyBox.Visible = false
	self.body.Visible = true
	self:refreshSummary()
end

function OutputWidget:isAtBottom()
	local body = self.body
	return body.CanvasPosition.Y + body.AbsoluteWindowSize.Y >= body.AbsoluteCanvasSize.Y - UI.OUTPUT_SCROLL_TOLERANCE
end

function OutputWidget:scrollToBottom()
	task.defer(function()
		local body = self.body
		body.CanvasPosition = Vector2.new(0, math.max(0, body.AbsoluteCanvasSize.Y - body.AbsoluteWindowSize.Y))
	end)
end

function OutputWidget:append(entry)
	local followTail = self:isAtBottom()
	self.order += 1
	local label = Widgets.label(self.body, string.format(UI.OUTPUT_LINE_FORMAT, entry.time, entry.text), {
		autoHeight = true,
		size = UDim2.new(1, -UI.GAP, 0, 0),
		color = COLOR_OF[entry.kind] or UI.COLORS.TEXT,
		order = self.order,
	})
	label.Font = UI.MONO_FONT
	label.TextSize = UI.OUTPUT_TEXT_SIZE
	label.Visible = self.filters[FILTER_OF[entry.kind] or KINDS.PRINT] == true
	table.insert(self.lines, { kind = entry.kind, label = label })
	if #self.lines > OUTPUT.CAPACITY then
		local oldest = table.remove(self.lines, 1)
		oldest.label:Destroy()
	end
	self.emptyLabel.Visible = false
	self:refreshSummary()
	if followTail then
		self:scrollToBottom()
	end
end

function OutputWidget:reset()
	for _, line in ipairs(self.lines) do
		line.label:Destroy()
	end
	self.lines = {}
	self.order = 0
	self.emptyLabel.Visible = true
	self:refreshSummary()
end

function OutputWidget:toggleFilter(kind)
	local enabled = not self.filters[kind]
	self.filters[kind] = enabled
	self.filterButtons[kind].Text = filterText(kind, enabled)
	for _, line in ipairs(self.lines) do
		if FILTER_OF[line.kind] == kind then
			line.label.Visible = enabled
		end
	end
end

function OutputWidget:refreshSummary()
	if #self.lines == 0 then
		self.summary.Text = UI.OUTPUT_EMPTY_TEXT
		return
	end
	self.summary.Text = string.format(UI.OUTPUT_SUMMARY_FORMAT, self.log:count(KINDS.ERROR), self.log:count(KINDS.WARN), self.log:size())
end

function OutputWidget:show()
	self.widget.Enabled = true
end

function OutputWidget:togglePanel()
	self.widget.Enabled = not self.widget.Enabled
end

function OutputWidget:isVisible()
	return self.widget.Enabled
end

function OutputWidget:onVisibilityChanged(callback)
	self.widget:GetPropertyChangedSignal(ENABLED):Connect(function()
		callback(self.widget.Enabled)
	end)
end

return OutputWidget
