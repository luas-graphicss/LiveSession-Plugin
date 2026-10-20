local ServerStorage = game:GetService("ServerStorage")

local Constants = require(script.Parent.Parent.Core.Constants)
local Traversal = require(script.Parent.Parent.Core.Traversal)
local Replay = require(script.Parent.Parent.Journal.Replay)
local WorldSnapshot = require(script.Parent.WorldSnapshot)
local Relink = require(script.Parent.Relink)

local WorldRestore = {}
WorldRestore.__index = WorldRestore

local TEXTS = Constants.TEXTS
local KINDS = Constants.ENTRY_KINDS
local PERCENT = 100
local NO_FIXED_ROOTS = {}

function WorldRestore.new(pluginFolder, containers, stableId)
	local containerSet = {}
	for _, container in ipairs(containers) do
		containerSet[container] = true
	end
	return setmetatable({
		pluginFolder = pluginFolder,
		containers = containers,
		containerSet = containerSet,
		stableId = stableId,
	}, WorldRestore)
end

function WorldRestore:isPluginOwned(instance)
	if instance == self.pluginFolder or instance:IsDescendantOf(self.pluginFolder) then
		return true
	end
	local root = instance
	while root.Parent and root.Parent ~= game and not self.containerSet[root.Parent] do
		root = root.Parent
	end
	return root.Name == Constants.PLUGIN_FOLDER_NAME and self.containerSet[root.Parent] == true
end

function WorldRestore:quarantineFolder()
	local folder = self.pluginFolder:FindFirstChild(Constants.QUARANTINE_FOLDER_NAME)
	if not folder then
		folder = Instance.new(Constants.CLASS_NAMES.FOLDER)
		folder.Name = Constants.QUARANTINE_FOLDER_NAME
		folder.Parent = self.pluginFolder
	end
	return folder
end

function WorldRestore:quarantineAuthoring(journal, quarantine, job)
	for _, entry in ipairs(journal:entriesOfKind(KINDS.CREATE)) do
		local instance = self.stableId:resolve(entry.id)
		if instance and not self:isPluginOwned(instance) then
			instance.Parent = quarantine
		end
		job.checkpoint(TEXTS.PROGRESS_RESTORE, 0, #self.containers)
	end
end

function WorldRestore:swapChildren(live, source, touchedIds, fixedRoots, job, index, total)
	local untouched = {}
	for _, child in ipairs(live:GetChildren()) do
		if fixedRoots[child] == nil and not self:isPluginOwned(child) then
			local id = touchedIds and self.stableId:idOf(child)
			if id and not touchedIds[id] then
				untouched[id] = true
			else
				pcall(child.Destroy, child)
			end
		end
		job.checkpoint(TEXTS.PROGRESS_RESTORE, index, total)
	end
	for _, clone in ipairs(source:GetChildren()) do
		local id = touchedIds and self.stableId:idOf(clone)
		if not (id and untouched[id]) then
			pcall(function()
				clone.Parent = live
			end)
		end
		job.checkpoint(TEXTS.PROGRESS_RESTORE, index, total)
	end
end

function WorldRestore:rootTouched(root, touchedIds)
	if touchedIds == nil then
		return true
	end
	local id = self.stableId:idOf(root)
	return id ~= nil and touchedIds[id] == true
end

function WorldRestore:swapContainers(snapshot, touchedIds, job)
	local total = #self.containers
	for index, container in ipairs(self.containers) do
		local source = snapshot:folderFor(container.Name)
		if source then
			local entries = snapshot:fixedEntries(container.Name)
			local fixedRoots = {}
			for _, child in ipairs(container:GetChildren()) do
				local entry = WorldSnapshot.takeEntry(entries, child)
				if entry or WorldSnapshot.isFixed(child) then
					fixedRoots[child] = entry or false
				end
			end
			self:swapChildren(container, source, touchedIds, fixedRoots, job, index, total)
			for root, entry in pairs(fixedRoots) do
				if entry and not entry:GetAttribute(Constants.FIXED_PARTIAL_ATTRIBUTE) and self:rootTouched(root, touchedIds) then
					self:swapChildren(root, entry, nil, NO_FIXED_ROOTS, job, index, total)
				end
			end
		end
	end
end

function WorldRestore:swapWorld(snapshot, job, touched)
	local rootCount = snapshot.rootCount or 0
	local touchedCount = touched and touched:count() or rootCount
	local limitPercent = Constants.INCREMENTAL_LIMIT_RATIO * PERCENT
	local incremental = touched ~= nil and touchedCount <= Constants.INCREMENTAL_LIMIT_RATIO * rootCount
	self:swapContainers(snapshot, if incremental then touched:ids() else nil, job)
	WorldSnapshot.writeServiceValues(snapshot.serviceValues)
	local text
	if incremental then
		text = string.format(TEXTS.RESTORE_INCREMENTAL, touchedCount, rootCount)
	else
		text = string.format(TEXTS.RESTORE_FULL, touchedCount, rootCount, limitPercent)
	end
	local terrainText = snapshot:restoreTerrain()
	if terrainText then
		text = string.format(TEXTS.RESTORE_WITH_TERRAIN, text, terrainText)
	end
	return text
end

function WorldRestore:rebuildIndex(quarantine, job)
	self.stableId:resetIndex()
	local roots = table.clone(self.containers)
	table.insert(roots, quarantine)
	Traversal.descendants(roots, function(instance)
		return instance == self.pluginFolder
	end, function(instance)
		self.stableId:index(instance)
	end, job, TEXTS.PROGRESS_INDEX)
end

function WorldRestore:collectUnresolved(quarantine)
	local leftovers = quarantine:GetChildren()
	if #leftovers == 0 then
		return nil
	end
	local folder = ServerStorage:FindFirstChild(Constants.UNRESOLVED_FOLDER_NAME)
	if not folder then
		folder = Instance.new(Constants.CLASS_NAMES.FOLDER)
		folder.Name = Constants.UNRESOLVED_FOLDER_NAME
		folder.Parent = ServerStorage
	end
	for _, instance in ipairs(leftovers) do
		pcall(function()
			instance.Parent = folder
		end)
	end
	return folder, #leftovers
end

function WorldRestore:replay(journal, quarantine, job)
	self:rebuildIndex(quarantine, job)
	local report = Replay.apply(journal, self.stableId, job)
	report.unresolvedFolder, report.unresolvedCount = self:collectUnresolved(quarantine)
	return report
end

function WorldRestore:run(snapshot, journal, job, touched)
	local quarantine = self:quarantineFolder()
	local swapText = nil
	if snapshot then
		self:rebuildIndex(quarantine, job)
		self:quarantineAuthoring(journal, quarantine, job)
		swapText = self:swapWorld(snapshot, job, touched)
	end
	local report = self:replay(journal, quarantine, job)
	report.swapText = swapText
	return report
end

function WorldRestore:cleanup(job)
	local report = Relink.newReport()
	local lookup = function(id)
		return self.stableId:lookup(id)
	end
	Traversal.descendants(self.containers, function(instance)
		return instance == self.pluginFolder
	end, function(instance)
		Relink.visit(instance, lookup, report)
		self.stableId:clear(instance)
	end, job, TEXTS.PROGRESS_CLEANUP)
	return report
end

return WorldRestore
