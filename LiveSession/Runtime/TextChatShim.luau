local TextChatService = game:GetService("TextChatService")

local Constants = require(script.Parent.Parent.Core.Constants)
local HostedSignal = require(script.Parent.HostedSignal)

local TextChatShim = {}
TextChatShim.__index = TextChatShim

local TEXT_CHAT = Constants.TEXT_CHAT
local METHODS = TEXT_CHAT.METHODS
local MEMBERS = TEXT_CHAT.MEMBERS
local CLASSES = Constants.CLASS_NAMES
local CONTEXTS = Constants.CONTEXTS
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

function TextChatShim.new(tracker, proxy, getPlayer, onChatted)
	return setmetatable({
		tracker = tracker,
		proxy = proxy,
		getPlayer = getPlayer,
		onChatted = onChatted,
		owner = { name = TEXT_CHAT.OWNER_NAME, context = CONTEXTS.SERVER },
		channelStates = setmetatable({}, { __mode = "k" }),
		channels = {},
		messageReceived = HostedSignal.new(tracker),
		sendingMessage = HostedSignal.new(tracker),
		onIncomingMessage = nil,
		messageListeners = {},
		nextMessageId = 0,
		bridgeTable = nil,
	}, TextChatShim)
end

function TextChatShim:ensureChild(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	self.tracker:addInstance(self.owner, instance)
	instance.Parent = parent
	return instance
end

function TextChatShim:createChannels()
	local channelsFolder = self:ensureChild(TextChatService, CLASSES.FOLDER, TEXT_CHAT.CHANNELS_FOLDER)
	self:ensureChild(TextChatService, CLASSES.FOLDER, TEXT_CHAT.COMMANDS_FOLDER)
	if TextChatService[TEXT_CHAT.CREATE_DEFAULT_CHANNELS] then
		self.channels[TEXT_CHAT.GENERAL_CHANNEL] = self:ensureChild(channelsFolder, TEXT_CHAT.CHANNEL_CLASS, TEXT_CHAT.GENERAL_CHANNEL)
	end
	self.channels[TEXT_CHAT.SYSTEM_CHANNEL] = self:ensureChild(channelsFolder, TEXT_CHAT.CHANNEL_CLASS, TEXT_CHAT.SYSTEM_CHANNEL)
end

function TextChatShim:stateFor(channel)
	local state = self.channelStates[channel]
	if not state then
		state = {
			messageReceived = HostedSignal.new(self.tracker),
			onIncomingMessage = nil,
			shouldDeliver = nil,
		}
		self.channelStates[channel] = state
	end
	return state
end

function TextChatShim:textSource()
	local player = self.getPlayer()
	if player == nil then
		return nil
	end
	return {
		ClassName = TEXT_CHAT.TEXT_SOURCE_CLASS,
		UserId = player.UserId,
		Name = player.Name,
		CanSend = true,
	}
end

function TextChatShim:buildMessage(channel, text, metadata, textSource)
	if type(text) ~= TYPES.STRING then
		error(TEXT_CHAT.INVALID_TEXT_MESSAGE, 4)
	end
	self.nextMessageId += 1
	return {
		ClassName = TEXT_CHAT.MESSAGE_CLASS,
		MessageId = tostring(self.nextMessageId),
		Text = text,
		PrefixText = EMPTY,
		Metadata = type(metadata) == TYPES.STRING and metadata or EMPTY,
		Status = TEXT_CHAT.SUCCESS_STATUS,
		TextSource = textSource,
		TextChannel = self.proxy:wrap(channel),
		Timestamp = DateTime.now(),
	}
end

function TextChatShim:applyProperties(message, properties)
	if typeof(properties) ~= TYPES.INSTANCE or not properties:IsA(TEXT_CHAT.PROPERTIES_CLASS) then
		return
	end
	if properties.Text ~= EMPTY then
		message.Text = properties.Text
	end
	if properties.PrefixText ~= EMPTY then
		message.PrefixText = properties.PrefixText
	end
end

function TextChatShim:deliver(channel, message)
	local state = self:stateFor(channel)
	if self.onIncomingMessage then
		self:applyProperties(message, self.onIncomingMessage(message))
	end
	if state.onIncomingMessage then
		self:applyProperties(message, state.onIncomingMessage(message))
	end
	if state.shouldDeliver and state.shouldDeliver(message, message.TextSource) == false then
		return message
	end
	state.messageReceived:fire(message)
	self.messageReceived:fire(message)
	for _, listener in ipairs(self.messageListeners) do
		listener(message)
	end
	return message
end

function TextChatShim:send(channel, text, metadata)
	local message = self:buildMessage(channel, text, metadata, self:textSource())
	self.sendingMessage:fire(message)
	return self:deliver(channel, message)
end

function TextChatShim:displaySystemMessage(channel, text, metadata)
	return self:deliver(channel, self:buildMessage(channel, text, metadata, nil))
end

function TextChatShim:bridge()
	if self.bridgeTable then
		return self.bridgeTable
	end
	local readers = {
		[METHODS.SEND_ASYNC] = function(channel)
			return function(_, text, metadata)
				return self:send(channel, text, metadata)
			end
		end,
		[METHODS.DISPLAY_SYSTEM_MESSAGE] = function(channel)
			return function(_, text, metadata)
				return self:displaySystemMessage(channel, text, metadata)
			end
		end,
		[METHODS.ADD_USER_ASYNC] = function()
			return function()
				return self:textSource(), true
			end
		end,
		[METHODS.SET_DIRECT_CHAT_REQUESTER] = constantMethod(noOp),
		[MEMBERS.MESSAGE_RECEIVED] = function(channel)
			return self:stateFor(channel).messageReceived:interface()
		end,
		[MEMBERS.ON_INCOMING_MESSAGE] = function(channel)
			return self:stateFor(channel).onIncomingMessage
		end,
		[MEMBERS.SHOULD_DELIVER_CALLBACK] = function(channel)
			return self:stateFor(channel).shouldDeliver
		end,
	}
	self.bridgeTable = {
		name = TEXT_CHAT.CHANNEL_CLASS,
		matches = function(instance)
			return instance.ClassName == TEXT_CHAT.CHANNEL_CLASS
		end,
		read = function(channel, key)
			local reader = readers[key]
			if reader then
				return true, reader(channel)
			end
			return false
		end,
		write = function(channel, key, value)
			if key == MEMBERS.ON_INCOMING_MESSAGE then
				self:stateFor(channel).onIncomingMessage = value
				return true
			elseif key == MEMBERS.SHOULD_DELIVER_CALLBACK then
				self:stateFor(channel).shouldDeliver = value
				return true
			end
			return false
		end,
	}
	return self.bridgeTable
end

function TextChatShim:install()
	self:createChannels()
	self.proxy:addBridge(self:bridge())
	local getters = {
		[MEMBERS.ON_INCOMING_MESSAGE] = function()
			return self.onIncomingMessage
		end,
		[MEMBERS.MESSAGE_RECEIVED] = function()
			return self.messageReceived:interface()
		end,
		[MEMBERS.SENDING_MESSAGE] = function()
			return self.sendingMessage:interface()
		end,
		[METHODS.DISPLAY_BUBBLE] = constantMethod(noOp),
	}
	for _, name in ipairs(TEXT_CHAT.TRUE_METHODS) do
		getters[name] = constantMethod(constantMethod(true))
	end
	self.proxy:override(TextChatService, getters, {
		[MEMBERS.ON_INCOMING_MESSAGE] = function(value)
			self.onIncomingMessage = value
		end,
	})
end

function TextChatShim:onMessage(callback)
	table.insert(self.messageListeners, callback)
end

function TextChatShim:sendLocal(text)
	local channel = self.channels[TEXT_CHAT.GENERAL_CHANNEL]
	if channel == nil then
		return nil
	end
	local message = self:send(channel, text)
	if self.onChatted then
		self.onChatted(message.Text)
	end
	return message
end

function TextChatShim:displaySystem(text)
	return self:displaySystemMessage(self.channels[TEXT_CHAT.SYSTEM_CHANNEL], text)
end

function TextChatShim:clear()
	self.messageReceived:clear()
	self.sendingMessage:clear()
	for _, state in pairs(self.channelStates) do
		state.messageReceived:clear()
	end
	self.channelStates = setmetatable({}, { __mode = "k" })
	self.channels = {}
	self.onIncomingMessage = nil
	self.messageListeners = {}
	self.proxy:clearOverrides(TextChatService)
	self.tracker:release(self.owner)
end

return TextChatShim
