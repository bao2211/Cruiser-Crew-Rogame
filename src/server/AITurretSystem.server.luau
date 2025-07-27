-- AI Turret System Server
-- Handles automatic target detection and firing for AI turrets
-- Requires VehicleSeat with aiturret=true and Airange part in parent model

local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

print("SERVER: AI Turret System loaded")

-- Explosion cooldown system (same as WeaponSystem)
local explosionCooldowns = {}
local EXPLOSION_COOLDOWN_TIME = 0.1

-- Configuration
local AI_UPDATE_INTERVAL = 0.1 -- Check for targets every 0.1 seconds
local TRACKING_SPEED = 15 -- How fast turret tracks targets

-- Storage for AI turret data
local aiTurrets = {}
local lastFireTimes = {} -- Track reload times per turret

-- Create explosion with visual effects and damage (same as WeaponSystem)
local function createExplosion(position, explosionRadius, explosionDamage, armorPen, firingVehicle)
	-- Check explosion cooldown to prevent infinite explosions
	local positionKey = string.format("%.1f,%.1f,%.1f", position.X, position.Y, position.Z)
	local currentTime = tick()
	
	if explosionCooldowns[positionKey] and (currentTime - explosionCooldowns[positionKey]) < EXPLOSION_COOLDOWN_TIME then
		print("SERVER: AI Explosion blocked by cooldown at", position)
		return
	end
	
	explosionCooldowns[positionKey] = currentTime
	
	-- Clean up old cooldown entries to prevent memory buildup
	for key, time in pairs(explosionCooldowns) do
		if (currentTime - time) > 10 then
			explosionCooldowns[key] = nil
		end
	end
	
	-- Create visual explosion sphere
	local explosionSphere = Instance.new("Part")
	explosionSphere.Name = "ExplosionRadius"
	explosionSphere.Shape = Enum.PartType.Ball
	explosionSphere.Material = Enum.Material.ForceField
	explosionSphere.BrickColor = BrickColor.new("Bright red")
	explosionSphere.Transparency = 0.7
	explosionSphere.CanCollide = false
	explosionSphere.CanTouch = false
	explosionSphere.CanQuery = false
	explosionSphere.Anchored = true
	explosionSphere.Size = Vector3.new(explosionRadius * 2, explosionRadius * 2, explosionRadius * 2)
	explosionSphere.Position = position
	explosionSphere:SetAttribute("is_explosion_sphere", true)
	explosionSphere.Parent = workspace
	
	-- Create standard explosion for visual/audio effects
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastRadius = 5
	explosion.BlastPressure = 0
	explosion.Parent = workspace
	
	-- Add custom explosion sound for better audio
	local explosionSound = Instance.new("Sound")
	explosionSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	explosionSound.Volume = 1.0
	explosionSound.Pitch = 0.8
	explosionSound.Parent = explosionSphere
	explosionSound:Play()
	Debris:AddItem(explosionSound, 5)
	
	print("SERVER: AI Explosion created at", position, "with radius", explosionRadius, "damage", explosionDamage, "armor pen", armorPen)
	
	-- Find all parts within explosion radius and apply damage
	for _, obj in pairs(workspace:GetPartBoundsInBox(CFrame.new(position), Vector3.new(explosionRadius * 2, explosionRadius * 2, explosionRadius * 2))) do
		if obj:IsA("BasePart") and obj ~= explosionSphere then
			-- Skip the firing vehicle to prevent self-damage
			if not (firingVehicle and obj:IsDescendantOf(firingVehicle)) then
				if not (obj.Name == "ExplosionRadius" or obj.Name:find("Projectile") or obj.Name:find("Explosion")) then
				local distance = (obj.Position - position).Magnitude
				if distance <= explosionRadius then
					local partArmor = tonumber(obj:GetAttribute("armor")) or 0
					
					if armorPen > partArmor then
						local damageFalloff = math.max(0.1, 1 - (distance / explosionRadius))
						local finalDamage = explosionDamage * damageFalloff
						
						-- Apply damage directly here
						local currentHealth = tonumber(obj:GetAttribute("health")) or 100
						local newHealth = math.max(0, currentHealth - finalDamage)
						obj:SetAttribute("health", newHealth)
						
						print("SERVER: AI Explosion damaged", obj.Name, "for", math.floor(finalDamage), "damage (health:", newHealth, ")")
						
						-- Create health bar
						local existingGui = obj:FindFirstChild("HealthBarGui")
						if existingGui then
							existingGui:Destroy()
						end
						
						if newHealth > 0 then
							local billboardGui = Instance.new("BillboardGui")
							billboardGui.Name = "HealthBarGui"
							billboardGui.Size = UDim2.fromScale(2, 0.5)
							billboardGui.StudsOffset = Vector3.new(0, obj.Size.Y/2 + 1, 0)
							billboardGui.Parent = obj
							
							local backgroundFrame = Instance.new("Frame")
							backgroundFrame.Size = UDim2.fromScale(1, 1)
							backgroundFrame.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
							backgroundFrame.BorderColor3 = Color3.new(1, 1, 1)
							backgroundFrame.BorderSizePixel = 2
							backgroundFrame.Parent = billboardGui
							
							local maxHealth = tonumber(obj:GetAttribute("max_health")) or 100
							local healthPercent = newHealth / maxHealth
							local healthBar = Instance.new("Frame")
							healthBar.Size = UDim2.fromScale(healthPercent, 0.6)
							healthBar.Position = UDim2.fromScale(0, 0.2)
							healthBar.BorderSizePixel = 0
							
							if healthPercent > 0.6 then
								healthBar.BackgroundColor3 = Color3.new(0, 1, 0)
							elseif healthPercent > 0.3 then
								healthBar.BackgroundColor3 = Color3.new(1, 1, 0)
							else
								healthBar.BackgroundColor3 = Color3.new(1, 0, 0)
							end
							healthBar.Parent = backgroundFrame
							
							local healthText = Instance.new("TextLabel")
							healthText.Size = UDim2.fromScale(1, 1)
							healthText.BackgroundTransparency = 1
							healthText.Text = string.format("%d/%d", newHealth, maxHealth)
							healthText.TextColor3 = Color3.new(1, 1, 1)
							healthText.TextScaled = true
							healthText.Font = Enum.Font.SourceSansBold
							healthText.Parent = backgroundFrame
							
							Debris:AddItem(billboardGui, 3)
						else
							-- Destroy part with fade
							obj:SetAttribute("being_destroyed", true)
							local originalTransparency = obj.Transparency
							local fadeTime = 3
							local startTime = tick()
							
							local fadeConnection
							fadeConnection = RunService.Heartbeat:Connect(function()
								local elapsed = tick() - startTime
								local progress = elapsed / fadeTime
								
								if progress >= 1 then
									fadeConnection:Disconnect()
									obj:Destroy()
									print("SERVER: AI explosion destroyed part", obj.Name, "after fade")
								else
									obj.Transparency = originalTransparency + (1 - originalTransparency) * progress
								end
							end)
						end
					end
				end
			end
			end -- Close the if not (obj.Name...) condition
		end
	end -- Close the main for loop
	
	-- Cleanup explosion sphere
	Debris:AddItem(explosionSphere, 3)
end

-- Find chamber part for a vehicle seat
local function findChamber(vehicleSeat)
	local parentModel = vehicleSeat.Parent
	if parentModel then
		for _, obj in pairs(parentModel:GetChildren()) do
			if obj:IsA("Part") and obj.Name == "chamber" then
				return obj
			end
		end
	end
	return nil
end

-- Find Airange part for a vehicle seat
local function findAirange(vehicleSeat)
	local parentModel = vehicleSeat.Parent
	if parentModel then
		for _, obj in pairs(parentModel:GetChildren()) do
			if obj:IsA("Part") and obj.Name == "Airange" then
				return obj
			end
		end
	end
	return nil
end

-- Check if a part is a valid target (has health attribute and is not part of the turret's vehicle)
local function isValidTarget(part, turretVehicle)
	-- Must be a BasePart with health attribute
	if not part:IsA("BasePart") or not part:GetAttribute("health") then
		return false
	end
	
	-- Must have health > 0
	local health = tonumber(part:GetAttribute("health"))
	if not health or health <= 0 then
		return false
	end
	
	-- Must not be part of the same vehicle (check if part is descendant of turret vehicle)
	if part:IsDescendantOf(turretVehicle) then
		-- Debug: Uncomment next line to see what parts are being filtered out
		-- print("DEBUG: Filtered out own vehicle part:", part.Name)
		return false
	end
	
	-- Must not be explosion spheres or temporary objects
	if part.Name == "ExplosionRadius" or part:GetAttribute("is_explosion_sphere") then
		-- Debug: Uncomment next line to see explosion spheres being filtered
		-- print("DEBUG: Filtered out explosion sphere:", part.Name)
		return false
	end
	
	-- Must not be projectiles
	if part.Name:find("Projectile") then
		-- Debug: Uncomment next line to see projectiles being filtered
		-- print("DEBUG: Filtered out projectile:", part.Name)
		return false
	end
	
	-- Must not be a player (to avoid targeting players directly)
	local humanoid = part.Parent:FindFirstChild("Humanoid")
	if humanoid then
		return false
	end
	
	return true
end

-- Find targets within Airange
local function findTargetsInRange(airange, turretVehicle)
	local targets = {}
	local airangePosition = airange.Position
	local airangeSize = airange.Size
	
	-- Check all parts in workspace for distance within Airange bounds
	for _, obj in pairs(workspace:GetDescendants()) do
		if isValidTarget(obj, turretVehicle) then
			local distance = (obj.Position - airangePosition).Magnitude
			-- Check if target is within the Airange bounds
			local relativePos = obj.Position - airangePosition
			if math.abs(relativePos.X) <= airangeSize.X/2 and
			   math.abs(relativePos.Y) <= airangeSize.Y/2 and
			   math.abs(relativePos.Z) <= airangeSize.Z/2 then
				table.insert(targets, {part = obj, distance = distance})
				print("DEBUG: AI Turret found valid target:", obj.Name, "Distance:", math.floor(distance), "studs")
			end
		end
	end
	
	-- Sort by distance (closest first)
	table.sort(targets, function(a, b)
		return a.distance < b.distance
	end)
	
	return targets
end

-- Calculate rotation needed to face target
local function calculateTargetRotation(vehicleSeat, chamber, targetPosition)
	-- Use chamber position for more accurate targeting
	local chamberPosition = chamber.Position
	local direction = (targetPosition - chamberPosition).Unit
	local currentForward = vehicleSeat.CFrame.LookVector
	
	-- Calculate angular velocity needed
	local cross = currentForward:Cross(direction)
	local dot = currentForward:Dot(direction)
	local targetAngularVelocity = cross * TRACKING_SPEED * (1 - dot)
	
	-- Limit pitch to prevent flipping
	local maxPitch = 1.5
	targetAngularVelocity = Vector3.new(
		math.clamp(targetAngularVelocity.X, -maxPitch, maxPitch),
		targetAngularVelocity.Y,
		0 -- No roll
	)
	
	return targetAngularVelocity
end

-- Apply rotation to turret
local function rotateTurret(vehicleSeat, targetAngularVelocity)
	local bodyAngular = vehicleSeat:FindFirstChild("AITurretAngular")
	if not bodyAngular then
		bodyAngular = Instance.new("BodyAngularVelocity")
		bodyAngular.Name = "AITurretAngular"
		bodyAngular.Parent = vehicleSeat
	end
	
	bodyAngular.AngularVelocity = targetAngularVelocity
	bodyAngular.MaxTorque = Vector3.new(math.huge, math.huge, 0)
	bodyAngular.P = 10000
end

-- Fire weapon at target
local function fireAtTarget(vehicleSeat, chamber, target)
	local turretId = tostring(vehicleSeat)
	local currentTime = tick()
	local reloadTime = chamber:GetAttribute("reload") or 1.0
	
	-- Check if turret is ready to fire (reload time passed)
	if lastFireTimes[turretId] and (currentTime - lastFireTimes[turretId]) < reloadTime then
		return -- Still reloading
	end
	
	-- Check if chamber is facing the target (within reasonable angle)
	local chamberForward = vehicleSeat.CFrame.LookVector
	local targetDirection = (target.part.Position - chamber.Position).Unit
	local dot = chamberForward:Dot(targetDirection)
	
	-- Only fire if chamber is roughly facing the target (dot > 0.95 means ~18 degree tolerance)
	if dot > 0.95 then
		-- Get firing direction and position from chamber
		local fireDirection = targetDirection -- Fire directly at target
		local firePosition = chamber.Position
		
		-- Fire the weapon directly for AI turret
		
		-- Get chamber attributes
		local ammoType = chamber:GetAttribute("ammotype") or "standard"
		local armorPen = tonumber(chamber:GetAttribute("armor_pen")) or 10
		local damage = tonumber(chamber:GetAttribute("damage")) or 25
		local afterPen = tonumber(chamber:GetAttribute("afterpen")) or 0.5
		local explosionRadius = tonumber(chamber:GetAttribute("explosion_radius")) or 20
		local explosionDamage = tonumber(chamber:GetAttribute("explosive_radius_damage")) or 50
		
		-- Create projectile
		local projectile = Instance.new("Part")
		projectile.Name = "AITurretProjectile"
		projectile.Size = Vector3.new(0.5, 0.5, 2)
		projectile.Shape = Enum.PartType.Cylinder
		projectile.Material = Enum.Material.Metal
		projectile.Position = firePosition + fireDirection * 3
		projectile.CFrame = CFrame.lookAt(projectile.Position, projectile.Position + fireDirection)
		projectile.CanCollide = true
		projectile.Parent = workspace
		
		-- Set projectile appearance based on ammo type
		if ammoType == "high_explosive" then
			projectile.BrickColor = BrickColor.new("Bright red")
		else
			projectile.BrickColor = BrickColor.new("Dark stone grey")
		end
		
		-- Store attributes in projectile
		projectile:SetAttribute("ammotype", ammoType)
		projectile:SetAttribute("armor_pen", armorPen)
		projectile:SetAttribute("damage", damage)
		projectile:SetAttribute("afterpen", afterPen)
		projectile:SetAttribute("has_exploded", false)
		
		-- Play firing sound
		local firingSound = Instance.new("Sound")
		firingSound.SoundId = "rbxasset://sounds/impact_water.mp3"
		firingSound.Volume = 0.8
		firingSound.Pitch = 1.2
		firingSound.Parent = chamber
		firingSound:Play()
		Debris:AddItem(firingSound, 3)
		
		print("SERVER: AI Turret fired", ammoType, "round at target:", target.part.Name, "Distance:", math.floor(target.distance), "studs")
		
		-- Add velocity
		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		bodyVelocity.Velocity = fireDirection * 200
		bodyVelocity.Parent = projectile
		
		-- Add collision detection
		projectile.Touched:Connect(function(hit)
			-- Ignore the firing vehicle
			if hit:IsDescendantOf(vehicleSeat.Parent) then
				return
			end
			
			-- Ignore other projectiles and explosion spheres
			if hit.Name:find("Projectile") or hit.Name == "ExplosionRadius" or hit:GetAttribute("is_explosion_sphere") then
				return
			end
			
			local projectileAmmoType = projectile:GetAttribute("ammotype")
			local projectileArmorPen = tonumber(projectile:GetAttribute("armor_pen")) or 10
			local projectileDamage = tonumber(projectile:GetAttribute("damage")) or 25
			local targetArmor = tonumber(hit:GetAttribute("armor")) or 0
			
			print("SERVER: AI Projectile hit", hit.Name, "Armor:", targetArmor, "Penetration:", projectileArmorPen)
			
			-- Handle explosive rounds
			if projectileAmmoType == "airburst" then
				-- Airburst rounds always explode immediately on contact
				local hasExploded = projectile:GetAttribute("has_exploded")
				if hasExploded then
					return
				end
				
				projectile:SetAttribute("has_exploded", true)
				print("SERVER: AI Airburst immediate detonation!")
				
				-- Create custom explosion with vehicle filtering
				createExplosion(projectile.Position, explosionRadius, explosionDamage, armorPen, vehicleSeat.Parent)
				projectile:Destroy()
				
			elseif projectileAmmoType == "high_explosive" then
				-- High explosive rounds use armor penetration logic
				local hasExploded = projectile:GetAttribute("has_exploded")
				if hasExploded then
					return
				end
				
				if targetArmor > 0 and projectileArmorPen > targetArmor then
					-- Penetrated armor - delayed explosion
					local afterPenDelay = tonumber(projectile:GetAttribute("afterpen")) or 0.5
					print("SERVER: AI Explosive penetrated armor! Exploding in", afterPenDelay, "seconds")
					
					projectile:SetAttribute("has_exploded", true)
					spawn(function()
						wait(afterPenDelay)
						if projectile and projectile.Parent then
							-- Create custom explosion with vehicle filtering
							createExplosion(projectile.Position, explosionRadius, explosionDamage, armorPen, vehicleSeat.Parent)
							projectile:Destroy()
						end
					end)
				else
					-- Blocked by armor or immediate explosion
					projectile:SetAttribute("has_exploded", true)
					print("SERVER: AI Explosive immediate detonation!")
					
					-- Create custom explosion with vehicle filtering
					createExplosion(projectile.Position, explosionRadius, explosionDamage, armorPen, vehicleSeat.Parent)
					projectile:Destroy()
				end
			else
				-- Standard ammo - deal damage
				if projectileArmorPen > targetArmor then
					-- Penetrated - reduce health
					local currentHealth = tonumber(hit:GetAttribute("health")) or 100
					local newHealth = currentHealth - projectileDamage
					hit:SetAttribute("health", math.max(0, newHealth))
					print("SERVER: AI Projectile penetrated and dealt", projectileDamage, "damage. Health:", newHealth)
				else
					-- Blocked by armor
					print("SERVER: AI Projectile blocked by armor")
				end
				projectile:Destroy()
			end
		end)
		
		-- Auto-cleanup after 10 seconds
		game:GetService("Debris"):AddItem(projectile, 10)
		
		-- Record fire time for reload tracking
		lastFireTimes[turretId] = currentTime
	end
end

-- Main AI turret update function
local function updateAITurrets()
	for _, turretData in pairs(aiTurrets) do
		local vehicleSeat = turretData.vehicleSeat
		local airange = turretData.airange
		local chamber = turretData.chamber
		
		-- Check if components still exist
		if not vehicleSeat.Parent or not airange.Parent or not chamber.Parent then
			-- Remove invalid turret
			local turretId = tostring(vehicleSeat)
			aiTurrets[turretId] = nil
			lastFireTimes[turretId] = nil
			continue
		end
		
		-- Check if AI turret is still enabled
		if not vehicleSeat:GetAttribute("aiturret") then
			continue
		end
		
		-- Find targets in range
		local targets = findTargetsInRange(airange, vehicleSeat.Parent)
		
		if #targets > 0 then
			local closestTarget = targets[1]
			
			-- Calculate rotation to face target
			local targetRotation = calculateTargetRotation(vehicleSeat, chamber, closestTarget.part.Position)
			
			-- Apply rotation
			rotateTurret(vehicleSeat, targetRotation)
			
			-- Try to fire at target
			fireAtTarget(vehicleSeat, chamber, closestTarget)
		else
			-- No targets, stop rotation
			rotateTurret(vehicleSeat, Vector3.new(0, 0, 0))
		end
	end
end

-- Scan for AI turrets and register them
local function scanForAITurrets()
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("VehicleSeat") and obj:GetAttribute("aiturret") then
			local turretId = tostring(obj)
			
			-- Skip if already registered
			if aiTurrets[turretId] then
				continue
			end
			
			-- Find required components
			local airange = findAirange(obj)
			local chamber = findChamber(obj)
			
			if airange and chamber then
				-- Register AI turret
				aiTurrets[turretId] = {
					vehicleSeat = obj,
					airange = airange,
					chamber = chamber
				}
				
				print("SERVER: Registered AI Turret:", obj.Name, "with Airange:", airange.Name, "and Chamber:", chamber.Name)
			else
				if not airange then
					print("SERVER: AI Turret", obj.Name, "missing Airange part in parent model")
				end
				if not chamber then
					print("SERVER: AI Turret", obj.Name, "missing chamber part in parent model")
				end
			end
		end
	end
end

-- Initialize system
local lastScanTime = 0
local lastUpdateTime = 0

-- Main loop
RunService.Heartbeat:Connect(function()
	local currentTime = tick()
	
	-- Scan for new AI turrets every 5 seconds
	if currentTime - lastScanTime >= 5.0 then
		scanForAITurrets()
		lastScanTime = currentTime
	end
	
	-- Update AI turrets at specified interval
	if currentTime - lastUpdateTime >= AI_UPDATE_INTERVAL then
		updateAITurrets()
		lastUpdateTime = currentTime
	end
end)

-- Initial scan
scanForAITurrets()
