local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
_G.services = _G.services or {}


local use_env = false
local env_folder = Instance.new('Folder')


export type Signal<T...> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> RBXScriptConnection,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> RBXScriptConnection,
	Wait: (self: Signal<T...>) -> T...,
	ConnectParallel: (self: Signal<T...>, callback: (T...) -> ()) -> RBXScriptConnection
}

export type Service<T> = {
	Name: string,
	Parent: Instance?,
	ClassName: string,
	className: string,
	IsA: (self: Service<T>, className: string) -> boolean,
	ChildAdded: Signal<Instance>,
	ChildRemoved: Signal<Instance>,
	GetPropertyChangedSignal: (self: Service<T>, property: string) -> RBXScriptSignal
} & T


local function createClientService() : Folder?
	if not use_env then
		if RunService:IsServer() then
			error('Cannot run on Server! (Please run it from the Client instead!)', 0)
			return nil
		end

		if not ReplicatedStorage:FindFirstChild('Services') then
			local services = Instance.new('Folder', ReplicatedStorage)
			services.Name = 'Services'
		end

		return ReplicatedStorage:FindFirstChild('Services', true)
	else
		return env_folder
	end
end
task.spawn(createClientService)


local function GiveOwnGlobals(Func : any, table, _env)
	if Func == nil then
		error("Func cannot be nil")
	end

	local Fenv = {}
	local RealFenv = table or {}

	local FenvMt = {}
	function FenvMt:__index(b)
		if RealFenv[b] == nil then
			return (_env or getfenv())[b]
		else
			return RealFenv[b]
		end
	end
	function FenvMt:__newindex(b, c)
		if RealFenv[b] == nil then
			(_env or getfenv())[b] = c
		else
			RealFenv[b] = c
		end
	end
	setmetatable(Fenv, FenvMt)
	setfenv(Func, Fenv)
	return Func
end


local propertySignals = setmetatable({}, {
	__index = function(self, index)
		local event = Instance.new('BindableEvent')
		rawset(self, index, event)
		return rawget(self, index)
	end,
}) :: {[any]: BindableEvent}

return {
	createSignal = function(name)
		local event = Instance.new('BindableEvent')
		event.Name = name or event.Name

		return {
			Event = event.Event,
			Fire = function(self, ...)
				event:Fire(...)
			end,
			event = event
		}
	end,

	createService = function(instance : Instance, className : string, extra : {[string]: (...any) -> (...any)|{readonly: boolean?, value: any, property: boolean?}}, _self : {}?) : Service<{}>
		local serviceFolder = nil -- createClientService()
		local blockedWords = {'ClassName', 'className', 'Parent'}
		local locatingTables = {
			['Name'] = function(name)
				instance.Name = name
			end,
		}


		instance.Parent = game
		instance.Name = className

		-- Merges 3 table together!
		local function merge<T1, T2, T3>(tbl : T1, tbl2 : T2, tbl3 : T3) : T1 & T2 & T3
			local merged = tbl

			for i, v in tbl2 do
				if not merged[i] then
					merged[i] = v
				end
			end

			for i, v in tbl3 do
				if not merged[i] then
					merged[i] = v
				end
			end

			return merged
		end



		local function mergeV2<T1, T2>(tbl : T1, tbl2 : T2) : T1 & T2
			local merged = tbl

			for i, v in tbl2 do
				if not merged[i] then
					merged[i] = v
				end
			end

			return merged
		end

		local function getInstancesInService()
			local instances = {}

			for _, v in instance:GetChildren() do
				instances[v.Name] = v
			end

			return instances
		end

		-- Deprecated: This deprecated function is a variant of Instance:FindFirstChild() which should be used instead.
		local function findFirstChild(name : string, recursive: boolean?) : Instance
			if not name then
				error('Argument 1 missing or nil', 0)
			end

			if typeof(name) ~= 'string' then
				return
			end

			return instance:findFirstChild(name, recursive)
		end

		local service = {}

		function service:findFirstChild(name : string, recursive: boolean?) : Instance?
			if not name then
				error('Argument 1 missing or nil', 0)
			end

			if typeof(name) ~= 'string' then
				return
			end

			return instance:findFirstChild(name, recursive)
		end

		function service:FindFirstChild(name, recursive)
			if not name then
				error('Argument 1 missing or nil', 0)
			end

			if typeof(name) ~= 'string' then
				return
			end

			return instance:findFirstChild(name, recursive)
		end

		local ClassName = className
		function service:IsA(className)
			return className == ClassName
		end
		
		
		function service:GetPropertyChangedSignal(property: string) : RBXScriptSignal
			return propertySignals[property].Event
		end


		local Service = Instance.new('Folder', serviceFolder) do
			Service.Name = className
		end

		local ServiceLocator = Instance.new('ObjectValue', Service)
		ServiceLocator.Name = 'Service'
		ServiceLocator.Value = instance

		local Events = Instance.new('Folder', Service)
		Events.Name = 'Events'

		-- local GetService = Instance.new('BindableFunction', Service)
		-- GetService.Name = 'GetService'

		local tbl = {}
		local proxy = newproxy(true)
		local mt = getmetatable(proxy)

		local readonlyPropertiesFixing = {}
		if extra then
			for i, v in pairs(extra) do
				if v and typeof(v) == 'table' and v.event then
					-- Event
					if typeof(v.event) == 'Instance' and v.event:IsA('BindableEvent') then
						-- Stay in a Safe Zone!
						coroutine.wrap(function()
							v.event.Parent = Events
							extra[i] = v.Event
						end)()
					end
				end

				if v then
					-- Functions
					if typeof(v) == 'function' then
						local oldFunc = extra[i]
						extra[i] = function(self, ...)
							if not self or self ~= proxy then
								error(`Expected ':' not '.' calling member function {tostring(i)}`, 0)
							end

							return coroutine.wrap(function(...)
								return oldFunc(...)
							end)(...)
						end
					else
						-- Properties
						if typeof(v) == 'table' then
							if v.value == nil then continue end

							if v.readonly then
								table.insert(blockedWords, i)
							end

							local oldValue = v.value
							instance:GetAttributeChangedSignal(i):Connect(function()
								-- GetAttributeChangedSignal never fires twoice anyways!
								-- however still have a check to make sure, it never runs twoice!
								if readonlyPropertiesFixing[i] then
									return
								end

								if typeof(instance:GetAttribute(i)) ~= typeof(v.value) then
									task.spawn(function()
										error(`Unable to assign property {i}. {typeof(v.value)} expected, got {typeof(instance:GetAttribute(i))}`, 0)
									end)

									readonlyPropertiesFixing[i] = true
									instance:SetAttribute(i, oldValue)
									readonlyPropertiesFixing[i] = false
									return
								end

								if v.readonly then
									task.spawn(function()
										error(`Unable to assign property {i}. Property is read only`, 0)
									end)

									readonlyPropertiesFixing[i] = true
									instance:SetAttribute(i, oldValue)
									readonlyPropertiesFixing[i] = false
									return
								end

								oldValue = instance:GetAttribute(i)
							end)

							extra[i] = v.value
							propertySignals[i]:Fire(v.value)

							if v.property then
								instance:SetAttribute(i, v.value)
							end
						end

						if typeof(v) == 'Instance' then
							v.Parent = instance
						end
					end
				end
			end
		end

		tbl = mergeV2(merge({
			Parent = instance.Parent,
			Name = instance.Name,
			ClassName = className
		}, service, getInstancesInService()), extra or {})


		mt.__tostring = function()
			return className
		end

		mt.__index = function(_, index, key)
			local self = tbl

			-- no longer needed
			-- if rawget(self, index) == nil then
			--	rawset(self, index, createNilPlacement())
			--end

			-- if the key is a 'Instance' then we can parent it to the Service!
			if typeof(key) == 'Instance' then
				key.Parent = instance
			end
			
			if typeof(rawget(extra, index)) == 'function' then
				return rawget(self, index)
			end

			-- Fixes Bug: where the Parent can be set to something else than its seposed to!
			if index == 'Parent' and rawget(self, 'Parent') ~= instance.Parent then
				rawset(self, 'Parent', instance.Parent)
			end

			-- if key is nil, the caller wants to GET the currently-
			-- asigned key to the index attached in self!
			if tostring(key) == 'nil' then
				local prop = rawget(self, index)

				if instance:FindFirstChild(index) then
					return instance:FindFirstChild(index)
				end

				if not prop or tostring(prop) == 'nil' then
					error(`{index} is not a valid member of {self.ClassName} "{self.Name}"`, 0)
				end

				return prop
			end

			-- Check Properties
			if instance:GetAttribute(index) and not key then
				key = instance:GetAttribute(index)
			end

			print('setitng index: ' .. tostring(index), 'to: ' .. tostring(key))
			-- set the Key if defined!
			self[index] = key
			return self[index]
		end

		mt.__newindex = function(_, index, key)
			local self = tbl
			
			if typeof(rawget(self, index)) == 'function' then
				return
			end
			
			if typeof(index) == 'string' and table.find(blockedWords, index) then
				error(`Unable to assign property {index}. Property is read only`, 0)
			end

			if typeof(index) ~= 'string' then
				error(`invalid argument #2 (string expected, got {typeof(index)})`, 0)
			end
			
			if typeof(rawget(extra, index)) == 'function' then
				return
			end

			if locatingTables[index] then
				locatingTables[index](key)
			end
			
			if key == nil then
				-- rawset(self, index, createNilPlacement())
				return
			else
				rawset(self, index, key)
				propertySignals[index]:Fire(key)
			end
			
			return self[index]
		end

		_G.services[className] = proxy
		return proxy
	end
}