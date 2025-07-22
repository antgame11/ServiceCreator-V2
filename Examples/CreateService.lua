local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ServerStorage = game:GetService('ServerStorage')

local ServiceCreator = require(ServerStorage.Flamework.ServiceCreator)
local CoreSignal = require(ServerStorage.Packages.CoreSignal)


local signal = CoreSignal.Signal
local signalAdded = ServiceCreator.createSignal('SignalAdded')
local signalRemoved = ServiceCreator.createSignal('SignalRemoved')

ServiceCreator.createService(Instance.new('Folder', ReplicatedStorage:WaitForChild('ServerServices')), 'CoreServer', {
	SignalRemoved = signalRemoved,
	SignalAdded = signalAdded,
	
	SetCore = CoreSignal.Signal.SetCore,
	GetCore = CoreSignal.Signal.GetCore
}, signal)


CoreSignal:RegisterGetCore('GetLoserYouTuber', function()
	return 'Syntax'
end)
