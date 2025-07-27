-- Weapon System Server
-- Handles weapon firing, projectile creation, and ballistics
-- Self-contained system for all weapon-related functionality

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for RemoteEvents (created by main server)
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local fireWeaponEvent = remoteEvents:WaitForChild("FireWeapon")

print("SERVER: Weapon System loaded")

-- Explosion cooldown system to prevent infinite explosions
local explosionCooldowns = {}
local EXPLOSION_COOLDOWN_TIME = 0.5

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
	
	if explosionCooldowns[positionKey] and (currentTime - explosionCooldowns[positionKey]) < EXPLOSION_COOLDOWN_TIME then
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
	
	print("SERVER: Explosion created at", position, "with radius", explosionRadius, "damage", explosionDamage, "armor pen", armorPen)
	
	-- Find all parts within explosion radius and apply damage
	for _, obj in pairs(workspace:GetPartBoundsInBox(CFrame.new(position), Vector3.new(explosionRadius * 2, explosionRadius * 2, explosionRadius * 2))) do
		if obj:IsA("BasePart") and obj ~= explosionSphere then
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
						
						print("SERVER: Explosion damaged", obj.Name, "for", math.floor(finalDamage), "damage (health:", newHealth, ")")
						
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
							
							game:GetService("Debris"):AddItem(billboardGui, 3)
						else
							-- Destroy part with fade
							obj:SetAttribute("being_destroyed", true)
							local originalTransparency = obj.Transparency
							local fadeTime = 3
							local startTime = tick()
							
							local fadeConnection
							fadeConnection = game:GetService("RunService").Heartbeat:Connect(function()
								local elapsed = tick() - startTime
								local progress = elapsed / fadeTime
								
								if progress >= 1 then
									fadeConnection:Disconnect()
									obj:Destroy()
									print("SERVER: Part", obj.Name, "destroyed after fade")
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
	
	-- Cleanup explosion sphere
	game:GetService("Debris"):AddItem(explosionSphere, 3)
end

-- Main weapon firing function
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
	local detectRange = tonumber(chamber:GetAttribute("detect_range")) or 15
	local explosionRadius = tonumber(chamber:GetAttribute("explosion_radius")) or 20
	local explosionDamage = tonumber(chamber:GetAttribute("explosive_radius_damage")) or 50
	
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
	
	-- Set projectile appearance based on ammo type
	if ammoType == "high_explosive" then
		projectile.BrickColor = BrickColor.new("Bright red")
		projectile.Name = "ExplosiveProjectile"
	elseif ammoType == "airburst" then
		projectile.BrickColor = BrickColor.new("Bright yellow")
		projectile.Name = "AirburstProjectile"
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
	projectile:SetAttribute("has_exploded", false)
	
	-- Add velocity
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bodyVelocity.Velocity = fireDirection * 200
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
				local searchSize = Vector3.new(projectileDetectRange * 2, projectileDetectRange * 2, projectileDetectRange * 2)
				for _, obj in pairs(workspace:GetPartBoundsInBox(projectile.CFrame, searchSize)) do
					if obj ~= projectile and not obj:IsDescendantOf(vehicleSeat.Parent) then
						if not (obj.Name == "ExplosionRadius" or obj.Name:find("Projectile") or obj:GetAttribute("is_explosion_sphere")) then
							local distance = (obj.Position - projectile.Position).Magnitude
							if distance <= projectileDetectRange then
								table.insert(nearbyParts, obj)
							end
						end
					end
				end
				
				if #nearbyParts > 0 then
					local hasExploded = projectile:GetAttribute("has_exploded")
					if not hasExploded then
						projectile:SetAttribute("has_exploded", true)
						print("SERVER: Airburst proximity detonation! Found", #nearbyParts, "nearby parts")
						createExplosion(projectile.Position, explosionRadius, explosionDamage, armorPen)
						projectile:Destroy()
						break
					end
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
		
		-- Ignore other projectiles and explosion spheres
		if hit.Name:find("Projectile") or hit.Name == "ExplosionRadius" or hit:GetAttribute("is_explosion_sphere") then
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
				if targetArmor > 0 then
					createSound(hit, "rbxasset://sounds/impact_water.mp3", 0.7, 1.0)
					print("SERVER: High explosive penetrated", hit.Name, "- will explode in", afterpenDelay, "seconds")
				end
				
				projectile:SetAttribute("has_exploded", true)
				
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
					
					-- Create health bar (same as explosion damage)
					local existingGui = hit:FindFirstChild("HealthBarGui")
					if existingGui then
						existingGui:Destroy()
					end
					
					if newHealth > 0 then
						local billboardGui = Instance.new("BillboardGui")
						billboardGui.Name = "HealthBarGui"
						billboardGui.Size = UDim2.fromScale(2, 0.5)
						billboardGui.StudsOffset = Vector3.new(0, hit.Size.Y/2 + 1, 0)
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
						
						local healthText = Instance.new("TextLabel")
						healthText.Size = UDim2.fromScale(1, 1)
						healthText.BackgroundTransparency = 1
						healthText.Text = string.format("%d/%d", newHealth, maxHealth)
						healthText.TextColor3 = Color3.new(1, 1, 1)
						healthText.TextScaled = true
						healthText.Font = Enum.Font.SourceSansBold
						healthText.Parent = backgroundFrame
						
						game:GetService("Debris"):AddItem(billboardGui, 3)
					else
						-- Destroy part with fade
						hit:SetAttribute("being_destroyed", true)
						local originalTransparency = hit.Transparency
						local fadeTime = 3
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
