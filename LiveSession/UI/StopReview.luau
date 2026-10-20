local Constants = require(script.Parent.Parent.Core.Constants)
local Widgets = require(script.Parent.Widgets)

local StopReview = {}
StopReview.__index = StopReview

local UI = Constants.UI
local HEADER_ROWS = 3
local FOOTER_ROWS = 1

function StopReview.new(plugin)
	local widget, root = Widgets.dockWidget(plugin, UI.REVIEW_ID, UI.REVIEW_TITLE, UI.REVIEW_WIDTH, UI.REVIEW_HEIGHT, UI.WIDGET_MIN_WIDTH, UI.WIDGET_MIN_HEIGHT)
	widget.Enabled = false
	return setmetatable({ widget = widget, root = root }, StopReview)
end

local function groupItems(items)
	local groups = {}
	local byPath = {}
	for index, item in ipairs(items) do
		local path = item.entry.path
		local group = byPath[path]
		if not group then
			group = { path = path, indices = {} }
			byPath[path] = group
			table.insert(groups, group)
		end
		table.insert(group.indices, index)
	end
	return groups
end

local function keptCount(group, decisions)
	local count = 0
	for _, index in ipairs(group.indices) do
		if decisions[index] then
			count += 1
		end
	end
	return count
end

local function decisionStyle(kept, total)
	if kept == total then
		return UI.REVIEW_KEEP, UI.COLORS.OK
	elseif kept == 0 then
		return UI.REVIEW_REVERT, UI.COLORS.DANGER
	end
	return UI.REVIEW_MIXED, UI.COLORS.PANEL_ALT
end

local function toggleButton(row, kept, total, onClick)
	local text, color = decisionStyle(kept, total)
	local button = Widgets.button(row, text, color, onClick, 0)
	button.Size = UDim2.new(0.28, 0, 1, 0)
	button.Position = UDim2.new(0.71, 0, 0, 0)
	return button
end

local function matchesFilter(group, filter)
	return filter == UI.EMPTY_TEXT or string.find(string.lower(group.path), string.lower(filter), 1, true) ~= nil
end

function StopReview:renderGroup(list, group, items, decisions, order, rerender)
	local header = Widgets.frame(list, UI.COLORS.PANEL_ALT, UDim2.new(1, -UI.GAP, 0, UI.BUTTON_HEIGHT))
	header.LayoutOrder = order
	Widgets.corner(header)
	Widgets.label(header, string.format(UI.REVIEW_GROUP_FORMAT, group.path, #group.indices), { bold = true, size = UDim2.new(0.7, 0, 1, 0) })
	toggleButton(header, keptCount(group, decisions), #group.indices, function()
		local keepAll = keptCount(group, decisions) < #group.indices
		for _, index in ipairs(group.indices) do
			decisions[index] = keepAll
		end
		rerender()
	end)
	for offset, index in ipairs(group.indices) do
		local row = Widgets.frame(list, UI.COLORS.PANEL, UDim2.new(1, -UI.GAP, 0, UI.BUTTON_HEIGHT))
		row.LayoutOrder = order + offset
		local description = Widgets.label(row, items[index].description, { size = UDim2.new(0.7, -UI.REVIEW_INDENT, 1, 0), color = UI.COLORS.TEXT_MUTED })
		description.Position = UDim2.new(0, UI.REVIEW_INDENT, 0, 0)
		toggleButton(row, decisions[index] and 1 or 0, 1, function()
			decisions[index] = not decisions[index]
			rerender()
		end)
	end
	return order + #group.indices + 1
end

function StopReview:renderList(list, groups, items, decisions, filter)
	for _, child in ipairs(list:GetChildren()) do
		if not child:IsA(Constants.CLASS_NAMES.UI_LIST_LAYOUT) then
			child:Destroy()
		end
	end
	local order = 1
	local rerender = function()
		self:renderList(list, groups, items, decisions, filter)
	end
	for _, group in ipairs(groups) do
		if matchesFilter(group, filter) then
			order = self:renderGroup(list, group, items, decisions, order, rerender)
		end
	end
end

function StopReview:renderBatchRow(order, applyAll)
	local row = Widgets.frame(self.root, UI.COLORS.PANEL, UDim2.new(1, 0, 0, UI.BUTTON_HEIGHT))
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	Widgets.list(row, true)
	local keepAll = Widgets.button(row, UI.REVIEW_KEEP_ALL, UI.COLORS.OK, function()
		applyAll(true)
	end, 1)
	keepAll.Size = UDim2.new(0.5, -UI.GAP / 2, 1, 0)
	local revertAll = Widgets.button(row, UI.REVIEW_REVERT_ALL, UI.COLORS.DANGER, function()
		applyAll(false)
	end, 2)
	revertAll.Size = UDim2.new(0.5, -UI.GAP / 2, 1, 0)
end

function StopReview:ask(items)
	if #items == 0 then
		return items
	end
	local thread = coroutine.running()
	local decisions = {}
	for index in ipairs(items) do
		decisions[index] = true
	end
	local groups = groupItems(items)
	local filter = UI.EMPTY_TEXT
	self.root:ClearAllChildren()
	Widgets.padding(self.root)
	Widgets.list(self.root)
	Widgets.label(self.root, UI.REVIEW_HINT, { color = UI.COLORS.TEXT_MUTED, autoHeight = true, size = UDim2.new(1, 0, 0, 0), order = 1 })
	local list = Widgets.scroll(self.root, 4)
	list.Size = UDim2.new(1, 0, 1, -((HEADER_ROWS + FOOTER_ROWS) * (UI.BUTTON_HEIGHT + UI.GAP)))
	local rerender = function()
		self:renderList(list, groups, items, decisions, filter)
	end
	Widgets.textBox(self.root, UI.REVIEW_FILTER_PLACEHOLDER, 2, function(text)
		filter = text
		rerender()
	end)
	self:renderBatchRow(3, function(keep)
		for _, group in ipairs(groups) do
			if matchesFilter(group, filter) then
				for _, index in ipairs(group.indices) do
					decisions[index] = keep
				end
			end
		end
		rerender()
	end)
	rerender()
	Widgets.button(self.root, UI.REVIEW_DONE, UI.COLORS.ACCENT, function()
		self.widget.Enabled = false
		local kept = {}
		for index, item in ipairs(items) do
			if decisions[index] then
				table.insert(kept, item)
			end
		end
		task.spawn(thread, kept)
	end, 5)
	self.widget.Enabled = true
	return coroutine.yield()
end

return StopReview
