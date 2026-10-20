local Constants = require(script.Parent.Parent.Core.Constants)

local Budget = {}
Budget.__index = Budget

local LEVELS = Constants.DEGRADATION_LEVELS
local MAX_LEVEL = LEVELS.GUI

function Budget.new(frameBudgetMs)
	return setmetatable({
		frameBudgetMs = frameBudgetMs,
		frameStart = os.clock(),
		frame = 0,
		framesSinceReport = 0,
		costs = {},
		slowSince = nil,
		fastSince = nil,
		level = LEVELS.NONE,
		listeners = {},
	}, Budget)
end

function Budget:beginFrame()
	self.frameStart = os.clock()
end

function Budget:elapsedMs()
	return (os.clock() - self.frameStart) * Constants.MILLISECONDS_PER_SECOND
end

function Budget:hasTime()
	return self:elapsedMs() < self.frameBudgetMs
end

function Budget:onDegradationChanged(callback)
	table.insert(self.listeners, callback)
end

function Budget:isDegraded()
	return self.level > LEVELS.NONE
end

function Budget:degradationLevel()
	return self.level
end

function Budget:setLevel(level)
	level = math.clamp(level, LEVELS.NONE, MAX_LEVEL)
	if self.level == level then
		return
	end
	self.level = level
	for _, listener in ipairs(self.listeners) do
		listener(level)
	end
end

function Budget:observeFrame(deltaSeconds)
	self.frame += 1
	self.framesSinceReport += 1
	local frameMs = deltaSeconds * Constants.MILLISECONDS_PER_SECOND
	local now = os.clock()
	if frameMs > Constants.DEGRADE_FRAME_MS then
		self.fastSince = nil
		self.slowSince = self.slowSince or now
		if now - self.slowSince >= Constants.DEGRADE_WINDOW_SECONDS then
			self.slowSince = now
			self:setLevel(self.level + 1)
		end
	else
		self.slowSince = nil
		self.fastSince = self.fastSince or now
		if now - self.fastSince >= Constants.DEGRADE_WINDOW_SECONDS then
			self.fastSince = now
			self:setLevel(self.level - 1)
		end
	end
end

function Budget:addCost(key, milliseconds)
	if key then
		self.costs[key] = (self.costs[key] or 0) + milliseconds
	end
end

function Budget:measure(key, callable, ...)
	local frame = self.frame
	local startedAt = os.clock()
	local results = table.pack(callable(...))
	if self.frame == frame then
		self:addCost(key, (os.clock() - startedAt) * Constants.MILLISECONDS_PER_SECOND)
	end
	return table.unpack(results, 1, results.n)
end

function Budget:costReport()
	local frames = math.max(self.framesSinceReport, 1)
	local report = {}
	for _, key in pairs(Constants.COST_KEYS) do
		report[key] = (self.costs[key] or 0) / frames
	end
	self.costs = {}
	self.framesSinceReport = 0
	return report
end

function Budget:reset()
	self.slowSince = nil
	self.fastSince = nil
	self.costs = {}
	self.framesSinceReport = 0
	self:setLevel(LEVELS.NONE)
end

return Budget
