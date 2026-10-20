local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local Constants = require(script.Parent.Parent.Core.Constants)
local HostedSignal = require(script.Parent.Parent.Runtime.HostedSignal)
local PromptGui = require(script.Parent.PromptGui)

local ProximityPromptDriver = {}
ProximityPromptDriver.__index = ProximityPromptDriver

local PROMPTS = Constants.PROXIMITY_PROMPTS
local EVENTS = PROMPTS.EVENTS
local CLASSES = Constants.CLASS_NAMES
local INPUT = Constants.INPUT
local STAGES = INPUT.STAGES
local CONTROLLER = Constants.CONTROLLER

local function targetOf(prompt)
	local ancestor = prompt.Parent
	while ancestor ~= nil do
		if ancestor:IsA(CLASSES.ATTACHMENT) then
			return ancestor, ancestor.WorldPosition, ancestor.Parent
		elseif ancestor:IsA(CLASSES.BASE_PART) then
			return ancestor, ancestor.Position, ancestor
		end
		ancestor = ancestor.Parent
	end
	return nil
end

local function byDistance(left, right)
	return left.distance < right.distance
end

function ProximityPromptDriver.new(deps)
	local self = setmetatable({
		deps = deps,
		states = setmetatable({}, { __mode = "k" }),
		tracked = {},
		shown = {},
		serviceSignals = {},
		connections = {},
		removeListener = nil,
		folder = nil,
		heartbeat = nil,
		lastScanAt = 0,
		rayParams = RaycastParams.new(),
	}, ProximityPromptDriver)
	self.rayParams.FilterType = INPUT.RAY_FILTER_TYPE
	for _, name in ipairs(PROMPTS.SERVICE_SIGNALS) do
		self.serviceSignals[name] = HostedSignal.new(deps.tracker)
	end
	return self
end

function ProximityPromptDriver:stateFor(prompt)
	local state = self.states[prompt]
	if not state then
		state = { signals = {}, holding = false, triggered = false, holdStartedAt = 0, gui = nil, adornee = nil }
		for _, name in ipairs(PROMPTS.INSTANCE_SIGNALS) do
			state.signals[name] = HostedSignal.new(self.deps.tracker)
		end
		self.states[prompt] = state
	end
	return state
end

function ProximityPromptDriver:install()
	local getters = {}
	for _, name in ipairs(PROMPTS.INSTANCE_SIGNALS) do
		getters[name] = function(prompt)
			return self:stateFor(prompt).signals[name]:interface()
		end
	end
	getters[PROMPTS.METHODS.INPUT_HOLD_BEGIN] = function(prompt)
		return function()
			self:holdBegin(prompt)
		end
	end
	getters[PROMPTS.METHODS.INPUT_HOLD_END] = function(prompt)
		return function()
			self:holdEnd(prompt)
		end
	end
	self.deps.proxy:addBridge({
		name = PROMPTS.CLASS_NAME,
		matches = function(instance)
			return instance.ClassName == PROMPTS.CLASS_NAME
		end,
		read = function(prompt, key)
			local getter = getters[key]
			if getter then
				return true, getter(prompt)
			end
			return false
		end,
	})
	local serviceGetters = {}
	for name, signal in pairs(self.serviceSignals) do
		serviceGetters[name] = function()
			return signal:interface()
		end
	end
	self.deps.proxy:override(ProximityPromptService, serviceGetters)
end

function ProximityPromptDriver:track(instance)
	if instance.ClassName == PROMPTS.CLASS_NAME then
		self.tracked[instance] = true
	end
end

function ProximityPromptDriver:untrack(instance)
	if instance.ClassName ~= PROMPTS.CLASS_NAME then
		return
	end
	self.tracked[instance] = nil
	if self.shown[instance] then
		self:hide(instance)
	end
	if self.deps.tracker:isDestroying(instance) then
		self.states[instance] = nil
	end
end

function ProximityPromptDriver:start(parent)
	local folder = Instance.new(CLASSES.FOLDER)
	folder.Name = PROMPTS.FOLDER_NAME
	folder.Parent = parent
	self.folder = folder
	for _, descendant in ipairs(workspace:GetDescendants()) do
		self:track(descendant)
	end
	table.insert(self.connections, workspace.DescendantAdded:Connect(function(instance)
		self:track(instance)
	end))
	table.insert(self.connections, workspace.DescendantRemoving:Connect(function(instance)
		self:untrack(instance)
	end))
	self.removeListener = self.deps.input:addListener(INPUT.PRIORITIES.PROMPTS, function(stage, input, gameProcessed)
		return self:handleInput(stage, input, gameProcessed)
	end)
	self.heartbeat = RunService.Heartbeat:Connect(function()
		self:step()
	end)
end

function ProximityPromptDriver:origin()
	local character = self.deps.getCharacter()
	local root = character and character:FindFirstChild(Constants.RIG.ROOT_NAME)
	if root then
		return root.Position
	end
	return workspace.CurrentCamera.CFrame.Position
end

function ProximityPromptDriver:hasLineOfSight(position, occluder)
	local cameraPosition = workspace.CurrentCamera.CFrame.Position
	local result = workspace:Raycast(cameraPosition, position - cameraPosition, self.rayParams)
	return result == nil or occluder ~= nil and (result.Instance == occluder or result.Instance:IsDescendantOf(occluder))
end

function ProximityPromptDriver:candidates()
	local origin = self:origin()
	local character = self.deps.getCharacter()
	self.rayParams.FilterDescendantsInstances = character and { character } or {}
	local list = {}
	for prompt in pairs(self.tracked) do
		if prompt.Enabled then
			local adornee, position, occluder = targetOf(prompt)
			if adornee then
				local distance = (position - origin).Magnitude
				if distance <= prompt.MaxActivationDistance and (not prompt.RequiresLineOfSight or self:hasLineOfSight(position, occluder)) then
					table.insert(list, { prompt = prompt, distance = distance, adornee = adornee })
				end
			end
		end
	end
	table.sort(list, byDistance)
	return list
end

function ProximityPromptDriver:select(candidates)
	local selected = {}
	local usedKeys = {}
	local count = 0
	local limit = ProximityPromptService.MaxPromptsVisible
	for _, candidate in ipairs(candidates) do
		if count >= limit then
			break
		end
		local prompt = candidate.prompt
		local exclusivity = prompt.Exclusivity
		local allowed = true
		if exclusivity == Enum.ProximityPromptExclusivity.OneGlobally then
			allowed = count == 0
		elseif exclusivity == Enum.ProximityPromptExclusivity.OnePerButton then
			allowed = not usedKeys[prompt.KeyboardKeyCode]
		end
		if allowed then
			selected[prompt] = candidate
			count += 1
			if exclusivity ~= Enum.ProximityPromptExclusivity.AlwaysShow then
				usedKeys[prompt.KeyboardKeyCode] = true
			end
			if exclusivity == Enum.ProximityPromptExclusivity.OneGlobally then
				break
			end
		end
	end
	return selected
end

function ProximityPromptDriver:show(prompt, adornee)
	local state = self:stateFor(prompt)
	self.shown[prompt] = true
	state.adornee = adornee
	if prompt.Style == Enum.ProximityPromptStyle.Default then
		state.gui = PromptGui.new(prompt, adornee, self.folder, function()
			self:holdBegin(prompt)
		end, function()
			self:holdEnd(prompt)
		end)
	end
	state.signals[EVENTS.SHOWN]:fire(PROMPTS.INPUT_TYPE)
	self.serviceSignals[EVENTS.SHOWN]:fire(self.deps.proxy:wrap(prompt), PROMPTS.INPUT_TYPE)
end

function ProximityPromptDriver:hide(prompt)
	local state = self:stateFor(prompt)
	self.shown[prompt] = nil
	state.adornee = nil
	if state.holding then
		self:holdEnd(prompt)
	end
	if state.gui then
		state.gui:destroy()
		state.gui = nil
	end
	state.signals[EVENTS.HIDDEN]:fire()
	self.serviceSignals[EVENTS.HIDDEN]:fire(self.deps.proxy:wrap(prompt))
end

function ProximityPromptDriver:step()
	local now = os.clock()
	if now - self.lastScanAt >= PROMPTS.SCAN_INTERVAL then
		self.lastScanAt = now
		self:scan()
	end
	for prompt in pairs(self.shown) do
		self:advanceHold(prompt, now)
	end
end

function ProximityPromptDriver:scan()
	if not ProximityPromptService.Enabled then
		for prompt in pairs(self.shown) do
			self:hide(prompt)
		end
		return
	end
	local selected = self:select(self:candidates())
	for prompt in pairs(self.shown) do
		local candidate = selected[prompt]
		if candidate == nil or candidate.adornee ~= self:stateFor(prompt).adornee then
			self:hide(prompt)
		end
	end
	for prompt, candidate in pairs(selected) do
		if not self.shown[prompt] then
			self:show(prompt, candidate.adornee)
		end
	end
end

function ProximityPromptDriver:advanceHold(prompt, now)
	local state = self:stateFor(prompt)
	if not state.holding or state.triggered then
		return
	end
	local fraction = (now - state.holdStartedAt) / prompt.HoldDuration
	if fraction >= 1 then
		self:fire(prompt, state, EVENTS.HOLD_ENDED, EVENTS.HOLD_ENDED)
		self:trigger(prompt, state)
	elseif state.gui then
		state.gui:setProgress(fraction)
	end
end

function ProximityPromptDriver:fire(prompt, state, instanceEvent, serviceEvent)
	local player = self.deps.proxy:wrap(self.deps.getPlayer())
	state.signals[instanceEvent]:fire(player)
	self.serviceSignals[serviceEvent]:fire(self.deps.proxy:wrap(prompt), player)
end

function ProximityPromptDriver:trigger(prompt, state)
	state.triggered = true
	if state.gui then
		state.gui:setProgress(0)
	end
	self:fire(prompt, state, EVENTS.TRIGGERED, EVENTS.SERVICE_TRIGGERED)
end

function ProximityPromptDriver:holdBegin(prompt)
	local state = self:stateFor(prompt)
	if not self.shown[prompt] or state.holding then
		return
	end
	state.holding = true
	state.triggered = false
	state.holdStartedAt = os.clock()
	if prompt.HoldDuration > 0 then
		self:fire(prompt, state, EVENTS.HOLD_BEGAN, EVENTS.HOLD_BEGAN)
	else
		self:trigger(prompt, state)
	end
end

function ProximityPromptDriver:holdEnd(prompt)
	local state = self:stateFor(prompt)
	if not state.holding then
		return
	end
	state.holding = false
	if state.gui then
		state.gui:setProgress(0)
	end
	if state.triggered then
		state.triggered = false
		self:fire(prompt, state, EVENTS.TRIGGER_ENDED, EVENTS.SERVICE_TRIGGER_ENDED)
	else
		self:fire(prompt, state, EVENTS.HOLD_ENDED, EVENTS.HOLD_ENDED)
	end
end

function ProximityPromptDriver:handleInput(stage, input, gameProcessed)
	if stage == STAGES.CHANGED or input.UserInputType ~= CONTROLLER.KEYBOARD then
		return false
	end
	local began = stage == STAGES.BEGAN
	if began and gameProcessed then
		return false
	end
	for prompt in pairs(self.shown) do
		if prompt.KeyboardKeyCode == input.KeyCode then
			if began then
				self:holdBegin(prompt)
			else
				self:holdEnd(prompt)
			end
		end
	end
	return false
end

function ProximityPromptDriver:stop()
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
	for prompt in pairs(self.shown) do
		self:hide(prompt)
	end
	self.shown = {}
	self.tracked = {}
	for _, state in pairs(self.states) do
		for _, signal in pairs(state.signals) do
			signal:clear()
		end
	end
	self.states = setmetatable({}, { __mode = "k" })
	for _, signal in pairs(self.serviceSignals) do
		signal:clear()
	end
	if self.folder then
		self.folder:Destroy()
		self.folder = nil
	end
	self.deps.proxy:clearOverrides(ProximityPromptService)
end

return ProximityPromptDriver
