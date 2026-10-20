local hosted = LiveSession
if hosted then
	return hosted
end

local Shim = {}

function Shim.preserve(_, initializer)
	return initializer()
end

function Shim.onReload() end

return Shim
