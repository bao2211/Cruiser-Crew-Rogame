-- Remote Event Manager
-- Centralizes all RemoteEvent creation and management
-- Provides type-safe remote communication between client and server

local RemoteManager = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Constants
local REMOTE_FOLDER_NAME = "RemoteEvents"
local REMOTE_TIMEOUT = 10 -- seconds to wait for remotes to be created

-- Remote event definitions
local REMOTE_EVENTS = {
	-- Vehicle system
	HoverToggle = {
		name = "HoverToggle",
		description = "Toggle vehicle hover mode and position lock"
	},
	
	-- Weapon system
	FireWeapon = {
		name = "FireWeapon",
		description = "Fire weapon from vehicle seat"
	},
	
	-- Health system
	HealthUpdate = {
		name = "HealthUpdate",
		description = "Update part health for client display"
	},
	
	-- Debug system
	DebugMessage = {
		name = "DebugMessage",
		description = "Send debug messages between client and server"
	}
}

-- Internal storage
local remoteFolder = nil
local remotes = {}
local isServer = RunService:IsServer()

-- === INITIALIZATION ===

-- Initialize the remote system
function RemoteManager.initialize()
	if isServer then
		RemoteManager._createRemoteFolder()
		RemoteManager._createRemoteEvents()
		print("SERVER: RemoteManager initialized - Created " .. #REMOTE_EVENTS .. " remote events")
	else
		RemoteManager._waitForRemoteEvents()
		print("CLIENT: RemoteManager initialized - Connected to remote events")
	end
end

-- Create the remote events folder (server only)
function RemoteManager._createRemoteFolder()
	remoteFolder = ReplicatedStorage:FindFirstChild(REMOTE_FOLDER_NAME)
	if not remoteFolder then
		remoteFolder = Instance.new("Folder")
		remoteFolder.Name = REMOTE_FOLDER_NAME
		remoteFolder.Parent = ReplicatedStorage
		print("SERVER: Created RemoteEvents folder")
	end
end

-- Create all remote events (server only)
function RemoteManager._createRemoteEvents()
	for eventKey, eventData in pairs(REMOTE_EVENTS) do
		local remoteName = eventData.name
		local existingRemote = remoteFolder:FindFirstChild(remoteName)
		
		if not existingRemote then
			local remoteEvent = Instance.new("RemoteEvent")
			remoteEvent.Name = remoteName
			remoteEvent.Parent = remoteFolder
			remotes[eventKey] = remoteEvent
			print("SERVER: Created RemoteEvent:", remoteName)
		else
			remotes[eventKey] = existingRemote
			print("SERVER: Found existing RemoteEvent:", remoteName)
		end
	end
end

-- Wait for remote events to be created (client only)
function RemoteManager._waitForRemoteEvents()
	-- Wait for folder
	remoteFolder = ReplicatedStorage:WaitForChild(REMOTE_FOLDER_NAME, REMOTE_TIMEOUT)
	if not remoteFolder then
		error("CLIENT: RemoteEvents folder not found within timeout")
	end
	
	-- Wait for each remote event
	for eventKey, eventData in pairs(REMOTE_EVENTS) do
		local remoteName = eventData.name
		local remoteEvent = remoteFolder:WaitForChild(remoteName, REMOTE_TIMEOUT)
		
		if remoteEvent then
			remotes[eventKey] = remoteEvent
			print("CLIENT: Connected to RemoteEvent:", remoteName)
		else
			error("CLIENT: RemoteEvent not found: " .. remoteName)
		end
	end
end

-- === REMOTE ACCESS ===

-- Get a remote event by key
function RemoteManager.getRemote(eventKey)
	local remote = remotes[eventKey]
	if not remote then
		warn("RemoteManager: Remote event not found:", eventKey)
		return nil
	end
	return remote
end

-- Get all available remotes
function RemoteManager.getAllRemotes()
	return remotes
end

-- Check if a remote exists
function RemoteManager.hasRemote(eventKey)
	return remotes[eventKey] ~= nil
end

-- === SERVER FUNCTIONS ===

-- Fire to a specific client (server only)
function RemoteManager.fireClient(eventKey, player, ...)
	if not isServer then
		error("RemoteManager.fireClient can only be called from server")
	end
	
	local remote = RemoteManager.getRemote(eventKey)
	if remote then
		remote:FireClient(player, ...)
	end
end

-- Fire to all clients (server only)
function RemoteManager.fireAllClients(eventKey, ...)
	if not isServer then
		error("RemoteManager.fireAllClients can only be called from server")
	end
	
	local remote = RemoteManager.getRemote(eventKey)
	if remote then
		remote:FireAllClients(...)
	end
end

-- Connect to remote event on server
function RemoteManager.onServerEvent(eventKey, callback)
	if not isServer then
		error("RemoteManager.onServerEvent can only be called from server")
	end
	
	local remote = RemoteManager.getRemote(eventKey)
	if remote then
		return remote.OnServerEvent:Connect(callback)
	end
	return nil
end

-- === CLIENT FUNCTIONS ===

-- Fire to server (client only)
function RemoteManager.fireServer(eventKey, ...)
	if isServer then
		error("RemoteManager.fireServer can only be called from client")
	end
	
	local remote = RemoteManager.getRemote(eventKey)
	if remote then
		remote:FireServer(...)
	end
end

-- Connect to remote event on client
function RemoteManager.onClientEvent(eventKey, callback)
	if isServer then
		error("RemoteManager.onClientEvent can only be called from client")
	end
	
	local remote = RemoteManager.getRemote(eventKey)
	if remote then
		return remote.OnClientEvent:Connect(callback)
	end
	return nil
end

-- === UTILITY FUNCTIONS ===

-- Get remote event information
function RemoteManager.getRemoteInfo(eventKey)
	return REMOTE_EVENTS[eventKey]
end

-- List all available remote events
function RemoteManager.listRemoteEvents()
	print("Available Remote Events:")
	for eventKey, eventData in pairs(REMOTE_EVENTS) do
		local status = remotes[eventKey] and "✓" or "✗"
		print(string.format("  %s %s - %s", status, eventData.name, eventData.description))
	end
end

-- === TYPED REMOTE FUNCTIONS ===
-- These provide type-safe wrappers for specific remote events

-- Vehicle hover toggle
RemoteManager.Vehicle = {
	-- Server: Handle hover toggle request
	onHoverToggle = function(callback)
		return RemoteManager.onServerEvent("HoverToggle", callback)
	end,
	
	-- Client: Request hover toggle
	toggleHover = function(hoverEnabled, positionLocked)
		RemoteManager.fireServer("HoverToggle", hoverEnabled, positionLocked)
	end
}

-- Weapon system
RemoteManager.Weapon = {
	-- Server: Handle weapon fire request
	onFireWeapon = function(callback)
		return RemoteManager.onServerEvent("FireWeapon", callback)
	end,
	
	-- Client: Request weapon fire
	fireWeapon = function(weaponType, targetPosition)
		RemoteManager.fireServer("FireWeapon", weaponType, targetPosition)
	end
}

-- Health system
RemoteManager.Health = {
	-- Server: Send health update to client
	updateHealth = function(player, partName, currentHealth, maxHealth)
		RemoteManager.fireClient("HealthUpdate", player, partName, currentHealth, maxHealth)
	end,
	
	-- Server: Send health update to all clients
	updateHealthAll = function(partName, currentHealth, maxHealth)
		RemoteManager.fireAllClients("HealthUpdate", partName, currentHealth, maxHealth)
	end,
	
	-- Client: Handle health updates
	onHealthUpdate = function(callback)
		return RemoteManager.onClientEvent("HealthUpdate", callback)
	end
}

-- Debug system
RemoteManager.Debug = {
	-- Server: Send debug message to client
	sendDebugMessage = function(player, category, message)
		RemoteManager.fireClient("DebugMessage", player, category, message)
	end,
	
	-- Client: Send debug message to server
	sendDebugMessage = function(category, message)
		RemoteManager.fireServer("DebugMessage", category, message)
	end,
	
	-- Server: Handle debug messages from clients
	onDebugMessage = function(callback)
		return RemoteManager.onServerEvent("DebugMessage", callback)
	end,
	
	-- Client: Handle debug messages from server
	onDebugMessage = function(callback)
		return RemoteManager.onClientEvent("DebugMessage", callback)
	end
}

-- === ERROR HANDLING ===

-- Wrap remote calls with error handling
function RemoteManager.safeCall(func, ...)
	local success, result = pcall(func, ...)
	if not success then
		warn("RemoteManager: Error in remote call:", result)
		return false, result
	end
	return true, result
end

-- === CLEANUP ===

-- Disconnect all remote connections
function RemoteManager.cleanup()
	for eventKey, remote in pairs(remotes) do
		if remote and remote.Parent then
			-- Note: Individual connections should be stored and disconnected by the calling code
			print("RemoteManager: Cleaning up remote:", eventKey)
		end
	end
	remotes = {}
end

-- === AUTO-INITIALIZATION ===

-- Automatically initialize when the module is loaded
spawn(function()
	wait(0.1) -- Small delay to ensure services are ready
	RemoteManager.initialize()
end)

return RemoteManager
