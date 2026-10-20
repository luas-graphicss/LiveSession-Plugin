local ContextActionService = game:GetService("ContextActionService")

local Constants = require(script.Parent.Parent.Core.Constants)
local HostedSignal = require(script.Parent.Parent.Runtime.HostedSignal)

local ContextActionShim = {}
ContextActionShim.__index = ContextActionShim

local ACTIONS = Constants.CONTEXT_ACTIONS
local METHODS = ACTIONS.METHODS
local EVENTS = ACTIONS.EVENTS
local STAGES = Constants.INPUT.STAGES
local CONTROLLER = Constants.CONTROLLER
local TRACKED_KINDS = Constants.TRACKED_KINDS
local TYPES = Constants.TYPE_NAMES
local EMPTY = Constants.UI.EMPTY_TEXT

local function noOp()
	return nil
end

local function constantMethod(value)
	return function()
		return value
	end
end

local function isInputType(value)
	return typeof(value) == TYPES.ENUM_ITEM and table.find(ACTIONS.INPUT_ENUMS, value.EnumType) ~= nil
end

local function priorityValue(priority)
	if typeof(priority) == TYPES.ENUM_ITEM then
		return priority.Value
	elseif type(priority) == TYPES.NUMBER then
		return priority
	end
	return ACTIONS.DEFAULT_PRIORITY
end

local function matchesInput(inputType, input)
	if inputType == input.KeyCode or inputType == input.UserInputType then
		return true
	end
	local keyList = ACTIONS.PLAYER_ACTION_KEYS[inputType]
	return keyList ~= nil and input.UserInputType == CONTROLLER.KEYBOARD and table.find(CONTROLLER[keyList], input.KeyCode) ~= nil
end

local function bindingMatches(binding, input)
	for _, inputType in ipairs(binding.inputTypes) do
		if matchesInput(inputType, input) then
			return true
		end
	end
	return false
end

local function inputKeyOf(input)
	if input.UserInputType == CONTROLLER.KEYBOARD then
		return input.KeyCode
	end
	return input.UserInputType
end

local function byPriority(left, right)
	if left.priority ~= right.priority then
		return left.priority > right.priority
	end
	return left.stackOrder > right.stackOrder
end

local function infoOf(binding)
	return {
		inputTypes = table.clone(binding.inputTypes),
		priorityLevel = binding.priority,
		createTouchButton = binding.createTouchButton,
		title = binding.title,
		image = binding.image,
		description = binding.description,
		stackOrder = binding.stackOrder,
	}
end

function ContextActionShim.new(tracker, proxy)
	local self = setmetatable({
		tracker = tracker,
		proxy = proxy,
		bindings = {},
		stackOrder = 0,
		equippedTool = nil,
		signals = {},
	}, ContextActionShim)
	for _, name in ipairs(ACTIONS.SIGNALS) do
		self.signals[name] = HostedSignal.new(tracker)
	end
	return self
end

function ContextActionShim:nextStackOrder()
	self.stackOrder += 1
	return self.stackOrder
end

function ContextActionShim:bind(name, callback, createTouchButton, priority, inputTypes)
	if type(name) ~= TYPES.STRING then
		error(ACTIONS.ERRORS.INVALID_NAME, 3)
	end
	if type(callback) ~= TYPES.FUNCTION then
		error(ACTIONS.ERRORS.INVALID_CALLBACK, 3)
	end
	for _, inputType in ipairs(inputTypes) do
		if not isInputType(inputType) then
			error(ACTIONS.ERRORS.INVALID_INPUT, 3)
		end
	end
	local owner = self.tracker:currentOwner()
	local existing = self.bindings[name]
	local binding = {
		name = name,
		callback = self.proxy:hostedArgument(callback, owner),
		createTouchButton = createTouchButton == true,
		priority = priority,
		inputTypes = inputTypes,
		owner = owner,
		title = existing and existing.title or EMPTY,
		image = existing and existing.image or EMPTY,
		description = existing and existing.description or EMPTY,
		position = existing and existing.position or nil,
		stackOrder = existing and existing.stackOrder or self:nextStackOrder(),
		active = {},
	}
	self.bindings[name] = binding
	if owner then
		self.tracker:addNamedBinding(owner, TRACKED_KINDS.ACTION, self, name)
	end
	self.signals[EVENTS.ACTION_ADDED]:fire(name, binding.createTouchButton, infoOf(binding))
end

function ContextActionShim:UnbindAction(name)
	local binding = self.bindings[name]
	if not binding then
		return
	end
	self.bindings[name] = nil
	self.signals[EVENTS.ACTION_REMOVED]:fire(name, infoOf(binding))
end

function ContextActionShim:unbindAll()
	for name in pairs(table.clone(self.bindings)) do
		self:UnbindAction(name)
	end
end

function ContextActionShim:setField(name, field, value)
	local binding = self.bindings[name]
	if binding then
		binding[field] = value
		self.signals[EVENTS.ACTION_CHANGED]:fire(name, field, infoOf(binding))
	end
end

function ContextActionShim:install()
	local getters = {
		[METHODS.BIND_ACTION] = constantMethod(function(_, name, callback, createTouchButton, ...)
			self:bind(name, callback, createTouchButton, ACTIONS.DEFAULT_PRIORITY, { ... })
		end),
		[METHODS.BIND_ACTION_AT_PRIORITY] = constantMethod(function(_, name, callback, createTouchButton, priority, ...)
			self:bind(name, callback, createTouchButton, priorityValue(priority), { ... })
		end),
		[METHODS.UNBIND_ACTION] = constantMethod(function(_, name)
			self:UnbindAction(name)
		end),
		[METHODS.UNBIND_ALL_ACTIONS] = constantMethod(function()
			self:unbindAll()
		end),
		[METHODS.GET_BOUND_ACTION_INFO] = constantMethod(function(_, name)
			local binding = self.bindings[name]
			return binding and infoOf(binding) or {}
		end),
		[METHODS.GET_ALL_BOUND_ACTION_INFO] = constantMethod(function()
			local all = {}
			for name, binding in pairs(self.bindings) do
				all[name] = infoOf(binding)
			end
			return all
		end),
		[METHODS.GET_CURRENT_LOCAL_TOOL_ICON] = constantMethod(function()
			return self.equippedTool and self.equippedTool.TextureId or EMPTY
		end),
	}
	for methodName, field in pairs(ACTIONS.SETTERS) do
		getters[methodName] = constantMethod(function(_, name, value)
			self:setField(name, field, value)
		end)
	end
	for _, methodName in ipairs(ACTIONS.NIL_METHODS) do
		getters[methodName] = constantMethod(noOp)
	end
	for name, signal in pairs(self.signals) do
		getters[name] = function()
			return signal:interface()
		end
	end
	self.proxy:override(ContextActionService, getters)
end

function ContextActionShim:candidates(input, inputKey, allowInactive)
	local list = {}
	for _, binding in pairs(self.bindings) do
		if (allowInactive or binding.active[inputKey]) and bindingMatches(binding, input) then
			table.insert(list, binding)
		end
	end
	table.sort(list, byPriority)
	return list
end

function ContextActionShim:invoke(binding, inputState, input)
	local ok, result = pcall(binding.callback, binding.name, inputState, input)
	if not ok then
		task.spawn(error, result, 0)
		return nil
	end
	return result
end

function ContextActionShim:dispatch(stage, input, gameProcessed)
	local inputState = ACTIONS.STAGE_STATES[stage]
	local inputKey = inputKeyOf(input)
	local ending = stage == STAGES.ENDED
	local sunk = false
	for _, binding in ipairs(self:candidates(input, inputKey, not gameProcessed)) do
		if ending or not sunk then
			if self:invoke(binding, inputState, input) ~= ACTIONS.PASS_RESULT then
				sunk = true
			end
			if stage == STAGES.BEGAN then
				binding.active[inputKey] = true
			elseif ending then
				binding.active[inputKey] = nil
			end
		end
	end
	return sunk
end

function ContextActionShim:listener()
	return function(stage, input, gameProcessed)
		return self:dispatch(stage, input, gameProcessed)
	end
end

function ContextActionShim:toolEquipped(tool)
	self.equippedTool = tool
	self.signals[EVENTS.TOOL_EQUIPPED]:fire(self.proxy:wrap(tool))
end

function ContextActionShim:toolUnequipped(tool)
	if self.equippedTool == tool then
		self.equippedTool = nil
	end
	self.signals[EVENTS.TOOL_UNEQUIPPED]:fire(self.proxy:wrap(tool))
end

function ContextActionShim:clear()
	self.bindings = {}
	self.equippedTool = nil
	for _, signal in pairs(self.signals) do
		signal:clear()
	end
	self.proxy:clearOverrides(ContextActionService)
end

return ContextActionShim
