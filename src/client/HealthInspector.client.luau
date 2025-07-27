-- Health Inspector Tool
-- Displays part health when walking near parts with health attribute
-- Press H to toggle health inspection mode

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Configuration
local HEALTH_INSPECTION_RANGE = 8  -- studs detection range
local HEALTH_UPDATE_INTERVAL = 0.3  -- seconds between updates
local HEALTH_GUI_OFFSET = Vector3.new(0, 2, 0)  -- height above part

-- State
local healthInspectionMode = false
local activeHealthGUIs = {}  -- part -> GUI mapping
local lastHealthUpdate = 0

-- Create health GUI for part
local function createHealthGUI(part)
	if activeHealthGUIs[part] then
		return activeHealthGUIs[part]
	end
	
	-- Get part health
	local health = part:GetAttribute("health")
	local maxHealth = part:GetAttribute("max_health") or health
	if not health then
		return nil  -- Part has no health attribute
	end
	
	-- Create billboard GUI
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "HealthInspector_" .. part.Name
	billboardGui.Size = UDim2.fromOffset(200, 60)
	billboardGui.StudsOffset = HEALTH_GUI_OFFSET
	billboardGui.Adornee = part
	billboardGui.Parent = workspace
	
	-- Create main frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.fromScale(1, 1)
	mainFrame.Position = UDim2.fromScale(0, 0)
	mainFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	mainFrame.BackgroundTransparency = 0.3
	mainFrame.BorderSizePixel = 2
	mainFrame.BorderColor3 = Color3.new(0, 1, 0)  -- Green border
	mainFrame.Parent = billboardGui
	
	-- Add corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = mainFrame
	
	-- Create title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 20)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundColor3 = Color3.new(0, 1, 0)  -- Green background
	titleLabel.BackgroundTransparency = 0
	titleLabel.Text = "HEALTH: " .. part.Name
	titleLabel.TextColor3 = Color3.new(0, 0, 0)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.SourceSansBold
	titleLabel.Parent = mainFrame
	
	-- Add corner to title
	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 6)
	titleCorner.Parent = titleLabel
	
	-- Create health bar background
	local healthBarBg = Instance.new("Frame")
	healthBarBg.Name = "HealthBarBackground"
	healthBarBg.Size = UDim2.new(1, -10, 0, 12)
	healthBarBg.Position = UDim2.fromOffset(5, 25)
	healthBarBg.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
	healthBarBg.BorderSizePixel = 1
	healthBarBg.BorderColor3 = Color3.new(0.5, 0.5, 0.5)
	healthBarBg.Parent = mainFrame
	
	-- Create health bar fill
	local healthBar = Instance.new("Frame")
	healthBar.Name = "HealthBar"
	healthBar.Size = UDim2.fromScale(health / maxHealth, 1)
	healthBar.Position = UDim2.new(0, 0, 0, 0)
	healthBar.BorderSizePixel = 0
	healthBar.Parent = healthBarBg
	
	-- Set health bar color based on percentage
	local healthPercent = health / maxHealth
	if healthPercent > 0.6 then
		healthBar.BackgroundColor3 = Color3.new(0, 1, 0)  -- Green
	elseif healthPercent > 0.3 then
		healthBar.BackgroundColor3 = Color3.new(1, 1, 0)  -- Yellow
	else
		healthBar.BackgroundColor3 = Color3.new(1, 0, 0)  -- Red
	end
	
	-- Create health text
	local healthText = Instance.new("TextLabel")
	healthText.Name = "HealthText"
	healthText.Size = UDim2.new(1, 0, 0, 15)
	healthText.Position = UDim2.fromOffset(0, 42)
	healthText.BackgroundTransparency = 1
	healthText.Text = string.format("%.0f / %.0f HP (%.1f%%)", health, maxHealth, healthPercent * 100)
	healthText.TextColor3 = Color3.new(1, 1, 1)
	healthText.TextScaled = true
	healthText.Font = Enum.Font.SourceSans
	healthText.Parent = mainFrame
	
	-- Store GUI reference
	activeHealthGUIs[part] = billboardGui
	
	return billboardGui
end

-- Remove health GUI for part
local function removeHealthGUI(part)
	if activeHealthGUIs[part] then
		activeHealthGUIs[part]:Destroy()
		activeHealthGUIs[part] = nil
	end
end

-- Find nearby parts with health
local function findNearbyHealthParts()
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		return {}
	end
	
	local playerPosition = player.Character.HumanoidRootPart.Position
	local nearbyParts = {}
	
	-- Search for parts with health attribute
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and obj:GetAttribute("health") then
			-- Skip player's character parts
			if obj:IsDescendantOf(player.Character) then
				continue
			end
			
			local distance = (obj.Position - playerPosition).Magnitude
			if distance <= HEALTH_INSPECTION_RANGE then
				table.insert(nearbyParts, obj)
			end
		end
	end
	
	return nearbyParts
end

-- Update health inspection
local function updateHealthInspection()
	if not healthInspectionMode then
		return
	end
	
	local currentTime = tick()
	if currentTime - lastHealthUpdate < HEALTH_UPDATE_INTERVAL then
		return
	end
	lastHealthUpdate = currentTime
	
	local nearbyParts = findNearbyHealthParts()
	local currentParts = {}
	
	-- Create GUIs for nearby parts
	for _, part in ipairs(nearbyParts) do
		currentParts[part] = true
		if not activeHealthGUIs[part] then
			createHealthGUI(part)
		else
			-- Update existing GUI with current health
			local gui = activeHealthGUIs[part]
			local health = part:GetAttribute("health")
			local maxHealth = part:GetAttribute("max_health") or health
			
			if health and gui then
				local healthPercent = health / maxHealth
				local healthBar = gui.MainFrame.HealthBarBackground.HealthBar
				local healthText = gui.MainFrame.HealthText
				
				-- Update bar size and color
				healthBar.Size = UDim2.fromScale(healthPercent, 1)
				if healthPercent > 0.6 then
					healthBar.BackgroundColor3 = Color3.new(0, 1, 0)  -- Green
				elseif healthPercent > 0.3 then
					healthBar.BackgroundColor3 = Color3.new(1, 1, 0)  -- Yellow
				else
					healthBar.BackgroundColor3 = Color3.new(1, 0, 0)  -- Red
				end
				
				-- Update text
				healthText.Text = string.format("%.0f / %.0f HP (%.1f%%)", health, maxHealth, healthPercent * 100)
			end
		end
	end
	
	-- Remove GUIs for parts no longer nearby
	for part, _ in pairs(activeHealthGUIs) do
		if not currentParts[part] then
			removeHealthGUI(part)
		end
	end
end

-- Toggle health inspection mode
local function toggleHealthInspectionMode()
	healthInspectionMode = not healthInspectionMode
	
	if healthInspectionMode then
		print("CLIENT: Health inspection mode ENABLED - Press H to disable")
	else
		print("CLIENT: Health inspection mode DISABLED")
		-- Clean up all health GUIs
		for part, _ in pairs(activeHealthGUIs) do
			removeHealthGUI(part)
		end
	end
end

-- Add H key handling for health inspection toggle
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.H then
		toggleHealthInspectionMode()
	end
end)

-- Add health inspection update to main loop
RunService.Heartbeat:Connect(function()
	updateHealthInspection()
end)

print("CLIENT: Health Inspector loaded - Press H to toggle health inspection mode")
