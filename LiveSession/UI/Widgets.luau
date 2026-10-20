local Constants = require(script.Parent.Parent.Core.Constants)

local Widgets = {}

local UI = Constants.UI
local CLASSES = Constants.CLASS_NAMES

function Widgets.frame(parent, color, size, position)
	local frame = Instance.new(CLASSES.FRAME)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Size = size
	if position then
		frame.Position = position
	end
	frame.Parent = parent
	return frame
end

function Widgets.corner(parent)
	local corner = Instance.new(CLASSES.UI_CORNER)
	corner.CornerRadius = UDim.new(0, UI.CORNER_RADIUS)
	corner.Parent = parent
	return corner
end

function Widgets.padding(parent)
	local padding = Instance.new(CLASSES.UI_PADDING)
	padding.PaddingTop = UDim.new(0, UI.PADDING)
	padding.PaddingBottom = UDim.new(0, UI.PADDING)
	padding.PaddingLeft = UDim.new(0, UI.PADDING)
	padding.PaddingRight = UDim.new(0, UI.PADDING)
	padding.Parent = parent
	return padding
end

function Widgets.list(parent, horizontal)
	local layout = Instance.new(CLASSES.UI_LIST_LAYOUT)
	layout.FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, UI.GAP)
	layout.Parent = parent
	return layout
end

function Widgets.label(parent, text, options)
	options = options or {}
	local label = Instance.new(CLASSES.TEXT_LABEL)
	label.BackgroundTransparency = 1
	label.Font = options.bold and UI.FONT_BOLD or UI.FONT
	label.TextSize = options.textSize or UI.TEXT_SIZE
	label.TextColor3 = options.color or UI.COLORS.TEXT
	label.TextXAlignment = options.center and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.RichText = false
	label.Text = text
	label.Size = options.size or UDim2.new(1, 0, 0, UI.ROW_HEIGHT)
	label.AutomaticSize = options.autoHeight and Enum.AutomaticSize.Y or Enum.AutomaticSize.None
	label.LayoutOrder = options.order or 0
	label.Parent = parent
	return label
end

function Widgets.button(parent, text, color, onClick, order)
	local button = Instance.new(CLASSES.TEXT_BUTTON)
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = UI.FONT_BOLD
	button.TextSize = UI.TEXT_SIZE
	button.TextColor3 = UI.COLORS.TEXT
	button.Text = text
	button.Size = UDim2.new(1, 0, 0, UI.BUTTON_HEIGHT)
	button.LayoutOrder = order or 0
	button.Parent = parent
	Widgets.corner(button)
	button.MouseButton1Click:Connect(onClick)
	return button
end

function Widgets.textBox(parent, placeholder, order, onChanged)
	local box = Instance.new(CLASSES.TEXT_BOX)
	box.BackgroundColor3 = UI.COLORS.PANEL_ALT
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.Font = UI.FONT
	box.TextSize = UI.TEXT_SIZE
	box.TextColor3 = UI.COLORS.TEXT
	box.PlaceholderColor3 = UI.COLORS.TEXT_MUTED
	box.PlaceholderText = placeholder
	box.Text = UI.EMPTY_TEXT
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Size = UDim2.new(1, 0, 0, UI.BUTTON_HEIGHT)
	box.LayoutOrder = order or 0
	box.Parent = parent
	Widgets.corner(box)
	Widgets.padding(box)
	box:GetPropertyChangedSignal(Constants.PROPERTY_NAMES.TEXT):Connect(function()
		onChanged(box.Text)
	end)
	return box
end

function Widgets.textArea(parent, size, order)
	local box = Instance.new(CLASSES.TEXT_BOX)
	box.BackgroundColor3 = UI.COLORS.PANEL_ALT
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.TextEditable = false
	box.MultiLine = true
	box.Font = UI.MONO_FONT
	box.TextSize = UI.OUTPUT_TEXT_SIZE
	box.TextColor3 = UI.COLORS.TEXT
	box.Text = UI.EMPTY_TEXT
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Top
	box.TextWrapped = false
	box.Size = size
	box.LayoutOrder = order or 0
	box.Parent = parent
	Widgets.corner(box)
	Widgets.padding(box)
	return box
end

function Widgets.scroll(parent, order)
	local scroll = Instance.new(CLASSES.SCROLLING_FRAME)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.new(1, 0, 1, 0)
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = UI.GAP
	scroll.LayoutOrder = order or 0
	scroll.Parent = parent
	Widgets.list(scroll)
	return scroll
end

function Widgets.row(parent, labelText, order)
	local row = Widgets.frame(parent, UI.COLORS.PANEL, UDim2.new(1, 0, 0, UI.ROW_HEIGHT))
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	Widgets.label(row, labelText, { color = UI.COLORS.TEXT_MUTED, size = UDim2.new(0.42, 0, 1, 0) })
	local value = Widgets.label(row, UI.EMPTY_VALUE, { size = UDim2.new(0.58, 0, 1, 0) })
	value.Position = UDim2.new(0.42, 0, 0, 0)
	return value
end

function Widgets.dockWidget(plugin, id, title, width, height, minWidth, minHeight)
	local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, width, height, minWidth, minHeight)
	local widget = plugin:CreateDockWidgetPluginGui(id, info)
	widget.Title = title
	widget.Name = id
	widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local root = Widgets.frame(widget, UI.COLORS.PANEL, UDim2.new(1, 0, 1, 0))
	Widgets.padding(root)
	Widgets.list(root)
	return widget, root
end

return Widgets
