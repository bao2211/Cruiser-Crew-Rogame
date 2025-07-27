local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

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

-- Note: Explosions are now handled server-side for security and synchronization

-- Function to fire cannon projectile (now uses RemoteEvent)
local function fireCannon(vehicleSeat)
	if not vehicleSeat or not vehicleSeat:IsA("VehicleSeat") then
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
	
	-- Immediate client feedback - play sound
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
		-- Dual axis turret - face the mouse position in 3D space with deadzone
		local deadZoneRadius = 50 -- Pixels from center
		local distanceFromCenter = math.sqrt(mouseOffsetX^2 + mouseOffsetY^2)
		
		if distanceFromCenter < deadZoneRadius then
			-- Inside deadzone - no rotation
			bodyAngular.AngularVelocity = Vector3.new(0, 0, 0)
		else
			-- Outside deadzone - face the mouse position
			-- Create a ray from camera through mouse position
			local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
			
			-- Cast ray to find world position
			local raycastParams = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Exclude
			raycastParams.FilterDescendantsInstances = {vehicleSeat.Parent} -- Don't hit the vehicle itself
			
			local raycastResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)
			local targetPosition
			
			if raycastResult then
				targetPosition = raycastResult.Position
			else
				-- If no hit, use a point far in the direction
				targetPosition = unitRay.Origin + unitRay.Direction * 1000
			end
			
			-- Calculate direction from seat to target
			local seatPosition = vehicleSeat.Position
			local direction = (targetPosition - seatPosition).Unit
			
			-- Get current seat forward direction
			local currentForward = vehicleSeat.CFrame.LookVector
			
			-- Calculate angular velocity needed to face the target
			local cross = currentForward:Cross(direction)
			local dot = currentForward:Dot(direction)
			
			-- Convert to angular velocity with speed control
			local angularSpeed = 8 -- Adjust for tracking speed
			local targetAngularVelocity = cross * angularSpeed * (1 - dot)
			
			-- Limit pitch to prevent flipping upside down
			local maxPitch = 1.2 -- About 70 degrees
			targetAngularVelocity = Vector3.new(
				math.clamp(targetAngularVelocity.X, -maxPitch, maxPitch),
				targetAngularVelocity.Y,
				0 -- No roll
			)
			
			bodyAngular.AngularVelocity = targetAngularVelocity
			bodyAngular.MaxTorque = Vector3.new(math.huge, math.huge, 0) -- Allow X and Y rotation
		end
	end
	
	bodyAngular.P = 10000
end

-- Get UI elements from PlayerGui (they're copied from StarterGui automatically)
local playerGui = player:WaitForChild("PlayerGui")
local vehicleControlGUI = playerGui:WaitForChild("VehicleControlGUI")
local mainFrame = vehicleControlGUI:WaitForChild("MainFrame")
local hoverButton = mainFrame:WaitForChild("HoverButton")
local lockButton = mainFrame:WaitForChild("LockButton")

print("GUI elements found successfully")

-- Camera management
local camera = Workspace.CurrentCamera

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
	print("CLIENT: Forces restored immediately after unlock")
end

-- Camera functions
local function fixVehicleCamera()
	if player.Character and player.Character:FindFirstChild("Humanoid") then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = player.Character.Humanoid
		print("CLIENT: Camera fixed")
	end
end

-- Add this near the top with other variables
local vehicleStates = {} -- Track state of all vehicles individually

-- Function to get or create vehicle state
local function getVehicleState(vehicleSeat)
	local seatName = vehicleSeat.Name
	if not vehicleStates[seatName] then
		-- Initialize new vehicle state with server's actual state
		vehicleStates[seatName] = {
			gravityCompensation = vehicleSeat:GetAttribute("GravityCompensation") or DEFAULT_GRAVITY_COMPENSATION,
			positionLocked = vehicleSeat:GetAttribute("PositionLocked") or false,
			isHovering = (vehicleSeat:GetAttribute("GravityCompensation") or DEFAULT_GRAVITY_COMPENSATION) >= 1.0,
		}
		print("Created new state for vehicle:", seatName, vehicleStates[seatName])
	end
	return vehicleStates[seatName]
end

-- Function to update vehicle state
local function updateVehicleState(vehicleSeat)
	local seatName = vehicleSeat.Name
	local state = getVehicleState(vehicleSeat)

	-- Read actual state from server
	local serverGravComp = vehicleSeat:GetAttribute("GravityCompensation") or DEFAULT_GRAVITY_COMPENSATION
	local serverPositionLocked = vehicleSeat:GetAttribute("PositionLocked") or false

	-- Update our tracked state
	state.gravityCompensation = serverGravComp
	state.positionLocked = serverPositionLocked
	state.isHovering = serverGravComp >= 1.0

	print("Updated state for", seatName, "- Hover:", state.isHovering, "Locked:", state.positionLocked)
	return state
end

-- Function to update UI based on vehicle seat attributes
local function updateUIFromSeatAttributes(vehicleSeat)
    -- Directly read attributes from the VehicleSeat
    local gravComp = vehicleSeat:GetAttribute("GravityCompensation") or 0
    local positionLocked = vehicleSeat:GetAttribute("PositionLocked") or false
    
    -- Update UI buttons based on vehicle seat attributes
    hoverButton.BackgroundColor3 = gravComp >= 1.0 and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    lockButton.BackgroundColor3 = positionLocked and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
end

-- Update button states - FIXED VERSION
local function updateButtonState()
	if not hoverButton or not lockButton then
		return
	end

	if not seat then
		-- No seat - hide the entire UI
		vehicleControlGUI.Enabled = false
		return
	end

	-- Show UI when in vehicle seat
	vehicleControlGUI.Enabled = true

	-- Update UI from VehicleSeat attributes
	updateUIFromSeatAttributes(seat)

	-- Read the ACTUAL current state from the vehicle seat
	local currentGravComp = seat:GetAttribute("GravityCompensation") or DEFAULT_GRAVITY_COMPENSATION
	local currentPositionLocked = seat:GetAttribute("PositionLocked") or false

	-- Update our local state to match the vehicle's state
	isPositionLocked = currentPositionLocked

	print("Updating UI for", seat.Name, "- Hover:", (currentGravComp >= 1.0), "Locked:", currentPositionLocked)

	if currentGravComp >= 1.0 then
		hoverButton.Text = "Disable Hover"
		lockButton.Visible = true

		if currentPositionLocked then
			lockButton.Text = "Unlock Position"
			print("UI: Showing unlock button for", seat.Name)
		else
			lockButton.Text = "Lock Position"
			print("UI: Showing lock button for", seat.Name)
		end
	else
		hoverButton.Text = "Enable Hover"
		lockButton.Visible = false
		isPositionLocked = false
	end
end

-- Animation functions - FIXED GroupTransparency issue
local function showUI()
	vehicleControlGUI.Enabled = true
	print("CLIENT: UI shown")
end

local function hideUI()
	vehicleControlGUI.Enabled = false
	print("CLIENT: UI hidden")
end

-- Initialize with UI hidden - SIMPLE VERSION
vehicleControlGUI.Enabled = false
print("CLIENT: UI initially hidden")

-- Seat change handler - MULTI-VEHICLE VERSION
local function onSeatChanged()
	-- Check current actual seating state
	local actuallySeated = false
	local actualSeat = nil

	if player.Character and player.Character:FindFirstChild("Humanoid") then
		local humanoid = player.Character.Humanoid
		if humanoid and humanoid.SeatPart and humanoid.SeatPart:IsA("VehicleSeat") then
			actuallySeated = true
			actualSeat = humanoid.SeatPart
		end
	end

	print("onSeatChanged called - seat variable:", seat and seat.Name or "nil")
	print("Actually seated:", actuallySeated, "in:", actualSeat and actualSeat.Name or "nil")

	if seat and actuallySeated and actualSeat == seat then
		-- We're properly seated in the current vehicle
		print("CONFIRMED: Seated in vehicle:", seat.Name)
		isInVehicle = true

		-- Show UI when entering vehicle
		showUI()
		print("CLIENT: UI shown - entered vehicle")

		-- Clean up any existing connections first
		local oldGravityConn = seat:GetAttribute("_gravityConnection")
		local oldLockConn = seat:GetAttribute("_lockConnection")
		if oldGravityConn and typeof(oldGravityConn) == "RBXScriptConnection" then
			oldGravityConn:Disconnect()
		end
		if oldLockConn and typeof(oldLockConn) == "RBXScriptConnection" then
			oldLockConn:Disconnect()
		end

		-- Get or create state for THIS vehicle
		local vehicleState = getVehicleState(seat)
		print("Loaded state for", seat.Name, ":", vehicleState)

		-- Sync our local state with THIS vehicle's state
		isPositionLocked = vehicleState.positionLocked

		-- Add fresh attribute listeners
		local gravityConnection
		local lockConnection

		gravityConnection = seat:GetAttributeChangedSignal("GravityCompensation"):Connect(function()
			-- Update the state for this specific vehicle
			local updatedState = updateVehicleState(seat)
			updateUIFromSeatAttributes(seat) -- Update UI immediately when gravity changes
			updateButtonState()
		end)

		lockConnection = seat:GetAttributeChangedSignal("PositionLocked"):Connect(function()
			-- Update the state for this specific vehicle
			local updatedState = updateVehicleState(seat)
			updateUIFromSeatAttributes(seat) -- Update UI immediately when lock changes

			if updatedState.positionLocked ~= isPositionLocked then
				isPositionLocked = updatedState.positionLocked
				print("CLIENT: Position lock state changed to:", isPositionLocked, "for", seat.Name)

				if not isPositionLocked then
					task.spawn(function()
						task.wait(0.05)
						forceRestoreControl()
					end)
				end

				updateButtonState()
			end
		end)

		-- Store connections locally instead of in attributes
		local connections = {
			gravity = gravityConnection,
			lock = lockConnection
		}

		-- Store connections in a local table instead of attributes
		seatConnections[seat] = connections

		-- Update UI to reflect THIS vehicle's current state
		updateUIFromSeatAttributes(seat) -- Update UI from current seat attributes
		updateButtonState()
	else
		-- We're not in a vehicle (or switching vehicles)
		print("CONFIRMED: Exited vehicle or switching")
		isInVehicle = false

		-- Hide UI when exiting vehicle
		hideUI()
		print("CLIENT: UI hidden - exited vehicle")

		-- Clean up old vehicle if we have a reference
		local oldSeat = seat
		if oldSeat then
			print("Cleaning up old seat:", oldSeat.Name)

			-- Save the final state of the vehicle we're leaving
			local vehicleState = getVehicleState(oldSeat)
			print("Saved final state for", oldSeat.Name, ":", vehicleState)

			-- Clean up connections
			local connections = seatConnections[oldSeat]
			if connections then
				if connections.gravity then
					connections.gravity:Disconnect()
					print("Disconnected gravity connection")
				end
				if connections.lock then
					connections.lock:Disconnect()
					print("Disconnected lock connection")
				end
				
				-- Remove from connections table
				seatConnections[oldSeat] = nil
			end

			-- Remove all client forces and rotation controls
			local controlForce = oldSeat:FindFirstChild("ControlForce")
			if controlForce then
				controlForce:Destroy()
				print("Removed ControlForce")
			end

			local controlAngular = oldSeat:FindFirstChild("ControlAngular")
			if controlAngular then
				controlAngular:Destroy()
				print("Removed ControlAngular")
			end

			-- Send cleanup request to server
			hoverToggleEvent:FireServer(oldSeat, "player_exited")
		end

		-- Reset control variables (but preserve vehicle states)
		throttle = 0
		steer = 0
		rotate = 0
		verticalThrust = 0

		-- Reset all key states
		for key, _ in pairs(keysPressed) do
			keysPressed[key] = false
		end

		print("CLIENT: Cleaned up - vehicle states preserved for future use")
	end
end

-- Seat detection setup - COMPLETE VERSION
local function setupSeatDetection()
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then
		return
	end

	humanoid.Seated:Connect(function(isSeated, seatPart)
		print("=== SEAT EVENT ===")
		print("isSeated:", isSeated)
		print("seatPart:", seatPart)
		print("Current seat variable:", seat and seat.Name or "nil")
		print("=================")

		if isSeated and seatPart and seatPart:IsA("VehicleSeat") then
			-- Player sat in a VehicleSeat
			print("ENTERING VEHICLE:", seatPart.Name)

			-- If we were in a different vehicle, clean up the old one first
			if seat and seat ~= seatPart then
				print("SWITCHING VEHICLES - Cleaning up old vehicle:", seat.Name)
				local oldSeat = seat
				seat = nil -- Temporarily set to nil to trigger cleanup
				onSeatChanged() -- This will clean up the old vehicle
			end

			-- Set new seat and enter
			seat = seatPart
			print("SETTING NEW SEAT TO:", seat.Name)
			onSeatChanged()
		elseif not isSeated then
			-- Player left seat completely
			print("EXITING VEHICLE")
			if seat then
				print("CLEANING UP VEHICLE:", seat.Name)
				seat = nil -- Set to nil to trigger exit cleanup
				onSeatChanged()
			end
		end
	end)

	-- Check if already seated when script starts
	if humanoid.Sit and humanoid.SeatPart and humanoid.SeatPart:IsA("VehicleSeat") then
		seat = humanoid.SeatPart
		print("Already seated in:", seat.Name)
		onSeatChanged()
	end
end

-- Connect hover button - FIXED to update state first
hoverButton.MouseButton1Click:Connect(function()
	print("Hover button clicked!")
	if seat then
		-- Update state first, then check it
		local vehicleState = updateVehicleState(seat)

		if vehicleState.isHovering then
			hoverToggleEvent:FireServer(seat, false)
			print("Requesting hover disable for", seat.Name)
		else
			hoverToggleEvent:FireServer(seat, true)
			print("Requesting hover enable for", seat.Name)
		end
	else
		print("CLIENT: Not seated in vehicle")
	end
end)

-- Connect lock button - FIXED to update state first
lockButton.MouseButton1Click:Connect(function()
	print("Lock button clicked!")
	if seat then
		-- Update state first, then check it
		local vehicleState = updateVehicleState(seat)

		if vehicleState.isHovering then
			if vehicleState.positionLocked then
				-- Currently locked - unlock it
				hoverToggleEvent:FireServer(seat, "unlock_position")
				print("CLIENT: Unlock requested for", seat.Name)
			else
				-- Currently unlocked - lock it
				hoverToggleEvent:FireServer(seat, "lock_position")
				print("CLIENT: Lock requested for", seat.Name)
			end
		else
			print("CLIENT: Must enable hover first for", seat.Name)
		end
	else
		print("CLIENT: Not seated in vehicle")
	end
end)

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	local keyCode = input.KeyCode

	if keyCode == Enum.KeyCode.F then
		fixVehicleCamera()
		return
	end

	if keyCode == Enum.KeyCode.W then
		keysPressed.W = true
		throttle = 1
	elseif keyCode == Enum.KeyCode.S then
		keysPressed.S = true
		throttle = -1
	elseif keyCode == Enum.KeyCode.A then
		keysPressed.A = true
		steer = -1
	elseif keyCode == Enum.KeyCode.D then
		keysPressed.D = true
		steer = 1
	elseif keyCode == Enum.KeyCode.Q then
		keysPressed.Q = true
		rotate = -1
	elseif keyCode == Enum.KeyCode.E then
		keysPressed.E = true
		rotate = 1
	elseif keyCode == Enum.KeyCode.X then
		keysPressed.X = true
		verticalThrust = 2
	elseif keyCode == Enum.KeyCode.C then
		keysPressed.C = true
		verticalThrust = -2
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	local keyCode = input.KeyCode
	if keyCode == Enum.KeyCode.W then
		keysPressed.W = false
		if not keysPressed.S then
			throttle = 0
		end
	elseif keyCode == Enum.KeyCode.S then
		keysPressed.S = false
		if not keysPressed.W then
			throttle = 0
		end
	elseif keyCode == Enum.KeyCode.A then
		keysPressed.A = false
		if not keysPressed.D then
			steer = 0
		end
	elseif keyCode == Enum.KeyCode.D then
		keysPressed.D = false
		if not keysPressed.A then
			steer = 0
		end
	elseif keyCode == Enum.KeyCode.Q then
		keysPressed.Q = false
		if not keysPressed.E then
			rotate = 0
		end
	elseif keyCode == Enum.KeyCode.E then
		keysPressed.E = false
		if not keysPressed.Q then
			rotate = 0
		end
	elseif keyCode == Enum.KeyCode.X then
		keysPressed.X = false
		if not keysPressed.C then
			verticalThrust = 0
		end
	elseif keyCode == Enum.KeyCode.C then
		keysPressed.C = false
		if not keysPressed.X then
			verticalThrust = 0
		end
	end
end)

-- Character spawning
player.CharacterAdded:Connect(function()
	task.wait(1)
	setupSeatDetection()
end)

-- Input handling for weapon firing and controls
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		-- Left mouse click - check for weapon firing
		if seat and isInVehicle then
			local weaponType = seat:GetAttribute("weapontype")
			if weaponType == "Cannon" then
				fireCannon(seat)
			end
		end
	elseif input.KeyCode == Enum.KeyCode.W then
		keysPressed.W = true
	elseif input.KeyCode == Enum.KeyCode.A then
		keysPressed.A = true
	elseif input.KeyCode == Enum.KeyCode.S then
		keysPressed.S = true
	elseif input.KeyCode == Enum.KeyCode.D then
		keysPressed.D = true
	elseif input.KeyCode == Enum.KeyCode.Q then
		keysPressed.Q = true
	elseif input.KeyCode == Enum.KeyCode.E then
		keysPressed.E = true
	elseif input.KeyCode == Enum.KeyCode.X then
		keysPressed.X = true
	elseif input.KeyCode == Enum.KeyCode.C then
		keysPressed.C = true
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.W then
		keysPressed.W = false
	elseif input.KeyCode == Enum.KeyCode.A then
		keysPressed.A = false
	elseif input.KeyCode == Enum.KeyCode.S then
		keysPressed.S = false
	elseif input.KeyCode == Enum.KeyCode.D then
		keysPressed.D = false
	elseif input.KeyCode == Enum.KeyCode.Q then
		keysPressed.Q = false
	elseif input.KeyCode == Enum.KeyCode.E then
		keysPressed.E = false
	elseif input.KeyCode == Enum.KeyCode.X then
		keysPressed.X = false
	elseif input.KeyCode == Enum.KeyCode.C then
		keysPressed.C = false
	end
end)

-- Update control variables based on key states
local function updateControlsFromKeys()
	if not seat or not isInVehicle then
		return
	end
	
	-- Movement controls (WASD)
	throttle = 0
	steer = 0
	if keysPressed.W then throttle = throttle + 1 end
	if keysPressed.S then throttle = throttle - 1 end
	if keysPressed.A then steer = steer - 1 end
	if keysPressed.D then steer = steer + 1 end
	
	-- Rotation controls (Q/E)
	rotate = 0
	if keysPressed.Q or keysPressed.A then rotate = rotate - 1 end
	if keysPressed.E or keysPressed.D then rotate = rotate + 1 end
	
	-- Vertical thrust (X/C)
	verticalThrust = 0
	if keysPressed.X then verticalThrust = verticalThrust + 1 end
	if keysPressed.C then verticalThrust = verticalThrust - 1 end
end

if player.Character then
	setupSeatDetection()
end

-- Main loop - COMPLETE VERSION
RunService.RenderStepped:Connect(function()
	-- Validate that we're actually still in the seat
	local actuallyInSeat = false
	if seat and player.Character then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and seat.Occupant == humanoid then
			actuallyInSeat = true -- FIX: Complete this line
		end
	end

	if seat and actuallyInSeat then
		-- Update controls from key states
		updateControlsFromKeys()
		
		if tick() % 1 < 0.016 then
			debugVehicleState()
		end

		applyForce()
		applyRotationWithPitchLock()

		if isPositionLocked then
			seat.Throttle = 0
			seat.Steer = 0
			throttle = 0
			steer = 0
			rotate = 0
		else
			seat.Throttle = throttle
			seat.Steer = steer
		end
	elseif seat then
		-- We have a seat reference but we're not actually in it
		-- This can happen during quick seat switches
		print("DETECTED: Seat reference mismatch - triggering cleanup")
		seat = nil
		onSeatChanged()
	end
end)

print("Hello world, from client!")

-- ========================================
-- CHAMBER INSPECTOR FUNCTIONALITY
-- ========================================

-- Chamber inspection variables
local inspectionMode = false
local activeGUIs = {}
local lastInspectionUpdate = 0
local INSPECTION_RANGE = 10 -- studs
local INSPECTION_UPDATE_INTERVAL = 0.2 -- seconds
local GUI_OFFSET = Vector3.new(0, 3, 0) -- offset above chamber

-- Create floating GUI for chamber
local function createChamberGUI(chamber)
	-- Remove existing GUI if present
	if activeGUIs[chamber] then
		activeGUIs[chamber]:Destroy()
		activeGUIs[chamber] = nil
	end
	
	-- Create BillboardGui
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "ChamberInspectorGUI"
	billboardGui.Adornee = chamber
	billboardGui.Size = UDim2.new(0, 300, 0, 200)
	billboardGui.StudsOffset = GUI_OFFSET
	billboardGui.LightInfluence = 0
	billboardGui.Parent = chamber
	
	-- Create main frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(1, 0, 1, 0)
	mainFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	mainFrame.BackgroundTransparency = 0.3
	mainFrame.BorderSizePixel = 2
	mainFrame.BorderColor3 = Color3.new(1, 1, 0) -- Yellow border
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
	scrollFrame.Size = UDim2.new(1, -15, 1, -35)  -- More space for scrollbar
	scrollFrame.Position = UDim2.new(0, 5, 0, 30)
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
		attrFrame.Size = UDim2.new(1, -15, 0, 25)  -- Taller rows, account for scrollbar
		attrFrame.BackgroundTransparency = 1
		attrFrame.Parent = scrollFrame
		
		-- Attribute name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "Name"
		nameLabel.Size = UDim2.new(0.4, 0, 1, 0)
		nameLabel.Position = UDim2.new(0, 0, 0, 0)
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
		valueLabel.Size = UDim2.new(0.55, -10, 1, 0)  -- Leave space for scrollbar
		valueLabel.Position = UDim2.new(0.4, 0, 0, 0)
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
		if obj:IsA("BasePart") and obj.Name:lower():find("chamber") then
			local distance = (obj.Position - playerPosition).Magnitude
			if distance <= INSPECTION_RANGE then
				table.insert(nearbyChambers, obj)
			end
		end
	end
	
	return nearbyChambers
end

-- Update chamber GUIs
local function updateChamberInspection()
	if not inspectionMode then
		return
	end
	
	local currentTime = tick()
	if currentTime - lastInspectionUpdate < INSPECTION_UPDATE_INTERVAL then
		return
	end
	lastInspectionUpdate = currentTime
	
	local nearbyChambers = findNearbyChambers()
	local nearbySet = {}
	
	-- Create set of nearby chambers
	for _, chamber in ipairs(nearbyChambers) do
		nearbySet[chamber] = true
	end
	
	-- Remove GUIs for chambers that are no longer nearby
	for chamber, gui in pairs(activeGUIs) do
		if not nearbySet[chamber] then
			removeChamberGUI(chamber)
		end
	end
	
	-- Create GUIs for new nearby chambers
	for _, chamber in ipairs(nearbyChambers) do
		if not activeGUIs[chamber] then
			createChamberGUI(chamber)
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
		for chamber, gui in pairs(activeGUIs) do
			removeChamberGUI(chamber)
		end
	end
end

print("CLIENT: Chamber Inspector loaded - Press T to toggle inspection mode")

-- ===== HEALTH INSPECTOR SYSTEM =====

-- Health inspector configuration
local HEALTH_INSPECTION_RANGE = 8  -- studs detection range
local HEALTH_UPDATE_INTERVAL = 0.3  -- seconds between updates
local HEALTH_GUI_OFFSET = Vector3.new(0, 2, 0)  -- height above part

-- Health inspector state
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
	for part, gui in pairs(activeHealthGUIs) do
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
		for part, gui in pairs(activeHealthGUIs) do
			removeHealthGUI(part)
		end
	end
end

print("CLIENT: Health Inspector loaded - Press H to toggle health inspection mode")

-- Add T and H key handling for inspection toggles
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.T then
		toggleInspectionMode()
	elseif input.KeyCode == Enum.KeyCode.H then
		toggleHealthInspectionMode()
	end
end)

-- Add inspection updates to main loop
RunService.Heartbeat:Connect(function()
	updateChamberInspection()
	updateHealthInspection()
end)
