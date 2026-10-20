local Constants = require(script.Parent.Parent.Core.Constants)

local Hotbar = {}
Hotbar.__index = Hotbar

local HOTBAR = Constants.HOTBAR
local THEME = Constants.UI
local COLORS = THEME.COLORS
local CLASSES = Constants.CLASS_NAMES
local EMPTY = THEME.EMPTY_TEXT

local function corner(parent)
	local instance = Instance.new(CLASSES.UI_CORNER)
	instance.CornerRadius = UDim.new(0, THEME.CORNER_RADIUS)
	instance.Parent = parent
end

function Hotbar.new(deps)
	return setmetatable({
		deps = deps,
		gui = nil,
		bar = nil,
		tooltip = nil,
		slots = {},
		equipped = nil,
		onSelected = nil,
		removeCoreGuiListener = nil,
	}, Hotbar)
end

function Hotbar:start(root)
	local gui = Instance.new(CLASSES.SCREEN_GUI)
	gui.Name = HOTBAR.GUI_NAME
	gui.DisplayOrder = HOTBAR.DISPLAY_ORDER
	gui.ResetOnSpawn = false
	local bar = Instance.new(CLASSES.FRAME)
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -HOTBAR.BOTTOM_MARGIN)
	bar.Size = UDim2.fromOffset(0, HOTBAR.SLOT_SIZE)
	bar.AutomaticSize = Enum.AutomaticSize.X
	bar.BackgroundTransparency = 1
	bar.Parent = gui
	local layout = Instance.new(CLASSES.UI_LIST_LAYOUT)
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, HOTBAR.SLOT_GAP)
	layout.Parent = bar
	local tooltip = Instance.new(CLASSES.TEXT_LABEL)
	tooltip.AnchorPoint = Vector2.new(0.5, 1)
	tooltip.Position = UDim2.new(0.5, 0, 1, -(HOTBAR.BOTTOM_MARGIN + HOTBAR.SLOT_SIZE + HOTBAR.TOOLTIP_OFFSET))
	tooltip.AutomaticSize = Enum.AutomaticSize.XY
	tooltip.Size = UDim2.fromOffset(0, THEME.TEXT_SIZE)
	tooltip.BackgroundColor3 = COLORS.PANEL
	tooltip.BorderSizePixel = 0
	tooltip.Font = THEME.FONT
	tooltip.TextSize = THEME.TEXT_SIZE
	tooltip.TextColor3 = COLORS.TEXT
	tooltip.Text = EMPTY
	tooltip.Visible = false
	tooltip.Parent = gui
	corner(tooltip)
	local tooltipPadding = Instance.new(CLASSES.UI_PADDING)
	tooltipPadding.PaddingLeft = UDim.new(0, THEME.GAP)
	tooltipPadding.PaddingRight = UDim.new(0, THEME.GAP)
	tooltipPadding.PaddingTop = UDim.new(0, THEME.GAP)
	tooltipPadding.PaddingBottom = UDim.new(0, THEME.GAP)
	tooltipPadding.Parent = tooltip
	self.gui = gui
	self.bar = bar
	self.tooltip = tooltip
	self:applyVisibility()
	local coreGui = self.deps.coreGui
	if coreGui then
		self.removeCoreGuiListener = coreGui:onChanged(function(coreGuiType)
			if coreGuiType == HOTBAR.CORE_GUI_TYPE then
				self:applyVisibility()
			end
		end)
	end
	gui.Parent = root
end

function Hotbar:applyVisibility()
	local coreGui = self.deps.coreGui
	self.gui.Enabled = coreGui == nil or coreGui:isEnabled(HOTBAR.CORE_GUI_TYPE)
end

function Hotbar:onSlotSelected(callback)
	self.onSelected = callback
end

function Hotbar:buildSlot(tool, index)
	local button = Instance.new(CLASSES.TEXT_BUTTON)
	button.Name = HOTBAR.SLOT_LABELS[index]
	button.Size = UDim2.fromOffset(HOTBAR.SLOT_SIZE, HOTBAR.SLOT_SIZE)
	button.BackgroundColor3 = COLORS.HOTBAR_SLOT
	button.BackgroundTransparency = HOTBAR.SLOT_TRANSPARENCY
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = EMPTY
	button.LayoutOrder = index
	button.Parent = self.bar
	corner(button)
	local number = Instance.new(CLASSES.TEXT_LABEL)
	number.BackgroundTransparency = 1
	number.Position = UDim2.fromOffset(HOTBAR.LABEL_INSET, HOTBAR.LABEL_INSET)
	number.Size = UDim2.fromOffset(HOTBAR.LABEL_TEXT_SIZE, HOTBAR.LABEL_TEXT_SIZE)
	number.Font = THEME.FONT_BOLD
	number.TextSize = HOTBAR.LABEL_TEXT_SIZE
	number.TextColor3 = COLORS.TEXT_MUTED
	number.TextXAlignment = Enum.TextXAlignment.Left
	number.Text = HOTBAR.SLOT_LABELS[index]
	number.Parent = button
	local icon = Instance.new(CLASSES.IMAGE_LABEL)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.new(1, -HOTBAR.ICON_PADDING * 2, 1, -HOTBAR.ICON_PADDING * 2)
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = button
	local name = Instance.new(CLASSES.TEXT_LABEL)
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 1)
	name.Font = THEME.FONT
	name.TextSize = HOTBAR.NAME_TEXT_SIZE
	name.TextColor3 = COLORS.TEXT
	name.TextWrapped = true
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Parent = button
	local slot = { tool = tool, button = button, icon = icon, name = name, connections = {} }
	table.insert(slot.connections, button.Activated:Connect(function()
		if self.onSelected then
			self.onSelected(tool)
		end
	end))
	table.insert(slot.connections, button.MouseEnter:Connect(function()
		self:showTooltip(tool)
	end))
	table.insert(slot.connections, button.MouseLeave:Connect(function()
		self.tooltip.Visible = false
	end))
	table.insert(slot.connections, tool.Changed:Connect(function(property)
		if HOTBAR.WATCHED_PROPERTIES[property] then
			self:refreshSlot(slot)
		end
	end))
	self:refreshSlot(slot)
	return slot
end

function Hotbar:refreshSlot(slot)
	local tool = slot.tool
	local hasTexture = tool.TextureId ~= EMPTY
	slot.icon.Image = tool.TextureId
	slot.icon.Visible = hasTexture
	slot.name.Text = tool.Name
	slot.name.Visible = not hasTexture
	slot.button.BackgroundColor3 = tool == self.equipped and COLORS.HOTBAR_SELECTED or COLORS.HOTBAR_SLOT
	if self.tooltip.Visible then
		self:showTooltip(tool)
	end
end

function Hotbar:showTooltip(tool)
	local text = tool.ToolTip
	self.tooltip.Text = text
	self.tooltip.Visible = text ~= EMPTY
end

function Hotbar:clearSlots()
	for _, slot in ipairs(self.slots) do
		for _, connection in ipairs(slot.connections) do
			connection:Disconnect()
		end
		slot.button:Destroy()
	end
	self.slots = {}
	if self.tooltip then
		self.tooltip.Visible = false
	end
end

function Hotbar:setTools(list)
	if self.gui == nil then
		return
	end
	self:clearSlots()
	for index = 1, math.min(#list, HOTBAR.MAX_SLOTS) do
		table.insert(self.slots, self:buildSlot(list[index], index))
	end
end

function Hotbar:setEquipped(tool)
	self.equipped = tool
	for _, slot in ipairs(self.slots) do
		self:refreshSlot(slot)
	end
end

function Hotbar:stop()
	self:clearSlots()
	if self.removeCoreGuiListener then
		self.removeCoreGuiListener()
		self.removeCoreGuiListener = nil
	end
	if self.gui then
		self.gui:Destroy()
		self.gui = nil
	end
	self.bar = nil
	self.tooltip = nil
	self.equipped = nil
	self.onSelected = nil
end

return Hotbar
