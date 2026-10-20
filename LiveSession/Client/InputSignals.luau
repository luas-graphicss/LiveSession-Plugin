local UserInputService = game:GetService("UserInputService")

local Constants = require(script.Parent.Parent.Core.Constants)
local HostedSignal = require(script.Parent.Parent.Runtime.HostedSignal)

local InputSignals = {}
InputSignals.__index = InputSignals

local INPUT = Constants.INPUT
local STAGES = INPUT.STAGES
local CONTROLLER = Constants.CONTROLLER

local function isJumpKey(input)
	return input.UserInputType == CONTROLLER.KEYBOARD and table.find(CONTROLLER.JUMP_KEYS, input.KeyCode) ~= nil
end

function InputSignals.new(tracker, proxy)
	local self = setmetatable({
		tracker = tracker,
		proxy = proxy,
		signals = {},
	}, InputSignals)
	for _, name in ipairs(INPUT.SIGNALS) do
		self.signals[name] = HostedSignal.new(tracker)
	end
	return self
end

function InputSignals:install()
	local getters = {}
	for name, signal in pairs(self.signals) do
		getters[name] = function()
			return signal:interface()
		end
	end
	self.proxy:override(UserInputService, getters)
end

function InputSignals:listener()
	return function(stage, input, gameProcessed)
		self.signals[INPUT.STAGE_SIGNALS[stage]]:fire(self.proxy:wrap(input), gameProcessed)
		if stage == STAGES.BEGAN and not gameProcessed and isJumpKey(input) then
			self.signals[INPUT.JUMP_SIGNAL]:fire()
		end
		return false
	end
end

function InputSignals:clear()
	for _, signal in pairs(self.signals) do
		signal:clear()
	end
end

return InputSignals
