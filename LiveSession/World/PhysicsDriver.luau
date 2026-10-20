local Constants = require(script.Parent.Parent.Core.Constants)

local PhysicsDriver = {}
PhysicsDriver.__index = PhysicsDriver

function PhysicsDriver.new(onFailure, recordCost)
	return setmetatable({
		onFailure = onFailure,
		recordCost = recordCost,
		running = false,
		rateHz = Constants.PHYSICS_FULL_RATE_HZ,
		accumulated = 0,
	}, PhysicsDriver)
end

function PhysicsDriver:start()
	self.accumulated = 0
	self.running = true
end

function PhysicsDriver:step(deltaSeconds)
	if not self.running then
		return
	end
	local stepSeconds = 1 / self.rateHz
	self.accumulated += deltaSeconds
	local steps = math.min(math.floor(self.accumulated / stepSeconds), Constants.PHYSICS_MAX_STEPS_PER_FRAME)
	if steps <= 0 then
		return
	end
	self.accumulated -= steps * stepSeconds
	local startedAt = os.clock()
	for _ = 1, steps do
		local ok, err = pcall(workspace.StepPhysics, workspace, stepSeconds)
		if not ok then
			self:stop()
			self.onFailure(string.format(Constants.ERRORS.STEP_PHYSICS, tostring(err)))
			return
		end
	end
	self.recordCost((os.clock() - startedAt) * Constants.MILLISECONDS_PER_SECOND)
end

function PhysicsDriver:setDegraded(degraded)
	self.rateHz = degraded and Constants.PHYSICS_DEGRADED_RATE_HZ or Constants.PHYSICS_FULL_RATE_HZ
end

function PhysicsDriver:isRunning()
	return self.running
end

function PhysicsDriver:rate()
	return self.rateHz
end

function PhysicsDriver:stop()
	self.running = false
end

return PhysicsDriver
