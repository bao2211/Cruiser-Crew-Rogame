-- Weapon System Server (Clean Version with Rocket Support)
-- Handles weapon firing, projectile creation, and ballistics
-- Self-contained system for all weapon-related functionality

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for RemoteEvents (created by main server)
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local fireWeaponEvent = remoteEvents:WaitForChild("FireWeapon")
local weaponFireConfirmEvent = remoteEvents:WaitForChild("WeaponFireConfirm")

-- Create rocket guidance RemoteEvent if it doesn't exist
local rocketGuidanceEvent = remoteEvents:FindFirstChild("RocketGuidance")
if not rocketGuidanceEvent then
	rocketGuidanceEvent = Instance.new("RemoteEvent")
	rocketGuidanceEvent.Name = "RocketGuidance"
	rocketGuidanceEvent.Parent = remoteEvents
end

-- Create reload RemoteEvent if it doesn't exist
local reloadWeaponEvent = remoteEvents:FindFirstChild("ReloadWeapon")
if not reloadWeaponEvent then
	reloadWeaponEvent = Instance.new("RemoteEvent")
	reloadWeaponEvent.Name = "ReloadWeapon"
	reloadWeaponEvent.Parent = remoteEvents
end

print("SERVER: Weapon System loaded")

-- Explosion cooldown system to prevent infinite explosions
local explosionCooldowns = {}
local EXPLOSION_COOLDOWN_TIME = 0.5

-- Reload cooldown system for player weapons
local reloadCooldowns = {}

-- Active rockets tracking for guidance
local activeRockets = {}

-- Create sound effect
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

-- Create explosion with visual effects and damage
local function createExplosion(position, explosionRadius, explosionDamage, armorPen)
	-- Check explosion cooldown to prevent infinite explosions
	local positionKey = string.format("%.1f,%.1f,%.1f", position.X, position.Y, position.Z)
	local currentTime = tick()

	if
		explosionCooldowns[positionKey]
		and (currentTime - explosionCooldowns[positionKey]) < EXPLOSION_COOLDOWN_TIME
	then
		print("SERVER: Explosion blocked by cooldown at", position)
		return
	end

	explosionCooldowns[positionKey] = currentTime

	-- Clean up old cooldown entries to prevent memory buildup
	for key, time in pairs(explosionCooldowns) do
		if (currentTime - time) > 10 then
			explosionCooldowns[key] = nil
		end
	end

	print("SERVER: Creating explosion at", position, "radius:", explosionRadius, "damage:", explosionDamage)

	-- Create visual explosion sphere
	local explosionSphere = Instance.new("Part")
	explosionSphere.Name = "ExplosionRadius"
	explosionSphere.Shape = Enum.PartType.Ball
	explosionSphere.Material = Enum.Material.Neon
	explosionSphere.BrickColor = BrickColor.new("Bright orange")
	explosionSphere.Size = Vector3.new(explosionRadius * 2, explosionRadius * 2, explosionRadius * 2)
	explosionSphere.Position = position
	explosionSphere.Anchored = true
	explosionSphere.CanCollide = false
	explosionSphere.Transparency = 0.3
	explosionSphere:SetAttribute("is_explosion_sphere", true)
	explosionSphere.Parent = workspace

	-- Animate explosion sphere
	local tween = game:GetService("TweenService"):Create(
		explosionSphere,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Transparency = 1, Size = Vector3.new(explosionRadius * 4, explosionRadius * 4, explosionRadius * 4) }
	)
	tween:Play()

	-- Clean up explosion sphere
	game:GetService("Debris"):AddItem(explosionSphere, 0.6)

	-- Create explosion sound (using part destruction sound)
	createSound(explosionSphere, "rbxasset://sounds/impact_water.mp3", 0.8, 0.6)

	-- Damage all parts within explosion radius
	for _, obj in
		pairs(
			workspace:GetPartBoundsInBox(
				CFrame.new(position),
				Vector3.new(explosionRadius * 2, explosionRadius * 2, explosionRadius * 2)
			)
		)
	do
		if obj:IsA("BasePart") and obj ~= explosionSphere then
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
					-- Calculate damage based on distance (closer = more damage)
					local distanceFactor = math.max(0.2, 1 - (distance / explosionRadius))
					local actualDamage = explosionDamage * distanceFactor

					local currentHealth = tonumber(obj:GetAttribute("health")) or 100
					local newHealth = math.max(0, currentHealth - actualDamage)
					obj:SetAttribute("health", newHealth)

					print("SERVER: Explosion damaged", obj.Name, "for", actualDamage, "health:", newHealth)

					-- If damaged part is a projectile, check if it should be destroyed
					if obj.Name:find("Projectile") and newHealth <= 0 then
						print("SERVER: Projectile", obj.Name, "destroyed by explosion!")

						-- Clean up rocket from active tracking if it's a rocket
						local objAmmoType = obj:GetAttribute("ammotype") or "standard"
						if objAmmoType == "rocket" then
							local rocketId = tostring(obj)
							if activeRockets[rocketId] then
								activeRockets[rocketId] = nil
								print("SERVER: Cleaned up destroyed rocket from tracking:", rocketId)
							end
						end

						-- Create small explosion effect for destroyed projectile
						if objAmmoType == "rocket" or objAmmoType == "high_explosive" then
							-- Explosive projectiles explode when destroyed
							local objExplosionRadius = tonumber(obj:GetAttribute("explosion_radius")) or 10
							local objExplosionDamage = tonumber(obj:GetAttribute("explosive_radius_damage")) or 25
							createExplosion(obj.Position, objExplosionRadius, objExplosionDamage, 0)
						end
						obj:Destroy()
					-- Skip health bar creation for this destroyed projectile, but continue processing other parts
					else
						-- Create health bar (same as direct damage)
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

							-- Auto-remove health bar after 3 seconds
							game:GetService("Debris"):AddItem(billboardGui, 3)
						else
							-- Part destroyed
							obj:SetAttribute("being_destroyed", true)

							-- Fade out and destroy
							local originalTransparency = obj.Transparency
							local fadeTime = 2.0
							local startTime = tick()

							local fadeConnection
							fadeConnection = game:GetService("RunService").Heartbeat:Connect(function()
								local elapsed = tick() - startTime
								local progress = elapsed / fadeTime

								if progress >= 1 then
									fadeConnection:Disconnect()
									obj:Destroy()
									print("SERVER: Part", obj.Name, "destroyed by explosion")
								else
									obj.Transparency = originalTransparency + (1 - originalTransparency) * progress
								end
							end)
						end
					end
				end
			end
		end
	end
end

-- Main weapon firing function
local function fireCannon(player, vehicleSeat, chamber)
	-- Validate player is in the seat
	if not vehicleSeat.Occupant or vehicleSeat.Occupant.Parent ~= player.Character then
		print("SERVER: Fire request denied - player not in seat")
		return
	end

	-- Check fire rate cooldown
	local playerId = tostring(player.UserId)
	local currentTime = tick()
	local fireRate = tonumber(chamber:GetAttribute("firerate")) or 1.0
	local fireInterval = 1.0 / fireRate -- Convert fire rate to time between shots

	if reloadCooldowns[playerId] and (currentTime - reloadCooldowns[playerId]) < fireInterval then
		local remainingTime = fireInterval - (currentTime - reloadCooldowns[playerId])
		print("SERVER: Fire rate cooldown active for", player.Name, "- remaining:", remainingTime, "seconds")
		return
	end

	-- Check bullet count
	local currentBullets = tonumber(chamber:GetAttribute("bullet_count")) or 0
	if currentBullets <= 0 then
		print("SERVER: No ammo remaining for", player.Name, "- need to reload")
		return
	end

	-- Consume one bullet
	chamber:SetAttribute("bullet_count", currentBullets - 1)
	print("SERVER: Bullets remaining:", currentBullets - 1)

	-- Set fire rate cooldown
	reloadCooldowns[playerId] = currentTime

	-- Get chamber attributes
	local ammoType = chamber:GetAttribute("ammotype") or "standard"
	local armorPen = tonumber(chamber:GetAttribute("armor_pen")) or 10
	local damage = tonumber(chamber:GetAttribute("damage")) or 25
	local afterPen = tonumber(chamber:GetAttribute("afterpen")) or 0.5
	local airburstTime = tonumber(chamber:GetAttribute("airburst_time")) or 2.0
	local detectRange = tonumber(chamber:GetAttribute("detect_range")) or 15
	local explosionRadius = tonumber(chamber:GetAttribute("explosion_radius")) or 20
	local explosionDamage = tonumber(chamber:GetAttribute("explosive_radius_damage")) or 50
	local projectileSpeed = tonumber(chamber:GetAttribute("projectile_speed")) or 100
	local projectileHealth = tonumber(chamber:GetAttribute("projectile_health")) or 50

	-- Get firing direction and position
	local fireDirection = vehicleSeat.CFrame.LookVector
	local firePosition = chamber.Position

	print("SERVER: Cannon fired by", player.Name, "from", chamber.Name, "in direction", fireDirection)

	-- Confirm weapon firing to client for sound effects
	weaponFireConfirmEvent:FireClient(player, vehicleSeat, chamber, ammoType)

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

		-- Set projectile appearance based on ammo type
		if ammoType == "high_explosive" then
			projectile.BrickColor = BrickColor.new("Bright red")
			projectile.Name = "ExplosiveProjectile"
		elseif ammoType == "airburst" then
			projectile.BrickColor = BrickColor.new("Bright yellow")
			projectile.Name = "AirburstProjectile"
		elseif ammoType == "rocket" then
			projectile.BrickColor = BrickColor.new("Bright orange")
			projectile.Name = "RocketProjectile"
			projectile.Size = Vector3.new(0.8, 0.8, 3) -- Larger rocket
		else
			projectile.BrickColor = BrickColor.new("Dark stone grey")
		end

		-- Store attributes in projectile
		projectile:SetAttribute("ammotype", ammoType)
		projectile:SetAttribute("armor_pen", armorPen)
		projectile:SetAttribute("damage", damage)
		projectile:SetAttribute("afterpen", afterPen)
		projectile:SetAttribute("airburst_time", airburstTime)
		projectile:SetAttribute("detect_range", detectRange)
		projectile:SetAttribute("health", projectileHealth) -- Projectiles can be damaged and destroyed
		projectile:SetAttribute("has_exploded", false)
		projectile:SetAttribute("firing_vehicle", tostring(vehicleSeat.Parent)) -- Track which vehicle fired this projectile

		-- Add velocity (use projectile_speed attribute)
		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		bodyVelocity.Velocity = fireDirection * projectileSpeed
		bodyVelocity.Parent = projectile

		-- Airburst timer for airburst rounds
		if ammoType == "airburst" then
			spawn(function()
				wait(airburstTime)
				if projectile and projectile.Parent then
					local hasExploded = projectile:GetAttribute("has_exploded")
					if not hasExploded then
						projectile:SetAttribute("has_exploded", true)
						print("SERVER: Airburst timer detonation!")
						createExplosion(projectile.Position, explosionRadius, explosionDamage, armorPen)
						projectile:Destroy()
					end
				end
			end)

			-- Proximity detection for airburst rounds
			spawn(function()
				while projectile and projectile.Parent do
					wait(0.1)

					local projectileDetectRange = tonumber(projectile:GetAttribute("detect_range")) or 15
					local nearbyParts = {}
					local searchSize =
						Vector3.new(projectileDetectRange * 2, projectileDetectRange * 2, projectileDetectRange * 2)
					for _, obj in pairs(workspace:GetPartBoundsInBox(projectile.CFrame, searchSize)) do
						if obj ~= projectile and not obj:IsDescendantOf(vehicleSeat.Parent) then
							if
								not (
									obj.Name:find("Projectile")
									or obj.Name == "ExplosionRadius"
									or obj.Name == "AIrange"
								)
							then
								local distance = (obj.Position - projectile.Position).Magnitude
								if distance <= projectileDetectRange then
									local hasExploded = projectile:GetAttribute("has_exploded")
									if not hasExploded then
										projectile:SetAttribute("has_exploded", true)
										print("SERVER: Airburst proximity detonation!")
										createExplosion(projectile.Position, explosionRadius, explosionDamage, armorPen)
										projectile:Destroy()
										break
									end
								end
							end
						end
					end
				end
			end)
		end

		-- Rocket guidance system for rocket ammo type
		if ammoType == "rocket" then
			-- Store rocket in active tracking
			local rocketId = tostring(projectile)
			activeRockets[rocketId] = {
				projectile = projectile,
				bodyVelocity = bodyVelocity,
				player = player,
				projectileSpeed = projectileSpeed,
				targetPosition = nil,
				startTime = tick(),
				airburstTime = airburstTime,
				explosionRadius = explosionRadius,
				explosionDamage = explosionDamage,
				armorPen = armorPen,
			}

			-- Request initial target from client
			rocketGuidanceEvent:FireClient(player, "request_target", rocketId)

			-- Rocket guidance and explosion timer
			spawn(function()
				local rocketData = activeRockets[rocketId]
				if not rocketData then
					return
				end

				while projectile and projectile.Parent and activeRockets[rocketId] do
					wait(0.05) -- Update guidance 20 times per second

					rocketData = activeRockets[rocketId]
					if not rocketData then
						break
					end

					-- Check if airburst time has elapsed
					if tick() - rocketData.startTime >= rocketData.airburstTime then
						local hasExploded = projectile:GetAttribute("has_exploded")
						if not hasExploded then
							projectile:SetAttribute("has_exploded", true)
							print("SERVER: Rocket airburst timer detonation!")
							-- Play rocket timer explosion sound
							createSound(projectile, "rbxasset://sounds/impact_water.mp3", 0.8, 1.2)
							createExplosion(
								projectile.Position,
								rocketData.explosionRadius,
								rocketData.explosionDamage,
								rocketData.armorPen
							)
							activeRockets[rocketId] = nil
							projectile:Destroy()
							break
						end
					end

					-- Apply guidance if target position is available
					if rocketData.targetPosition then
						local currentPosition = projectile.Position
						local direction = (rocketData.targetPosition - currentPosition).Unit

						-- Update rocket direction (gentle guidance, not instant)
						local currentVelocity = rocketData.bodyVelocity.Velocity
						local targetVelocity = direction * rocketData.projectileSpeed
						local newVelocity = currentVelocity:lerp(targetVelocity, 0.15) -- 15% guidance strength

						rocketData.bodyVelocity.Velocity = newVelocity
						projectile.CFrame = CFrame.lookAt(projectile.Position, projectile.Position + newVelocity.Unit)
					end
				end

				-- Clean up when rocket is destroyed
				activeRockets[rocketId] = nil
			end)
		end

		-- Collision detection
		local connection
		connection = projectile.Touched:Connect(function(hit)
			-- Ignore the firing vehicle
			if hit:IsDescendantOf(vehicleSeat.Parent) then
				return
			end

			-- Ignore explosion spheres but allow projectile-on-projectile damage
			if hit.Name == "ExplosionRadius" or hit:GetAttribute("is_explosion_sphere") then
				return
			end

			-- Ignore AI turret range detection parts
			if hit.Name == "AIrange" then
				return
			end

			local projectileAmmoType = projectile:GetAttribute("ammotype")
			local projectileArmorPen = tonumber(projectile:GetAttribute("armor_pen")) or 10
			local projectileDamage = tonumber(projectile:GetAttribute("damage")) or 25
			local targetArmor = tonumber(hit:GetAttribute("armor")) or 0

			print("SERVER: Projectile hit", hit.Name, "Armor:", targetArmor, "Penetration:", projectileArmorPen)

			-- Handle different ammo types
			if projectileAmmoType == "airburst" then
				-- Airburst: Explode on any contact
				local hasExploded = projectile:GetAttribute("has_exploded")
				if not hasExploded then
					projectile:SetAttribute("has_exploded", true)
					print("SERVER: Airburst contact detonation!")
					createExplosion(projectile.Position, explosionRadius, explosionDamage, armorPen)
					connection:Disconnect()
					projectile:Destroy()
				end
			elseif projectileAmmoType == "high_explosive" then
				-- High explosive: Check if already exploded
				local hasExploded = projectile:GetAttribute("has_exploded")
				if hasExploded then
					return
				end

				-- Check armor penetration
				if projectileArmorPen > targetArmor then
					-- Penetrates - delayed explosion
					local afterpenDelay = tonumber(projectile:GetAttribute("afterpen")) or 0.5
					projectile:SetAttribute("has_exploded", true)
					createSound(hit, "rbxasset://sounds/impact_water.mp3", 0.7, 1.0)
					print("SERVER: High explosive penetrated - delayed explosion in", afterpenDelay, "seconds")

					spawn(function()
						wait(afterpenDelay)
						if projectile and projectile.Parent then
							print("SERVER: High explosive delayed detonation!")
							createExplosion(projectile.Position, explosionRadius, explosionDamage, armorPen)
							connection:Disconnect()
							projectile:Destroy()
						end
					end)
				else
					-- Cannot penetrate - explode immediately
					projectile:SetAttribute("has_exploded", true)
					createSound(hit, "rbxasset://sounds/electronicbeep.mp3", 0.5, 0.8)
					print("SERVER: High explosive blocked by armor - exploding on contact!")
					createExplosion(projectile.Position, explosionRadius, explosionDamage, armorPen)
					connection:Disconnect()
					projectile:Destroy()
				end
			elseif projectileAmmoType == "rocket" then
				-- Rocket: Explode on any contact
				local hasExploded = projectile:GetAttribute("has_exploded")
				if not hasExploded then
					projectile:SetAttribute("has_exploded", true)
					print("SERVER: Rocket impact detonation!")

					-- Play rocket impact sound
					createSound(hit, "rbxasset://sounds/impact_water.mp3", 0.8, 1.2)

					-- Clean up from active rockets tracking
					local rocketId = tostring(projectile)
					if activeRockets[rocketId] then
						local rocketData = activeRockets[rocketId]
						createExplosion(
							projectile.Position,
							rocketData.explosionRadius,
							rocketData.explosionDamage,
							rocketData.armorPen
						)
						activeRockets[rocketId] = nil
					else
						-- Fallback if rocket data is missing
						createExplosion(projectile.Position, explosionRadius, explosionDamage, armorPen)
					end

					connection:Disconnect()
					projectile:Destroy()
				end
			elseif projectileAmmoType == "standard" then
				-- Standard round: Pass through and damage until blocked
				if projectileArmorPen > targetArmor then
					-- Penetrates and damages
					if targetArmor > 0 then
						createSound(hit, "rbxasset://sounds/impact_water.mp3", 0.7, 1.0)
						print("SERVER: Standard round penetrated", hit.Name)
					end

					-- Apply direct damage
					if not hit:GetAttribute("being_destroyed") then
						local currentHealth = tonumber(hit:GetAttribute("health")) or 100
						local newHealth = math.max(0, currentHealth - projectileDamage)
						hit:SetAttribute("health", newHealth)

						print("SERVER: Part", hit.Name, "damaged for", projectileDamage, "health:", newHealth)

						-- If hit part is a projectile, check if it should be destroyed
						if hit.Name:find("Projectile") and newHealth <= 0 then
							print("SERVER: Projectile", hit.Name, "destroyed by bullet!")
							-- Create small explosion effect for destroyed projectile
							local hitAmmoType = hit:GetAttribute("ammotype") or "standard"
							if hitAmmoType == "rocket" or hitAmmoType == "high_explosive" then
								-- Explosive projectiles explode when destroyed
								local hitExplosionRadius = tonumber(hit:GetAttribute("explosion_radius")) or 10
								local hitExplosionDamage = tonumber(hit:GetAttribute("explosive_radius_damage")) or 25
								createExplosion(hit.Position, hitExplosionRadius, hitExplosionDamage, 0)
							end
							hit:Destroy()
							return -- Don't continue processing if projectile was destroyed
						end

						-- Create health bar (same as explosion damage)
						local existingGui = hit:FindFirstChild("HealthBarGui")
						if existingGui then
							existingGui:Destroy()
						end

						if newHealth > 0 then
							local billboardGui = Instance.new("BillboardGui")
							billboardGui.Name = "HealthBarGui"
							billboardGui.Size = UDim2.fromScale(2, 0.5)
							billboardGui.StudsOffset = Vector3.new(0, hit.Size.Y / 2 + 1, 0)
							billboardGui.Parent = hit

							local backgroundFrame = Instance.new("Frame")
							backgroundFrame.Size = UDim2.fromScale(1, 1)
							backgroundFrame.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
							backgroundFrame.BorderColor3 = Color3.new(1, 1, 1)
							backgroundFrame.BorderSizePixel = 2
							backgroundFrame.Parent = billboardGui

							local maxHealth = tonumber(hit:GetAttribute("max_health")) or 100
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

							-- Auto-remove health bar after 3 seconds
							game:GetService("Debris"):AddItem(billboardGui, 3)
						else
							-- Part destroyed
							hit:SetAttribute("being_destroyed", true)

							-- Fade out and destroy
							local originalTransparency = hit.Transparency
							local fadeTime = 2.0
							local startTime = tick()

							local fadeConnection
							fadeConnection = game:GetService("RunService").Heartbeat:Connect(function()
								local elapsed = tick() - startTime
								local progress = elapsed / fadeTime

								if progress >= 1 then
									fadeConnection:Disconnect()
									hit:Destroy()
									print("SERVER: Part", hit.Name, "destroyed after fade")
								else
									hit.Transparency = originalTransparency + (1 - originalTransparency) * progress
								end
							end)
						end
					end
				else
					-- Blocked by armor - ricochet and destroy
					createSound(hit, "rbxasset://sounds/electronicpingshort.wav", 0.6, 1.8)
					print("SERVER: Standard round ricocheted off armor and destroyed")
					connection:Disconnect()
					projectile:Destroy()
				end
			end
		end)

		-- Clean up rocket from tracking when projectile is destroyed (for any reason)
		if ammoType == "rocket" then
			local rocketId = tostring(projectile)
			projectile.AncestryChanged:Connect(function()
				if not projectile.Parent then
					-- Projectile was destroyed, clean up from tracking
					if activeRockets[rocketId] then
						activeRockets[rocketId] = nil
						print("SERVER: Cleaned up rocket from tracking on destruction:", rocketId)
					end
				end
			end)
		end

		-- Auto-cleanup projectile after 10 seconds
		game:GetService("Debris"):AddItem(projectile, 10)
end

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

-- Handle rocket guidance updates from clients
rocketGuidanceEvent.OnServerEvent:Connect(function(player, action, rocketId, targetPosition)
	if action == "update_target" and activeRockets[rocketId] then
		local rocketData = activeRockets[rocketId]
		if rocketData and rocketData.player == player then
			rocketData.targetPosition = targetPosition
		end
	end
end)

-- Reload function
local function reloadWeapon(player, vehicleSeat, chamber)
		-- Validate player is in the seat
		if not vehicleSeat.Occupant or vehicleSeat.Occupant.Parent ~= player.Character then
			print("SERVER: Reload request denied - player not in seat")
			return
		end

		-- Get current and max bullet counts
		local currentBullets = tonumber(chamber:GetAttribute("bullet_count")) or 0
		local maxBullets = tonumber(chamber:GetAttribute("max_bullet_count")) or 10

		-- Check if already full
		if currentBullets >= maxBullets then
			print("SERVER: Magazine already full for", player.Name)
			return
		end

		-- Get reload time (using the old reload attribute for reload duration)
		local reloadTime = tonumber(chamber:GetAttribute("reload")) or 2.0

		-- Check if already reloading
		if chamber:GetAttribute("is_reloading") then
			print("SERVER: Already reloading for", player.Name)
			return
		end

		-- Start reload process
		chamber:SetAttribute("is_reloading", true)
		print("SERVER: Starting reload for", player.Name, "- duration:", reloadTime, "seconds")

		-- Reload after delay
		spawn(function()
			wait(reloadTime)

			-- Complete reload
			chamber:SetAttribute("bullet_count", maxBullets)
			chamber:SetAttribute("is_reloading", false)
			print("SERVER: Reload complete for", player.Name, "- bullets:", maxBullets)
		end)
	end

	-- Handle reload requests from clients
	reloadWeaponEvent.OnServerEvent:Connect(function(player, vehicleSeat)
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
			print("SERVER: No chamber found for reload")
			return
		end

		-- Reload the weapon
		reloadWeapon(player, vehicleSeat, chamber)
	end)
