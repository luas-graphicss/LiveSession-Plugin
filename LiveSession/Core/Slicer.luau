local Slicer = {}
Slicer.__index = Slicer

function Slicer.new(budget)
	return setmetatable({ budget = budget }, Slicer)
end

function Slicer:run(work, onProgress)
	local budget = self.budget
	local job = {}
	budget:beginFrame()

	function job.checkpoint(label, done, total)
		if budget:hasTime() then
			return
		end
		if onProgress and label then
			onProgress(label, done, total)
		end
		task.wait()
		budget:beginFrame()
	end

	work(job)
	return job
end

return Slicer
