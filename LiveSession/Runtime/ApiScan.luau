local Constants = require(script.Parent.Parent.Core.Constants)

local ApiScan = {}

local NEWLINE = Constants.UI.LINE_SEPARATOR
local COMMENT_LINE = Constants.LUA_COMMENT_LINE_PATTERN

local function lineOf(source, position)
	local _, newlines = string.gsub(string.sub(source, 1, position), NEWLINE, NEWLINE)
	return newlines + 1
end

local function lineStart(source, position)
	local start = position
	while start > 1 and string.sub(source, start - 1, start - 1) ~= NEWLINE do
		start -= 1
	end
	return start
end

local function isCommented(source, position)
	return string.find(source, COMMENT_LINE, lineStart(source, position)) ~= nil
end

local function findUsage(source, api)
	local position = string.find(source, api, 1, true)
	while position and isCommented(source, position) do
		position = string.find(source, api, position + 1, true)
	end
	return position
end

function ApiScan.find(source)
	local findings = {}
	for _, entry in ipairs(Constants.UNSUPPORTED_APIS) do
		local position = findUsage(source, entry.api)
		if position then
			table.insert(findings, { api = entry.api, note = entry.note, line = lineOf(source, position) })
		end
	end
	return findings
end

function ApiScan.describe(instance, finding)
	return string.format(Constants.TEXTS.API_FINDING_FORMAT, instance:GetFullName(), finding.line, finding.api, finding.note)
end

return ApiScan
