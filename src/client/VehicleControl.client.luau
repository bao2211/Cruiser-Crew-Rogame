-- Vehicle Control System
-- Handles hover, movement, rotation, and weapon firing for vehicles
-- Supports cruiser, turret, and 2xturret seat types

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
-- Removed unused services to fix lint warnings

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Wait for RemoteEvents
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local hoverToggleEvent = remoteEvents:WaitForChild("HoverToggle")
local fireWeaponEvent = remoteEvents:WaitForChild("FireWeapon")

-- Default values
local DEFAULT_FORCE_MAGNITUDE = 3000
local DEFAULT_ROTATE_SPEED = 0.1
local DEFAULT_GRAVITY_COMPENSATION = 0.8
local DEFAULT_VERTICAL_FORCE_UP = 3000
local DEFAULT_VERTICAL_FORCE_DOWN = 3000
local DEFAULT_MAX_HORIZONTAL_SPEED = 50
local DEFAULT_MAX_VERTICAL_SPEED = 50

-- Control variables
local seat = nil
local throttle = 0
local steer = 0
local rotate = 0
local verticalThrust = 0
local isPositionLocked = false
local isInVehicle = false

-- Input state tracking
local keysPressed = {
	W = false,
	A = false,
	S = false,
	D = false,
	Q = false,
	E = false,
	X = false,
	C = false,
}

-- Table to store seat connections
local seatConnections = {} -- Store RBXScriptConnection objects by seat

-- GUI elements
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = nil
local hoverButton = nil
local lockButton = nil

-- Function to create control GUI
local function createControlGUI()
	-- Create ScreenGui if it doesn't exist
	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "VehicleControlGUI"
		screenGui.Parent = playerGui
	end
	
	-- Create hover button
	if not hoverButton then
		hoverButton = Instance.new("TextButton")
		hoverButton.Name = "HoverButton"
		hoverButton.Size = UDim2.fromOffset(100, 40)
		hoverButton.Position = UDim2.fromOffset(10, 10)
		hoverButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
		hoverButton.BorderColor3 = Color3.fromRGB(255, 255, 255)
		hoverButton.BorderSizePixel = 2
		hoverButton.Text = "Hover: OFF"
		hoverButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		hoverButton.TextSize = 14
		hoverButton.Font = Enum.Font.SourceSansBold
		hoverButton.Parent = screenGui
	end
	
	-- Create position lock button
	if not lockButton then
		lockButton = Instance.new("TextButton")
		lockButton.Name = "LockButton"
		lockButton.Size = UDim2.fromOffset(100, 40)
		lockButton.Position = UDim2.fromOffset(120, 10)
		lockButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
		lockButton.BorderColor3 = Color3.fromRGB(255, 255, 255)
		lockButton.BorderSizePixel = 2
		lockButton.Text = "Lock: OFF"
		lockButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		lockButton.TextSize = 14
		lockButton.Font = Enum.Font.SourceSansBold
		lockButton.Visible = false -- Initially hidden until hover is enabled
		lockButton.Parent = screenGui
	end
end

-- Function to update button appearance
local function updateButtonState()
	if not hoverButton or not lockButton then
		print("CLIENT: updateButtonState called but buttons don't exist")
		return
	end
	
	if not seat then
		print("CLIENT: updateButtonState called but no seat")
		return
	end
	
	-- Get current attribute values
	local gravityComp = seat:GetAttribute("GravityCompensation")
	local positionLocked = seat:GetAttribute("PositionLocked")
	
	print("CLIENT: updateButtonState - GravityComp:", gravityComp, "PositionLocked:", positionLocked)
	
	-- Update hover button
	if gravityComp and gravityComp >= 1.0 then
		hoverButton.Text = "Hover: ON"
		hoverButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
		print("CLIENT: Set hover button to ON")
	else
		hoverButton.Text = "Hover: OFF"
		hoverButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
		print("CLIENT: Set hover button to OFF")
	end
	
	-- Update lock button (only show when hover is enabled)
	if gravityComp and gravityComp >= 1.0 then
		-- Hover is enabled, show lock button
		lockButton.Visible = true
		if positionLocked then
			lockButton.Text = "Lock: ON"
			lockButton.BackgroundColor3 = Color3.fromRGB(150, 150, 0)
			print("CLIENT: Set lock button to ON")
		else
			lockButton.Text = "Lock: OFF"
			lockButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
			print("CLIENT: Set lock button to OFF")
		end
	else
		-- Hover is disabled, hide lock button
		lockButton.Visible = false
		print("CLIENT: Lock button hidden - hover disabled")
	end
end

-- Function to show/hide GUI based on vehicle state
local function updateGUIVisibility()
	if screenGui then
		-- Hide UI if not in vehicle
		if not isInVehicle or not seat then
			screenGui.Enabled = false
			return
		end
		
		-- Hide UI if vehicle seat has a weapon type (not "None")
		local weaponType = seat:GetAttribute("weapontype") or "None"
		if weaponType ~= "None" then
			screenGui.Enabled = false
			print("CLIENT: Hiding vehicle control UI - seat has weapon type:", weaponType)
			return
		end
		
		-- Show UI for non-weapon seats
		screenGui.Enabled = true
		print("CLIENT: Showing vehicle control UI - no weapon type")
	end
end

-- Function to fire cannon projectile (now uses RemoteEvent)
local function fireCannon(vehicleSeat)
	-- Only fire if we're actually in a vehicle to prevent sound bug on exit
	if not vehicleSeat or not vehicleSeat:IsA("VehicleSeat") or not isInVehicle then
		return
	end
	
	-- Additional check: make sure we're still the occupant
	if not vehicleSeat.Occupant or vehicleSeat.Occupant.Parent ~= player.Character then
		print("CLIENT: Prevented firing - not occupant of seat")
		return
	end
	
	-- Additional check: make sure the seat reference matches our current seat
	if seat ~= vehicleSeat then
		print("CLIENT: Prevented firing - seat reference mismatch")
		return
	end
	
	-- Additional check: make sure player character is actually sitting (not jumping/exiting)
	local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Sit == false then
		print("CLIENT: Prevented firing - player not sitting")
		return
	end
	
	-- Additional check: make sure we're not in the middle of exiting
	if humanoid.Jump == true then
		print("CLIENT: Prevented firing - player jumping/exiting")
		return
	end
	
	-- Find the chamber block in the vehicle's parent model
	local vehicleModel = vehicleSeat.Parent
	if not vehicleModel then
		return
	end
	
	local chamber = vehicleModel:FindFirstChild("chamber")
	if not chamber then
		print("CLIENT: No 'chamber' block found in vehicle model for cannon firing")
		return
	end
	
	-- Get ammo type for client feedback
	local ammoType = chamber:GetAttribute("ammotype") or "standard"
	
	-- Send fire request to server
	fireWeaponEvent:FireServer(vehicleSeat)
	
	-- Delayed client feedback - play sound after brief validation delay
	task.wait(0.05) -- Small delay to allow exit detection
	
	-- Re-validate before playing sound (exit might have happened)
	if not isInVehicle or seat ~= vehicleSeat then
		print("CLIENT: Cancelled sound - player exited during fire request")
		return
	end
	
	local fireSound = Instance.new("Sound")
	fireSound.SoundId = "rbxasset://sounds/impact_water.mp3"
	fireSound.Volume = 0.5
	fireSound.Parent = chamber
	fireSound:Play()
	
	-- Auto-cleanup sound
	game:GetService("Debris"):AddItem(fireSound, 3)
	
	print("CLIENT: Fire request sent for", ammoType, "round from", chamber.Name)
end

-- Function to handle turret rotation
local function handleTurretRotation(vehicleSeat, seatType)
	if not vehicleSeat or not vehicleSeat:IsA("VehicleSeat") then
		return
	end

	-- Get mouse position
	local mouse = player:GetMouse()
	
	-- Calculate screen center and mouse offsets
	local screenCenterX = camera.ViewportSize.X / 2
	local screenCenterY = camera.ViewportSize.Y / 2
	local mouseOffsetX = mouse.X - screenCenterX
	local mouseOffsetY = mouse.Y - screenCenterY
	
	-- Normalize the offsets to rotation speeds (-1 to 1)
	local maxOffsetX = screenCenterX
	local normalizedOffsetX = math.clamp(mouseOffsetX / maxOffsetX, -1, 1)
	
	-- Create BodyAngularVelocity if needed
	local bodyAngular = vehicleSeat:FindFirstChild("TurretAngular")
	if not bodyAngular then
		bodyAngular = Instance.new("BodyAngularVelocity")
		bodyAngular.Name = "TurretAngular"
		bodyAngular.Parent = vehicleSeat
	end
	
	local rotationSpeed = 5 -- Adjust this value for sensitivity
	
	if seatType == "turret" then
		-- Single axis turret - Y-axis rotation only (left/right)
		local yRotation = -normalizedOffsetX * rotationSpeed
		bodyAngular.AngularVelocity = Vector3.new(0, yRotation, 0)
		bodyAngular.MaxTorque = Vector3.new(0, math.huge, 0)
	elseif seatType == "2xturret" then
		-- Dual axis turret - make turret face where mouse is pointing
		local deadZoneRadius = 50 -- Pixels from center
		local distanceFromCenter = math.sqrt(mouseOffsetX^2 + mouseOffsetY^2)
		
		if distanceFromCenter < deadZoneRadius then
			-- Inside deadzone - no rotation
			bodyAngular.AngularVelocity = Vector3.new(0, 0, 0)
		else
			-- Outside deadzone - make turret face mouse direction
			-- Create a ray from camera through mouse position
			local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
			
			-- Calculate target direction (where mouse is pointing)
			local targetDirection = unitRay.Direction.Unit
			
			-- Get current turret forward direction
			local currentForward = vehicleSeat.CFrame.LookVector
			
			-- Calculate the rotation needed to face the target
			local cross = currentForward:Cross(targetDirection)
			local dot = currentForward:Dot(targetDirection)
			
			-- Convert to angular velocity
			local angularSpeed = 5 -- Tracking speed
			local targetAngularVelocity = cross * angularSpeed * (1 - dot)
			
			-- Limit pitch to prevent flipping
			local maxPitch = 1.5
			targetAngularVelocity = Vector3.new(
				math.clamp(targetAngularVelocity.X, -maxPitch, maxPitch),
				targetAngularVelocity.Y,
				0 -- No roll
			)
			
			bodyAngular.AngularVelocity = targetAngularVelocity
			bodyAngular.MaxTorque = Vector3.new(math.huge, math.huge, 0)
		end
	end
	
	bodyAngular.P = 10000
end

-- GUI elements are now created dynamically via createControlGUI function
-- Removed redundant declarations that were shadowing earlier variables

-- Debug function
local function debugVehicleState()
	if not seat then
		return
	end

	local velocity = seat.AssemblyLinearVelocity
	local speed = velocity.Magnitude
	local gravComp = seat:GetAttribute("GravityCompensation") or 0
	local isHovering = gravComp >= 1.0
	local posLocked = seat:GetAttribute("PositionLocked") or false

	local controlForce = seat:FindFirstChild("ControlForce")
	local forceVector = controlForce and controlForce.Force or Vector3.new(0, 0, 0)

	print(
		string.format(
			"DEBUG: Speed=%.2f | Hovering=%s(%.1f) | Thrust=%.1f | X=%s C=%s | Force=(%.0f,%.0f,%.0f) | Locked=%s",
			speed,
			tostring(isHovering),
			gravComp,
			verticalThrust,
			tostring(keysPressed.X),
			tostring(keysPressed.C),
			forceVector.X,
			forceVector.Y,
			forceVector.Z,
			tostring(posLocked)
		)
	)
end

-- Apply force function
local function applyForce()
	if not seat or not seat:IsDescendantOf(workspace) then
		return
	end

	-- If position is locked, remove ALL forces
	if isPositionLocked then
		local controlForce = seat:FindFirstChild("ControlForce")
		if controlForce then
			controlForce:Destroy()
		end
		return
	end

	-- Get vehicle attributes
	local forceMagnitude = seat:GetAttribute("ForceMagnitude") or DEFAULT_FORCE_MAGNITUDE
	local verticalForceUp = seat:GetAttribute("VerticalForceUp") or DEFAULT_VERTICAL_FORCE_UP
	local verticalForceDown = seat:GetAttribute("VerticalForceDown") or DEFAULT_VERTICAL_FORCE_DOWN
	local maxHorizontalSpeed = seat:GetAttribute("MaxHorizontalSpeed") or DEFAULT_MAX_HORIZONTAL_SPEED
	local maxVerticalSpeed = seat:GetAttribute("MaxVerticalSpeed") or DEFAULT_MAX_VERTICAL_SPEED
	local gravityCompensationMultiplier = seat:GetAttribute("GravityCompensation") or DEFAULT_GRAVITY_COMPENSATION

	-- Create or get VectorForce
	local vf = seat:FindFirstChild("ControlForce")
	if not vf then
		vf = Instance.new("VectorForce")
		vf.Name = "ControlForce"
		vf.Parent = seat
		print("DEBUG: Created new ControlForce")
	end

	local attachment = seat:FindFirstChildOfClass("Attachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Parent = seat
	end

	vf.Attachment0 = attachment

	-- Calculate forces
	local currentVelocity = seat.AssemblyLinearVelocity
	local horizontalVelocity = Vector3.new(currentVelocity.X, 0, currentVelocity.Z)
	local verticalVelocity = math.abs(currentVelocity.Y)

	-- Horizontal forces (WASD movement)
	local localHorizontalForce = Vector3.new(steer * forceMagnitude, 0, throttle * -forceMagnitude)

	-- Vertical forces - gravity compensation
	local gravityCompensation = seat.AssemblyMass * workspace.Gravity * gravityCompensationMultiplier
	local verticalForce = gravityCompensation

	-- Add vertical thrust (X/C keys)
	if verticalThrust > 0 then
		verticalForce = verticalForce + (verticalThrust * verticalForceUp)
	elseif verticalThrust < 0 then
		verticalForce = verticalForce + (verticalThrust * verticalForceDown)
	end

	-- Transform horizontal force to world space
	local vehicleRotation = seat.CFrame.Rotation
	local worldHorizontalForce = vehicleRotation * localHorizontalForce

	-- Speed limiting for horizontal movement
	if horizontalVelocity.Magnitude >= maxHorizontalSpeed then
		local velocityDirection = horizontalVelocity.Unit
		local forceDirection = Vector3.new(worldHorizontalForce.X, 0, worldHorizontalForce.Z)
		if forceDirection.Magnitude > 0 then
			forceDirection = forceDirection.Unit
			if velocityDirection:Dot(forceDirection) > 0 then
				worldHorizontalForce = worldHorizontalForce * 0.1
			end
		end
	end

	-- Speed limiting for vertical movement
	if verticalVelocity >= maxVerticalSpeed then
		if (currentVelocity.Y > 0 and verticalThrust > 0) or (currentVelocity.Y < 0 and verticalThrust < 0) then
			verticalForce = (verticalForce - gravityCompensation) * 0.1 + gravityCompensation
		end
	end

	-- Apply final force vector
	local forceVector = Vector3.new(worldHorizontalForce.X, verticalForce, worldHorizontalForce.Z)
	vf.Force = forceVector
	vf.RelativeTo = Enum.ActuatorRelativeTo.World
end

-- Apply rotation function
local function applyRotationWithPitchLock()
	if not seat or not seat:IsDescendantOf(workspace) then
		return
	end

	-- Get seat type with additional nil check
	local seatType = "cruiser" -- Default value
	if seat and seat.GetAttribute then
		seatType = seat:GetAttribute("seattype") or "cruiser"
	end

	-- If position is locked, remove rotation controls
	if isPositionLocked then
		for _, child in ipairs(seat:GetChildren()) do
			if child.ClassName == "BodyAngularVelocity" and (child.Name == "ControlAngular" or child.Name == "TurretAngular") then
				child:Destroy()
			end
		end
		return
	end

	-- Handle rotation based on seat type
	if seatType == "cruiser" then
		-- Normal cruiser rotation with Q/E and A/D keys
		local bodyAngularVelocity = seat:FindFirstChild("ControlAngular")
		if not bodyAngularVelocity then
			bodyAngularVelocity = Instance.new("BodyAngularVelocity")
			bodyAngularVelocity.Name = "ControlAngular"
			bodyAngularVelocity.Parent = seat
		end

		local rotateSpeed = seat:GetAttribute("RotateSpeed") or DEFAULT_ROTATE_SPEED
		local targetAngularVelocity = Vector3.new(0, rotate * rotateSpeed * 10, 0)
		bodyAngularVelocity.AngularVelocity = targetAngularVelocity
		bodyAngularVelocity.MaxTorque = Vector3.new(50000, 50000, 50000)
		bodyAngularVelocity.P = 10000
	elseif seatType == "turret" or seatType == "2xturret" then
		-- Turret rotation follows mouse movement
		handleTurretRotation(seat, seatType)
	end
end

-- Force restore function
local function forceRestoreControl()
	if not seat then
		return
	end

	local controlForce = seat:FindFirstChild("ControlForce")
	if controlForce then
		controlForce:Destroy()
	end

	applyForce()
end

-- Camera functions
local function fixVehicleCamera()
	if player.Character and player.Character:FindFirstChild("Humanoid") then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = player.Character.Humanoid
	end
end

-- Function to update vehicle state (simplified version)
local function updateVehicleState(vehicleSeat)
	if not vehicleSeat then
		return
	end
	
	-- Read actual state from server
	local serverGravComp = vehicleSeat:GetAttribute("GravityCompensation") or DEFAULT_GRAVITY_COMPENSATION
	local serverPositionLocked = vehicleSeat:GetAttribute("PositionLocked") or false
	
	-- Update our local state
	isPositionLocked = serverPositionLocked
	
	print("CLIENT: Updated vehicle state - Hover:", serverGravComp >= 1.0, "Locked:", serverPositionLocked)
end

-- Handle seat occupancy
local function handleSeatOccupancy(vehicleSeat)
	if vehicleSeat.Occupant then
		-- Player entered seat
		if vehicleSeat.Occupant.Parent == player.Character then
			seat = vehicleSeat
			isInVehicle = true
			isPositionLocked = vehicleSeat:GetAttribute("PositionLocked") or false
			createControlGUI()
			updateGUIVisibility()
			print("CLIENT: Entered vehicle seat:", vehicleSeat.Name)
			
			-- Update state from server
			updateVehicleState(vehicleSeat)
			updateButtonState()
			
			-- Create connection for this seat to monitor attribute changes
			if not seatConnections[vehicleSeat] then
				print("CLIENT: Setting up attribute change listeners for", vehicleSeat.Name)
				seatConnections[vehicleSeat] = vehicleSeat.AttributeChanged:Connect(function(attributeName)
					print("CLIENT: Attribute changed:", attributeName, "on", vehicleSeat.Name)
					if attributeName == "GravityCompensation" or attributeName == "PositionLocked" then
						print("CLIENT: Updating button state due to attribute change:", attributeName)
						updateVehicleState(vehicleSeat)
						updateButtonState()
					elseif attributeName == "weapontype" then
						print("CLIENT: Weapon type changed - updating GUI visibility")
						updateGUIVisibility()
					end
				end)
			end
		end
	else
		-- Player left seat
		if seat == vehicleSeat then
			seat = nil
			isInVehicle = false
			isPositionLocked = false
			updateGUIVisibility()
			print("CLIENT: Exited vehicle seat:", vehicleSeat.Name)
			throttle = 0
			steer = 0
			rotate = 0
			verticalThrust = 0
			
			-- Reset key states
			for key, _ in pairs(keysPressed) do
				keysPressed[key] = false
			end
			
			updateButtonState()
			fixVehicleCamera()
			
			-- Disconnect seat-specific connections
			if seatConnections[vehicleSeat] then
				seatConnections[vehicleSeat]:Disconnect()
				seatConnections[vehicleSeat] = nil
			end
		end
	end
end

-- Monitor all vehicle seats
local function monitorVehicleSeats()
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("VehicleSeat") then
			-- Connect to occupancy changes
			obj:GetPropertyChangedSignal("Occupant"):Connect(function()
				handleSeatOccupancy(obj)
			end)
			
			-- Check current occupancy
			handleSeatOccupancy(obj)
		end
	end
end

-- Monitor for new vehicle seats
workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("VehicleSeat") then
		obj:GetPropertyChangedSignal("Occupant"):Connect(function()
			handleSeatOccupancy(obj)
		end)
		handleSeatOccupancy(obj)
	end
end)

-- Input handling
local function handleInput(input, gameProcessed)
	if gameProcessed or not isInVehicle then
		return
	end

	local keyCode = input.KeyCode
	local inputType = input.UserInputType

	if inputType == Enum.UserInputType.Keyboard then
		if keyCode == Enum.KeyCode.W then
			keysPressed.W = true
		elseif keyCode == Enum.KeyCode.A then
			keysPressed.A = true
		elseif keyCode == Enum.KeyCode.S then
			keysPressed.S = true
		elseif keyCode == Enum.KeyCode.D then
			keysPressed.D = true
		elseif keyCode == Enum.KeyCode.Q then
			keysPressed.Q = true
		elseif keyCode == Enum.KeyCode.E then
			keysPressed.E = true
		elseif keyCode == Enum.KeyCode.X then
			keysPressed.X = true
		elseif keyCode == Enum.KeyCode.C then
			keysPressed.C = true
		elseif keyCode == Enum.KeyCode.Space then
			-- Fire weapon
			if seat then
				fireCannon(seat)
			end
		elseif keyCode == Enum.KeyCode.F then
			-- Toggle hover
			if seat then
				local currentHover = seat:GetAttribute("GravityCompensation") or DEFAULT_GRAVITY_COMPENSATION
				local newHoverState = currentHover < 1.0 -- If currently off, turn on
				print("CLIENT: F key pressed - toggling hover to:", newHoverState)
				hoverToggleEvent:FireServer(seat, newHoverState)
				-- Button state will update automatically via attribute change listener
			end
		elseif keyCode == Enum.KeyCode.G then
			-- Toggle position lock
			if seat then
				local currentLock = seat:GetAttribute("PositionLocked") or false
				local lockCommand = currentLock and "unlock_position" or "lock_position"
				print("CLIENT: G key pressed - sending command:", lockCommand)
				hoverToggleEvent:FireServer(seat, lockCommand)
				-- Button state will update automatically via attribute change listener
			end
		elseif keyCode == Enum.KeyCode.V then
			-- Debug output
			debugVehicleState()
		end
	elseif inputType == Enum.UserInputType.MouseButton1 then
		-- Fire weapon with mouse
		if seat then
			fireCannon(seat)
		end
	end
end

local function handleInputEnd(input, gameProcessed)
	if gameProcessed or not isInVehicle then
		return
	end

	local keyCode = input.KeyCode
	local inputType = input.UserInputType

	if inputType == Enum.UserInputType.Keyboard then
		if keyCode == Enum.KeyCode.W then
			keysPressed.W = false
		elseif keyCode == Enum.KeyCode.A then
			keysPressed.A = false
		elseif keyCode == Enum.KeyCode.S then
			keysPressed.S = false
		elseif keyCode == Enum.KeyCode.D then
			keysPressed.D = false
		elseif keyCode == Enum.KeyCode.Q then
			keysPressed.Q = false
		elseif keyCode == Enum.KeyCode.E then
			keysPressed.E = false
		elseif keyCode == Enum.KeyCode.X then
			keysPressed.X = false
		elseif keyCode == Enum.KeyCode.C then
			keysPressed.C = false
		end
	end
end

-- Update control values based on key states
local function updateControlValues()
	if not isInVehicle then
		return
	end

	-- Throttle (W/S)
	if keysPressed.W and not keysPressed.S then
		throttle = 1
	elseif keysPressed.S and not keysPressed.W then
		throttle = -1
	else
		throttle = 0
	end

	-- Steer (A/D)
	if keysPressed.A and not keysPressed.D then
		steer = -1
	elseif keysPressed.D and not keysPressed.A then
		steer = 1
	else
		steer = 0
	end

	-- Rotate (Q/E)
	if keysPressed.Q and not keysPressed.E then
		rotate = -1
	elseif keysPressed.E and not keysPressed.Q then
		rotate = 1
	else
		rotate = 0
	end

	-- Vertical thrust (X/C)
	if keysPressed.X and not keysPressed.C then
		verticalThrust = 1
	elseif keysPressed.C and not keysPressed.X then
		verticalThrust = -1
	else
		verticalThrust = 0
	end
	
	-- Handle turret rotation if this is a turret seat
	if seat then
		local weaponType = seat:GetAttribute("weapontype") or "None"
		if weaponType == "turret" or weaponType == "2xturret" then
			handleTurretRotation(seat, weaponType)
		end
	end
end

-- Function to connect button handlers (called after GUI creation)
local function connectButtonHandlers()
	if hoverButton then
		hoverButton.MouseButton1Click:Connect(function()
			if seat then
				-- Toggle hover: send true/false based on current state
				local currentHover = seat:GetAttribute("GravityCompensation") or DEFAULT_GRAVITY_COMPENSATION
				local newHoverState = currentHover < 1.0 -- If currently off, turn on
				print("CLIENT: Hover button clicked - toggling to:", newHoverState)
				hoverToggleEvent:FireServer(seat, newHoverState)
				-- Button state will update automatically via attribute change listener
			end
		end)
	end
	
	if lockButton then
		lockButton.MouseButton1Click:Connect(function()
			if seat then
				-- Toggle lock: send lock_position/unlock_position based on current state
				local currentLock = seat:GetAttribute("PositionLocked") or false
				local lockCommand = currentLock and "unlock_position" or "lock_position"
				print("CLIENT: Lock button clicked - sending command:", lockCommand)
				hoverToggleEvent:FireServer(seat, lockCommand)
				-- Button state will update automatically via attribute change listener
			end
		end)
	end
end

-- Connect input events
UserInputService.InputBegan:Connect(handleInput)
UserInputService.InputEnded:Connect(handleInputEnd)

-- Main update loop
RunService.Heartbeat:Connect(function()
	updateControlValues()
	applyForce()
	applyRotationWithPitchLock()
end)

-- Initialize
monitorVehicleSeats()
createControlGUI()
connectButtonHandlers()
updateGUIVisibility()

print("CLIENT: Vehicle Control System loaded")
