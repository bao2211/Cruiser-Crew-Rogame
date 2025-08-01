-- AI Turret System Server
-- Handles automatic target detection and firing for AI turrets
-- Requires VehicleSeat with aiturret=true and AIrange part in parent model

local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

print("SERVER: AI Turret System loaded")

-- Explosion cooldown system (same as WeaponSystem)
local explosionCooldowns = {}
local EXPLOSION_COOLDOWN_TIME = 0.1

-- Default Configuration (can be overridden by VehicleSeat attributes)
local DEFAULT_AI_UPDATE_INTERVAL = 0.05 -- Check for targets every 0.05 seconds (20 FPS for responsive targeting)
local DEFAULT_TRACKING_SPEED = 15 -- How fast turret tracks targets
local DEFAULT_TARGET_CACHE_TIME = 0.1 -- Reduced cache time for more responsive target detection
local DEFAULT_MAX_TARGET_DISTANCE = 200 -- Maximum distance to consider targets (optimization)

-- Helper function to get turret-specific configuration values
local function getTurretConfig(vehicleSeat)
	return {
		updateInterval = tonumber(vehicleSeat:GetAttribute("ai_update_interval")) or DEFAULT_AI_UPDATE_INTERVAL,
		trackingSpeed = tonumber(vehicleSeat:GetAttribute("tracking_speed")) or DEFAULT_TRACKING_SPEED,
		cacheTime = tonumber(vehicleSeat:GetAttribute("target_cache_time")) or DEFAULT_TARGET_CACHE_TIME,
		maxDistance = tonumber(vehicleSeat:GetAttribute("max_target_distance")) or DEFAULT_MAX_TARGET_DISTANCE,
	}
end

-- Storage for AI turret data
local aiTurrets = {}
local lastFireTimes = {} -- Track reload times per turret
local lastRocketFireTimes = {} -- Track rocket firing to prevent spam
local targetCache = {} -- Cache target search results
local lastTargetSearchTime = {} -- Track when each turret last searched for targets

-- Create explosion with visual effects and damage (same as WeaponSystem)
local function createExplosion(position, explosionRadius, explosionDamage, armorPen, firingVehicle, ammoType)
	-- Check explosion cooldown to prevent infinite explosions
	local positionKey = string.format("%.1f,%.1f,%.1f", position.X, position.Y, position.Z)
	local currentTime = tick()

	if
		explosionCooldowns[positionKey]
		and (currentTime - explosionCooldowns[positionKey]) < EXPLOSION_COOLDOWN_TIME
	then
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

	-- Set explosion color based on ammo type
	if ammoType == "airburst" then
		explosionSphere.BrickColor = BrickColor.new("Bright yellow")
	elseif ammoType == "rocket" then
		explosionSphere.BrickColor = BrickColor.new("Bright orange")
	else -- high_explosive and others
		explosionSphere.BrickColor = BrickColor.new("Bright red")
	end

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

	print(
		"SERVER: AI Explosion created at",
		position,
		"with radius",
		explosionRadius,
		"damage",
		explosionDamage,
		"armor pen",
		armorPen
	)

	-- Find all parts within explosion radius and apply damage
	for _, obj in
		pairs(
			workspace:GetPartBoundsInBox(
				CFrame.new(position),
				Vector3.new(explosionRadius * 2, explosionRadius * 2, explosionRadius * 2)
			)
		)
	do
		if obj:IsA("BasePart") and obj ~= explosionSphere then
			-- Skip the firing vehicle to prevent self-damage
			if not (firingVehicle and obj:IsDescendantOf(firingVehicle)) then
				-- Allow projectiles to be damaged, but exclude explosion spheres and AIrange parts
				if
					not (
						obj.Name == "ExplosionRadius"
						or obj.Name:find("Explosion")
						or obj.Name == "AIrange"
						or obj:GetAttribute("is_explosion_sphere")
					)
				then
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

							print(
								"SERVER: AI Explosion damaged",
								obj.Name,
								"for",
								math.floor(finalDamage),
								"damage (health:",
								newHealth,
								")"
							)

							-- If damaged part is a projectile, check if it should be destroyed
							if obj.Name:find("Projectile") and newHealth <= 0 then
								print("SERVER: Projectile", obj.Name, "destroyed by AI explosion!")
								-- Create small explosion effect for destroyed projectile
								local objAmmoType = obj:GetAttribute("ammotype") or "standard"
								if objAmmoType == "rocket" or objAmmoType == "high_explosive" then
									-- Explosive projectiles explode when destroyed
									local objExplosionRadius = tonumber(obj:GetAttribute("explosion_radius")) or 10
									local objExplosionDamage = tonumber(obj:GetAttribute("explosive_radius_damage"))
										or 25
									createExplosion(
										obj.Position,
										objExplosionRadius,
										objExplosionDamage,
										0,
										firingVehicle,
										objAmmoType
									)
								end
								obj:Destroy()
							end

							-- Create health bar
							local existingGui = obj:FindFirstChild("HealthBarGui")
							if existingGui then
								existingGui:Destroy()
							end

							if newHealth > 0 then
								local billboardGui = Instance.new("BillboardGui")
								billboardGui.Name = "HealthBarGui"
								billboardGui.Size = UDim2.fromScale(2, 0.5)
								billboardGui.StudsOffset = Vector3.new(0, obj.Size.Y / 2 + 1, 0)
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

-- Find AIrange part for a vehicle seat
local function findAirange(vehicleSeat)
	local parentModel = vehicleSeat.Parent
	if parentModel then
		for _, obj in pairs(parentModel:GetChildren()) do
			if obj:IsA("Part") and obj.Name == "AIrange" then
				return obj
			end
		end
	end
	return nil
end

-- Check if a part is a valid target (has health attribute and is not part of the turret's vehicle)
-- OPTIMIZED VERSION with improved player vehicle targeting
local function isValidTarget(part, turretVehicle)
	-- Quick type and existence checks first (cheapest operations)
	if not part:IsA("BasePart") then
		return false
	end

	-- Check for health attribute early
	local health = tonumber(part:GetAttribute("health"))
	if not health or health <= 0 then
		return false
	end

	-- Must not be part of the same vehicle (expensive check, do after health check)
	if part:IsDescendantOf(turretVehicle) then
		return false
	end

	-- Must not be explosion spheres or temporary objects
	if part.Name == "ExplosionRadius" or part:GetAttribute("is_explosion_sphere") then
		return false
	end

	-- Special case: Target rocket projectiles (high priority targets)
	if part.Name:find("Projectile") then
		local ammoType = part:GetAttribute("ammotype")
		if ammoType == "rocket" then
			-- Check if this rocket was fired by the same vehicle (avoid self-targeting)
			local firingVehicle = part:GetAttribute("firing_vehicle")
			if firingVehicle == tostring(turretVehicle) then
				return false -- This is our own rocket, don't target it
			end
			return true -- Rockets from other vehicles are high-priority targets
		else
			return false -- Filter out other projectiles (including our own non-rocket projectiles)
		end
	end

	-- Target VehicleSeats and Seats that have health (player vehicles)
	if part:IsA("Seat") or part:IsA("VehicleSeat") then
		-- Only target if it has health attribute (indicating it's a targetable vehicle part)
		if health and health > 0 then
			return true
		else
			return false
		end
	end

	-- Don't target player characters directly, but allow targeting their vehicles
	local character = part.Parent
	if character and character:FindFirstChild("Humanoid") then
		return false -- Skip player character parts
	end

	-- Target any other part with health that isn't filtered out above
	return true
end

-- Find targets within AIrange - OPTIMIZED VERSION with configurable settings
local function findTargetsInRange(airange, turretVehicle, turretId, config)
	local currentTime = tick()

	-- Use cached results if available and recent
	if
		targetCache[turretId]
		and lastTargetSearchTime[turretId]
		and (currentTime - lastTargetSearchTime[turretId]) < config.cacheTime
	then
		return targetCache[turretId]
	end

	local targets = {}
	local airangePosition = airange.Position
	local airangeSize = airange.Size

	-- Use spatial query with GetPartBoundsInBox for better performance
	local searchSize = Vector3.new(
		math.min(airangeSize.X, config.maxDistance),
		math.min(airangeSize.Y, config.maxDistance),
		math.min(airangeSize.Z, config.maxDistance)
	)

	-- Get parts in the region using spatial query
	local success, partsInRegion = pcall(function()
		return workspace:GetPartBoundsInBox(CFrame.new(airangePosition), searchSize)
	end)

	if success and partsInRegion then
		for _, obj in pairs(partsInRegion) do
			if isValidTarget(obj, turretVehicle) then
				local distance = (obj.Position - airangePosition).Magnitude

				-- Quick distance check first (cheaper than bounds check)
				if distance <= config.maxDistance then
					-- More precise bounds check only for nearby targets
					local relativePos = obj.Position - airangePosition
					if
						math.abs(relativePos.X) <= airangeSize.X / 2
						and math.abs(relativePos.Y) <= airangeSize.Y / 2
						and math.abs(relativePos.Z) <= airangeSize.Z / 2
					then
						table.insert(targets, { part = obj, distance = distance })
					end
				end
			end
		end
	else
		-- Fallback to reduced descendant search if spatial query fails
		-- Only search in nearby models instead of entire workspace
		local nearbyModels = {}
		for _, obj in pairs(workspace:GetChildren()) do
			if obj:IsA("Model") and obj ~= turretVehicle then
				local modelCenter = obj:GetPivot().Position
				local distance = (modelCenter - airangePosition).Magnitude
				if distance <= config.maxDistance * 1.5 then -- Slightly larger search for models
					table.insert(nearbyModels, obj)
				end
			end
		end

		-- Search only in nearby models
		for _, model in pairs(nearbyModels) do
			for _, obj in pairs(model:GetDescendants()) do
				if isValidTarget(obj, turretVehicle) then
					local distance = (obj.Position - airangePosition).Magnitude
					if distance <= config.maxDistance then
						local relativePos = obj.Position - airangePosition
						if
							math.abs(relativePos.X) <= airangeSize.X / 2
							and math.abs(relativePos.Y) <= airangeSize.Y / 2
							and math.abs(relativePos.Z) <= airangeSize.Z / 2
						then
							table.insert(targets, { part = obj, distance = distance })
							-- Break early if we find enough targets
							if #targets >= 10 then
								break
							end
						end
					end
				end
			end
			-- Break early if we find enough targets across all models
			if #targets >= 10 then
				break
			end
		end
	end

	-- Sort by priority: rockets first, then by distance
	table.sort(targets, function(a, b)
		local aIsRocket = a.part:GetAttribute("ammotype") == "rocket"
		local bIsRocket = b.part:GetAttribute("ammotype") == "rocket"

		-- Rockets have higher priority
		if aIsRocket and not bIsRocket then
			return true
		elseif not aIsRocket and bIsRocket then
			return false
		else
			-- Same priority, sort by distance
			return a.distance < b.distance
		end
	end)

	-- Debug output for targeting (comment out after testing)
	if #targets > 0 then
		print(
			"DEBUG: AI Turret found",
			#targets,
			"targets. Closest:",
			targets[1].part.Name,
			"at distance:",
			math.floor(targets[1].distance)
		)
	end

	-- Cache the results
	targetCache[turretId] = targets
	lastTargetSearchTime[turretId] = currentTime

	return targets
end

-- Calculate rotation needed to face target - IMPROVED WITH SMOOTH EASING and configurable speed
local function calculateTargetRotation(vehicleSeat, chamber, targetPosition, config)
	-- Use chamber position for more accurate targeting
	local chamberPosition = chamber.Position
	local direction = (targetPosition - chamberPosition).Unit
	local currentForward = vehicleSeat.CFrame.LookVector

	-- Calculate angular velocity needed
	local cross = currentForward:Cross(direction)
	local dot = currentForward:Dot(direction)

	-- Calculate the angle between current and target direction
	local angle = math.acos(math.clamp(dot, -1, 1))

	-- Add deadzone - if very close to target, don't rotate at all
	if angle < math.rad(2) then -- Within 2 degrees = no rotation needed
		return Vector3.new(0, 0, 0)
	end

	-- Apply smooth easing based on angle - closer to target = slower movement
	local easingFactor
	if angle < math.rad(5) then -- Very close (within 5 degrees)
		easingFactor = 0.1 -- Very slow
	elseif angle < math.rad(15) then -- Close (within 15 degrees)
		easingFactor = 0.3 -- Slow
	elseif angle < math.rad(45) then -- Medium distance (within 45 degrees)
		easingFactor = 0.6 -- Medium speed
	else -- Far (more than 45 degrees)
		easingFactor = 1.0 -- Full speed
	end

	-- Apply the easing to the tracking speed (now configurable per turret)
	local adjustedTrackingSpeed = config.trackingSpeed * easingFactor
	local targetAngularVelocity = cross * adjustedTrackingSpeed * (1 - dot)

	-- Limit pitch to prevent flipping
	local maxPitch = 1.5
	targetAngularVelocity = Vector3.new(
		math.clamp(targetAngularVelocity.X, -maxPitch, maxPitch),
		targetAngularVelocity.Y,
		0 -- No roll
	)

	return targetAngularVelocity
end

-- Apply rotation to turret - IMPROVED WITH DAMPING
local function rotateTurret(vehicleSeat, targetAngularVelocity)
	local bodyAngular = vehicleSeat:FindFirstChild("AITurretAngular")
	if not bodyAngular then
		bodyAngular = Instance.new("BodyAngularVelocity")
		bodyAngular.Name = "AITurretAngular"
		bodyAngular.Parent = vehicleSeat
	end

	-- Smooth interpolation between current and target angular velocity
	local currentAngularVelocity = bodyAngular.AngularVelocity
	local lerpFactor = 0.3 -- How quickly to blend to new velocity (0.1 = very smooth, 1.0 = instant)
	local smoothedAngularVelocity = currentAngularVelocity:lerp(targetAngularVelocity, lerpFactor)

	bodyAngular.AngularVelocity = smoothedAngularVelocity
	bodyAngular.MaxTorque = Vector3.new(math.huge, math.huge, 0)

	-- Reduced power for smoother movement (BodyAngularVelocity doesn't have D property)
	bodyAngular.P = 5000 -- Reduced from 10000 for smoother movement
end

-- Fire weapon at target with configurable distance checking
local function fireAtTarget(vehicleSeat, chamber, target, config)
	-- Use consistent unique turret ID format
	local parentName = vehicleSeat.Parent and vehicleSeat.Parent.Name or "NoParent"
	local position = vehicleSeat.Position
	local objString = tostring(vehicleSeat):gsub("[^%w]", "_")
	-- Round position to whole numbers to prevent drift from creating new IDs
	local posString = string.format("%.0f_%.0f_%.0f", position.X, position.Y, position.Z)
	local turretId = "Turret_" .. objString .. "_" .. parentName .. "_" .. posString
	local currentTime = tick()

	-- Check bullet count
	local currentBullets = tonumber(chamber:GetAttribute("bullet_count")) or 0
	if currentBullets <= 0 then
		-- Auto-reload for AI turrets
		if not chamber:GetAttribute("is_reloading") then
			local maxBullets = tonumber(chamber:GetAttribute("max_bullet_count")) or 10
			local reloadTime = tonumber(chamber:GetAttribute("reload")) or 2.0
			chamber:SetAttribute("is_reloading", true)
			print("SERVER: AI Turret auto-reloading - duration:", reloadTime, "seconds")

			spawn(function()
				wait(reloadTime)
				chamber:SetAttribute("bullet_count", maxBullets)
				chamber:SetAttribute("is_reloading", false)
				print("SERVER: AI Turret reload complete - bullets:", maxBullets)
			end)
		end
		return -- Don't fire while reloading
	end

	-- Check fire rate cooldown
	local baseFireRate = tonumber(chamber:GetAttribute("firerate")) or 1.0
	-- Faster fire rate when targeting rockets (anti-missile defense)
	local isTargetingRocket = target.part:GetAttribute("ammotype") == "rocket"
	local fireRate = isTargetingRocket and (baseFireRate * 3.0) or baseFireRate -- 3x faster for rockets
	local fireInterval = 1.0 / fireRate

	-- Check if turret is ready to fire (fire rate cooldown)
	if lastFireTimes[turretId] and (currentTime - lastFireTimes[turretId]) < fireInterval then
		return -- Still reloading
	end

	-- Additional cooldown for rocket ammo to prevent spam loops
	local chamberAmmoType = chamber:GetAttribute("ammotype") or "standard"
	if chamberAmmoType == "rocket" then
		local rocketCooldown = 1.0 -- Minimum 1 second between rocket fires
		if lastRocketFireTimes[turretId] and (currentTime - lastRocketFireTimes[turretId]) < rocketCooldown then
			return -- Prevent rocket spam
		end
	end

	-- Use faster fire rate when targeting rockets (anti-missile defense) - handled in fireRate calculation above

	-- Re-validate that target is still valid and in range before firing
	local airange = vehicleSeat.Parent:FindFirstChild("AIrange")
	if not airange or not isValidTarget(target.part, vehicleSeat.Parent) then
		return
	end

	-- Quick distance check before expensive bounds check (using configurable max distance)
	local airangePosition = airange.Position
	local targetDistance = (target.part.Position - airangePosition).Magnitude
	if targetDistance > config.maxDistance then
		return
	end

	-- Check if target is still within AIrange bounds
	local airangeSize = airange.Size
	local relativePos = target.part.Position - airangePosition
	if
		not (
			math.abs(relativePos.X) <= airangeSize.X / 2
			and math.abs(relativePos.Y) <= airangeSize.Y / 2
			and math.abs(relativePos.Z) <= airangeSize.Z / 2
		)
	then
		return
	end

	-- Check if chamber is facing the target (within reasonable angle)
	local chamberForward = vehicleSeat.CFrame.LookVector
	local targetDirection = (target.part.Position - chamber.Position).Unit
	local dot = chamberForward:Dot(targetDirection)

	-- Only fire if chamber is roughly facing the target (more lenient tolerance for smoother rotation)
	if dot > 0.9 then -- Increased from 0.95 to 0.9 (~25 degree tolerance instead of ~18 degrees)
		-- Get firing direction and position from chamber
		local fireDirection
		local firePosition = chamber.Position

		-- Use predictive targeting for fast-moving rockets
		if isTargetingRocket and target.part:FindFirstChild("BodyVelocity") then
			local rocketVelocity = target.part.BodyVelocity.Velocity
			local projectileSpeed = tonumber(chamber:GetAttribute("projectile_speed")) or 100
			local timeToTarget = target.distance / projectileSpeed
			local predictedPosition = target.part.Position + (rocketVelocity * timeToTarget)
			fireDirection = (predictedPosition - firePosition).Unit
		else
			-- Standard direct targeting
			fireDirection = targetDirection
		end

		-- Fire the weapon directly for AI turret

		-- Get chamber attributes
		local ammoType = chamber:GetAttribute("ammotype") or "standard"
		local armorPen = tonumber(chamber:GetAttribute("armor_pen")) or 10
		local damage = tonumber(chamber:GetAttribute("damage")) or 25
		local afterPen = tonumber(chamber:GetAttribute("afterpen")) or 0.5
		local explosionRadius = tonumber(chamber:GetAttribute("explosion_radius")) or 20
		local explosionDamage = tonumber(chamber:GetAttribute("explosive_radius_damage")) or 50
		local projectileHealth = tonumber(chamber:GetAttribute("projectile_health")) or 50
		local projectileSpeed = tonumber(chamber:GetAttribute("projectile_speed")) or 100

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
		elseif ammoType == "airburst" then
			projectile.BrickColor = BrickColor.new("Bright yellow")
		elseif ammoType == "rocket" then
			projectile.BrickColor = BrickColor.new("Bright orange")
			projectile.Size = Vector3.new(0.8, 0.8, 3) -- Larger rocket size
			projectile.Name = "AIRocketProjectile" -- Specific name for AI rockets
		else -- standard
			projectile.BrickColor = BrickColor.new("Dark stone grey")
		end

		-- Store attributes in projectile
		projectile:SetAttribute("ammotype", ammoType)
		projectile:SetAttribute("armor_pen", armorPen)
		projectile:SetAttribute("damage", damage)
		projectile:SetAttribute("afterpen", afterPen)
		projectile:SetAttribute("explosion_radius", explosionRadius)
		projectile:SetAttribute("explosive_radius_damage", explosionDamage)
		projectile:SetAttribute("health", projectileHealth) -- AI projectiles can be damaged and destroyed
		projectile:SetAttribute("has_exploded", false)
		projectile:SetAttribute("firing_vehicle", tostring(vehicleSeat.Parent)) -- Mark which vehicle fired this

		-- Add airburst-specific attributes
		if ammoType == "airburst" then
			local airburstTime = tonumber(chamber:GetAttribute("airburst_time")) or 2.0
			local detectRange = tonumber(chamber:GetAttribute("detect_range")) or 15
			projectile:SetAttribute("airburst_time", airburstTime)
			projectile:SetAttribute("detect_range", detectRange)
		end

		-- Play firing sound
		local firingSound = Instance.new("Sound")
		firingSound.SoundId = "rbxasset://sounds/impact_water.mp3"
		firingSound.Volume = 0.8
		firingSound.Pitch = 1.2
		firingSound.Parent = chamber
		firingSound:Play()
		Debris:AddItem(firingSound, 3)

		print("SERVER: AI Turret fired", ammoType, "round at", target.part.Name)

		-- Consume one bullet and update fire time
		chamber:SetAttribute("bullet_count", currentBullets - 1)
		lastFireTimes[turretId] = currentTime

		-- Track rocket firing specifically to prevent spam
		if ammoType == "rocket" then
			lastRocketFireTimes[turretId] = currentTime
		end

		-- Add velocity
		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		bodyVelocity.Velocity = fireDirection * projectileSpeed
		bodyVelocity.Parent = projectile

		-- AI Rocket guidance system for rocket ammo type
		if ammoType == "rocket" then
			local airburstTime = tonumber(chamber:GetAttribute("airburst_time")) or 2.0

			-- Rocket guidance and explosion timer
			spawn(function()
				local startTime = tick()

				while projectile and projectile.Parent do
					wait(0.05) -- Update guidance 20 times per second

					-- Check if airburst time has elapsed
					if tick() - startTime >= airburstTime then
						local hasExploded = projectile:GetAttribute("has_exploded")
						if not hasExploded then
							projectile:SetAttribute("has_exploded", true)
							print("SERVER: AI Rocket airburst timer detonation!")
							createExplosion(
								projectile.Position,
								explosionRadius,
								explosionDamage,
								armorPen,
								vehicleSeat.Parent,
								ammoType
							)
							projectile:Destroy()
							break
						end
					end

					-- Update rocket guidance to track current target
					if target and target.part and target.part.Parent then
						local targetPosition = target.part.Position
						local currentPosition = projectile.Position
						local directionToTarget = (targetPosition - currentPosition).Unit

						-- Smooth guidance - blend current direction with target direction
						local currentDirection = bodyVelocity.Velocity.Unit
						local guidanceStrength = 0.3 -- How aggressively rockets turn (0.1 = gentle, 1.0 = instant)
						local newDirection = (currentDirection + directionToTarget * guidanceStrength).Unit

						-- Update velocity to guide toward target
						bodyVelocity.Velocity = newDirection * projectileSpeed
					end
				end
			end)
		end

		-- Add airburst timer if needed
		if ammoType == "airburst" then
			local airburstTime = projectile:GetAttribute("airburst_time") or 2.0
			spawn(function()
				wait(airburstTime)
				if projectile and projectile.Parent and not projectile:GetAttribute("has_exploded") then
					projectile:SetAttribute("has_exploded", true)
					print("SERVER: AI Airburst timer detonation!")
					createExplosion(
						projectile.Position,
						explosionRadius,
						explosionDamage,
						armorPen,
						vehicleSeat.Parent,
						"airburst"
					)
					projectile:Destroy()
				end
			end)

			-- Add proximity detection for airburst (with small delay to avoid immediate explosion)
			local detectRange = projectile:GetAttribute("detect_range") or 15
			spawn(function()
				wait(0.2) -- Small delay to let projectile travel away from firing chamber
				while projectile and projectile.Parent and not projectile:GetAttribute("has_exploded") do
					wait(0.1)

					-- Use spatial query for better performance
					local success, nearbyParts = pcall(function()
						return workspace:GetPartBoundsInBox(
							projectile.CFrame,
							Vector3.new(detectRange * 2, detectRange * 2, detectRange * 2)
						)
					end)

					if success and nearbyParts then
						for _, obj in pairs(nearbyParts) do
							if
								obj:IsA("BasePart")
								and obj ~= projectile
								and not obj:IsDescendantOf(vehicleSeat.Parent)
							then
								-- Filter out invalid targets for airburst proximity
								if
									obj:GetAttribute("health")
									and not obj.Name:find("Projectile")
									and obj.Name ~= "AIrange"
									and obj.Name ~= "ExplosionRadius"
									and not obj:GetAttribute("is_explosion_sphere")
								then
									projectile:SetAttribute("has_exploded", true)
									createExplosion(
										projectile.Position,
										explosionRadius,
										explosionDamage,
										armorPen,
										vehicleSeat.Parent,
										"airburst"
									)
									projectile:Destroy()
									return
								end
							end
						end
					end
				end
			end)
		end

		-- Add collision detection
		projectile.Touched:Connect(function(hit)
			-- Ignore the firing vehicle
			if hit:IsDescendantOf(vehicleSeat.Parent) then
				return
			end

			-- Ignore explosion spheres but allow projectile-on-projectile damage
			if hit.Name == "ExplosionRadius" or hit:GetAttribute("is_explosion_sphere") then
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
				createExplosion(
					projectile.Position,
					explosionRadius,
					explosionDamage,
					armorPen,
					vehicleSeat.Parent,
					projectileAmmoType
				)
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
							createExplosion(
								projectile.Position,
								explosionRadius,
								explosionDamage,
								armorPen,
								vehicleSeat.Parent,
								projectileAmmoType
							)
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
			elseif projectileAmmoType == "rocket" then
				-- Rocket rounds always explode on contact
				local hasExploded = projectile:GetAttribute("has_exploded")
				if hasExploded then
					return
				end

				projectile:SetAttribute("has_exploded", true)
				print("SERVER: AI Rocket impact detonation!")

				-- Create custom explosion with vehicle filtering
				createExplosion(
					projectile.Position,
					explosionRadius,
					explosionDamage,
					armorPen,
					vehicleSeat.Parent,
					projectileAmmoType
				)
				projectile:Destroy()
			else
				-- Standard ammo - deal damage
				if projectileArmorPen > targetArmor then
					-- Penetrated - reduce health
					local currentHealth = tonumber(hit:GetAttribute("health")) or 100
					local newHealth = currentHealth - projectileDamage
					hit:SetAttribute("health", math.max(0, newHealth))
					print("SERVER: AI Projectile penetrated and dealt", projectileDamage, "damage. Health:", newHealth)

					-- If hit part is a projectile, check if it should be destroyed
					if hit.Name:find("Projectile") and newHealth <= 0 then
						print("SERVER: Projectile", hit.Name, "destroyed by AI turret!")
						-- Create small explosion effect for destroyed projectile
						local hitAmmoType = hit:GetAttribute("ammotype") or "standard"
						if hitAmmoType == "rocket" or hitAmmoType == "high_explosive" then
							-- Explosive projectiles explode when destroyed
							local hitExplosionRadius = tonumber(hit:GetAttribute("explosion_radius")) or 10
							local hitExplosionDamage = tonumber(hit:GetAttribute("explosive_radius_damage")) or 25
							createExplosion(
								hit.Position,
								hitExplosionRadius,
								hitExplosionDamage,
								0,
								vehicleSeat.Parent,
								hitAmmoType
							)
						end
						hit:Destroy()
					end
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

-- Main AI turret update function - OPTIMIZED VERSION with configurable settings
local function updateAITurrets()
	local processedTurrets = 0
	local activeTurrets = 0
	
	for turretId, turretData in pairs(aiTurrets) do
		processedTurrets = processedTurrets + 1
		local vehicleSeat = turretData.vehicleSeat
		local airange = turretData.airange
		local chamber = turretData.chamber

		-- Check if components still exist
		if not vehicleSeat.Parent or not airange.Parent or not chamber.Parent then
			-- Remove invalid turret and clean up cache
			print("DEBUG: Removing invalid turret:", vehicleSeat.Name)
			aiTurrets[turretId] = nil
			lastFireTimes[turretId] = nil
			lastRocketFireTimes[turretId] = nil
			targetCache[turretId] = nil
			lastTargetSearchTime[turretId] = nil
			continue
		end

		-- Check if AI turret is still enabled
		if not vehicleSeat:GetAttribute("aiturret") then
			-- Stop rotation for disabled turrets
			rotateTurret(vehicleSeat, Vector3.new(0, 0, 0))
			continue
		end

		-- Check if turret is reloading - skip expensive target search if it can't fire anyway
		if chamber:GetAttribute("is_reloading") then
			continue
		end

		activeTurrets = activeTurrets + 1

		-- Get turret-specific configuration
		local config = getTurretConfig(vehicleSeat)

		-- Find targets in range (now uses caching and optimized search)
		local targets = findTargetsInRange(airange, vehicleSeat.Parent, turretId, config)

		if #targets > 0 then
			local closestTarget = targets[1]

			-- Calculate rotation to face target
			local targetRotation = calculateTargetRotation(vehicleSeat, chamber, closestTarget.part.Position, config)

			-- Apply rotation
			rotateTurret(vehicleSeat, targetRotation)

			-- Try to fire at target
			fireAtTarget(vehicleSeat, chamber, closestTarget, config)
		else
			-- No targets, stop rotation
			rotateTurret(vehicleSeat, Vector3.new(0, 0, 0))
		end
	end
	
	-- Debug output every 100 updates (about every 5 seconds at 20 FPS)
	if math.random(1, 100) == 1 then
		print("DEBUG: Processed", processedTurrets, "turrets,", activeTurrets, "active")
	end
end

-- Scan for AI turrets and register them
local function scanForAITurrets()
	local scannedCount = 0
	local validCount = 0
	local invalidCount = 0
	
	-- First, clean up invalid registrations (turrets that no longer exist or moved)
	local toRemove = {}
	for turretId, turretData in pairs(aiTurrets) do
		local vehicleSeat = turretData.vehicleSeat
		if not vehicleSeat.Parent or not vehicleSeat:GetAttribute("aiturret") then
			-- Turret no longer exists or no longer has aiturret=true
			table.insert(toRemove, turretId)
		else
			-- Check if position-based ID still matches (in case turret moved significantly)
			local parentName = vehicleSeat.Parent and vehicleSeat.Parent.Name or "NoParent"
			local position = vehicleSeat.Position
			local objString = tostring(vehicleSeat):gsub("[^%w]", "_")
			local posString = string.format("%.0f_%.0f_%.0f", position.X, position.Y, position.Z)
			local currentId = "Turret_" .. objString .. "_" .. parentName .. "_" .. posString
			
			if currentId ~= turretId then
				-- Turret moved significantly, remove old registration
				table.insert(toRemove, turretId)
			end
		end
	end
	
	-- Remove invalid registrations
	for _, turretId in pairs(toRemove) do
		print("DEBUG: Cleaning up invalid turret registration:", turretId)
		aiTurrets[turretId] = nil
		lastFireTimes[turretId] = nil
		lastRocketFireTimes[turretId] = nil
		targetCache[turretId] = nil
		lastTargetSearchTime[turretId] = nil
	end
	
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("VehicleSeat") and obj:GetAttribute("aiturret") then
			scannedCount = scannedCount + 1
			
			-- Create truly unique turret ID using multiple unique factors
			local parentName = obj.Parent and obj.Parent.Name or "NoParent"
			local position = obj.Position
			local objString = tostring(obj):gsub("[^%w]", "_")
			-- Round position to whole numbers to prevent drift from creating new IDs
			local posString = string.format("%.0f_%.0f_%.0f", position.X, position.Y, position.Z)
			local turretId = "Turret_" .. objString .. "_" .. parentName .. "_" .. posString

			-- Debug: Show what we're scanning
			print("DEBUG: Found VehicleSeat with aiturret=true:", obj.Name, "Parent:", parentName, "ID:", turretId)

			-- Skip if already registered
			if aiTurrets[turretId] then
				print("DEBUG: Skipping - already registered")
				continue
			end

			-- Find required components
			local airange = findAirange(obj)
			local chamber = findChamber(obj)

			if airange and chamber then
				validCount = validCount + 1
				-- Register AI turret
				aiTurrets[turretId] = {
					vehicleSeat = obj,
					airange = airange,
					chamber = chamber,
				}

				print(
					"SERVER: Registered AI Turret:",
					obj.Name,
					"in model:",
					obj.Parent and obj.Parent.Name or "None",
					"with AIrange:",
					airange.Name,
					"and Chamber:",
					chamber.Name,
					"ID:",
					turretId
				)
			else
				invalidCount = invalidCount + 1
				if not airange then
					print("SERVER: VehicleSeat", obj.Name, "in", obj.Parent and obj.Parent.Name or "None", "has aiturret=true but missing AIrange part")
				end
				if not chamber then
					print("SERVER: VehicleSeat", obj.Name, "in", obj.Parent and obj.Parent.Name or "None", "has aiturret=true but missing chamber part")
				end
			end
		end
	end
	
	-- Debug: Show scan summary
	print("DEBUG: Scan complete - Found", scannedCount, "VehicleSeats with aiturret=true")
	print("DEBUG: Valid turrets:", validCount, "Invalid turrets:", invalidCount)
	
	-- Debug: Show total registered turrets
	local turretCount = 0
	for turretId, turretData in pairs(aiTurrets) do
		turretCount = turretCount + 1
		print("DEBUG: Registered turret ID:", turretId, "- VehicleSeat:", turretData.vehicleSeat.Name, "in model:", turretData.vehicleSeat.Parent and turretData.vehicleSeat.Parent.Name or "None")
	end
	print("DEBUG: Total AI turrets registered:", turretCount)
end

-- Initialize system
local lastScanTime = 0
local lastUpdateTime = 0
local lastCacheCleanTime = 0

-- Cleanup function to prevent memory leaks
local function cleanupCaches()
	-- Clean up target cache for non-existent turrets
	for turretId in pairs(targetCache) do
		if not aiTurrets[turretId] then
			targetCache[turretId] = nil
			lastTargetSearchTime[turretId] = nil
		end
	end

	-- Clean up old fire times
	for turretId in pairs(lastFireTimes) do
		if not aiTurrets[turretId] then
			lastFireTimes[turretId] = nil
		end
	end

	-- Clean up old rocket fire times
	for turretId in pairs(lastRocketFireTimes) do
		if not aiTurrets[turretId] then
			lastRocketFireTimes[turretId] = nil
		end
	end
end

-- Main loop - OPTIMIZED VERSION with adaptive timing
RunService.Heartbeat:Connect(function()
	local currentTime = tick()

	-- Scan for new AI turrets every 2 seconds (more frequent for better responsiveness)
	if currentTime - lastScanTime >= 2.0 then
		scanForAITurrets()
		lastScanTime = currentTime
	end

	-- Clean up caches every 30 seconds
	if currentTime - lastCacheCleanTime >= 30.0 then
		cleanupCaches()
		lastCacheCleanTime = currentTime
	end

	-- Adaptive update interval based on number of turrets
	local numTurrets = 0
	for _ in pairs(aiTurrets) do
		numTurrets = numTurrets + 1
	end

	-- Adjust update interval based on load (more responsive but still scalable)
	local dynamicInterval = DEFAULT_AI_UPDATE_INTERVAL
	if numTurrets > 15 then
		dynamicInterval = DEFAULT_AI_UPDATE_INTERVAL * 1.5 -- Slow down if many turrets
	elseif numTurrets > 30 then
		dynamicInterval = DEFAULT_AI_UPDATE_INTERVAL * 2.0 -- Slow down more for very many turrets
	end

	-- Update AI turrets at adjusted interval
	if currentTime - lastUpdateTime >= dynamicInterval then
		updateAITurrets()
		lastUpdateTime = currentTime
	end
end)

-- Initial scan
scanForAITurrets()
