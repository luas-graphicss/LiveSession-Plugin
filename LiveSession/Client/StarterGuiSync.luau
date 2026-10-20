local StarterGui = game:GetService("StarterGui")

local Constants = require(script.Parent.Parent.Core.Constants)
local StarterClone = require(script.Parent.StarterClone)

 
 
 
 
 
 
 
 
local StarterGuiSync = {}
StarterGuiSync.__index = StarterGuiSync

local SYNC = Constants.GUI_SYNC
local IGNORED = SYNC.IGNORED_PROPERTIES
local TEXTS = Constants.TEXTS
local VALUE_PROPERTY = Constants.PROPERTY_NAMES.VALUE

function StarterGuiSync.new(deps)
	return setmetatable({
		deps = deps,
		connections = {},
		watched = {},
		topOf = {},
		pending = {},
		timer = nil,
		active = false,
	}, StarterGuiSync)
end

local function topLevel(instance)
	local current = instance
	while current and current.Parent ~= StarterGui do
		current = current.Parent
	end
	return current
end

function StarterGuiSync:start()
	if self.active then
		return
	end
	self.active = true
	table.insert(self.connections, StarterGui.DescendantAdded:Connect(function(instance)
		self:onAdded(instance)
	end))
	table.insert(self.connections, StarterGui.DescendantRemoving:Connect(function(instance)
		self:onRemoving(instance)
	end))
	for _, instance in ipairs(StarterGui:GetDescendants()) do
		self:watch(instance, topLevel(instance))
	end
end

function StarterGuiSync:watch(instance, top)
	if self.watched[instance] or top == nil then
		return
	end
	self.topOf[instance] = top
	local changed = instance.Changed:Connect(function(property)
		if type(property) ~= "string" then
			property = VALUE_PROPERTY
		end
		self:onProperty(instance, property)
	end)
	local attribute = instance.AttributeChanged:Connect(function(name)
		self:onAttribute(instance, name)
	end)
	self.watched[instance] = { changed, attribute }
end

function StarterGuiSync:unwatch(instance)
	local connections = self.watched[instance]
	if connections then
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		self.watched[instance] = nil
	end
	self.topOf[instance] = nil
end

function StarterGuiSync:isRuntime(instance)
	local ok, runtime = pcall(self.deps.isRuntime, instance)
	return ok and runtime == true
end

function StarterGuiSync:job(top)
	local job = self.pending[top]
	if not job then
		job = { remount = false, properties = {}, attributes = {} }
		self.pending[top] = job
	end
	return job
end

function StarterGuiSync:schedule()
	if self.timer or not self.active then
		return
	end
	self.timer = task.delay(SYNC.DEBOUNCE_SECONDS, function()
		self.timer = nil
		self:flush()
	end)
end

function StarterGuiSync:onAdded(instance)
	if not self.active or self:isRuntime(instance) then
		return
	end
	local top = topLevel(instance)
	if not top then
		return
	end
	self:watch(instance, top)
	self:job(top).remount = true
	self:schedule()
end

function StarterGuiSync:onRemoving(instance)
	if not self.active then
		return
	end
	local top = self.topOf[instance] or topLevel(instance)
	self:unwatch(instance)
	if not top or self:isRuntime(instance) then
		return
	end
	self:job(top).remount = true
	self:schedule()
end

function StarterGuiSync:onProperty(instance, property)
	if not self.active or self:isRuntime(instance) then
		return
	end
	local top = self.topOf[instance]
	if not top then
		return
	end
	if property == "Parent" then
		 
		self:job(top).remount = true
		local newTop = topLevel(instance)
		if newTop and newTop ~= top then
			self.topOf[instance] = newTop
			self:job(newTop).remount = true
		end
		self:schedule()
		return
	end
	if IGNORED[property] then
		return
	end
	local job = self:job(top)
	local properties = job.properties[instance]
	if not properties then
		properties = {}
		job.properties[instance] = properties
	end
	properties[property] = true
	self:schedule()
end

function StarterGuiSync:onAttribute(instance, name)
	if not self.active or name == Constants.STABLE_ID_ATTRIBUTE or self:isRuntime(instance) then
		return
	end
	local top = self.topOf[instance]
	if not top then
		return
	end
	local job = self:job(top)
	local attributes = job.attributes[instance]
	if not attributes then
		attributes = {}
		job.attributes[instance] = attributes
	end
	attributes[name] = true
	self:schedule()
end

function StarterGuiSync:entryOf(top)
	local mount = self.deps.guiMount
	for index, entry in ipairs(mount.mounted) do
		if entry.original == top then
			return entry, index
		end
	end
	return nil, nil
end

function StarterGuiSync:releaseClone(clone)
	local scripts = {}
	if clone:IsA(Constants.CLASS_NAMES.LUA_SOURCE_CONTAINER) then
		table.insert(scripts, clone)
	end
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA(Constants.CLASS_NAMES.LUA_SOURCE_CONTAINER) then
			table.insert(scripts, descendant)
		end
	end
	for _, host in ipairs(self.deps.hosts) do
		for _, scriptInstance in ipairs(scripts) do
			if host:isRunning(scriptInstance) then
				pcall(host.release, host, scriptInstance)
			end
			pcall(host.releaseModule, host, scriptInstance)
		end
	end
end

 
 
 
local function buildMap(original, clone, tracker, map)
	map[original] = clone
	local cloneChildren = {}
	for _, child in ipairs(clone:GetChildren()) do
		if not tracker:isHostedInstance(child) then
			table.insert(cloneChildren, child)
		end
	end
	local index = 0
	for _, child in ipairs(original:GetChildren()) do
		if child.Archivable then
			index += 1
			local counterpart = cloneChildren[index]
			if counterpart == nil or counterpart.ClassName ~= child.ClassName then
				return false
			end
			if not buildMap(child, counterpart, tracker, map) then
				return false
			end
		end
	end
	return true
end

function StarterGuiSync:mapOf(entry)
	if entry.syncMap and entry.syncClone == entry.clone then
		return entry.syncMap
	end
	local map = {}
	local ok, built = pcall(buildMap, entry.original, entry.clone, self.deps.tracker, map)
	if not ok or not built then
		return nil
	end
	entry.syncMap = map
	entry.syncClone = entry.clone
	return map
end

function StarterGuiSync:remount(top)
	local mount = self.deps.guiMount
	if not mount.playerGui then
		return false
	end
	local entry, index = self:entryOf(top)
	if entry and entry.clone and entry.clone.Parent then
		self:releaseClone(entry.clone)
		pcall(entry.clone.Destroy, entry.clone)
	end
	if top.Parent == StarterGui and top.Archivable then
		local clone, pairs_ = StarterClone.one(top, mount.playerGui, self.deps.tracker, mount.owner)
		if not clone then
			return false
		end
		if entry then
			entry.clone = clone
			entry.syncMap = nil
			entry.syncClone = nil
		else
			table.insert(mount.mounted, { clone = clone, original = top })
		end
		self.deps.onScripts(pairs_)
		self.deps.onSynced(top, TEXTS.GUI_SYNC_MODE_REMOUNT)
		return true
	end
	if entry then
		table.remove(mount.mounted, index)
	end
	self.deps.onRemoved(top)
	return true
end

local function mapValue(value, map)
	if typeof(value) == "Instance" and map[value] then
		return map[value]
	end
	return value
end

function StarterGuiSync:mirror(top, job)
	local entry = self:entryOf(top)
	if not entry or not entry.clone or not entry.clone.Parent then
		return self:remount(top)
	end
	local map = self:mapOf(entry)
	if not map then
		return self:remount(top)
	end
	for instance, properties in pairs(job.properties) do
		local counterpart = map[instance]
		if not counterpart then
			return self:remount(top)
		end
		for property in pairs(properties) do
			 
			pcall(function()
				counterpart[property] = mapValue(instance[property], map)
			end)
		end
	end
	for instance, attributes in pairs(job.attributes) do
		local counterpart = map[instance]
		if counterpart then
			for name in pairs(attributes) do
				pcall(counterpart.SetAttribute, counterpart, name, instance:GetAttribute(name))
			end
		end
	end
	self.deps.onSynced(top, TEXTS.GUI_SYNC_MODE_MIRROR)
	return true
end

function StarterGuiSync:flush()
	if not self.active then
		return
	end
	local jobs = self.pending
	self.pending = {}
	for top, job in pairs(jobs) do
		local ok, err = pcall(function()
			if job.remount then
				self:remount(top)
			else
				self:mirror(top, job)
			end
		end)
		if not ok then
			self.deps.onError(tostring(err))
		end
	end
end

function StarterGuiSync:remountAll()
	local count = 0
	for _, child in ipairs(StarterGui:GetChildren()) do
		if child.Archivable and self:remount(child) then
			count += 1
		end
	end
	return count
end

function StarterGuiSync:stop()
	self.active = false
	if self.timer then
		task.cancel(self.timer)
		self.timer = nil
	end
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.connections = {}
	for instance in pairs(self.watched) do
		self:unwatch(instance)
	end
	self.watched = {}
	self.topOf = {}
	self.pending = {}
end

return StarterGuiSync
