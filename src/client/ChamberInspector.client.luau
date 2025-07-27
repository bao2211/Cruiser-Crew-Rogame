-- Chamber Inspector Tool
-- Displays chamber attributes when walking near chambers
-- Press T to toggle inspection mode

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Configuration
local INSPECTION_RANGE = 10  -- studs detection range
local INSPECTION_UPDATE_INTERVAL = 0.2  -- seconds between updates
local GUI_OFFSET = Vector3.new(0, 3, 0)  -- height above chamber

-- State
local inspectionMode = false
local activeGUIs = {}  -- chamber -> GUI mapping
local lastUpdate = 0

-- Create GUI for chamber
local function createChamberGUI(chamber)
	if activeGUIs[chamber] then
		return activeGUIs[chamber]
	end
	
	-- Create billboard GUI
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "ChamberInspector_" .. chamber.Name
	billboardGui.Size = UDim2.fromOffset(300, 200)
	billboardGui.StudsOffset = GUI_OFFSET
	billboardGui.Adornee = chamber
	billboardGui.Parent = workspace
	
	-- Create main frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.fromScale(1, 1)
	mainFrame.Position = UDim2.fromScale(0, 0)
	mainFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	mainFrame.BackgroundTransparency = 0.3
	mainFrame.BorderSizePixel = 2
	mainFrame.BorderColor3 = Color3.new(1, 1, 0)  -- Yellow border
	mainFrame.Parent = billboardGui
	
	-- Add corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = mainFrame
	
	-- Create title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 25)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundColor3 = Color3.new(1, 1, 0)
	titleLabel.BackgroundTransparency = 0
	titleLabel.Text = "CHAMBER: " .. chamber.Name
	titleLabel.TextColor3 = Color3.new(0, 0, 0)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.SourceSansBold
	titleLabel.Parent = mainFrame
	
	-- Add corner to title
	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 8)
	titleCorner.Parent = titleLabel
	
	-- Create scrolling frame for attributes
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "AttributesList"
	scrollFrame.Size = UDim2.fromScale(1, 1)
	scrollFrame.Position = UDim2.fromOffset(5, 30)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 10  -- Thicker for better interaction
	scrollFrame.ScrollBarImageColor3 = Color3.new(1, 1, 0)
	scrollFrame.ScrollBarImageTransparency = 0  -- Fully visible
	scrollFrame.ScrollingEnabled = true
	scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollFrame.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	scrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.None
	scrollFrame.VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Right
	scrollFrame.CanvasSize = UDim2.fromOffset(0, 500)  -- Start with large canvas
	scrollFrame.Parent = mainFrame
	
	-- Create list layout
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.Name
	listLayout.Padding = UDim.new(0, 3)  -- Slightly more padding
	listLayout.Parent = scrollFrame
	
	-- Get all chamber attributes
	local attributes = chamber:GetAttributes()
	
	-- Define attribute order and descriptions
	local attributeInfo = {
		ammotype = {order = 1, desc = "Projectile behavior type"},
		armor_pen = {order = 2, desc = "Armor penetration value"},
		damage = {order = 3, desc = "Direct damage dealt"},
		afterpen = {order = 4, desc = "HE explosion delay (seconds)"},
		airburst_time = {order = 5, desc = "Airburst timer (seconds)"},
		detect_range = {order = 6, desc = "Proximity detection (studs)"},
		explosion_radius = {order = 7, desc = "Blast radius (studs)"},
		explosive_radius_damage = {order = 8, desc = "Explosion damage"},
		weapontype = {order = 9, desc = "Weapon capability"}
	}
	
	-- Sort attributes by defined order
	local sortedAttributes = {}
	for name, value in pairs(attributes) do
		table.insert(sortedAttributes, {name = name, value = value, info = attributeInfo[name]})
	end
	
	table.sort(sortedAttributes, function(a, b)
		local orderA = a.info and a.info.order or 999
		local orderB = b.info and b.info.order or 999
		if orderA == orderB then
			return a.name < b.name
		end
		return orderA < orderB
	end)
	
	-- Create attribute labels
	for _, attr in ipairs(sortedAttributes) do
		local attrFrame = Instance.new("Frame")
		attrFrame.Name = attr.name
		attrFrame.Size = UDim2.fromScale(1, 0)
		attrFrame.BackgroundTransparency = 1
		attrFrame.Parent = scrollFrame
		
		-- Attribute name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "Name"
		nameLabel.Size = UDim2.fromScale(0.4, 1)
		nameLabel.Position = UDim2.fromScale(0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = attr.name .. ":"
		nameLabel.TextColor3 = Color3.new(1, 1, 0)
		nameLabel.TextScaled = true
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Font = Enum.Font.SourceSans
		nameLabel.Parent = attrFrame
		
		-- Attribute value
		local valueLabel = Instance.new("TextLabel")
		valueLabel.Name = "Value"
		valueLabel.Size = UDim2.fromScale(0.55, 1)
		valueLabel.Position = UDim2.fromScale(0.4, 0)
		valueLabel.BackgroundTransparency = 1
		valueLabel.Text = tostring(attr.value)
		valueLabel.TextColor3 = Color3.new(1, 1, 1)
		valueLabel.TextScaled = true
		valueLabel.TextXAlignment = Enum.TextXAlignment.Right
		valueLabel.Font = Enum.Font.SourceSans
		valueLabel.Parent = attrFrame
	end
	
	-- Update canvas size after all elements are created
	local function updateCanvasSize()
		local contentSize = listLayout.AbsoluteContentSize
		local frameSize = scrollFrame.AbsoluteSize
		local canvasHeight = math.max(contentSize.Y + 10, frameSize.Y + 1)  -- Ensure scrollable
		scrollFrame.CanvasSize = UDim2.fromOffset(0, canvasHeight)
		
		-- Debug output
		print("CLIENT: ScrollFrame - Content:", contentSize.Y, "Frame:", frameSize.Y, "Canvas:", canvasHeight, "Scrollable:", canvasHeight > frameSize.Y)
	end
	
	-- Connect to layout changes
	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvasSize)
	scrollFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateCanvasSize)
	
	-- Delay update to ensure proper sizing
	task.spawn(function()
		task.wait(0.1)  -- Wait for layout to settle
		updateCanvasSize()
	end)
	
	-- Store GUI reference
	activeGUIs[chamber] = billboardGui
	
	return billboardGui
end

-- Remove GUI for chamber
local function removeChamberGUI(chamber)
	if activeGUIs[chamber] then
		activeGUIs[chamber]:Destroy()
		activeGUIs[chamber] = nil
	end
end

-- Find nearby chambers
local function findNearbyChambers()
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		return {}
	end
	
	local playerPosition = player.Character.HumanoidRootPart.Position
	local nearbyChambers = {}
	
	-- Search for chamber parts
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and string.find(string.lower(obj.Name), "chamber") then
			-- Skip player's character parts
			if obj:IsDescendantOf(player.Character) then
				continue
			end
			
			local distance = (obj.Position - playerPosition).Magnitude
			if distance <= INSPECTION_RANGE then
				table.insert(nearbyChambers, obj)
			end
		end
	end
	
	return nearbyChambers
end

-- Update chamber inspection
local function updateChamberInspection()
	if not inspectionMode then
		return
	end
	
	local currentTime = tick()
	if currentTime - lastUpdate < INSPECTION_UPDATE_INTERVAL then
		return
	end
	lastUpdate = currentTime
	
	local nearbyChambers = findNearbyChambers()
	local currentChambers = {}
	
	-- Create GUIs for nearby chambers
	for _, chamber in ipairs(nearbyChambers) do
		currentChambers[chamber] = true
		if not activeGUIs[chamber] then
			createChamberGUI(chamber)
		end
	end
	
	-- Remove GUIs for chambers no longer nearby
	for chamber, _ in pairs(activeGUIs) do
		if not currentChambers[chamber] then
			removeChamberGUI(chamber)
		end
	end
end

-- Toggle inspection mode
local function toggleInspectionMode()
	inspectionMode = not inspectionMode
	
	if inspectionMode then
		print("CLIENT: Chamber inspection mode ENABLED - Press T to disable")
	else
		print("CLIENT: Chamber inspection mode DISABLED")
		-- Clean up all GUIs
		for chamber, _ in pairs(activeGUIs) do
			removeChamberGUI(chamber)
		end
	end
end

-- Add T key handling for inspection toggle
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.T then
		toggleInspectionMode()
	end
end)

-- Add inspection update to main loop
RunService.Heartbeat:Connect(function()
	updateChamberInspection()
end)

print("CLIENT: Chamber Inspector loaded - Press T to toggle inspection mode")
