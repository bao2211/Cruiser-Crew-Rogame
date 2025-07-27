-- Attribute Initializer System Server
-- Sets up default attributes for chambers, parts, and vehicle seats
-- Self-contained system for all attribute initialization

local RunService = game:GetService("RunService")

print("SERVER: Attribute Initializer loaded")

-- Initialize chamber parts with weapon attributes
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
			
			-- Initialize explosion radius if not set
			if not obj:GetAttribute("explosion_radius") then
				obj:SetAttribute("explosion_radius", 20) -- Default explosion radius
			end
			
			-- Initialize explosive radius damage if not set
			if not obj:GetAttribute("explosive_radius_damage") then
				obj:SetAttribute("explosive_radius_damage", 50) -- Default explosion damage
			end
			
			-- Initialize detect range if not set
			if not obj:GetAttribute("detect_range") then
				obj:SetAttribute("detect_range", 15) -- Default proximity detection range
			end
			
			-- Initialize reload time if not set
			if not obj:GetAttribute("reload") then
				obj:SetAttribute("reload", 1.0) -- Default reload time in seconds
			end
			
			-- Initialize weapon type if not set
			if not obj:GetAttribute("weapontype") then
				obj:SetAttribute("weapontype", "Cannon") -- Default weapon type
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

-- Initialize vehicle seats with control attributes
local function initializeVehicleSeats()
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
			
			-- Initialize aiturret attribute if not set
			if not obj:GetAttribute("aiturret") then
				obj:SetAttribute("aiturret", false) -- Default AI turret disabled
			end
			
			-- Initialize hover attributes if not set
			if not obj:GetAttribute("GravityCompensation") then
				obj:SetAttribute("GravityCompensation", 0.8) -- Default gravity compensation
			end
			
			if not obj:GetAttribute("PositionLocked") then
				obj:SetAttribute("PositionLocked", false) -- Default not locked
			end
			
			-- Initialize movement attributes if not set
			if not obj:GetAttribute("ForceMagnitude") then
				obj:SetAttribute("ForceMagnitude", 3000) -- Default force magnitude
			end
			
			if not obj:GetAttribute("RotateSpeed") then
				obj:SetAttribute("RotateSpeed", 0.1) -- Default rotation speed
			end
			
			if not obj:GetAttribute("VerticalForceUp") then
				obj:SetAttribute("VerticalForceUp", 3000) -- Default vertical force up
			end
			
			if not obj:GetAttribute("VerticalForceDown") then
				obj:SetAttribute("VerticalForceDown", 3000) -- Default vertical force down
			end
			
			if not obj:GetAttribute("MaxHorizontalSpeed") then
				obj:SetAttribute("MaxHorizontalSpeed", 50) -- Default max horizontal speed
			end
			
			if not obj:GetAttribute("MaxVerticalSpeed") then
				obj:SetAttribute("MaxVerticalSpeed", 50) -- Default max vertical speed
			end
		end
	end
end

-- Run all initialization functions
local function initializeAll()
	initializeChambers()
	initializeParts()
	initializeVehicleSeats()
end

-- Run initialization periodically to catch new objects
local lastUpdate = 0
RunService.Heartbeat:Connect(function()
	local now = tick()
	if now - lastUpdate >= 1.0 then -- Every 1 second
		lastUpdate = now
		initializeAll()
	end
end)

-- Run initial setup
initializeAll()
