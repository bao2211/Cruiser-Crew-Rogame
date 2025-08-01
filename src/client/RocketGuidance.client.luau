-- Rocket Guidance Client
-- Handles mouse tracking for rocket guidance system

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Wait for RemoteEvents
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local rocketGuidanceEvent = remoteEvents:WaitForChild("RocketGuidance")

print("CLIENT: Rocket Guidance System loaded")

-- Track active rockets that need guidance
local activeGuidedRockets = {}

-- Function to check if a target should be ignored for collision (not for raycasting through)
local function shouldIgnoreForCollision(target)
	if not target then return true end
	
	-- Ignore projectiles and explosion spheres
	if target.Name:find("Projectile") or target.Name == "ExplosionRadius" or target:GetAttribute("is_explosion_sphere") then
		return true
	end
	
	return false
end

-- Function to get the actual target position, looking through AIrange parts
local function getTargetPosition()
	local camera = workspace.CurrentCamera
	if not camera then return nil end
	
	-- Create raycast params to ignore AIrange parts and other invalid targets
	local raycastParams = RaycastParams.new()
	local ignoreList = {}
	
	-- Add all AIrange parts to ignore list
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj.Name == "AIrange" or shouldIgnoreForCollision(obj) then
			table.insert(ignoreList, obj)
		end
	end
	
	raycastParams.FilterDescendantsInstances = ignoreList
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	
	-- Cast ray from camera through mouse position
	local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local raycastResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)
	
	if raycastResult then
		return raycastResult.Position
	else
		-- Fallback to mouse.Hit if raycast fails
		return mouse.Hit and mouse.Hit.Position
	end
end

-- Handle rocket guidance requests from server
rocketGuidanceEvent.OnClientEvent:Connect(function(action, rocketId)
	if action == "request_target" then
		print("CLIENT: Starting guidance for rocket", rocketId)
		
		-- Add rocket to tracking
		activeGuidedRockets[rocketId] = {
			active = true,
			lastUpdate = tick(),
			startTime = tick()
		}
		
		-- Send initial target position (using raycast to see through AIrange)
		local targetPos = getTargetPosition()
		if targetPos then
			rocketGuidanceEvent:FireServer("update_target", rocketId, targetPos)
		end
	end
end)

-- Continuous guidance update loop
local function updateRocketGuidance()
	for rocketId, rocketData in pairs(activeGuidedRockets) do
		if rocketData.active then
			-- Update target position based on mouse (using raycast to see through AIrange)
			local targetPos = getTargetPosition()
			if targetPos then
				local currentTime = tick()
				-- Only send updates every 0.1 seconds to reduce network traffic
				if currentTime - rocketData.lastUpdate >= 0.1 then
					rocketGuidanceEvent:FireServer("update_target", rocketId, targetPos)
					rocketData.lastUpdate = currentTime
				end
			end
			
			-- Clean up old rockets after 10 seconds from creation (not last update)
			if tick() - rocketData.startTime > 10 then
				activeGuidedRockets[rocketId] = nil
				print("CLIENT: Cleaned up rocket guidance after 10 seconds:", rocketId)
			end
		end
	end
end

-- Connect the guidance update to heartbeat
RunService.Heartbeat:Connect(updateRocketGuidance)

print("CLIENT: Rocket guidance tracking active")
