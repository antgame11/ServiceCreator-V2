local GetService = require(game:GetService('ServerStorage'):WaitForChild('Flamework').Service)

local CoreServer = GetService('CoreServer')
local test = GetService('CoreServer')


print(CoreServer == test) -- true

print(CoreServer) -- CoreServer
print(CoreServer.ClassName) -- CoreServer

print(CoreServer:GetCore('GetLoserYouTuber')) -- Syntax
print(CoreServer:GetCore('GetLoser')) -- ServerStorage.Flamework.ServiceCreator:249: GetCore: GetLoser has not been registered by SLInclude
