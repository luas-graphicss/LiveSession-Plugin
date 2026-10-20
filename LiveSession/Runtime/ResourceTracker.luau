local Constants = require(script.Parent.Parent.Core.Constants)

local ResourceTracker = {}
ResourceTracker.__index = ResourceTracker

local DEAD = Constants.COROUTINE_STATUS_DEAD
local COMPACT_MIN_ENTRIES = Constants.TRACKER_COMPACT_MIN_ENTRIES
local TWEEN_BASE = Constants.CLASS_NAMES.TWEEN_BASE

local UNBIND = {
	[Constants.TRACKED_KINDS.ACTION] = function(service, name)
		service:UnbindAction(name)
	end,
	[Constants.TRACKED_KINDS.RENDER_BIND] = function(service, name)
		service:UnbindFromRenderStep(name)
	end,
}

local function isThreadAlive(thread)
	return coroutine.status(thread) ~= DEAD
end

local function isConnectionAlive(connection)
	return connection.Connected ~= false
end

local function isInstanceAlive(instance)
	return instance.Parent ~= nil
end

local function newList(isAlive)
	return { entries = {}, isAlive = isAlive, compactAt = COMPACT_MIN_ENTRIES }
end

local function compact(list)
	local entries = list.entries
	local kept = 0
	for index = 1, #entries do
		local entry = entries[index]
		if list.isAlive(entry) then
			kept += 1
			entries[kept] = entry
		end
	end
	for index = #entries, kept + 1, -1 do
		entries[index] = nil
	end
	list.compactAt = math.max(COMPACT_MIN_ENTRIES, kept * 2)
end

local function append(list, entry)
	if #list.entries >= list.compactAt then
		compact(list)
	end
	table.insert(list.entries, entry)
end

local function newCounts()
	return { connections = 0, threads = 0, instances = 0, failures = 0 }
end

local function countFailure(counts, ok)
	if not ok then
		counts.failures += 1
	end
end

local function unbindAll(bucket, counts)
	for index = #bucket.bindings, 1, -1 do
		local binding = bucket.bindings[index]
		counts.connections += 1
		countFailure(counts, pcall(UNBIND[binding.kind], binding.service, binding.name))
	end
end

local function disconnectAll(bucket, counts)
	local connections = bucket.connections.entries
	for index = #connections, 1, -1 do
		local connection = connections[index]
		counts.connections += 1
		countFailure(counts, pcall(connection.Disconnect, connection))
	end
end

local function cancelThreads(bucket, counts)
	local current = coroutine.running()
	local threads = bucket.threads.entries
	for index = #threads, 1, -1 do
		local thread = threads[index]
		counts.threads += 1
		if thread ~= current and isThreadAlive(thread) then
			countFailure(counts, pcall(task.cancel, thread))
		end
	end
end

local function stopActivity(bucket, counts)
	unbindAll(bucket, counts)
	disconnectAll(bucket, counts)
	cancelThreads(bucket, counts)
end

function ResourceTracker.new()
	return setmetatable({
		buckets = {},
		ownerByThread = setmetatable({}, { __mode = "k" }),
		hostedInstances = setmetatable({}, { __mode = "k" }),
		destroying = setmetatable({}, { __mode = "k" }),
	}, ResourceTracker)
end

function ResourceTracker:bucket(owner)
	local bucket = self.buckets[owner]
	if not bucket then
		bucket = {
			connections = newList(isConnectionAlive),
			threads = newList(isThreadAlive),
			instances = newList(isInstanceAlive),
			bindings = {},
		}
		self.buckets[owner] = bucket
	end
	return bucket
end

function ResourceTracker:addNamedBinding(owner, kind, service, name)
	table.insert(self:bucket(owner).bindings, { kind = kind, service = service, name = name })
end

function ResourceTracker:adopt(thread, owner)
	self.ownerByThread[thread] = owner
end

function ResourceTracker:ownerOf(thread)
	return self.ownerByThread[thread]
end

function ResourceTracker:currentOwner()
	return self.ownerByThread[coroutine.running()]
end

function ResourceTracker:addConnection(owner, connection)
	append(self:bucket(owner).connections, connection)
end

function ResourceTracker:addThread(owner, thread)
	self.ownerByThread[thread] = owner
	append(self:bucket(owner).threads, thread)
end

function ResourceTracker:addInstance(owner, instance)
	self.hostedInstances[instance] = true
	append(self:bucket(owner).instances, instance)
end

function ResourceTracker:isHostedInstance(instance)
	return self.hostedInstances[instance] == true
end

function ResourceTracker:markDestroying(instance)
	self.destroying[instance] = true
end

function ResourceTracker:isDestroying(instance)
	return self.destroying[instance] == true
end

function ResourceTracker:destroyInstances(bucket, counts)
	local instances = bucket.instances.entries
	for index = #instances, 1, -1 do
		local instance = instances[index]
		self.destroying[instance] = true
		counts.instances += 1
		if instance:IsA(TWEEN_BASE) then
			pcall(instance.Cancel, instance)
		end
		countFailure(counts, pcall(instance.Destroy, instance))
	end
end

function ResourceTracker:takeBucket(owner)
	local bucket = self.buckets[owner]
	self.buckets[owner] = nil
	return bucket
end

function ResourceTracker:stop(owner)
	local counts = newCounts()
	local bucket = self:takeBucket(owner)
	if bucket then
		stopActivity(bucket, counts)
	end
	return counts
end

function ResourceTracker:release(owner)
	local counts = newCounts()
	local bucket = self:takeBucket(owner)
	if bucket then
		stopActivity(bucket, counts)
		self:destroyInstances(bucket, counts)
	end
	return counts
end

function ResourceTracker:releaseAll()
	local totals = newCounts()
	for owner in pairs(self.buckets) do
		local counts = self:release(owner)
		for key, value in pairs(counts) do
			totals[key] += value
		end
	end
	return totals
end

function ResourceTracker:counts()
	local totals = { connections = 0, threads = 0, instances = 0 }
	for _, bucket in pairs(self.buckets) do
		totals.connections += #bucket.connections.entries + #bucket.bindings
		totals.threads += #bucket.threads.entries
		totals.instances += #bucket.instances.entries
	end
	return totals
end

return ResourceTracker
