local LogService = game:GetService("LogService")

local Constants = require(script.Parent.Parent.Core.Constants)

local OutputLog = {}
OutputLog.__index = OutputLog

local OUTPUT = Constants.OUTPUT
local KINDS = OUTPUT.KINDS

function OutputLog.new()
	return setmetatable({
		entries = {},
		counts = { [KINDS.ERROR] = 0, [KINDS.WARN] = 0 },
		entryListeners = {},
		clearListeners = {},
		attentionListeners = {},
		connection = nil,
		nextSeq = 1,
	}, OutputLog)
end

function OutputLog:onEntry(callback)
	table.insert(self.entryListeners, callback)
end

function OutputLog:onCleared(callback)
	table.insert(self.clearListeners, callback)
end

function OutputLog:onAttention(callback)
	table.insert(self.attentionListeners, callback)
end

function OutputLog:push(kind, text)
	local entry = { kind = kind, text = tostring(text), time = os.date(Constants.UI.OUTPUT_TIME_FORMAT), seq = self.nextSeq }
	self.nextSeq += 1
	table.insert(self.entries, entry)
	if self.counts[kind] then
		self.counts[kind] += 1
	end
	if #self.entries > OUTPUT.CAPACITY then
		table.remove(self.entries, 1)
	end
	for _, listener in ipairs(self.entryListeners) do
		listener(entry)
	end
	return entry
end

function OutputLog:error(text)
	return self:push(KINDS.ERROR, text)
end

function OutputLog:warn(text)
	return self:push(KINDS.WARN, text)
end

function OutputLog:info(text)
	return self:push(KINDS.INFO, text)
end

function OutputLog:attention()
	for _, listener in ipairs(self.attentionListeners) do
		listener()
	end
end

function OutputLog:capture()
	if self.connection then
		return
	end
	self.connection = LogService.MessageOut:Connect(function(message, messageType)
		local kind = OUTPUT.MESSAGE_TYPES[messageType.Name]
		if kind then
			self:push(kind, message)
		end
	end)
end

function OutputLog:release()
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
end

function OutputLog:clear()
	self.entries = {}
	for kind in pairs(self.counts) do
		self.counts[kind] = 0
	end
	for _, listener in ipairs(self.clearListeners) do
		listener()
	end
end

function OutputLog:count(kind)
	return self.counts[kind] or 0
end

function OutputLog:size()
	return #self.entries
end

function OutputLog:all()
	return self.entries
end

return OutputLog
