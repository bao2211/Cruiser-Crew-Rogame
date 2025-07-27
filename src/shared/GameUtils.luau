-- Game Utilities Module
-- Common utility functions used by both client and server scripts
-- Provides reusable functions for GUI creation, sound management, and calculations

local GameUtils = {}

-- Services
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
-- SoundService removed - was unused

-- === GUI UTILITIES ===

-- Create a standardized BillboardGui
function GameUtils.createBillboardGui(parent, size, offset, studOffset)
	local gui = Instance.new("BillboardGui")
	gui.Size = size or UDim2.fromOffset(200, 100)
	gui.StudsOffset = studOffset or Vector3.new(0, 2, 0)
	gui.StudsOffsetWorldSpace = offset or Vector3.new(0, 0, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = parent
	return gui
end

-- Create a standardized Frame with border
function GameUtils.createFrame(parent, backgroundColor, borderColor, transparency)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.Position = UDim2.fromScale(0, 0)
	frame.BackgroundColor3 = backgroundColor or Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = transparency or 0.3
	frame.BorderSizePixel = 2
	frame.BorderColor3 = borderColor or Color3.fromRGB(255, 255, 255)
	frame.Parent = parent
	
	-- Add corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = frame
	
	return frame
end

-- Create a standardized TextLabel
function GameUtils.createTextLabel(parent, text, textColor, textSize, position, size)
	local label = Instance.new("TextLabel")
	label.Text = text or ""
	label.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
	label.TextSize = textSize or 14
	label.Font = Enum.Font.SourceSansBold
	label.BackgroundTransparency = 1
	label.Position = position or UDim2.fromScale(0, 0)
	label.Size = size or UDim2.fromScale(1, 0.2)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = parent
	return label
end

-- Create a scrollable frame for lists
function GameUtils.createScrollingFrame(parent, position, size)
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Position = position or UDim2.fromScale(0, 0.2)
	scrollFrame.Size = size or UDim2.fromScale(1, 0.8)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
	scrollFrame.CanvasSize = UDim2.fromScale(0, 0)
	scrollFrame.Parent = parent
	
	-- Add list layout
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 2)
	listLayout.Parent = scrollFrame
	
	-- Auto-resize canvas
	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scrollFrame.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y)
	end)
	
	return scrollFrame, listLayout
end

-- Create a health bar with background and fill
function GameUtils.createHealthBar(parent, healthPercent, barColor, position, size)
	-- Background bar
	local backgroundBar = Instance.new("Frame")
	backgroundBar.Position = position or UDim2.fromScale(0, 0.5)
	backgroundBar.Size = size or UDim2.fromScale(1, 0.3)
	backgroundBar.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	backgroundBar.BorderSizePixel = 1
	backgroundBar.BorderColor3 = Color3.fromRGB(255, 255, 255)
	backgroundBar.Parent = parent
	
	-- Health fill bar
	local healthBar = Instance.new("Frame")
	healthBar.Position = UDim2.fromScale(0, 0)
	healthBar.Size = UDim2.fromScale(healthPercent or 1, 1)
	healthBar.BackgroundColor3 = barColor or Color3.fromRGB(0, 255, 0)
	healthBar.BorderSizePixel = 0
	healthBar.Parent = backgroundBar
	
	return backgroundBar, healthBar
end

-- === SOUND UTILITIES ===

-- Create and play a sound with automatic cleanup
function GameUtils.createSound(parent, soundId, volume, pitch, lifetime)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.Pitch = pitch or 1.0
	sound.Parent = parent
	sound:Play()
	
	-- Auto-cleanup
	Debris:AddItem(sound, lifetime or 3)
	
	return sound
end

-- Play a sound with distance-based volume
function GameUtils.playSoundAtPosition(position, soundId, _, volume, pitch)
	local part = Instance.new("Part")
	part.Name = "SoundSource"
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Parent = workspace
	
	local sound = GameUtils.createSound(part, soundId, volume, pitch, 3)
	
	-- Cleanup part after sound
	Debris:AddItem(part, 3)
	
	return sound
end

-- === MATH UTILITIES ===

-- Calculate distance between two Vector3 positions
function GameUtils.getDistance(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

-- Calculate damage falloff based on distance
function GameUtils.calculateDamageFalloff(distance, maxRadius, baseDamage, minPercent)
	local falloff = math.max(minPercent or 0.1, 1 - (distance / maxRadius))
	return baseDamage * falloff
end

-- Clamp a value between min and max
function GameUtils.clamp(value, min, max)
	return math.max(min, math.min(max, value))
end

-- Linear interpolation between two values
function GameUtils.lerp(a, b, t)
	return a + (b - a) * t
end

-- Convert angle to unit vector
function GameUtils.angleToVector(angle)
	return Vector3.new(math.cos(angle), 0, math.sin(angle))
end

-- === PART UTILITIES ===

-- Find all parts with a specific attribute
function GameUtils.findPartsWithAttribute(parent, attributeName, attributeValue)
	local parts = {}
	
	for _, descendant in pairs(parent:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local value = descendant:GetAttribute(attributeName)
			if value ~= nil and (attributeValue == nil or value == attributeValue) then
				table.insert(parts, descendant)
			end
		end
	end
	
	return parts
end

-- Find parts within a radius of a position
function GameUtils.findPartsInRadius(center, radius, parent)
	parent = parent or workspace
	local parts = {}
	-- Region3 approach removed - using GetPartBoundsInBox instead
	
	-- Use GetPartBoundsInBox for better performance
	local searchSize = Vector3.new(radius * 2, radius * 2, radius * 2)
	local foundParts = workspace:GetPartBoundsInBox(CFrame.new(center), searchSize)
	
	for _, part in pairs(foundParts) do
		local distance = GameUtils.getDistance(center, part.Position)
		if distance <= radius then
			table.insert(parts, part)
		end
	end
	
	return parts
end

-- Check if a part has a specific name pattern
function GameUtils.partNameContains(part, pattern)
	return string.find(string.lower(part.Name), string.lower(pattern)) ~= nil
end

-- === ATTRIBUTE UTILITIES ===

-- Safely get an attribute with a default value
function GameUtils.getAttribute(object, attributeName, defaultValue)
	local value = object:GetAttribute(attributeName)
	if value == nil then
		return defaultValue
	end
	return value
end

-- Set an attribute only if it doesn't already exist
function GameUtils.setDefaultAttribute(object, attributeName, defaultValue)
	if object:GetAttribute(attributeName) == nil then
		object:SetAttribute(attributeName, defaultValue)
		return true -- Attribute was set
	end
	return false -- Attribute already existed
end

-- Initialize multiple attributes with defaults
function GameUtils.initializeAttributes(object, attributeDefaults)
	local initialized = {}
	
	for attributeName, defaultValue in pairs(attributeDefaults) do
		if GameUtils.setDefaultAttribute(object, attributeName, defaultValue) then
			table.insert(initialized, attributeName)
		end
	end
	
	return initialized
end

-- === TWEEN UTILITIES ===

-- Create a fade-out tween for transparency
function GameUtils.fadeOut(object, duration, startTransparency, endTransparency)
	local tweenInfo = TweenInfo.new(
		duration or 2,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.InOut
	)
	
	local tween = TweenService:Create(object, tweenInfo, {
		Transparency = endTransparency or 1
	})
	
	if startTransparency then
		object.Transparency = startTransparency
	end
	
	tween:Play()
	return tween
end

-- Create a size tween
function GameUtils.tweenSize(object, targetSize, duration, easingStyle)
	local tweenInfo = TweenInfo.new(
		duration or 1,
		easingStyle or Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	
	local tween = TweenService:Create(object, tweenInfo, {
		Size = targetSize
	})
	
	tween:Play()
	return tween
end

-- === VALIDATION UTILITIES ===

-- Check if an object is valid and has a parent
function GameUtils.isValidObject(object)
	return object and object.Parent ~= nil
end

-- Validate that a part has required attributes
function GameUtils.validatePartAttributes(part, requiredAttributes)
	for _, attributeName in pairs(requiredAttributes) do
		if part:GetAttribute(attributeName) == nil then
			return false, "Missing attribute: " .. attributeName
		end
	end
	return true, "All attributes present"
end

-- === DEBUG UTILITIES ===

-- Format a debug message with timestamp
function GameUtils.formatDebugMessage(prefix, category, message)
	local timestamp = os.date("%H:%M:%S")
	return string.format("[%s] %s [%s] %s", timestamp, prefix, category, message)
end

-- Print debug message with formatting
function GameUtils.debugPrint(prefix, category, message)
	print(GameUtils.formatDebugMessage(prefix, category, message))
end

-- === CLEANUP UTILITIES ===

-- Clean up all children of a specific type
function GameUtils.cleanupChildrenOfType(parent, className)
	local cleaned = 0
	for _, child in pairs(parent:GetChildren()) do
		if child:IsA(className) then
			child:Destroy()
			cleaned = cleaned + 1
		end
	end
	return cleaned
end

-- Clean up objects with a specific attribute
function GameUtils.cleanupByAttribute(parent, attributeName, attributeValue)
	local cleaned = 0
	for _, descendant in pairs(parent:GetDescendants()) do
		local value = descendant:GetAttribute(attributeName)
		if value ~= nil and (attributeValue == nil or value == attributeValue) then
			descendant:Destroy()
			cleaned = cleaned + 1
		end
	end
	return cleaned
end

return GameUtils
