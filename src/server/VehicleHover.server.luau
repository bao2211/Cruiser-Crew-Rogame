local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create RemoteEvents folder if it doesn't exist
local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then
	remoteEvents = Instance.new("Folder")
	remoteEvents.Name = "RemoteEvents"
	remoteEvents.Parent = ReplicatedStorage
end

-- Create HoverToggle RemoteEvent if it doesn't exist
local hoverToggleEvent = remoteEvents:FindFirstChild("HoverToggle")
if not hoverToggleEvent then
	hoverToggleEvent = Instance.new("RemoteEvent")
	hoverToggleEvent.Name = "HoverToggle"
	hoverToggleEvent.Parent = remoteEvents
end

print("VehicleHover ServerScript started!")

-- Handle hover toggle requests from clients - IMMEDIATE response
hoverToggleEvent.OnServerEvent:Connect(function(player, vehicleSeat, command)
	print("SERVER: Received request from", player.Name, "Command:", command)

	if vehicleSeat and vehicleSeat:IsA("VehicleSeat") then
		if command == "lock_position" then
			-- Lock position - IMMEDIATE anchoring
			vehicleSeat.Anchored = true
			vehicleSeat:SetAttribute("PositionLocked", true)
			vehicleSeat:SetAttribute("LockedPosition", vehicleSeat.Position)
			vehicleSeat:SetAttribute("LockedCFrame", vehicleSeat.CFrame)

			-- Force velocity to zero immediately
			vehicleSeat.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			vehicleSeat.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			print("SERVER: Position locked for", vehicleSeat.Name, "by", player.Name)
		elseif command == "unlock_position" then
			-- Unlock position - More careful to avoid camera issues

			-- 1. First clean up ALL body movers (including client ones temporarily)
			local allBodyMovers = {
				"HoverBodyPosition",
				"HoverAngularVelocity",
				"HoverVelocity",
				"HoverOrientation",
				"HoverRotation",
				"ControlForce", -- Remove client force temporarily
				"ControlAngular", -- Remove client angular temporarily
			}

			for _, name in pairs(allBodyMovers) do
				local objToRemove = vehicleSeat:FindFirstChild(name)
				if objToRemove then
					objToRemove:Destroy()
				end
			end

			-- 2. Wait a tiny bit, then unanchor more gently
			task.wait(0.05)
			vehicleSeat.Anchored = false

			-- 3. Set attribute after unanchoring to reduce camera issues
			task.wait(0.05)
			vehicleSeat:SetAttribute("PositionLocked", false) -- This triggers client listener

			print("SERVER: Position unlocked for", vehicleSeat.Name, "by", player.Name, "- client will restore forces")
		elseif command == true then
			-- Enable hover
			vehicleSeat:SetAttribute("GravityCompensation", 1.0)
			vehicleSeat:SetAttribute("PositionLocked", false)
			vehicleSeat.Anchored = false
			print("SERVER: Hover enabled for", vehicleSeat.Name, "by", player.Name)
		elseif command == false then
			-- Disable hover
			vehicleSeat:SetAttribute("GravityCompensation", 0.8)
			vehicleSeat:SetAttribute("PositionLocked", false)
			vehicleSeat.Anchored = false
			print("SERVER: Hover disabled for", vehicleSeat.Name, "by", player.Name)
		end
	end
end)

-- Add debug function at top
local function debugServerVehicle(obj, state)
	local velocity = obj.AssemblyLinearVelocity
	local speed = velocity.Magnitude
	local isMoving = speed > 0.1
	local gravComp = obj:GetAttribute("GravityCompensation") or 0
	local positionLocked = obj:GetAttribute("PositionLocked") or false
	local hasOccupant = obj.Occupant ~= nil

	print(
		string.format(
			"SERVER DEBUG [%s]: %s | Speed=%.2f | Moving=%s | Hovering=%s | Locked=%s | Occupied=%s",
			obj.Name,
			state,
			speed,
			tostring(isMoving),
			tostring(gravComp >= 1.0),
			tostring(positionLocked),
			tostring(hasOccupant)
		)
	)
end

-- Simplified maintainHover - less interference with client control
local function maintainHover()
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("VehicleSeat") then
			local gravComp = obj:GetAttribute("GravityCompensation")
			local positionLocked = obj:GetAttribute("PositionLocked")

			if gravComp and gravComp >= 1.0 then
				if not obj.Occupant then
					-- NO PLAYER SEATED - Server handles hovering
					obj.Anchored = false

					local bodyPosition = obj:FindFirstChild("HoverBodyPosition")
					if not bodyPosition then
						bodyPosition = Instance.new("BodyPosition")
						bodyPosition.Name = "HoverBodyPosition"
						bodyPosition.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
						bodyPosition.P = 100000
						bodyPosition.D = 10000
						bodyPosition.Parent = obj
					end
					bodyPosition.Position = obj.Position

					local bodyAngularVelocity = obj:FindFirstChild("HoverAngularVelocity")
					if not bodyAngularVelocity then
						bodyAngularVelocity = Instance.new("BodyAngularVelocity")
						bodyAngularVelocity.Name = "HoverAngularVelocity"
						bodyAngularVelocity.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
						bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
						bodyAngularVelocity.P = 100000
						bodyAngularVelocity.Parent = obj
					else
						bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
					end

					if math.random(1, 100) == 1 then
						debugServerVehicle(obj, "HOVERING_NO_PLAYER")
					end
				else
					-- PLAYER IS SEATED
					if positionLocked then
						-- POSITION LOCKED - Keep anchored, remove all forces
						obj.Anchored = true

						-- Remove ALL body movers when position locked
						local allBodyMovers = {
							"HoverBodyPosition",
							"HoverAngularVelocity",
							"HoverVelocity",
							"HoverOrientation",
							"HoverRotation",
							"ControlForce",
							"ControlAngular",
						}

						for _, name in pairs(allBodyMovers) do
							local objToRemove = obj:FindFirstChild(name)
							if objToRemove then
								objToRemove:Destroy()
							end
						end

						-- Keep velocities at zero
						obj.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
						obj.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

						if math.random(1, 100) == 1 then
							debugServerVehicle(obj, "POSITION_LOCKED_ANCHORED")
						end
					else
						-- Player seated, NOT locked - DON'T interfere with client forces during unlock
						obj.Anchored = false

						-- Only remove server body movers, leave client forces alone
						-- UNLESS they don't exist (then client will recreate)
						local serverOnlyBodyMovers = {
							"HoverBodyPosition",
							"HoverAngularVelocity",
							"HoverVelocity",
							"HoverOrientation",
							"HoverRotation",
						}

						for _, name in pairs(serverOnlyBodyMovers) do
							local objToRemove = obj:FindFirstChild(name)
							if objToRemove then
								objToRemove:Destroy()
							end
						end

						-- Let client recreate ControlForce and ControlAngular

						if math.random(1, 300) == 1 then -- Less frequent debug
							debugServerVehicle(obj, "CLIENT_CONTROLLED")
						end
					end
				end
			else
				-- NOT HOVERING - clean up
				obj.Anchored = false

				local allBodyMovers = {
					"HoverBodyPosition",
					"HoverAngularVelocity",
					"HoverVelocity",
					"HoverOrientation",
					"HoverRotation",
				}

				for _, name in pairs(allBodyMovers) do
					local objToRemove = obj:FindFirstChild(name)
					if objToRemove then
						objToRemove:Destroy()
					end
				end
			end
		end
	end
end

-- Run hover maintenance less frequently to reduce interference
local lastUpdate = 0
RunService.Heartbeat:Connect(function()
	local now = tick()
	if now - lastUpdate >= 0.2 then -- Every 0.2 seconds to reduce interference
		lastUpdate = now
		maintainHover()
	end
end)
