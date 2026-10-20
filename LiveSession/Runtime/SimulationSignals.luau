local Constants = require(script.Parent.Parent.Core.Constants)
local HostedSignal = require(script.Parent.HostedSignal)

local SimulationSignals = {}
SimulationSignals.__index = SimulationSignals

local MEMBERS = Constants.RUN_SERVICE_MEMBERS

function SimulationSignals.new(tracker)
	return setmetatable({
		preAnimation = HostedSignal.new(tracker),
		stepped = HostedSignal.new(tracker),
		preSimulation = HostedSignal.new(tracker),
		postSimulation = HostedSignal.new(tracker),
		elapsed = 0,
	}, SimulationSignals)
end

function SimulationSignals:getters()
	return {
		[MEMBERS.PRE_ANIMATION] = function()
			return self.preAnimation:interface()
		end,
		[MEMBERS.STEPPED] = function()
			return self.stepped:interface()
		end,
		[MEMBERS.PRE_SIMULATION] = function()
			return self.preSimulation:interface()
		end,
		[MEMBERS.POST_SIMULATION] = function()
			return self.postSimulation:interface()
		end,
	}
end

function SimulationSignals:beforeStep(deltaSeconds)
	self.elapsed += deltaSeconds
	self.preAnimation:fire(deltaSeconds)
	self.stepped:fire(self.elapsed, deltaSeconds)
	self.preSimulation:fire(deltaSeconds)
end

function SimulationSignals:afterStep(deltaSeconds)
	self.postSimulation:fire(deltaSeconds)
end

function SimulationSignals:clear()
	self.elapsed = 0
	for _, signal in ipairs({ self.preAnimation, self.stepped, self.preSimulation, self.postSimulation }) do
		signal:clear()
	end
end

return SimulationSignals
