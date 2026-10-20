local Constants = require(script.Parent.Parent.Core.Constants)
local TeamCreate = require(script.Parent.Parent.Core.TeamCreate)

local WorldSnapshot = {}
WorldSnapshot.__index = WorldSnapshot

local TEXTS = Constants.TEXTS
local TERRAIN = Constants.TERRAIN
local FIXED_CLASSES = Constants.FIXED_ROOT_CLASSES
local CLASS_ATTRIBUTE = Constants.FIXED_CLASS_ATTRIBUTE
local PARTIAL_ATTRIBUTE = Constants.FIXED_PARTIAL_ATTRIBUTE

local function newFolder(name, parent)
	local folder = Instance.new(Constants.CLASS_NAMES.FOLDER)
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function tryClone(instance)
	if not instance.Archivable then
		return nil
	end
	local ok, clone = pcall(instance.Clone, instance)
	if ok then
		return clone
	end
	return nil
end

local function currentTerrain()
	return workspace:FindFirstChildOfClass(TERRAIN.CLASS_NAME)
end

function WorldSnapshot.new(pluginFolder, containers)
	return setmetatable({
		pluginFolder = pluginFolder,
		containers = containers,
		folder = nil,
		serviceValues = {},
		rootCount = 0,
		terrainRegion = nil,
		terrainTrusted = false,
		terrainError = nil,
	}, WorldSnapshot)
end

function WorldSnapshot.isFixed(instance)
	return FIXED_CLASSES[instance.ClassName] == true or instance == workspace.CurrentCamera
end

function WorldSnapshot.readServiceValues()
	local values = {}
	for serviceName, properties in pairs(Constants.SERVICE_PROPERTIES) do
		local ok, service = pcall(game.GetService, game, serviceName)
		if ok and service then
			values[serviceName] = {}
			for _, property in ipairs(properties) do
				local readOk, value = pcall(function()
					return service[property]
				end)
				if readOk then
					values[serviceName][property] = value
				end
			end
		end
	end
	return values
end

function WorldSnapshot.writeServiceValues(values)
	for serviceName, properties in pairs(values) do
		local ok, service = pcall(game.GetService, game, serviceName)
		if ok and service then
			for property, value in pairs(properties) do
				pcall(function()
					if service[property] ~= value then
						service[property] = value
					end
				end)
			end
		end
	end
end

function WorldSnapshot:captureFixed(fixedFolder, container, root)
	local containerFolder = fixedFolder:FindFirstChild(container.Name) or newFolder(container.Name, fixedFolder)
	local entry = newFolder(root.Name, containerFolder)
	entry:SetAttribute(CLASS_ATTRIBUTE, root.ClassName)
	for _, child in ipairs(root:GetChildren()) do
		local clone = tryClone(child)
		if clone then
			clone.Parent = entry
		elseif child.Archivable then
			entry:SetAttribute(PARTIAL_ATTRIBUTE, true)
		end
	end
end

function WorldSnapshot:captureTerrain()
	local terrain = currentTerrain()
	if not terrain then
		return
	end
	local ok, region = pcall(terrain.CopyRegion, terrain, terrain.MaxExtents)
	if not ok or region == nil then
		self.terrainError = tostring(region)
		return
	end
	region.Name = Constants.TERRAIN_REGION_NAME
	for _, property in ipairs(TERRAIN.PROPERTIES) do
		pcall(function()
			region:SetAttribute(property, terrain[property])
		end)
	end
	region.Parent = self.folder
	self.terrainRegion = region
	self.terrainTrusted = true
end

function WorldSnapshot:capture(job)
	local folder = newFolder(Constants.SNAPSHOT_FOLDER_NAME, self.pluginFolder)
	self.folder = folder
	self.serviceValues = WorldSnapshot.readServiceValues()
	local fixedFolder = newFolder(Constants.FIXED_FOLDER_NAME, folder)
	local total = #self.containers
	for index, container in ipairs(self.containers) do
		local target = newFolder(container.Name, folder)
		for _, child in ipairs(container:GetChildren()) do
			if child.Name ~= Constants.PLUGIN_FOLDER_NAME and child.Archivable then
				local clone = not WorldSnapshot.isFixed(child) and tryClone(child)
				if clone then
					clone.Parent = target
				else
					self:captureFixed(fixedFolder, container, child)
				end
				self.rootCount += 1
			end
			job.checkpoint(TEXTS.PROGRESS_SNAPSHOT, index, total)
		end
	end
	self:captureTerrain()
	job.checkpoint(TEXTS.PROGRESS_SNAPSHOT, total, total)
end

function WorldSnapshot:folderFor(containerName)
	return self.folder and self.folder:FindFirstChild(containerName)
end

function WorldSnapshot:fixedEntries(containerName)
	local fixedFolder = self.folder and self.folder:FindFirstChild(Constants.FIXED_FOLDER_NAME)
	local containerFolder = fixedFolder and fixedFolder:FindFirstChild(containerName)
	if containerFolder then
		return containerFolder:GetChildren()
	end
	return {}
end

function WorldSnapshot.takeEntry(entries, instance)
	for index, entry in ipairs(entries) do
		if entry.Name == instance.Name and entry:GetAttribute(CLASS_ATTRIBUTE) == instance.ClassName then
			table.remove(entries, index)
			return entry
		end
	end
	return nil
end

function WorldSnapshot:restoreTerrain()
	local terrain = currentTerrain()
	if not terrain then
		return nil
	end
	local region = self.terrainRegion
	if not region then
		if self.terrainError then
			return string.format(TEXTS.RESTORE_TERRAIN_NOT_CAPTURED, self.terrainError)
		end
		return nil
	end
	if not self.terrainTrusted then
		return TEXTS.RESTORE_TERRAIN_SKIPPED
	end
	local ok, err = pcall(terrain.PasteRegion, terrain, region, terrain.MaxExtents.Min, true)
	if not ok then
		return string.format(TEXTS.RESTORE_TERRAIN_FAILED, tostring(err))
	end
	for _, property in ipairs(TERRAIN.PROPERTIES) do
		local value = region:GetAttribute(property)
		if value ~= nil then
			pcall(function()
				if terrain[property] ~= value then
					terrain[property] = value
				end
			end)
		end
	end
	return TEXTS.RESTORE_TERRAIN_DONE
end

function WorldSnapshot.existing(pluginFolder, containers)
	local folder = pluginFolder and pluginFolder:FindFirstChild(Constants.SNAPSHOT_FOLDER_NAME)
	if not folder then
		return nil
	end
	local snapshot = WorldSnapshot.new(pluginFolder, containers)
	snapshot.folder = folder
	for _, container in ipairs(containers) do
		local containerFolder = folder:FindFirstChild(container.Name)
		if containerFolder then
			snapshot.rootCount += #containerFolder:GetChildren()
		end
		snapshot.rootCount += #snapshot:fixedEntries(container.Name)
	end
	local region = folder:FindFirstChild(Constants.TERRAIN_REGION_NAME)
	if region and region:IsA(TERRAIN.REGION_CLASS_NAME) then
		snapshot.terrainRegion = region
		snapshot.terrainTrusted = not TeamCreate.isActive()
	end
	return snapshot
end

function WorldSnapshot:discard()
	if self.folder then
		self.folder:Destroy()
		self.folder = nil
	end
end

return WorldSnapshot
