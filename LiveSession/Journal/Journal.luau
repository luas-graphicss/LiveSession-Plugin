local HttpService = game:GetService("HttpService")

local Constants = require(script.Parent.Parent.Core.Constants)

local Journal = {}
Journal.__index = Journal

local KINDS = Constants.ENTRY_KINDS
local TYPES = Constants.TYPE_NAMES

local validKinds = {}
for _, kind in pairs(KINDS) do
	validKinds[kind] = true
end

function Journal.new(header)
	return setmetatable({
		format = Constants.JOURNAL_FORMAT_VERSION,
		sessionId = header.sessionId,
		placeId = header.placeId,
		startedAt = header.startedAt,
		closed = false,
		entries = {},
		nextSeq = 1,
	}, Journal)
end

function Journal:append(kind, fields)
	local entry = table.clone(fields)
	entry.seq = self.nextSeq
	entry.kind = kind
	entry.at = os.time()
	self.nextSeq += 1
	table.insert(self.entries, entry)
	if kind == KINDS.SOURCE then
		self:compactSources(entry.id)
	end
	return entry
end

function Journal:compactSources(id)
	local kept = 0
	for index = #self.entries, 1, -1 do
		local entry = self.entries[index]
		if entry.kind == KINDS.SOURCE and entry.id == id then
			kept += 1
			if kept > Constants.SOURCE_HISTORY_DEPTH and entry.source ~= nil then
				entry.sourceLength = #entry.source
				entry.source = nil
			end
		end
	end
end

function Journal:entriesOfKind(kind)
	local result = {}
	for _, entry in ipairs(self.entries) do
		if entry.kind == kind then
			table.insert(result, entry)
		end
	end
	return result
end

function Journal:finalSources()
	local latest = {}
	for _, entry in ipairs(self.entries) do
		if entry.kind == KINDS.SOURCE and entry.source ~= nil then
			latest[entry.id] = entry
		end
	end
	return latest
end

function Journal:lifecycles()
	local lifecycles = {}
	for _, entry in ipairs(self.entries) do
		if entry.kind == KINDS.CREATE or entry.kind == KINDS.DESTROY then
			local lifecycle = lifecycles[entry.id]
			if not lifecycle then
				lifecycle = { preexisting = entry.kind == KINDS.DESTROY, originPath = entry.path }
				lifecycles[entry.id] = lifecycle
			end
			lifecycle.alive = entry.kind == KINDS.CREATE
		end
	end
	return lifecycles
end

function Journal:lastSourceEntry(id)
	for index = #self.entries, 1, -1 do
		local entry = self.entries[index]
		if entry.kind == KINDS.SOURCE and entry.id == id then
			return entry
		end
	end
	return nil
end

function Journal:lastSourceHash(id)
	local entry = self:lastSourceEntry(id)
	return entry and entry.afterHash or nil
end

function Journal:count()
	return #self.entries
end

function Journal:close()
	self.closed = true
end

function Journal:toTable()
	return {
		format = self.format,
		sessionId = self.sessionId,
		placeId = self.placeId,
		startedAt = self.startedAt,
		closed = self.closed,
		entries = self.entries,
	}
end

function Journal:serialize()
	return HttpService:JSONEncode(self:toTable())
end

local function validateEntry(entry)
	return type(entry) == TYPES.TABLE
		and type(entry.seq) == TYPES.NUMBER
		and validKinds[entry.kind] == true
		and type(entry.id) == TYPES.STRING
end

function Journal.fromTable(data)
	if type(data) ~= TYPES.TABLE then
		return nil, Constants.ERRORS.JOURNAL_NOT_TABLE
	end
	if data.format ~= Constants.JOURNAL_FORMAT_VERSION then
		return nil, string.format(Constants.ERRORS.JOURNAL_FORMAT, tostring(data.format))
	end
	if type(data.sessionId) ~= TYPES.STRING then
		return nil, Constants.ERRORS.JOURNAL_SESSION
	end
	if type(data.entries) ~= TYPES.TABLE then
		return nil, Constants.ERRORS.JOURNAL_ENTRIES
	end
	local journal = Journal.new({ sessionId = data.sessionId, placeId = data.placeId, startedAt = data.startedAt })
	journal.closed = data.closed == true
	for index, entry in ipairs(data.entries) do
		if not validateEntry(entry) then
			return nil, string.format(Constants.ERRORS.JOURNAL_ENTRY, index)
		end
		table.insert(journal.entries, entry)
		journal.nextSeq = math.max(journal.nextSeq, entry.seq + 1)
	end
	return journal
end

function Journal.deserialize(text)
	local ok, data = pcall(HttpService.JSONDecode, HttpService, text)
	if not ok then
		return nil, data
	end
	return Journal.fromTable(data)
end

return Journal
