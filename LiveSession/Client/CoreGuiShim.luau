local StarterGui = game:GetService("StarterGui")

local Constants = require(script.Parent.Parent.Core.Constants)

local CoreGuiShim = {}
CoreGuiShim.__index = CoreGuiShim

local CORE_GUI = Constants.CORE_GUI
local METHODS = CORE_GUI.METHODS
local FIELDS = CORE_GUI.NOTIFICATION_FIELDS
local THEME = Constants.UI
local COLORS = THEME.COLORS
local CLASSES = Constants.CLASS_NAMES
local TYPES = Constants.TYPE_NAMES
local EMPTY = THEME.EMPTY_TEXT

local function isCoreGuiType(value)
	return typeof(value) == TYPES.ENUM_ITEM and value.EnumType == Enum.CoreGuiType
end

local function stringOr(value, fallback)
	if type(value) == TYPES.STRING then
		return value
	end
	return fallback
end

local function label(parent, text, textSize, color, bold, order)
	local instance = Instance.new(CLASSES.TEXT_LABEL)
	instance.BackgroundTransparency = 1
	instance.Font = bold and THEME.FONT_BOLD or THEME.FONT
	instance.TextSize = textSize
	instance.TextColor3 = color
	instance.TextXAlignment = Enum.TextXAlignment.Left
	instance.TextWrapped = true
	instance.Text = text
	instance.AutomaticSize = Enum.AutomaticSize.Y
	instance.Size = UDim2.new(1, 0, 0, textSize)
	instance.LayoutOrder = order
	instance.Parent = parent
	return instance
end

function CoreGuiShim.new(tracker, proxy, deps)
	local self = setmetatable({
		tracker = tracker,
		proxy = proxy,
		deps = deps or {},
		enabled = {},
		coreValues = {},
		listeners = {},
		gui = nil,
		column = nil,
		timers = {},
	}, CoreGuiShim)
	for _, coreGuiType in ipairs(Enum.CoreGuiType:GetEnumItems()) do
		if coreGuiType ~= CORE_GUI.ALL_TYPE then
			self.enabled[coreGuiType] = true
		end
	end
	return self
end

function CoreGuiShim:isEnabled(coreGuiType)
	if coreGuiType == CORE_GUI.ALL_TYPE then
		for _, enabled in pairs(self.enabled) do
			if not enabled then
				return false
			end
		end
		return true
	end
	return self.enabled[coreGuiType] == true
end

function CoreGuiShim:onChanged(callback)
	table.insert(self.listeners, callback)
	return function()
		local index = table.find(self.listeners, callback)
		if index then
			table.remove(self.listeners, index)
		end
	end
end

function CoreGuiShim:setEnabled(coreGuiType, enabled)
	if not isCoreGuiType(coreGuiType) then
		return
	end
	enabled = enabled == true
	if coreGuiType == CORE_GUI.ALL_TYPE then
		for eachType in pairs(self.enabled) do
			self:setEnabled(eachType, enabled)
		end
		return
	end
	if self.enabled[coreGuiType] == enabled then
		return
	end
	self.enabled[coreGuiType] = enabled
	for _, listener in ipairs(table.clone(self.listeners)) do
		listener(coreGuiType, enabled)
	end
end

function CoreGuiShim:resolveCallback(value)
	local callback = self.proxy:unwrap(value)
	if type(callback) == TYPES.FUNCTION then
		return self.proxy:hostedArgument(callback, self.tracker:currentOwner())
	elseif typeof(callback) == TYPES.INSTANCE and callback:IsA(CORE_GUI.BINDABLE_FUNCTION_CLASS) then
		return function(buttonText)
			return callback:Invoke(buttonText)
		end
	end
	return nil
end

function CoreGuiShim:addButton(row, text, callback, dismiss)
	local button = Instance.new(CLASSES.TEXT_BUTTON)
	button.Size = UDim2.new(0, 0, 0, CORE_GUI.BUTTON_HEIGHT)
	button.AutomaticSize = Enum.AutomaticSize.X
	button.BackgroundColor3 = COLORS.PANEL_ALT
	button.BorderSizePixel = 0
	button.Font = THEME.FONT_BOLD
	button.TextSize = THEME.TEXT_SIZE
	button.TextColor3 = COLORS.TEXT
	button.Text = text
	button.Parent = row
	local corner = Instance.new(CLASSES.UI_CORNER)
	corner.CornerRadius = UDim.new(0, THEME.CORNER_RADIUS)
	corner.Parent = button
	local padding = Instance.new(CLASSES.UI_PADDING)
	padding.PaddingLeft = UDim.new(0, THEME.GAP)
	padding.PaddingRight = UDim.new(0, THEME.GAP)
	padding.Parent = button
	button.Activated:Connect(function()
		dismiss()
		if callback then
			task.spawn(callback, text)
		end
	end)
end

function CoreGuiShim:notify(options)
	if self.column == nil or type(options) ~= TYPES.TABLE then
		return
	end
	local card = Instance.new(CLASSES.FRAME)
	card.Size = CORE_GUI.NOTIFICATION_SIZE
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = COLORS.PANEL
	card.BorderSizePixel = 0
	local corner = Instance.new(CLASSES.UI_CORNER)
	corner.CornerRadius = UDim.new(0, THEME.CORNER_RADIUS)
	corner.Parent = card
	local padding = Instance.new(CLASSES.UI_PADDING)
	padding.PaddingTop = UDim.new(0, THEME.GAP)
	padding.PaddingBottom = UDim.new(0, THEME.GAP)
	padding.PaddingLeft = UDim.new(0, THEME.GAP)
	padding.PaddingRight = UDim.new(0, THEME.GAP)
	padding.Parent = card
	local layout = Instance.new(CLASSES.UI_LIST_LAYOUT)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, THEME.GAP)
	layout.Parent = card
	local icon = stringOr(options[FIELDS.ICON], EMPTY)
	if icon ~= EMPTY then
		local image = Instance.new(CLASSES.IMAGE_LABEL)
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromOffset(CORE_GUI.ICON_SIZE, CORE_GUI.ICON_SIZE)
		image.Image = icon
		image.LayoutOrder = 1
		image.Parent = card
	end
	label(card, stringOr(options[FIELDS.TITLE], EMPTY), THEME.TEXT_SIZE, COLORS.TEXT, true, 2)
	label(card, stringOr(options[FIELDS.TEXT], EMPTY), THEME.TEXT_SIZE, COLORS.TEXT_MUTED, false, 3)
	local timer = nil
	local function dismiss()
		if timer == nil then
			return
		end
		local index = table.find(self.timers, timer)
		if index then
			table.remove(self.timers, index)
		end
		timer = nil
		card:Destroy()
	end
	local callback = self:resolveCallback(options[FIELDS.CALLBACK])
	local buttons = {}
	for _, field in ipairs(CORE_GUI.BUTTON_FIELDS) do
		local text = stringOr(options[field], EMPTY)
		if text ~= EMPTY then
			table.insert(buttons, text)
		end
	end
	if #buttons > 0 then
		local row = Instance.new(CLASSES.FRAME)
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, CORE_GUI.BUTTON_HEIGHT)
		row.LayoutOrder = 4
		row.Parent = card
		local rowLayout = Instance.new(CLASSES.UI_LIST_LAYOUT)
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Padding = UDim.new(0, THEME.GAP)
		rowLayout.Parent = row
		for _, text in ipairs(buttons) do
			self:addButton(row, text, callback, dismiss)
		end
	end
	card.Parent = self.column
	local duration = options[FIELDS.DURATION]
	if type(duration) ~= TYPES.NUMBER then
		duration = CORE_GUI.NOTIFICATION_DURATION
	end
	timer = task.delay(duration, dismiss)
	table.insert(self.timers, timer)
end

function CoreGuiShim:setCore(name, value)
	if name == METHODS.SEND_NOTIFICATION then
		self:notify(value)
	elseif name == METHODS.CHAT_SYSTEM_MESSAGE then
		local textChat = self.deps.textChat
		if textChat and type(value) == TYPES.TABLE and type(value[FIELDS.TEXT]) == TYPES.STRING then
			textChat:displaySystem(value[FIELDS.TEXT])
		end
	elseif table.find(CORE_GUI.STORED_CORES, name) then
		self.coreValues[name] = self.proxy:unwrap(value)
	end
end

function CoreGuiShim:getCore(name)
	local stored = self.coreValues[name]
	if stored ~= nil then
		return stored
	end
	return CORE_GUI.DEFAULTS[name]
end

function CoreGuiShim:install()
	self.proxy:override(StarterGui, {
		[METHODS.SET_CORE] = function()
			return function(_, name, value)
				pcall(self.setCore, self, name, value)
				return nil
			end
		end,
		[METHODS.GET_CORE] = function()
			return function(_, name)
				return self:getCore(name)
			end
		end,
		[METHODS.SET_CORE_GUI_ENABLED] = function()
			return function(_, coreGuiType, enabled)
				self:setEnabled(coreGuiType, enabled)
			end
		end,
		[METHODS.GET_CORE_GUI_ENABLED] = function()
			return function(_, coreGuiType)
				return self:isEnabled(coreGuiType)
			end
		end,
	})
end

function CoreGuiShim:start(root)
	local gui = Instance.new(CLASSES.SCREEN_GUI)
	gui.Name = CORE_GUI.GUI_NAME
	gui.DisplayOrder = CORE_GUI.DISPLAY_ORDER
	gui.ResetOnSpawn = false
	local column = Instance.new(CLASSES.FRAME)
	column.AnchorPoint = Vector2.new(1, 1)
	column.Position = UDim2.new(1, -CORE_GUI.MARGIN, 1, -CORE_GUI.MARGIN)
	column.Size = UDim2.fromOffset(CORE_GUI.NOTIFICATION_SIZE.X.Offset, 0)
	column.AutomaticSize = Enum.AutomaticSize.Y
	column.BackgroundTransparency = 1
	column.Parent = gui
	local layout = Instance.new(CLASSES.UI_LIST_LAYOUT)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, CORE_GUI.NOTIFICATION_GAP)
	layout.Parent = column
	self.gui = gui
	self.column = column
	gui.Parent = root
end

function CoreGuiShim:stop()
	for _, timer in ipairs(self.timers) do
		pcall(task.cancel, timer)
	end
	self.timers = {}
	if self.gui then
		self.gui:Destroy()
		self.gui = nil
	end
	self.column = nil
end

function CoreGuiShim:clear()
	self:stop()
	for coreGuiType in pairs(self.enabled) do
		self.enabled[coreGuiType] = true
	end
	self.coreValues = {}
	self.listeners = {}
	self.proxy:clearOverrides(StarterGui)
end

return CoreGuiShim
