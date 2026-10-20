local MessagingService = game:GetService("MessagingService")

local Constants = require(script.Parent.Parent.Core.Constants)
local HostedSignal = require(script.Parent.HostedSignal)

local MessagingShim = {}
MessagingShim.__index = MessagingShim

local MESSAGING = Constants.MESSAGING
local TYPES = Constants.TYPE_NAMES

local function copyMessage(value, copies)
	if type(value) ~= TYPES.TABLE then
		return value
	end
	local existing = copies[value]
	if existing then
		return existing
	end
	local copy = {}
	copies[value] = copy
	for key, item in pairs(value) do
		copy[key] = copyMessage(item, copies)
	end
	return copy
end

function MessagingShim.new(proxy, tracker)
	return setmetatable({
		proxy = proxy,
		tracker = tracker,
		topics = {},
	}, MessagingShim)
end

function MessagingShim:topic(name)
	if type(name) ~= TYPES.STRING then
		error(MESSAGING.TOPIC_ERROR, 3)
	end
	local signal = self.topics[name]
	if not signal then
		signal = HostedSignal.new(self.tracker)
		self.topics[name] = signal
	end
	return signal
end

function MessagingShim:subscribe(name, callback)
	if type(callback) ~= TYPES.FUNCTION then
		error(MESSAGING.CALLBACK_ERROR, 3)
	end
	return self:topic(name):connect(callback, false)
end

function MessagingShim:publish(name, message)
	local signal = self:topic(name)
	local payload = { Data = copyMessage(self.proxy:unwrap(message), {}), Sent = os.time() }
	task.defer(function()
		signal:fire(payload)
	end)
end

function MessagingShim:install()
	self.proxy:override(MessagingService, {
		[MESSAGING.SUBSCRIBE] = function()
			return function(_, name, callback)
				return self:subscribe(name, callback)
			end
		end,
		[MESSAGING.PUBLISH] = function()
			return function(_, name, message)
				self:publish(name, message)
			end
		end,
	})
end

function MessagingShim:counts()
	local topics = 0
	local subscribers = 0
	for _, signal in pairs(self.topics) do
		topics += 1
		subscribers += #signal.handlers
	end
	return { topics = topics, subscribers = subscribers }
end

function MessagingShim:clear()
	for _, signal in pairs(self.topics) do
		signal:clear()
	end
	self.topics = {}
	self.proxy:clearOverrides(MessagingService)
end

return MessagingShim
