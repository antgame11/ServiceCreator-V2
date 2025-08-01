local ServerStorage = game:GetService('ServerStorage')
_G.services = _G.services or {}

return function(_service)
	if _G.services[_service] then
		return _G.services[_service]
	end
	
	local ok, service = pcall(function()
		local a = game:GetService(_service)
		
		return a:GetFullName() and a
	end)
	
	if not ok and service:find('The current thread cannot access') then
		_G.services[_service] = service
		return service
	end
	
	ok, service = pcall(function()
		if not ServerStorage:FindFirstChild('Services') then
			while not ServerStorage:FindFirstChild('Services') do
				ServerStorage.ChildAdded:Wait()
			end
		end
		
		return _G.services[_service]
	end)
	
	
	return service
end