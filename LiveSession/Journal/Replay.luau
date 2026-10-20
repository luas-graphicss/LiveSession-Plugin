local Constants = require(script.Parent.Parent.Core.Constants)
local ValueCodec = require(script.Parent.ValueCodec)

local Replay = {}

local KINDS = Constants.ENTRY_KINDS
local PROPERTIES = Constants.PROPERTY_NAMES

local function newReport()
	return { applied = 0, rebuilt = 0, skipped = 0, failed = {}, unresolved = {} }
end

local function fail(report, entry, reason)
	table.insert(report.failed, { entry = entry, reason = tostring(reason) })
end

local function unresolved(report, entry)
	table.insert(report.unresolved, entry)
end

local function latestPerKey(entries, keyOf)
	local latest = {}
	local order = {}
	for _, entry in ipairs(entries) do
		local key = keyOf(entry)
		if not latest[key] then
			table.insert(order, key)
		end
		latest[key] = entry
	end
	local result = {}
	for _, key in ipairs(order) do
		table.insert(result, latest[key])
	end
	return result
end

local function isAlive(lifecycles, id)
	local lifecycle = lifecycles[id]
	return lifecycle == nil or lifecycle.alive
end

local function locate(index, lifecycles, entry)
	local lifecycle = lifecycles[entry.id]
	if lifecycle == nil then
		return index:resolve(entry.id, entry.path)
	end
	if lifecycle.preexisting then
		return index:resolve(entry.id, lifecycle.originPath)
	end
	return index:resolve(entry.id)
end

local function nameOf(entry)
	return entry.name or string.match(entry.path, Constants.PATH_LAST_SEGMENT_PATTERN) or entry.className
end

local function rebuild(entry, parent, index, report)
	local ok, err = pcall(function()
		local instance = Instance.new(entry.className)
		instance.Name = nameOf(entry)
		index:adopt(instance, entry.id)
		instance.Parent = parent
	end)
	if ok then
		report.rebuilt += 1
	else
		fail(report, entry, err)
	end
end

local function reparent(entry, instance, parent, report)
	local ok, err = pcall(function()
		instance.Parent = parent
	end)
	if ok then
		report.applied += 1
	else
		fail(report, entry, err)
	end
end

local function applyCreates(journal, index, lifecycles, report, job)
	for _, entry in ipairs(journal:entriesOfKind(KINDS.CREATE)) do
		if not isAlive(lifecycles, entry.id) then
			report.skipped += 1
		else
			local instance = locate(index, lifecycles, entry)
			local parent = index:resolve(entry.parentId, entry.parentPath)
			if parent == nil then
				unresolved(report, entry)
			elseif instance == nil then
				rebuild(entry, parent, index, report)
			elseif instance.Parent ~= parent then
				reparent(entry, instance, parent, report)
			else
				report.skipped += 1
			end
		end
		if job then
			job.checkpoint()
		end
	end
end

local function applySources(journal, index, lifecycles, report, job)
	for id, entry in pairs(journal:finalSources()) do
		if not isAlive(lifecycles, id) then
			report.skipped += 1
		else
			local instance = locate(index, lifecycles, entry)
			if not instance then
				unresolved(report, entry)
			elseif instance[PROPERTIES.SOURCE] == entry.source then
				report.skipped += 1
			else
				local ok, err = pcall(function()
					instance[PROPERTIES.SOURCE] = entry.source
				end)
				if ok then
					report.applied += 1
				else
					fail(report, entry, err)
				end
			end
		end
		if job then
			job.checkpoint()
		end
	end
end

local function applyProperties(journal, index, lifecycles, report, job)
	local entries = latestPerKey(journal:entriesOfKind(KINDS.PROPERTY), function(entry)
		return entry.id .. (entry.attribute and "@" or ".") .. entry.property
	end)
	local resolveReference = function(id)
		return index:resolve(id)
	end
	for _, entry in ipairs(entries) do
		if not isAlive(lifecycles, entry.id) then
			report.skipped += 1
		else
			local instance = locate(index, lifecycles, entry)
			if not instance then
				unresolved(report, entry)
			else
				local value, decodeError = ValueCodec.decode(entry.value, resolveReference)
				 
				local current = nil
				local okRead = pcall(function()
					if entry.attribute then
						current = instance:GetAttribute(entry.property)
					else
						current = instance[entry.property]
					end
				end)
				if decodeError then
					fail(report, entry, decodeError)
				elseif okRead and current == value then
					report.skipped += 1
				else
					local ok, err = pcall(function()
						if entry.attribute then
							instance:SetAttribute(entry.property, value)
						else
							instance[entry.property] = value
						end
					end)
					if ok then
						report.applied += 1
					else
						fail(report, entry, err)
					end
				end
			end
		end
		if job then
			job.checkpoint()
		end
	end
end

local function applyDestroys(journal, index, lifecycles, report, job)
	for _, entry in ipairs(journal:entriesOfKind(KINDS.DESTROY)) do
		local instance = nil
		if not isAlive(lifecycles, entry.id) then
			instance = locate(index, lifecycles, entry)
		end
		if instance then
			local ok, err = pcall(instance.Destroy, instance)
			if ok then
				report.applied += 1
			else
				fail(report, entry, err)
			end
		else
			report.skipped += 1
		end
		if job then
			job.checkpoint()
		end
	end
end

function Replay.apply(journal, index, job)
	local report = newReport()
	local lifecycles = journal:lifecycles()
	applyCreates(journal, index, lifecycles, report, job)
	applySources(journal, index, lifecycles, report, job)
	applyProperties(journal, index, lifecycles, report, job)
	applyDestroys(journal, index, lifecycles, report, job)
	return report
end

function Replay.describe(report)
	return string.format(Constants.TEXTS.RESTORE_REPORT, report.applied, report.rebuilt, report.skipped, #report.failed, #report.unresolved)
end

return Replay
