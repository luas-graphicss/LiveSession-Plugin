local Constants = require(script.Parent.Parent.Core.Constants)
local Hash = require(script.Parent.Parent.Core.Hash)
local Journal = require(script.Parent.Journal)

local JournalStore = {}
JournalStore.__index = JournalStore

local SETTINGS = Constants.SETTINGS
local TYPES = Constants.TYPE_NAMES

local function splitChunks(text, chunkChars)
	local chunks = {}
	local position = 1
	repeat
		table.insert(chunks, string.sub(text, position, position + chunkChars - 1))
		position += chunkChars
	until position > #text
	return chunks
end

local function joinChunks(chunks, expectedCount, expectedHash)
	if #chunks ~= expectedCount then
		return nil, Constants.ERRORS.JOURNAL_CHUNKS
	end
	local text = table.concat(chunks)
	if Hash.text(text) ~= expectedHash then
		return nil, Constants.ERRORS.JOURNAL_HASH
	end
	return text
end

local function isIndex(index)
	return type(index) == TYPES.TABLE and type(index.chunkCount) == TYPES.NUMBER
end

local function usesFlatChunkKeys(index)
	return index.chunks == nil
end

function JournalStore.new(plugin)
	return setmetatable({
		plugin = plugin,
		mirrorParent = nil,
		mirrorInterval = 0,
		mirrorPending = false,
		lastMirrorAt = 0,
	}, JournalStore)
end

function JournalStore:setMirrorParent(folder)
	self.mirrorParent = folder
end

function JournalStore:setMirrorInterval(seconds)
	self.mirrorInterval = seconds
end

function JournalStore:writeChunkedSetting(indexKey, text, hash, index)
	index.chunks = splitChunks(text, Constants.JOURNAL_CHUNK_CHARS)
	index.chunkCount = #index.chunks
	index.chars = #text
	index.hash = hash
	index.writtenAt = os.time()
	self.plugin:SetSetting(indexKey, index)
end

function JournalStore:readFlatChunks(index, chunkPrefix)
	local chunks = {}
	for number = 1, index.chunkCount do
		local chunk = self.plugin:GetSetting(chunkPrefix .. number)
		if type(chunk) ~= TYPES.STRING then
			return nil
		end
		chunks[number] = chunk
	end
	return chunks
end

function JournalStore:readChunkedSetting(indexKey, chunkPrefix)
	local index = self.plugin:GetSetting(indexKey)
	if not isIndex(index) or type(index.hash) ~= TYPES.STRING then
		return nil
	end
	local chunks = if usesFlatChunkKeys(index) then self:readFlatChunks(index, chunkPrefix) else index.chunks
	if not chunks then
		return nil, Constants.ERRORS.JOURNAL_CHUNKS
	end
	local text, reason = joinChunks(chunks, index.chunkCount, index.hash)
	if not text then
		return nil, reason
	end
	return Journal.deserialize(text)
end

function JournalStore:clearChunkedSetting(indexKey, chunkPrefix)
	local index = self.plugin:GetSetting(indexKey)
	if isIndex(index) and usesFlatChunkKeys(index) then
		for number = 1, index.chunkCount do
			self.plugin:SetSetting(chunkPrefix .. number, nil)
		end
	end
	self.plugin:SetSetting(indexKey, nil)
end

function JournalStore:writeMirror(text, hash, journal)
	local parent = self.mirrorParent
	if not parent then
		return
	end
	local folder = parent:FindFirstChild(Constants.JOURNAL_FOLDER_NAME)
	if not folder then
		folder = Instance.new(Constants.CLASS_NAMES.FOLDER)
		folder.Name = Constants.JOURNAL_FOLDER_NAME
		folder.Parent = parent
	end
	local chunks = splitChunks(text, Constants.MIRROR_CHUNK_CHARS)
	for number, chunk in ipairs(chunks) do
		local name = Constants.MIRROR_CHUNK_NAME_PREFIX .. number
		local value = folder:FindFirstChild(name)
		if not value then
			value = Instance.new(Constants.CLASS_NAMES.STRING_VALUE)
			value.Name = name
			value.Parent = folder
		end
		value.Value = chunk
	end
	for _, child in ipairs(folder:GetChildren()) do
		local number = tonumber(string.sub(child.Name, #Constants.MIRROR_CHUNK_NAME_PREFIX + 1))
		if number and number > #chunks then
			child:Destroy()
		end
	end
	folder:SetAttribute(Constants.MIRROR_CHUNK_COUNT_ATTRIBUTE, #chunks)
	folder:SetAttribute(Constants.MIRROR_HASH_ATTRIBUTE, hash)
	folder:SetAttribute(Constants.MIRROR_SESSION_ATTRIBUTE, journal.sessionId)
end

function JournalStore.readMirror(pluginFolder)
	local folder = pluginFolder and pluginFolder:FindFirstChild(Constants.JOURNAL_FOLDER_NAME)
	if not folder then
		return nil
	end
	local count = folder:GetAttribute(Constants.MIRROR_CHUNK_COUNT_ATTRIBUTE)
	local hash = folder:GetAttribute(Constants.MIRROR_HASH_ATTRIBUTE)
	if type(count) ~= TYPES.NUMBER or type(hash) ~= TYPES.STRING then
		return nil, Constants.ERRORS.JOURNAL_CHUNKS
	end
	local chunks = {}
	for number = 1, count do
		local value = folder:FindFirstChild(Constants.MIRROR_CHUNK_NAME_PREFIX .. number)
		if not value then
			return nil, Constants.ERRORS.JOURNAL_CHUNKS
		end
		chunks[number] = value.Value
	end
	local text, reason = joinChunks(chunks, count, hash)
	if not text then
		return nil, reason
	end
	return Journal.deserialize(text)
end

function JournalStore:scheduleMirror(journal)
	if self.mirrorPending then
		return
	end
	self.mirrorPending = true
	task.delay(self.mirrorInterval - (os.clock() - self.lastMirrorAt), function()
		self.mirrorPending = false
		if self.mirrorParent then
			local text = journal:serialize()
			pcall(self.writeMirror, self, text, Hash.text(text), journal)
			self.lastMirrorAt = os.clock()
		end
	end)
end

function JournalStore:write(journal)
	local text = journal:serialize()
	local hash = Hash.text(text)
	local settingsOk, settingsError = pcall(self.writeChunkedSetting, self, SETTINGS.JOURNAL_INDEX, text, hash, {
		format = journal.format,
		sessionId = journal.sessionId,
		closed = journal.closed,
	})
	local mirrorOk, mirrorError = true, nil
	if self.mirrorInterval > 0 and not journal.closed and os.clock() - self.lastMirrorAt < self.mirrorInterval then
		self:scheduleMirror(journal)
	else
		mirrorOk, mirrorError = pcall(self.writeMirror, self, text, hash, journal)
		self.lastMirrorAt = os.clock()
	end
	return settingsOk, settingsError, mirrorOk, mirrorError, #text
end

function JournalStore:readSettings()
	return self:readChunkedSetting(SETTINGS.JOURNAL_INDEX, SETTINGS.JOURNAL_CHUNK_PREFIX)
end

function JournalStore:clear()
	self:clearChunkedSetting(SETTINGS.JOURNAL_INDEX, SETTINGS.JOURNAL_CHUNK_PREFIX)
end

function JournalStore:archive(journal)
	local text = journal:serialize()
	local prefix = SETTINGS.ARCHIVE_PREFIX .. journal.sessionId
	self:writeChunkedSetting(prefix .. SETTINGS.ARCHIVE_INDEX_SUFFIX, text, Hash.text(text), {
		format = journal.format,
		sessionId = journal.sessionId,
		closed = journal.closed,
	})
	local closed = self.plugin:GetSetting(SETTINGS.CLOSED_SESSIONS)
	if type(closed) ~= TYPES.TABLE then
		closed = {}
	end
	table.insert(closed, journal.sessionId)
	while #closed > Constants.CLOSED_JOURNAL_RETENTION_SESSIONS do
		local oldest = table.remove(closed, 1)
		local oldPrefix = SETTINGS.ARCHIVE_PREFIX .. oldest
		self:clearChunkedSetting(oldPrefix .. SETTINGS.ARCHIVE_INDEX_SUFFIX, oldPrefix .. SETTINGS.ARCHIVE_CHUNK_SUFFIX)
	end
	self.plugin:SetSetting(SETTINGS.CLOSED_SESSIONS, closed)
	self:clear()
end

function JournalStore:writeLock(sessionId, placeId)
	self.plugin:SetSetting(SETTINGS.LOCK, { sessionId = sessionId, placeId = placeId, heartbeatAt = os.time() })
end

function JournalStore:readLock()
	local lock = self.plugin:GetSetting(SETTINGS.LOCK)
	if type(lock) ~= TYPES.TABLE or type(lock.sessionId) ~= TYPES.STRING or type(lock.heartbeatAt) ~= TYPES.NUMBER then
		return nil
	end
	lock.alive = os.time() - lock.heartbeatAt < Constants.LOCK_STALE_SECONDS
	return lock
end

function JournalStore:clearLock()
	self.plugin:SetSetting(SETTINGS.LOCK, nil)
end

local validEngines = {}
for _, engine in pairs(Constants.ENGINES) do
	validEngines[engine] = true
end

function JournalStore:readEngine(placeId)
	local engine = self.plugin:GetSetting(SETTINGS.ENGINE_PREFIX .. tostring(placeId))
	if validEngines[engine] then
		return engine
	end
	return Constants.ENGINES.HOSTED
end

function JournalStore:writeEngine(placeId, engine)
	if not validEngines[engine] then
		error(string.format(Constants.ERRORS.INVALID_ENGINE, tostring(engine)), 2)
	end
	self.plugin:SetSetting(SETTINGS.ENGINE_PREFIX .. tostring(placeId), engine)
end

function JournalStore:isAcknowledged(code)
	return self.plugin:GetSetting(SETTINGS.ACKNOWLEDGED_PREFIX .. code) == true
end

function JournalStore:acknowledge(code)
	self.plugin:SetSetting(SETTINGS.ACKNOWLEDGED_PREFIX .. code, true)
end

return JournalStore
