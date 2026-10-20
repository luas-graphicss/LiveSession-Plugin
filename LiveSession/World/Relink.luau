local Constants = require(script.Parent.Parent.Core.Constants)

local Relink = {}

local ATTRIBUTE = Constants.STABLE_ID_ATTRIBUTE
local TYPES = Constants.TYPE_NAMES
local TEXTS = Constants.TEXTS
local propertiesByClass = {}

local function referencePropertiesOf(instance)
	local className = instance.ClassName
	local cached = propertiesByClass[className]
	if cached then
		return cached
	end
	local properties = {}
	for _, group in ipairs(Constants.REFERENCE_PROPERTIES) do
		if instance:IsA(group.class) then
			for _, property in ipairs(group.properties) do
				table.insert(properties, property)
			end
		end
	end
	propertiesByClass[className] = properties
	return properties
end

local function isDetached(value)
	return typeof(value) == TYPES.INSTANCE and value ~= game and value.Parent == nil
end

local function readProperty(instance, property)
	local ok, value = pcall(function()
		return instance[property]
	end)
	return ok and value or nil
end

local function writeProperty(instance, property, value)
	return pcall(function()
		instance[property] = value
	end)
end

function Relink.newReport()
	return { relinked = 0, unresolved = {} }
end

function Relink.visit(instance, lookup, report)
	for _, property in ipairs(referencePropertiesOf(instance)) do
		local value = readProperty(instance, property)
		if isDetached(value) then
			local id = value:GetAttribute(ATTRIBUTE)
			local target = type(id) == TYPES.STRING and lookup(id) or nil
			if target and writeProperty(instance, property, target) then
				report.relinked += 1
			else
				table.insert(report.unresolved, string.format(TEXTS.REFERENCE_FORMAT, instance:GetFullName(), property))
			end
		end
	end
end

function Relink.describe(report)
	return string.format(TEXTS.RELINK_REPORT, report.relinked, #report.unresolved)
end

return Relink
