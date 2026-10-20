local RunService = game:GetService("RunService")

local FrameLoop = {}
FrameLoop.__index = FrameLoop

function FrameLoop.new(signals, physics, animations)
	return setmetatable({
		signals = signals,
		physics = physics,
		animations = animations,
		connection = nil,
	}, FrameLoop)
end

function FrameLoop:start()
	if self.connection then
		return
	end
	self.connection = RunService.Heartbeat:Connect(function(deltaSeconds)
		self.signals:beforeStep(deltaSeconds)
		self.physics:step(deltaSeconds)
		self.animations:step(deltaSeconds)
		self.signals:afterStep(deltaSeconds)
	end)
end

function FrameLoop:isRunning()
	return self.connection ~= nil
end

function FrameLoop:stop()
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
end

return FrameLoop
