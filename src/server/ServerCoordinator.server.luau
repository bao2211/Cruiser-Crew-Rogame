-- Server Coordinator
-- Main server script that sets up RemoteEvents and coordinates all systems
-- Must load first to create RemoteEvents for other systems

local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("SERVER: Server Coordinator starting...")

-- Create RemoteEvents folder if it doesn't exist
local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then
	remoteEvents = Instance.new("Folder")
	remoteEvents.Name = "RemoteEvents"
	remoteEvents.Parent = ReplicatedStorage
	print("SERVER: Created RemoteEvents folder")
end

-- Create HoverToggle RemoteEvent if it doesn't exist
local hoverToggleEvent = remoteEvents:FindFirstChild("HoverToggle")
if not hoverToggleEvent then
	hoverToggleEvent = Instance.new("RemoteEvent")
	hoverToggleEvent.Name = "HoverToggle"
	hoverToggleEvent.Parent = remoteEvents
	print("SERVER: Created HoverToggle RemoteEvent")
end

-- Create FireWeapon RemoteEvent if it doesn't exist
local fireWeaponEvent = remoteEvents:FindFirstChild("FireWeapon")
if not fireWeaponEvent then
	fireWeaponEvent = Instance.new("RemoteEvent")
	fireWeaponEvent.Name = "FireWeapon"
	fireWeaponEvent.Parent = remoteEvents
	print("SERVER: Created FireWeapon RemoteEvent")
end

print("SERVER: All RemoteEvents created successfully")
print("SERVER: Server systems will load automatically:")
print("  - WeaponSystem.server.luau")
print("  - VehicleHoverSystem.server.luau")
print("  - AttributeInitializer.server.luau")

print("SERVER: Server Coordinator initialization complete!")
