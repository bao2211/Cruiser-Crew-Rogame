local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- Wait for RemoteEvents
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local hoverToggleEvent = remoteEvents:WaitForChild("HoverToggle")

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

	-- If position is locked, remove rotation controls
	if isPositionLocked then
		for _, child in ipairs(seat:GetChildren()) do
			if child.ClassName == "BodyAngularVelocity" and child.Name == "ControlAngular" then
				child:Destroy()
			end
		end
		return
	end

	-- Get or create rotation control
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
