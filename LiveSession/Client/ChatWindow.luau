local Constants = require(script.Parent.Parent.Core.Constants)

local ChatWindow = {}
ChatWindow.__index = ChatWindow

local CHAT = Constants.CHAT_WINDOW
local TEXTS = Constants.TEXTS
local INPUT = Constants.INPUT
local STAGES = INPUT.STAGES
local CLASSES = Constants.CLASS_NAMES
local THEME = Constants.UI
local EMPTY = THEME.EMPTY_TEXT

local function corner(parent)
	local instance = Instance.new(CLASSES.UI_CORNER)
	instance.CornerRadius = UDim.new(0, THEME.CORNER_RADIUS)
	instance.Parent = parent
end

local function escapeRichText(text)
	return (string.gsub(text, CHAT.RICH_TEXT_PATTERN, CHAT.RICH_TEXT_ESCAPES))
end

function ChatWindow.new(deps)
	local self = setmetatable({
		deps = deps,
		gui = nil,
		list = nil,
		layout = nil,
		textBox = nil,
		connections = {},
		removeListener = nil,
		lineCount = 0,
	}, ChatWindow)
	deps.textChat:onMessage(function(message)
		self:addMessage(message)
	end)
	deps.coreGui:onChanged(function(coreGuiType, enabled)
		if coreGuiType == CHAT.CORE_GUI_TYPE and self.gui then
			self.gui.Enabled = enabled
		end
	end)
	return self
end

function ChatWindow:buildList(panel)
	local list = Instance.new(CLASSES.SCROLLING_FRAME)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(THEME.GAP, THEME.GAP)
	list.Size = UDim2.new(1, -THEME.GAP * 2, 1, -(CHAT.INPUT_HEIGHT + THEME.GAP * 3))
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = CHAT.SCROLL_BAR_THICKNESS
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.Parent = panel
	local layout = Instance.new(CLASSES.UI_LIST_LAYOUT)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, CHAT.LINE_GAP)
	layout.Parent = list
	return list, layout
end

function ChatWindow:buildTextBox(panel)
	local textBox = Instance.new(CLASSES.TEXT_BOX)
	textBox.AnchorPoint = Vector2.new(0, 1)
	textBox.Position = UDim2.new(0, THEME.GAP, 1, -THEME.GAP)
	textBox.Size = UDim2.new(1, -THEME.GAP * 2, 0, CHAT.INPUT_HEIGHT)
	textBox.BackgroundColor3 = THEME.COLORS.PANEL_ALT
	textBox.BorderSizePixel = 0
	textBox.Font = THEME.FONT
	textBox.TextSize = THEME.TEXT_SIZE
	textBox.TextColor3 = THEME.COLORS.TEXT
	textBox.PlaceholderColor3 = THEME.COLORS.TEXT_MUTED
	textBox.PlaceholderText = TEXTS.CHAT_PLACEHOLDER
	textBox.TextXAlignment = Enum.TextXAlignment.Left
	textBox.ClearTextOnFocus = false
	textBox.Text = EMPTY
	textBox.Parent = panel
	corner(textBox)
	return textBox
end

function ChatWindow:start(root)
	local gui = Instance.new(CLASSES.SCREEN_GUI)
	gui.Name = CHAT.GUI_NAME
	gui.DisplayOrder = CHAT.DISPLAY_ORDER
	gui.ResetOnSpawn = false
	gui.Enabled = self.deps.coreGui:isEnabled(CHAT.CORE_GUI_TYPE)
	local panel = Instance.new(CLASSES.FRAME)
	panel.Position = CHAT.POSITION
	panel.Size = CHAT.SIZE
	panel.BackgroundColor3 = THEME.COLORS.PANEL
	panel.BackgroundTransparency = CHAT.BACKGROUND_TRANSPARENCY
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel)
	self.list, self.layout = self:buildList(panel)
	self.textBox = self:buildTextBox(panel)
	self.gui = gui
	gui.Parent = root
	table.insert(self.connections, self.textBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			self:send()
		end
	end))
	table.insert(self.connections, self.layout:GetPropertyChangedSignal(CHAT.CONTENT_SIZE_PROPERTY):Connect(function()
		self:scrollToBottom()
	end))
	self.removeListener = self.deps.input:addListener(CHAT.FOCUS_PRIORITY, function(stage, input, gameProcessed)
		if stage == STAGES.BEGAN and not gameProcessed and input.KeyCode == CHAT.FOCUS_KEY then
			self:focus()
		end
		return false
	end)
end

function ChatWindow:focus()
	if not self.gui.Enabled then
		return
	end
	self.textBox:CaptureFocus()
	task.defer(function()
		if self.textBox and self.textBox.Text == CHAT.FOCUS_KEY_TEXT then
			self.textBox.Text = EMPTY
		end
	end)
end

function ChatWindow:send()
	local text = string.sub(self.textBox.Text, 1, CHAT.MAX_LENGTH)
	self.textBox.Text = EMPTY
	if string.match(text, CHAT.BLANK_PATTERN) then
		return
	end
	self.deps.textChat:sendLocal(text)
end

function ChatWindow:formatMessage(message)
	if message.TextSource == nil then
		return string.format(CHAT.SYSTEM_LINE_FORMAT, THEME.COLORS.CHAT_SYSTEM:ToHex(), message.Text)
	end
	local prefix = message.PrefixText ~= EMPTY and message.PrefixText or message.TextSource.Name
	return string.format(CHAT.LINE_FORMAT, THEME.COLORS.CHAT_NAME:ToHex(), prefix, escapeRichText(message.Text))
end

function ChatWindow:addMessage(message)
	if not self.list then
		return
	end
	local line = Instance.new(CLASSES.TEXT_LABEL)
	line.BackgroundTransparency = 1
	line.RichText = true
	line.Font = THEME.FONT
	line.TextSize = THEME.TEXT_SIZE
	line.TextColor3 = THEME.COLORS.TEXT
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextWrapped = true
	line.AutomaticSize = Enum.AutomaticSize.Y
	line.Size = UDim2.new(1, 0, 0, THEME.TEXT_SIZE)
	line.Text = self:formatMessage(message)
	self.lineCount += 1
	line.LayoutOrder = self.lineCount
	line.Parent = self.list
	self:trimLines()
end

function ChatWindow:trimLines()
	local lines = {}
	for _, child in ipairs(self.list:GetChildren()) do
		if child:IsA(CLASSES.TEXT_LABEL) then
			table.insert(lines, child)
		end
	end
	for index = 1, #lines - CHAT.MAX_LINES do
		lines[index]:Destroy()
	end
end

function ChatWindow:scrollToBottom()
	self.list.CanvasPosition = Vector2.new(0, math.max(0, self.layout.AbsoluteContentSize.Y - self.list.AbsoluteWindowSize.Y))
end

function ChatWindow:stop()
	if self.removeListener then
		self.removeListener()
		self.removeListener = nil
	end
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.connections = {}
	if self.gui then
		self.gui:Destroy()
		self.gui = nil
	end
	self.list = nil
	self.layout = nil
	self.textBox = nil
	self.lineCount = 0
end

return ChatWindow
