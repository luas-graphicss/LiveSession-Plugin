local RunService = game:GetService("RunService")

local Constants = require(script.Parent.Parent.Core.Constants)
local HostedSignal = require(script.Parent.Parent.Runtime.HostedSignal)

local ClickDetectorDriver = {}
ClickDetectorDriver.__index = ClickDetectorDriver

local DETECTORS = Constants.CLICK_DETECTORS
local EVENTS = DETECTORS.EVENTS
local INPUT = Constants.INPUT
local STAGES = INPUT.STAGES
local CLASSES = Constants.CLASS_NAMES
local EMPTY = Constants.UI.EMPTY_TEXT

function ClickDetectorDriver.new(deps)
	return setmetatable({
		deps = deps,
		signals = setmetatable({}, { __mode = "k" }),
		tracked = {},
		hovered = nil,
		originalCursor = nil,
		connections = {},
		removeListener = nil,
		heartbeat = nil,
		lastHoverAt = 0,
	}, ClickDetectorDriver)
end

function ClickDetectorDriver:signalsFor(detector)
	local signals = self.signals[detector]
	if not signals then
		signals = {}
		for _, name in ipairs(DETECTORS.SIGNALS) do
			signals[name] = HostedSignal.new(self.deps.tracker)
		end
		self.signals[detector] = signals
	end
	return signals
end

function ClickDetectorDriver:install()
	self.deps.proxy:addBridge({
		name = DETECTORS.CLASS_NAME,
		matches = function(instance)
			return instance.ClassName == DETECTORS.CLASS_NAME
		end,
		read = function(detector, key)
			if table.find(DETECTORS.SIGNALS, key) then
				return true, self:signalsFor(detector)[key]:interface()
			end
			return false
		end,
	})
end

function ClickDetectorDriver:track(instance)
	if instance.ClassName == DETECTORS.CLASS_NAME then
		self.tracked[instance] = true
	end
end

function ClickDetectorDriver:untrack(instance)
	if instance.ClassName ~= DETECTORS.CLASS_NAME then
		return
	end
	self.tracked[instance] = nil
	if self.hovered == instance then
		self:setHovered(nil)
	end
	if self.deps.tracker:isDestroying(instance) then
		self.signals[instance] = nil
	end
end

function ClickDetectorDriver:start()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		self:track(descendant)
	end
	table.insert(self.connections, workspace.DescendantAdded:Connect(function(instance)
		self:track(instance)
	end))
	table.insert(self.connections, workspace.DescendantRemoving:Connect(function(instance)
		self:untrack(instance)
	end))
	self.removeListener = self.deps.input:addListener(INPUT.PRIORITIES.CLICK_DETECTORS, function(stage, input, gameProcessed)
		return self:handleInput(stage, input, gameProcessed)
	end)
	self.heartbeat = RunService.Heartbeat:Connect(function()
		self:step()
	end)
end

function ClickDetectorDriver:detectorAt(part)
	local node = part
	while node ~= nil and node ~= workspace do
		if node == part or node:IsA(CLASSES.MODEL) then
			local detector = node:FindFirstChildOfClass(DETECTORS.CLASS_NAME)
			if detector and self.tracked[detector] then
				return detector
			end
		end
		node = node.Parent
	end
	return nil
end

function ClickDetectorDriver:origin()
	local character = self.deps.getCharacter()
	local root = character and character:FindFirstChild(Constants.RIG.ROOT_NAME)
	if root then
		return root.Position
	end
	return workspace.CurrentCamera.CFrame.Position
end

function ClickDetectorDriver:step()
	local now = os.clock()
	if now - self.lastHoverAt < DETECTORS.HOVER_INTERVAL then
		return
	end
	self.lastHoverAt = now
	local result = self.deps.mouseRay:cast(INPUT.RAY_MAX_DISTANCE)
	local detector = result and self:detectorAt(result.Instance)
	if detector and (result.Position - self:origin()).Magnitude > detector.MaxActivationDistance then
		detector = nil
	end
	self:setHovered(detector)
end

function ClickDetectorDriver:player()
	return self.deps.proxy:wrap(self.deps.getPlayer())
end

function ClickDetectorDriver:setHovered(detector)
	local previous = self.hovered
	if previous == detector then
		return
	end
	self.hovered = detector
	local player = self:player()
	if previous then
		self:signalsFor(previous)[EVENTS.HOVER_LEAVE]:fire(player)
	end
	if detector then
		self:signalsFor(detector)[EVENTS.HOVER_ENTER]:fire(player)
	end
	self:updateCursor(detector)
end

function ClickDetectorDriver:updateCursor(detector)
	local mouse = self.deps.getMouse()
	if detector then
		if self.originalCursor == nil then
			self.originalCursor = mouse.Icon
		end
		mouse.Icon = detector.CursorIcon ~= EMPTY and detector.CursorIcon or DETECTORS.DEFAULT_CURSOR
	elseif self.originalCursor ~= nil then
		mouse.Icon = self.originalCursor
		self.originalCursor = nil
	end
end

function ClickDetectorDriver:handleInput(stage, input, gameProcessed)
	if stage ~= STAGES.BEGAN or gameProcessed or self.hovered == nil then
		return false
	end
	local event = DETECTORS.BUTTON_EVENTS[input.UserInputType]
	if event then
		self:signalsFor(self.hovered)[event]:fire(self:player())
	end
	return false
end

function ClickDetectorDriver:stop()
	if self.heartbeat then
		self.heartbeat:Disconnect()
		self.heartbeat = nil
	end
	if self.removeListener then
		self.removeListener()
		self.removeListener = nil
	end
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.connections = {}
	self:setHovered(nil)
	self.tracked = {}
	for _, signals in pairs(self.signals) do
		for _, signal in pairs(signals) do
			signal:clear()
		end
	end
	self.signals = setmetatable({}, { __mode = "k" })
end

return ClickDetectorDriver
