-- Sorry if you do not understand how ServiceCreator works but i will show you examples on how it works in this Script!

-- Client:
-- This is how it whould work on the Client!
local to = script.Parent:WaitForChild('Client')
local Creator = require(to.ServiceCreator) -- We get the Service Creator.
local GetService = require(to.GetService) -- So we can get our Custom Service.


-- this is what the Creator will target, it can be ANY Instance!
local ServiceFolder = Instance.new('Folder')

-- A custom ClassName
local ClassName = 'ServiceCreator'
local FunSignal = Creator.createSignal('FunSignal') -- Name: Optional: The name of the Event.


local Service = Creator.createService(ServiceFolder, ClassName, {
	-- if you wanna make a function, you can do this:
	test = function(hello)
		print('Test said: ' .. hello)
	end,
	
	-- if you wanna make a Variable:
	var = {
		-- set to: true if you want the variable to be readonly (default: false):
		readonly = false,
		
		-- this is what the variable will be set to (REQUIRED):
		value = 1,
		
		-- set to: true if you want the variable to be displayed on the Instance like a 'Attribute' (default: false):
		property = true
	},
	
	-- fires the signal.
	fireSignal = function()
		FunSignal:Fire('GG')
	end,
	
	-- creates the variable 'FunSignal' for the signal:
	FunSignal = FunSignal
})


-- Get the Service
local service = GetService('ServiceCreator')
print(service, service.var)

service:test('Hello') -- should print: 'Test said: Hello'
print(service.var) -- should print: 1

service.FunSignal:Connect(function(response)
	print('Signal fired with: ' .. response)
end)

service:fireSignal()

-- PropertyChangedSignal fires when a property is changed from the Service.
service:GetPropertyChangedSignal('Name'):Connect(function(e)
	print('printed when the Name property is changed: ' .. e) -- prints: GG
end)

service.Name = 'GG'