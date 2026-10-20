local CoreGui = game:GetService("CoreGui")

local Constants = require(script.Parent.Parent.Core.Constants)
local Widgets = require(script.Parent.Widgets)

local WarningGate = {}
WarningGate.__index = WarningGate

local UI = Constants.UI
local SEVERITIES = Constants.SEVERITIES

function WarningGate.new(onAlert)
	return setmetatable({
		onAlert = onAlert,
		queue = {},
		current = nil,
	}, WarningGate)
end

function WarningGate:raise(warning, detail, columns)
	if warning.severity == SEVERITIES.ALERT then
		self.onAlert(warning, detail)
		return
	end
	table.insert(self.queue, { warning = warning, detail = detail, columns = columns, options = { Constants.OPTIONS.CONFIRM }, thread = nil })
	self:showNext()
end

function WarningGate:ask(warning, detail, options)
	local item = { warning = warning, detail = detail, options = options or { Constants.OPTIONS.CONFIRM }, thread = coroutine.running() }
	table.insert(self.queue, item)
	self:showNext()
	return coroutine.yield()
end

function WarningGate:raiseAndWait(warning, detail)
	return self:ask(warning, detail, { Constants.OPTIONS.CONFIRM })
end

function WarningGate:bodyText(item)
	local warning = item.warning
	local parts = { warning.happened, warning.did, warning.action }
	if item.detail and item.detail ~= UI.EMPTY_TEXT then
		table.insert(parts, tostring(item.detail))
	end
	return table.concat(parts, UI.PARAGRAPH_SEPARATOR)
end

local function panelSize(item)
	if item.columns then
		return UI.GATE_WIDE_PANEL_WIDTH, UI.GATE_WIDE_PANEL_HEIGHT
	end
	return UI.GATE_PANEL_WIDTH, UI.GATE_PANEL_HEIGHT
end

local function renderColumn(parent, column, order)
	local frame = Widgets.frame(parent, UI.COLORS.PANEL_ALT, UDim2.new(UI.GATE_COLUMN_WIDTH_SCALE, 0, 1, 0))
	frame.LayoutOrder = order
	Widgets.corner(frame)
	Widgets.padding(frame)
	Widgets.list(frame)
	Widgets.label(frame, column.title, { bold = true, color = UI.COLORS.TEXT_MUTED, order = 1 })
	local scroll = Widgets.scroll(frame, 2)
	scroll.Size = UDim2.new(1, 0, 1, -(UI.ROW_HEIGHT + UI.GAP))
	local text = Widgets.label(scroll, column.text, { autoHeight = true, size = UDim2.new(1, -UI.GAP, 0, 0) })
	text.Font = UI.MONO_FONT
	return frame
end

function WarningGate:renderBody(panel, item, bodyHeightOffset)
	if not item.columns then
		local body = Widgets.scroll(panel, 2)
		body.Size = UDim2.new(1, 0, 1, bodyHeightOffset)
		Widgets.label(body, self:bodyText(item), { autoHeight = true, size = UDim2.new(1, -UI.GAP, 0, 0) })
		return
	end
	local summary = Widgets.label(panel, self:bodyText(item), { autoHeight = true, size = UDim2.new(1, 0, 0, 0), order = 2 })
	local columns = Widgets.frame(panel, UI.COLORS.PANEL, UDim2.new(1, 0, 1, bodyHeightOffset))
	columns.BackgroundTransparency = 1
	columns.LayoutOrder = 3
	local layout = Widgets.list(columns, true)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	renderColumn(columns, item.columns.left, 1)
	renderColumn(columns, item.columns.right, 2)
	summary:GetPropertyChangedSignal(Constants.PROPERTY_NAMES.ABSOLUTE_SIZE):Connect(function()
		columns.Size = UDim2.new(1, 0, 1, bodyHeightOffset - summary.AbsoluteSize.Y - UI.GAP)
	end)
end

function WarningGate:showNext()
	if self.current or #self.queue == 0 then
		return
	end
	local item = table.remove(self.queue, 1)
	self.current = item
	local width, height = panelSize(item)
	local gui = Instance.new(Constants.CLASS_NAMES.SCREEN_GUI)
	gui.Name = UI.GATE_GUI_NAME
	gui.DisplayOrder = UI.GATE_DISPLAY_ORDER
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local backdrop = Widgets.frame(gui, UI.COLORS.BACKDROP, UDim2.new(1, 0, 1, 0))
	backdrop.BackgroundTransparency = UI.BACKDROP_TRANSPARENCY
	backdrop.Active = true
	local panel = Widgets.frame(backdrop, UI.COLORS.PANEL, UDim2.new(0, width, 0, height), UDim2.new(0.5, -width / 2, 0.5, -height / 2))
	panel.Active = true
	Widgets.corner(panel)
	Widgets.padding(panel)
	Widgets.list(panel)
	Widgets.label(panel, string.format(UI.GATE_TITLE_FORMAT, item.warning.code, item.warning.title), {
		bold = true,
		textSize = UI.TITLE_TEXT_SIZE,
		color = item.warning.severity == SEVERITIES.BLOCKING and UI.COLORS.DANGER or UI.COLORS.ACCENT,
		size = UDim2.new(1, 0, 0, UI.BUTTON_HEIGHT),
		order = 1,
	})
	local bodyHeightOffset = -(UI.BUTTON_HEIGHT * 2 + UI.GAP * 2) - (#item.options * (UI.BUTTON_HEIGHT + UI.GAP))
	self:renderBody(panel, item, bodyHeightOffset)
	for index, option in ipairs(item.options) do
		Widgets.button(panel, option, index == 1 and UI.COLORS.ACCENT or UI.COLORS.PANEL_ALT, function()
			self:resolve(gui, item, option)
		end, 3 + index)
	end
	gui.Parent = CoreGui
end

function WarningGate:resolve(gui, item, option)
	if self.current ~= item then
		return
	end
	gui:Destroy()
	self.current = nil
	if item.thread then
		task.spawn(item.thread, option)
	end
	self:showNext()
end

function WarningGate:isShowing()
	return self.current ~= nil
end

return WarningGate
