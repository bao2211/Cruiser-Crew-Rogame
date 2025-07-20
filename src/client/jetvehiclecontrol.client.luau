local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

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

-- GUI elements
local screenGui, hoverButton, lockButton

-- Camera management
local camera = Workspace.CurrentCamera
local isInVehicle = false

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

-- Camera functions (simplified)
local function fixVehicleCamera()
	if player.Character and player.Character:FindFirstChild("Humanoid") then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = player.Character.Humanoid
		print("CLIENT: Camera fixed")
	end
end

-- Create GUI function
local function createGUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "VehicleControlGUI"
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(0, 300, 0, 170)
	mainFrame.Position = UDim2.new(0, 10, 0, 10)
	mainFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	mainFrame.BorderSizePixel = 2
	mainFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
	mainFrame.Parent = screenGui

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0, 30)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Vehicle Controls"
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = 18
	titleLabel.Font = Enum.Font.SourceSansBold
	titleLabel.Parent = mainFrame

	local hoverButton = Instance.new("TextButton")
	hoverButton.Size = UDim2.new(0.45, -5, 0, 40)
	hoverButton.Position = UDim2.new(0, 5, 0, 35)
	hoverButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	hoverButton.Text = "Enable Hover"
	hoverButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	hoverButton.TextSize = 14
	hoverButton.Font = Enum.Font.SourceSans
	hoverButton.Parent = mainFrame

	local lockButton = Instance.new("TextButton")
	lockButton.Size = UDim2.new(0.45, -5, 0, 40)
	lockButton.Position = UDim2.new(0.55, 0, 0, 35)
	lockButton.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
	lockButton.Text = "Lock Position"
	lockButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	lockButton.TextSize = 14
	lockButton.Font = Enum.Font.SourceSans
	lockButton.Parent = mainFrame

	local controlsLabel = Instance.new("TextLabel")
	controlsLabel.Size = UDim2.new(1, -10, 0, 80)
	controlsLabel.Position = UDim2.new(0, 5, 0, 85)
	controlsLabel.BackgroundTransparency = 1
	controlsLabel.Text = "WASD: Move | QE: Rotate\nX: Thrust Up | C: Thrust Down\nF: Fix Camera"
	controlsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	controlsLabel.TextSize = 12
	controlsLabel.Font = Enum.Font.SourceSans
	controlsLabel.TextYAlignment = Enum.TextYAlignment.Top
	controlsLabel.Parent = mainFrame

	return screenGui, hoverButton, lockButton
end

-- Update button states
local function updateButtonState()
	if not seat or not hoverButton or not lockButton then
		return
	end

	local currentGravComp = seat:GetAttribute("GravityCompensation") or DEFAULT_GRAVITY_COMPENSATION
	print("Updating button state - GravComp:", currentGravComp)

	if currentGravComp >= 1.0 then
		hoverButton.Text = "Disable Hover"
		hoverButton.BackgroundColor3 = Color3.fromRGB(50, 100, 50)
		lockButton.Visible = true

		if isPositionLocked then
			lockButton.Text = "Unlock Position"
			lockButton.BackgroundColor3 = Color3.fromRGB(100, 100, 50)
		else
			lockButton.Text = "Lock Position"
			lockButton.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
		end
	else
		hoverButton.Text = "Enable Hover"
		hoverButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
		lockButton.Visible = false
		isPositionLocked = false
	end
end

-- Seat change handler - DEFINE BEFORE USE
local function onSeatChanged()
	if seat then
		print("Seated in vehicle:", seat.Name)
		isInVehicle = true

		-- Add attribute listeners
		local gravityConnection = seat:GetAttributeChangedSignal("GravityCompensation"):Connect(function()
			updateButtonState()
		end)

		local lockConnection = seat:GetAttributeChangedSignal("PositionLocked"):Connect(function()
			local serverLocked = seat:GetAttribute("PositionLocked") or false

			if serverLocked ~= isPositionLocked then
				isPositionLocked = serverLocked
				print("CLIENT: Position lock state changed to:", isPositionLocked)

				if not isPositionLocked then
					task.spawn(function()
						task.wait(0.05)
						forceRestoreControl()
					end)
				end

				updateButtonState()
			end
		end)

		-- Store connections
		seat:SetAttribute("_gravityConnection", gravityConnection)
		seat:SetAttribute("_lockConnection", lockConnection)
		updateButtonState()
	else
		print("Exited vehicle")
		isInVehicle = false

		-- Clean up connections
		if seat then
			local gravityConnection = seat:GetAttribute("_gravityConnection")
			local lockConnection = seat:GetAttribute("_lockConnection")

			if gravityConnection and typeof(gravityConnection) == "RBXScriptConnection" then
				gravityConnection:Disconnect()
			end
			if lockConnection and typeof(lockConnection) == "RBXScriptConnection" then
				lockConnection:Disconnect()
			end
		end

		isPositionLocked = false

		if hoverButton and lockButton then
			hoverButton.Text = "Enable Hover"
			hoverButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
			lockButton.Visible = false
		end
	end
end

-- Seat detection setup
local function setupSeatDetection()
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then
		return
	end

	-- Connect to seat changes
	humanoid.Seated:Connect(function(isSeated, seatPart)
		print("Seat event fired - Seated:", isSeated, "SeatPart:", seatPart)

		if isSeated and seatPart and seatPart:IsA("VehicleSeat") then
			seat = seatPart
			print("Seated in VehicleSeat:", seat.Name)
			onSeatChanged()
		elseif not isSeated then
			print("Left seat")
			seat = nil
			onSeatChanged()
		end
	end)

	-- Check if already seated
	if humanoid.Sit and humanoid.SeatPart and humanoid.SeatPart:IsA("VehicleSeat") then
		seat = humanoid.SeatPart
		print("Already seated in:", seat.Name)
		onSeatChanged()
	end
end

-- Initialize GUI
screenGui, hoverButton, lockButton = createGUI()
print("GUI created successfully")

-- Connect hover button
hoverButton.MouseButton1Click:Connect(function()
	print("Hover button clicked!")
	if seat then
		local currentGravComp = seat:GetAttribute("GravityCompensation") or DEFAULT_GRAVITY_COMPENSATION

		if currentGravComp >= 1.0 then
			print("CLIENT: Requesting hover disable")
			hoverToggleEvent:FireServer(seat, false)
		else
			print("CLIENT: Requesting hover enable")
			hoverToggleEvent:FireServer(seat, true)
		end
	else
		print("CLIENT: Not seated in vehicle")
	end
end)

-- Connect lock button
lockButton.MouseButton1Click:Connect(function()
	print("Lock button clicked!")
	if seat then
		local currentGravComp = seat:GetAttribute("GravityCompensation") or DEFAULT_GRAVITY_COMPENSATION

		if currentGravComp >= 1.0 then
			isPositionLocked = not isPositionLocked
			updateButtonState()

			if isPositionLocked then
				local controlForce = seat:FindFirstChild("ControlForce")
				if controlForce then
					controlForce:Destroy()
				end

				throttle = 0
				steer = 0
				rotate = 0
				verticalThrust = 0
				seat.Throttle = 0
				seat.Steer = 0

				hoverToggleEvent:FireServer(seat, "lock_position")
				print("CLIENT: Position locked")
			else
				hoverToggleEvent:FireServer(seat, "unlock_position")
				print("CLIENT: Unlock requested")
			end
		else
			print("CLIENT: Must enable hover first")
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

	-- Emergency camera fix with F key
	if keyCode == Enum.KeyCode.F then
		print("CLIENT: Emergency camera fix activated")
		fixVehicleCamera()
		return
	end

	-- Movement controls
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

-- Handle character spawning
player.CharacterAdded:Connect(function()
	print("Character spawned, setting up seat detection")
	task.wait(1)
	setupSeatDetection()
end)

-- Handle existing character
if player.Character then
	print("Existing character found, setting up seat detection")
	setupSeatDetection()
end

-- Main loop (removed camera checking that was causing issues)
RunService.RenderStepped:Connect(function()
	if seat and seat.Occupant == player.Character:FindFirstChildOfClass("Humanoid") then
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
	end
end)

print("Hello world, from client!")
