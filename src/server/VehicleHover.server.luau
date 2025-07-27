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

-- Create FireWeapon RemoteEvent if it doesn't exist
local fireWeaponEvent = remoteEvents:FindFirstChild("FireWeapon")
if not fireWeaponEvent then
	fireWeaponEvent = Instance.new("RemoteEvent")
	fireWeaponEvent.Name = "FireWeapon"
	fireWeaponEvent.Parent = remoteEvents
end

print("VehicleHover ServerScript started!")

-- Weapon System Functions
local function createExplosion(position, blastRadius, blastPressure)
	-- Create explosion instance
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastRadius = blastRadius or 20
	explosion.BlastPressure = blastPressure or 500000
	explosion.Parent = workspace
	
	print("SERVER: Explosion created at", position, "with blast radius", blastRadius)
end

local function createHealthBar(part)
	-- Remove existing health bar
	local existingGui = part:FindFirstChild("HealthBarGui")
	if existingGui then 
		existingGui:Destroy() 
	end
	
	local currentHealth = tonumber(part:GetAttribute("health")) or 100
	local maxHealth = tonumber(part:GetAttribute("max_health")) or 100
	
	if currentHealth <= 0 then
		return -- Don't show health bar for destroyed parts
	end
	
	-- Create BillboardGui
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "HealthBarGui"
	billboardGui.Size = UDim2.fromScale(2, 0.5)
	billboardGui.StudsOffset = Vector3.new(0, part.Size.Y/2 + 1, 0)
	billboardGui.Parent = part
	
	-- Background frame
	local backgroundFrame = Instance.new("Frame")
	backgroundFrame.Size = UDim2.fromScale(1, 1)
	backgroundFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	backgroundFrame.BorderColor3 = Color3.new(1, 1, 1)
	backgroundFrame.BorderSizePixel = 2
	backgroundFrame.Parent = billboardGui
	
	-- Health bar
	local healthBar = Instance.new("Frame")
	local healthPercent = currentHealth / maxHealth
	healthBar.Size = UDim2.fromScale(healthPercent, 0.6)
	healthBar.Position = UDim2.fromScale(0, 0.2)
	healthBar.BorderSizePixel = 0
	
	-- Color based on health percentage
	if healthPercent > 0.6 then
		healthBar.BackgroundColor3 = Color3.new(0, 1, 0) -- Green
	elseif healthPercent > 0.3 then
		healthBar.BackgroundColor3 = Color3.new(1, 1, 0) -- Yellow
	else
		healthBar.BackgroundColor3 = Color3.new(1, 0, 0) -- Red
	end
	healthBar.Parent = backgroundFrame
	
	-- Health text
	local healthText = Instance.new("TextLabel")
	healthText.Size = UDim2.fromScale(1, 1)
	healthText.BackgroundTransparency = 1
	healthText.Text = string.format("%d/%d", currentHealth, maxHealth)
	healthText.TextColor3 = Color3.new(1, 1, 1)
	healthText.TextScaled = true
	healthText.Font = Enum.Font.SourceSansBold
	healthText.Parent = backgroundFrame
	
	-- Auto-cleanup after 3 seconds
	game:GetService("Debris"):AddItem(billboardGui, 3)
end

local function destroyPart(part)
	if not part or not part.Parent then
		return
	end
	
	print("SERVER: Destroying part", part.Name)
	
	-- Unweld all joints
	for _, obj in pairs(part:GetChildren()) do
		if obj:IsA("WeldConstraint") or obj:IsA("Weld") or obj:IsA("Motor6D") then
			obj:Destroy()
		end
	end
	
	-- Start transparency fade
	local originalTransparency = part.Transparency
	local fadeTime = 3
	local startTime = tick()
	
	local fadeConnection
	fadeConnection = game:GetService("RunService").Heartbeat:Connect(function()
		local elapsed = tick() - startTime
		local progress = elapsed / fadeTime
		
		if progress >= 1 then
			-- Fade complete - destroy part
			fadeConnection:Disconnect()
			part:Destroy()
			print("SERVER: Part", part.Name, "destroyed after fade")
		else
			-- Update transparency
			part.Transparency = originalTransparency + (1 - originalTransparency) * progress
		end
	end)
end

local function damagePart(part, damage)
	if not part or not part:GetAttribute("health") then
		return
	end
	
	local currentHealth = tonumber(part:GetAttribute("health")) or 100
	local newHealth = math.max(0, currentHealth - damage)
	part:SetAttribute("health", newHealth)
	
	print("SERVER: Part", part.Name, "damaged for", damage, "health:", newHealth)
	
	-- Show health bar
	createHealthBar(part)
	
	-- Destroy if health reaches 0
	if newHealth <= 0 then
		destroyPart(part)
	end
end

local function createSound(parent, soundId, volume, pitch)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.Pitch = pitch or 1.0
	sound.Parent = parent
	sound:Play()
	
	-- Auto-cleanup
	game:GetService("Debris"):AddItem(sound, 3)
	return sound
end

local function fireCannon(player, vehicleSeat, chamber)
	-- Validate player is in the seat
	if not vehicleSeat.Occupant or vehicleSeat.Occupant.Parent ~= player.Character then
		print("SERVER: Fire request denied - player not in seat")
		return
	end
	
	print("SERVER: Received fire weapon request from", player.Name)
	
	-- Get chamber attributes
	local ammoType = chamber:GetAttribute("ammotype") or "standard"
	local armorPen = tonumber(chamber:GetAttribute("armor_pen")) or 10
	local damage = tonumber(chamber:GetAttribute("damage")) or 25
	local afterPen = tonumber(chamber:GetAttribute("afterpen")) or 0.5
	local airburstTime = tonumber(chamber:GetAttribute("airburst_time")) or 2.0
	
	-- Get firing direction and position
	local fireDirection = vehicleSeat.CFrame.LookVector
	local firePosition = chamber.Position
	
	print("SERVER: Cannon fired by", player.Name, "from", chamber.Name, "in direction", fireDirection)
	
	-- Create projectile
	local projectile = Instance.new("Part")
	projectile.Name = "CannonProjectile"
	projectile.Size = Vector3.new(0.5, 0.5, 2)
	projectile.Shape = Enum.PartType.Cylinder
	projectile.Material = Enum.Material.Metal
	projectile.Position = firePosition + fireDirection * 3
	projectile.CFrame = CFrame.lookAt(projectile.Position, projectile.Position + fireDirection)
	projectile.CanCollide = true
	projectile.Parent = workspace
	
	-- Set projectile appearance and attributes based on ammo type
	if ammoType == "high_explosive" then
		projectile.BrickColor = BrickColor.new("Bright red")
		projectile.Name = "ExplosiveProjectile"
	elseif ammoType == "airburst" then
		projectile.BrickColor = BrickColor.new("Bright yellow")
		projectile.Name = "AirburstProjectile"
	elseif ammoType == "high_penetration_explosive" then
		projectile.BrickColor = BrickColor.new("Bright orange")
		projectile.Name = "HighPenExplosiveProjectile"
	else
		projectile.BrickColor = BrickColor.new("Dark stone grey")
	end
	
	-- Store attributes in projectile
	projectile:SetAttribute("ammotype", ammoType)
	projectile:SetAttribute("armor_pen", armorPen)
	projectile:SetAttribute("damage", damage)
	projectile:SetAttribute("afterpen", afterPen)
	projectile:SetAttribute("airburst_time", airburstTime)
	
	-- Add velocity
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bodyVelocity.Velocity = fireDirection * 200
	bodyVelocity.Parent = projectile
	
	-- Airburst timer and proximity detection for airburst rounds
	if ammoType == "airburst" then
		spawn(function()
			wait(airburstTime)
			if projectile and projectile.Parent then
				print("SERVER: Airburst timer detonation!")
				createExplosion(projectile.Position, 25, 600000)
				projectile:Destroy()
			end
		end)
		
		-- Proximity detection for airburst rounds
		spawn(function()
			while projectile and projectile.Parent do
				wait(0.1) -- Check every 0.1 seconds
				
				-- Check for parts within 10 studs
				local nearbyParts = {}
				for _, obj in pairs(workspace:GetPartBoundsInBox(projectile.CFrame, Vector3.new(20, 20, 20))) do
					if obj ~= projectile and not obj:IsDescendantOf(vehicleSeat.Parent) then
						local distance = (obj.Position - projectile.Position).Magnitude
						if distance <= 10 then
							table.insert(nearbyParts, obj)
						end
					end
				end
				
				-- If parts found within 10 studs, explode
				if #nearbyParts > 0 then
					print("SERVER: Airburst proximity detonation! Found", #nearbyParts, "nearby parts")
					createExplosion(projectile.Position, 25, 600000)
					projectile:Destroy()
					break
				end
			end
		end)
	end
	
	-- Collision detection
	local connection
	connection = projectile.Touched:Connect(function(hit)
		-- Ignore the firing vehicle
		if hit:IsDescendantOf(vehicleSeat.Parent) then
			return
		end
		
		-- Ignore other projectiles
		if hit.Name:find("Projectile") then
			return
		end
		
		local projectileAmmoType = projectile:GetAttribute("ammotype")
		local projectileArmorPen = tonumber(projectile:GetAttribute("armor_pen")) or 10
		local projectileDamage = tonumber(projectile:GetAttribute("damage")) or 25
		local projectileAfterPen = tonumber(projectile:GetAttribute("afterpen")) or 0.5
		
		local targetArmor = tonumber(hit:GetAttribute("armor")) or 0
		
		print("SERVER: Projectile hit", hit.Name, "Armor:", targetArmor, "Penetration:", projectileArmorPen)
		
		-- Handle different ammo types
		if projectileAmmoType == "airburst" then
			-- Airburst explodes on any contact (also has proximity detection)
			print("SERVER: Airburst round hit target! Exploding on contact")
			createExplosion(projectile.Position, 25, 600000)
			connection:Disconnect()
			projectile:Destroy()
			return
		elseif projectileAmmoType == "high_explosive" then
			-- High explosive: Always explode on any hit
			createSound(hit, "rbxasset://sounds/impact_water.mp3", 0.7, 1.0)
			print("SERVER: High explosive round hit", hit.Name, "- exploding!")
			createExplosion(projectile.Position, 20, 500000)
			connection:Disconnect()
			projectile:Destroy()
			return
		elseif projectileAmmoType == "high_penetration_explosive" then
			-- High penetration explosive: Afterpen timer behavior
			if projectileArmorPen > targetArmor then
				-- Penetrates armor - start afterpen timer
				if targetArmor > 0 then
					createSound(hit, "rbxasset://sounds/impact_water.mp3", 0.7, 1.0)
					print("SERVER: High-pen explosive penetrated armor! Exploding in", projectileAfterPen, "seconds")
				else
					createSound(hit, "rbxasset://sounds/impact_water.mp3", 0.8, 1.2)
					print("SERVER: High-pen explosive passed through unarmored part - exploding in", projectileAfterPen, "seconds")
				end
				
				damagePart(hit, projectileDamage)
				
				-- Delayed explosion after penetration
				spawn(function()
					wait(projectileAfterPen)
					if projectile and projectile.Parent then
						createExplosion(projectile.Position, 20, 500000)
						connection:Disconnect()
						projectile:Destroy()
					end
				end)
			else
				-- Blocked by armor - explode on contact
				createSound(hit, "rbxasset://sounds/electronicpingshort.wav", 0.5, 1.5)
				print("SERVER: High-pen explosive blocked by armor - exploding on contact")
				createExplosion(projectile.Position, 20, 500000)
				connection:Disconnect()
				projectile:Destroy()
			end
		elseif projectileAmmoType == "standard" then
			-- Standard round: Pass through and damage until blocked, then ricochet and destroy
			if projectileArmorPen > targetArmor then
				-- Penetrates and damages
				if targetArmor > 0 then
					createSound(hit, "rbxasset://sounds/impact_water.mp3", 0.7, 1.0)
					print("SERVER: Standard round penetrated", hit.Name)
				else
					-- Silent pass-through for unarmored
					print("SERVER: Standard round passed through unarmored part", hit.Name)
				end
				
				damagePart(hit, projectileDamage)
				-- Continue flying (don't destroy projectile)
			else
				-- Blocked by armor - ricochet and destroy
				createSound(hit, "rbxasset://sounds/electronicpingshort.wav", 0.6, 1.8)
				print("SERVER: Standard round ricocheted off armor and destroyed")
				
				-- Destroy projectile (no more ricocheting)
				connection:Disconnect()
				projectile:Destroy()
			end
		end
	end)
	
	-- Note: Firing sound is played by client for immediate feedback
	
	-- Auto-cleanup projectile after 10 seconds
	game:GetService("Debris"):AddItem(projectile, 10)
end

-- Handle hover toggle requests from clients
hoverToggleEvent.OnServerEvent:Connect(function(player, vehicleSeat, command)
	print("SERVER: Received request from", player.Name, "Command:", command, "Vehicle:", vehicleSeat.Name)

	if vehicleSeat and vehicleSeat:IsA("VehicleSeat") then
		if command == "lock_position" then
			-- Lock position for THIS specific vehicle
			vehicleSeat.Anchored = true
			vehicleSeat:SetAttribute("PositionLocked", true)
			vehicleSeat:SetAttribute("LockedPosition", vehicleSeat.Position)
			vehicleSeat:SetAttribute("LockedCFrame", vehicleSeat.CFrame)

			-- Force velocity to zero immediately
			vehicleSeat.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			vehicleSeat.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			print("SERVER: Position locked for", vehicleSeat.Name, "by", player.Name)
		elseif command == "unlock_position" then
			-- Unlock position for THIS specific vehicle
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
				local objToRemove = vehicleSeat:FindFirstChild(name)
				if objToRemove then
					objToRemove:Destroy()
				end
			end

			task.wait(0.05)
			vehicleSeat.Anchored = false

			task.wait(0.05)
			vehicleSeat:SetAttribute("PositionLocked", false)

			print("SERVER: Position unlocked for", vehicleSeat.Name, "by", player.Name)
		elseif command == "player_exited" then
			-- Player exited vehicle - DON'T reset the vehicle's state, just clean up forces
			print("SERVER: Player", player.Name, "exited vehicle", vehicleSeat.Name, "- preserving vehicle state")

			-- Remove player-specific forces but keep vehicle state attributes
			local playerForces = {
				"ControlForce",
				"ControlAngular",
			}

			for _, name in pairs(playerForces) do
				local objToRemove = vehicleSeat:FindFirstChild(name)
				if objToRemove then
					objToRemove:Destroy()
				end
			end

			-- DON'T reset these - preserve the vehicle's state:
			-- vehicleSeat:SetAttribute("PositionLocked", false) -- KEEP THIS
			-- vehicleSeat:SetAttribute("GravityCompensation", 0.8) -- KEEP THIS

			-- Only reset physical movement
			vehicleSeat.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			vehicleSeat.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

			print("SERVER: Cleaned up player forces for", vehicleSeat.Name, "- state preserved")
		elseif command == true then
			-- Enable hover for THIS specific vehicle
			vehicleSeat:SetAttribute("GravityCompensation", 1.0)
			vehicleSeat.Anchored = false
			print("SERVER: Hover enabled for", vehicleSeat.Name, "by", player.Name)
		elseif command == false then
			-- Disable hover for THIS specific vehicle
			vehicleSeat:SetAttribute("GravityCompensation", 0.8)
			vehicleSeat:SetAttribute("PositionLocked", false) -- Can't be locked if not hovering
			vehicleSeat.Anchored = false
			print("SERVER: Hover disabled for", vehicleSeat.Name, "by", player.Name)
		end
	end
end)

-- Handle weapon firing requests from clients
fireWeaponEvent.OnServerEvent:Connect(function(player, vehicleSeat)
	if not vehicleSeat or not vehicleSeat:IsA("VehicleSeat") then
		return
	end
	
	-- Find chamber in the vehicle
	local vehicleModel = vehicleSeat.Parent
	if not vehicleModel then
		return
	end
	
	local chamber = vehicleModel:FindFirstChild("chamber")
	if not chamber then
		print("SERVER: No chamber found for weapon firing")
		return
	end
	
	-- Fire the cannon
	fireCannon(player, vehicleSeat, chamber)
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
			-- Initialize seattype attribute if not set
			if not obj:GetAttribute("seattype") then
				obj:SetAttribute("seattype", "cruiser") -- Default to cruiser
			end
			
			-- Initialize weapontype attribute if not set
			if not obj:GetAttribute("weapontype") then
				obj:SetAttribute("weapontype", "None") -- Default to no weapon
			end
			
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

-- Initialize chamber parts with ammotype attribute
local function initializeChambers()
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("Part") and obj.Name == "chamber" then
			-- Initialize ammotype attribute for chamber parts if not set
			if not obj:GetAttribute("ammotype") then
				obj:SetAttribute("ammotype", "standard") -- Default to standard ammo
			end
			
			-- Initialize weapon attributes if not set
			if not obj:GetAttribute("armor_pen") then
				obj:SetAttribute("armor_pen", 10) -- Default armor penetration
			end
			
			if not obj:GetAttribute("damage") then
				obj:SetAttribute("damage", 25) -- Default damage
			end
			
			if not obj:GetAttribute("afterpen") then
				obj:SetAttribute("afterpen", 0.5) -- Default afterpen delay
			end
			
			if not obj:GetAttribute("airburst_time") then
				obj:SetAttribute("airburst_time", 2.0) -- Default airburst time
			end
		end
	end
end

-- Initialize all parts with health and armor attributes
local function initializeParts()
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and not obj:IsA("VehicleSeat") then
			-- Initialize armor attribute if not set
			if not obj:GetAttribute("armor") then
				obj:SetAttribute("armor", 5) -- Default armor value
			end
			
			-- Initialize health attribute if not set
			if not obj:GetAttribute("health") then
				obj:SetAttribute("health", 100) -- Default health
			end
			
			-- Initialize max_health attribute if not set
			if not obj:GetAttribute("max_health") then
				local currentHealth = obj:GetAttribute("health") or 100
				obj:SetAttribute("max_health", currentHealth) -- Set max_health to current health
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
		initializeChambers()
		initializeParts()
	end
end)
