local Traversal = {}

function Traversal.descendants(roots, shouldSkipRoot, visitor, job, label)
	local total = #roots
	for index, root in ipairs(roots) do
		for _, child in ipairs(root:GetChildren()) do
			if not shouldSkipRoot(child) then
				visitor(child, root)
				job.checkpoint(label, index, total)
				for _, descendant in ipairs(child:GetDescendants()) do
					visitor(descendant, root)
					job.checkpoint(label, index, total)
				end
			end
		end
	end
end

return Traversal
