local Constants = require(script.Parent.Parent.Core.Constants)

local Logger = {}
Logger.__index = Logger

local minimumLevel = Constants.LOG_LEVELS.INFO
local sink = nil

local function emit(level, scope, message, ...)
	if level < minimumLevel then
		return
	end
	if select("#", ...) > 0 then
		message = string.format(message, ...)
	end
	local line = string.format(Constants.LOG_FORMAT, Constants.LOG_PREFIX, Constants.LOG_LEVEL_NAMES[level], scope, message)
	if level >= Constants.LOG_LEVELS.WARN then
		warn(line)
	else
		print(line)
	end
	if sink then
		sink(level, scope, message)
	end
end

function Logger.setMinimumLevel(level)
	minimumLevel = level
end

function Logger.setSink(callback)
	sink = callback
end

function Logger.new(scope)
	return setmetatable({ scope = scope }, Logger)
end

function Logger:debug(message, ...)
	emit(Constants.LOG_LEVELS.DEBUG, self.scope, message, ...)
end

function Logger:info(message, ...)
	emit(Constants.LOG_LEVELS.INFO, self.scope, message, ...)
end

function Logger:warn(message, ...)
	emit(Constants.LOG_LEVELS.WARN, self.scope, message, ...)
end

function Logger:error(message, ...)
	emit(Constants.LOG_LEVELS.ERROR, self.scope, message, ...)
end

return Logger
