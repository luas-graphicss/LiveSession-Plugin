local RunService = game:GetService("RunService")

local Constants = require(script.Parent.Parent.Core.Constants)
local HostedSignal = require(script.Parent.Parent.Runtime.HostedSignal)

local ToolDriver = {}
ToolDriver.__index = ToolDriver

local TOOLS = Constants.TOOLS
local EVENTS = TOOLS.EVENTS
local METHODS = TOOLS.METHODS
local HUMANOID_METHODS = TOOLS.HUMANOID_METHODS
local HOTBAR = Constants.HOTBAR
local CLASSES = Constants.CLASS_NAMES
local STAGES = Constants.INPUT.STAGES
local PRIORITIES = Constants.INPUT.PRIORITIES
local TYPES = Constants.TYPE_NAMES

local function weakKeyed()
	return setmetatable({}, { __mode = "k" })
end

local function isTool(instance)
	return typeof(instance) == TYPES.INSTANCE and instance:IsA(TOOLS.CLASS_NAME)
end

local function handleOf(tool)
	local handle = tool:FindFirstChild(TOOLS.HANDLE_NAME)
	if handle and handle:IsA(CLASSES.BASE_PART) then
		return handle
	end
	return nil
end

local function disconnectAll(connections)
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
end

function ToolDriver.new(deps)
	return setmetatable({
		deps = deps,
		states = weakKeyed(),
		tools = {},
		character = nil,
		humanoid = nil,
		equipped = nil,
		activeTool = nil,
		grip = nil,
		gripConnection = nil,
		handleStep = nil,
		characterConnections = {},
		backpackConnections = {},
		removeListener = nil,
		silent = false,
		started = false,
	}, ToolDriver)
end

function ToolDriver:stateFor(tool)
	local state = self.states[tool]
	if not state then
		state = { signals = {} }
		for _, name in ipairs(TOOLS.SIGNALS) do
			state.signals[name] = HostedSignal.new(self.deps.tracker)
		end
		self.states[tool] = state
	end
	return state
end

function ToolDriver:install()
	local proxy = self.deps.proxy
	proxy:addBridge({
		name = TOOLS.CLASS_NAME,
		matches = function(instance)
			return instance:IsA(TOOLS.CLASS_NAME)
		end,
		read = function(tool, key)
			if table.find(TOOLS.SIGNALS, key) then
				return true, self:stateFor(tool).signals[key]:interface()
			elseif key == METHODS.ACTIVATE then
				return true, function()
					self:activate(tool)
				end
			elseif key == METHODS.DEACTIVATE then
				return true, function()
					self:deactivate(tool)
				end
			end
			return false
		end,
	})
	proxy:addBridge({
		name = TOOLS.HUMANOID_BRIDGE_NAME,
		matches = function(instance)
			return instance:IsA(CLASSES.HUMANOID)
		end,
		read = function(humanoid, key)
			if humanoid ~= self.humanoid then
				return false
			elseif key == HUMANOID_METHODS.EQUIP then
				return true, function(_, tool)
					self:equip(proxy:unwrap(tool))
				end
			elseif key == HUMANOID_METHODS.UNEQUIP then
				return true, function()
					self:unequip()
				end
			end
			return false
		end,
	})
end

function ToolDriver:start()
	self.started = true
	local backpack = self.deps.getBackpack()
	table.insert(self.backpackConnections, backpack.ChildAdded:Connect(function()
		self:syncTools()
	end))
	table.insert(self.backpackConnections, backpack.ChildRemoved:Connect(function()
		self:syncTools()
	end))
	self.deps.hotbar:onSlotSelected(function(tool)
		self:toggle(tool)
	end)
	self.deps.onCharacterChanged(function(character)
		if self.started then
			self:onCharacter(character)
		end
	end)
	self.removeListener = self.deps.input:addListener(PRIORITIES.TOOLS, function(stage, input, gameProcessed)
		return self:handleInput(stage, input, gameProcessed)
	end)
	self:onCharacter(self.deps.getCharacter())
end

function ToolDriver:onCharacter(character)
	disconnectAll(self.characterConnections)
	self.characterConnections = {}
	if self.equipped then
		self:detach()
	end
	self.character = character
	self.humanoid = character and character:FindFirstChildOfClass(CLASSES.HUMANOID)
	if character then
		table.insert(self.characterConnections, character.ChildAdded:Connect(function(child)
			self:onCharacterChild(child)
		end))
		table.insert(self.characterConnections, character.ChildRemoved:Connect(function(child)
			self:onCharacterChildRemoved(child)
		end))
		if self.humanoid then
			table.insert(self.characterConnections, self.humanoid.Died:Connect(function()
				self:onDied()
			end))
		end
		for _, child in ipairs(character:GetChildren()) do
			self:onCharacterChild(child)
		end
	end
	self:syncTools()
end

function ToolDriver:onCharacterChild(child)
	if isTool(child) and child ~= self.equipped and child.Parent == self.character then
		self:equip(child)
	end
end

function ToolDriver:onCharacterChildRemoved(child)
	if child == self.equipped and child.Parent ~= self.character then
		self:detach()
	end
	self:syncTools()
end

function ToolDriver:onDied()
	if self.equipped then
		self:detach()
	end
end

function ToolDriver:syncTools()
	local backpack = self.deps.getBackpack()
	local kept = {}
	for _, tool in ipairs(self.tools) do
		if tool.Parent == backpack or (self.character ~= nil and tool.Parent == self.character) then
			table.insert(kept, tool)
		end
	end
	for _, child in ipairs(backpack:GetChildren()) do
		if isTool(child) and not table.find(kept, child) then
			table.insert(kept, child)
		end
	end
	if self.equipped and not table.find(kept, self.equipped) then
		table.insert(kept, self.equipped)
	end
	self.tools = kept
	self.deps.hotbar:setTools(kept)
end

function ToolDriver:gripC0(limb, rigType)
	if rigType == Enum.HumanoidRigType.R6 then
		return TOOLS.GRIP_C0_R6
	end
	local attachment = limb:FindFirstChild(TOOLS.GRIP_ATTACHMENT)
	return attachment and attachment.CFrame or CFrame.identity
end

function ToolDriver:attachHandle(tool, handle)
	local rigType = self.humanoid and self.humanoid.RigType or Enum.HumanoidRigType.R15
	local limb = self.character:FindFirstChild(TOOLS.GRIP_LIMB[rigType])
	if limb == nil then
		return
	end
	local grip = Instance.new(CLASSES.WELD)
	grip.Name = TOOLS.GRIP_WELD_NAME
	grip.Part0 = limb
	grip.Part1 = handle
	grip.C0 = self:gripC0(limb, rigType)
	grip.C1 = tool.Grip
	grip.Parent = limb
	self.grip = grip
	self.gripConnection = tool:GetPropertyChangedSignal(TOOLS.GRIP_PROPERTY):Connect(function()
		grip.C1 = tool.Grip
	end)
	if not self.deps.capabilities.stepPhysics then
		self.handleStep = RunService.Heartbeat:Connect(function()
			handle.CFrame = limb.CFrame * grip.C0 * grip.C1:Inverse()
		end)
	end
end

function ToolDriver:equip(tool)
	if self.character == nil or not isTool(tool) or tool == self.equipped then
		return
	end
	local handle = handleOf(tool)
	if tool.RequiresHandle and handle == nil then
		return
	end
	self:unequip()
	self.equipped = tool
	if tool.Parent ~= self.character then
		tool.Parent = self.character
	end
	if handle then
		self:attachHandle(tool, handle)
	end
	self:syncTools()
	self:stateFor(tool).signals[EVENTS.EQUIPPED]:fire(self.deps.proxy:wrap(self.deps.getMouse()))
	self.deps.contextActions:toolEquipped(tool)
	self.deps.hotbar:setEquipped(tool)
end

function ToolDriver:detach()
	local tool = self.equipped
	self.equipped = nil
	if self.handleStep then
		self.handleStep:Disconnect()
		self.handleStep = nil
	end
	if self.gripConnection then
		self.gripConnection:Disconnect()
		self.gripConnection = nil
	end
	if self.grip then
		self.grip:Destroy()
		self.grip = nil
	end
	if self.silent then
		self.activeTool = nil
		return
	end
	self:deactivate(tool)
	self:stateFor(tool).signals[EVENTS.UNEQUIPPED]:fire()
	self.deps.contextActions:toolUnequipped(tool)
	self.deps.hotbar:setEquipped(nil)
end

function ToolDriver:unequip()
	local tool = self.equipped
	if tool == nil then
		return
	end
	self:detach()
	tool.Parent = self.deps.getBackpack()
end

function ToolDriver:toggle(tool)
	if tool == self.equipped then
		self:unequip()
	else
		self:equip(tool)
	end
end

function ToolDriver:drop()
	local tool = self.equipped
	if tool == nil or not tool.CanBeDropped or self.character == nil then
		return
	end
	local rootPart = self.character:FindFirstChild(Constants.RIG.ROOT_NAME)
	local handle = handleOf(tool)
	self:detach()
	tool.Parent = workspace
	if handle and rootPart then
		handle.CFrame = rootPart.CFrame * CFrame.new(TOOLS.DROP_OFFSET)
	end
end

function ToolDriver:activate(tool)
	if tool ~= self.equipped then
		return
	end
	self.activeTool = tool
	self:stateFor(tool).signals[EVENTS.ACTIVATED]:fire()
end

function ToolDriver:deactivate(tool)
	if tool == nil or tool ~= self.activeTool then
		return
	end
	self.activeTool = nil
	self:stateFor(tool).signals[EVENTS.DEACTIVATED]:fire()
end

function ToolDriver:handleInput(stage, input, gameProcessed)
	if stage == STAGES.CHANGED then
		return false
	end
	if input.UserInputType == TOOLS.ACTIVATE_BUTTON then
		if stage == STAGES.ENDED then
			self:deactivate(self.activeTool)
		elseif not gameProcessed and self.equipped and self.equipped.Enabled and not self.equipped.ManualActivationOnly then
			self:activate(self.equipped)
		end
		return false
	end
	if stage ~= STAGES.BEGAN or gameProcessed then
		return false
	end
	if input.KeyCode == TOOLS.DROP_KEY then
		self:drop()
		return false
	end
	local slot = table.find(HOTBAR.SLOT_KEYS, input.KeyCode)
	local tool = slot and self.tools[slot]
	if tool then
		self:toggle(tool)
	end
	return false
end

function ToolDriver:stop()
	self.started = false
	if self.removeListener then
		self.removeListener()
		self.removeListener = nil
	end
	if self.equipped then
		self.silent = true
		self:detach()
		self.silent = false
	end
	disconnectAll(self.characterConnections)
	disconnectAll(self.backpackConnections)
	self.characterConnections = {}
	self.backpackConnections = {}
	self.character = nil
	self.humanoid = nil
	self.activeTool = nil
	self.tools = {}
	for _, state in pairs(self.states) do
		for _, signal in pairs(state.signals) do
			signal:clear()
		end
	end
	self.states = weakKeyed()
end

return ToolDriver
