local UserInputService = game:GetService("UserInputService")

local Constants = require(script.Parent.Parent.Core.Constants)

local InputBridge = {}
InputBridge.__index = InputBridge

local CONTROLLER = Constants.CONTROLLER
local INPUT = Constants.INPUT
local STAGES = INPUT.STAGES
local TYPES = Constants.TYPE_NAMES

local function keySet(list)
	local set = {}
	for _, key in ipairs(list) do
		set[key] = true
	end
	return set
end

local FORWARD = keySet(CONTROLLER.FORWARD_KEYS)
local BACK = keySet(CONTROLLER.BACK_KEYS)
local LEFT = keySet(CONTROLLER.LEFT_KEYS)
local RIGHT = keySet(CONTROLLER.RIGHT_KEYS)
local JUMP = keySet(CONTROLLER.JUMP_KEYS)

function InputBridge.new(plugin, onReleased)
	return setmetatable({
		plugin = plugin,
		onReleased = onReleased,
		connections = {},
		keysDown = {},
		jumpRequested = false,
		mouseDelta = Vector2.zero,
		zoomDelta = 0,
		rotating = false,
		active = false,
		listeners = {},
	}, InputBridge)
end

function InputBridge:addListener(priority, callback)
	if type(priority) ~= TYPES.NUMBER or type(callback) ~= TYPES.FUNCTION then
		error(INPUT.INVALID_LISTENER_MESSAGE, 2)
	end
	local entry = { priority = priority, callback = callback }
	local index = 1
	while index <= #self.listeners and self.listeners[index].priority > priority do
		index += 1
	end
	table.insert(self.listeners, index, entry)
	return function()
		local position = table.find(self.listeners, entry)
		if position then
			table.remove(self.listeners, position)
		end
	end
end

function InputBridge:dispatch(stage, input)
	local gameProcessed = UserInputService:GetFocusedTextBox() ~= nil
	for _, entry in ipairs(table.clone(self.listeners)) do
		if entry.callback(stage, input, gameProcessed) then
			gameProcessed = true
		end
	end
	return gameProcessed
end

function InputBridge:start()
	self:activate()
	table.insert(self.connections, UserInputService.InputBegan:Connect(function(input)
		self:onInputBegan(input)
	end))
	table.insert(self.connections, UserInputService.InputEnded:Connect(function(input)
		self:onInputEnded(input)
	end))
	table.insert(self.connections, UserInputService.InputChanged:Connect(function(input)
		self:onInputChanged(input)
	end))
	table.insert(self.connections, self.plugin.Deactivation:Connect(function()
		self.active = false
	end))
end

function InputBridge:activate()
	pcall(self.plugin.Activate, self.plugin, true)
	self.active = true
end

function InputBridge:release()
	self.active = false
	self.keysDown = {}
	self.rotating = false
	pcall(self.plugin.Deactivate, self.plugin)
	self:setMouseLocked(false)
	self.onReleased()
end

function InputBridge:isActive()
	return self.active
end

function InputBridge:onInputBegan(input)
	if input.UserInputType == CONTROLLER.FOCUS_BUTTON and not self.active then
		self:activate()
		return
	end
	if not self.active then
		return
	end
	if input.UserInputType == CONTROLLER.KEYBOARD and input.KeyCode == CONTROLLER.ESCAPE_KEY then
		self:release()
		return
	end
	if self:dispatch(STAGES.BEGAN, input) then
		return
	end
	if input.UserInputType == CONTROLLER.KEYBOARD then
		self.keysDown[input.KeyCode] = true
		if JUMP[input.KeyCode] then
			self.jumpRequested = true
		end
	elseif input.UserInputType == CONTROLLER.ROTATE_BUTTON then
		self.rotating = true
	end
end

function InputBridge:onInputEnded(input)
	if input.UserInputType == CONTROLLER.KEYBOARD then
		self.keysDown[input.KeyCode] = nil
	elseif input.UserInputType == CONTROLLER.ROTATE_BUTTON then
		self.rotating = false
	end
	self:dispatch(STAGES.ENDED, input)
end

function InputBridge:onInputChanged(input)
	if not self.active then
		return
	end
	if self:dispatch(STAGES.CHANGED, input) then
		return
	end
	if input.UserInputType == CONTROLLER.MOUSE_MOVEMENT then
		self.mouseDelta += Vector2.new(input.Delta.X, input.Delta.Y)
	elseif input.UserInputType == CONTROLLER.MOUSE_WHEEL then
		self.zoomDelta += input.Position.Z
	end
end

function InputBridge:moveAxes()
	local x = 0
	local z = 0
	for key in pairs(self.keysDown) do
		if FORWARD[key] then
			z -= 1
		elseif BACK[key] then
			z += 1
		elseif LEFT[key] then
			x -= 1
		elseif RIGHT[key] then
			x += 1
		end
	end
	return x, z
end

function InputBridge:consumeJump()
	local requested = self.jumpRequested
	self.jumpRequested = false
	return requested
end

function InputBridge:consumeMouseDelta()
	local delta = self.mouseDelta
	self.mouseDelta = Vector2.zero
	return delta
end

function InputBridge:consumeZoomDelta()
	local delta = self.zoomDelta
	self.zoomDelta = 0
	return delta
end

function InputBridge:isRotating()
	return self.rotating
end

function InputBridge:setMouseLocked(locked)
	pcall(function()
		UserInputService.MouseBehavior = locked and CONTROLLER.LOCK_BEHAVIOR or CONTROLLER.FREE_BEHAVIOR
	end)
end

function InputBridge:stop()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.connections = {}
	self.listeners = {}
	self.keysDown = {}
	self.active = false
	self:setMouseLocked(false)
	pcall(self.plugin.Deactivate, self.plugin)
end

return InputBridge
