local Players = game:GetService("Players")
local player = Players.LocalPlayer

local seat = nil
local throttle = 0
local steer = 0
local rotate = 0
local verticalThrust = 0 -- New variable for vertical force

local UserInputService = game:GetService("UserInputService")

-- Default values if not found in seat
local DEFAULT_FORCE_MAGNITUDE = 5000
local DEFAULT_ROTATE_SPEED = 0.0000001 -- Reduced from 0.1 to make rotation slower
local DEFAULT_VERTICAL_FORCE = 20000 -- New default for vertical thrust
local THRUST_DECAY_RATE = 0.95 -- How fast thrust decays (0.95 = 5% decay per frame)
local DEFAULT_MAX_HORIZONTAL_SPEED = 50 -- Maximum horizontal speed
local DEFAULT_MAX_VERTICAL_SPEED = 30 -- Maximum vertical speed
local DEFAULT_GRAVITY_COMPENSATION = 0.8 -- Default gravity compensation (80%)

-- Listen for when the player's humanoid sits in a VehicleSeat
local function onSeated(active, seatPart)
	if active and seatPart and seatPart:IsA("VehicleSeat") then
		seat = seatPart
		print("Seated in vehicle with Force:", seat:GetAttribute("ForceMagnitude") or DEFAULT_FORCE_MAGNITUDE)
		print("Rotate Speed:", seat:GetAttribute("RotateSpeed") or DEFAULT_ROTATE_SPEED)
		print("Gravity Compensation:", seat:GetAttribute("GravityCompensation") or DEFAULT_GRAVITY_COMPENSATION)
	else
		seat = nil
	end
end

local function setupCharacter(char)
	local humanoid = char:WaitForChild("Humanoid")
	humanoid.Seated:Connect(onSeated)
end

if player.Character then
	setupCharacter(player.Character)
end
player.CharacterAdded:Connect(setupCharacter)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.W then
		throttle = 1
	elseif input.KeyCode == Enum.KeyCode.S then
		throttle = -1
	elseif input.KeyCode == Enum.KeyCode.A then
		steer = -1
	elseif input.KeyCode == Enum.KeyCode.D then
		steer = 1
	elseif input.KeyCode == Enum.KeyCode.Q then
		rotate = -1
	elseif input.KeyCode == Enum.KeyCode.E then
		rotate = 1
	elseif input.KeyCode == Enum.KeyCode.X then
		verticalThrust = 1 -- Thrust up
		print("X pressed - Thrust up:", verticalThrust)
	elseif input.KeyCode == Enum.KeyCode.C then
		verticalThrust = -1 -- Thrust down
		print("C pressed - Thrust down:", verticalThrust)
	end
end)

UserInputService.InputEnded:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.S then
		throttle = 0
	elseif input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.D then
		steer = 0
	elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.E then
		rotate = 0
	elseif input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.C then
		-- Don't immediately set to 0, let it decay naturally
	end
end)

local function applyForce()
	if seat and seat:IsDescendantOf(workspace) then
		local forceMagnitude = seat:GetAttribute("ForceMagnitude") or DEFAULT_FORCE_MAGNITUDE
		local verticalForceMagnitude = seat:GetAttribute("VerticalForce") or DEFAULT_VERTICAL_FORCE
		local maxHorizontalSpeed = seat:GetAttribute("MaxHorizontalSpeed") or DEFAULT_MAX_HORIZONTAL_SPEED
		local maxVerticalSpeed = seat:GetAttribute("MaxVerticalSpeed") or DEFAULT_MAX_VERTICAL_SPEED
		local gravityCompensationMultiplier = seat:GetAttribute("GravityCompensation") or DEFAULT_GRAVITY_COMPENSATION

		local vf = seat:FindFirstChild("ControlForce") or Instance.new("VectorForce")
		vf.Name = "ControlForce"
		vf.Attachment0 = seat:FindFirstChildOfClass("Attachment") or Instance.new("Attachment", seat)

		-- Check current velocity to limit speed
		local currentVelocity = seat.AssemblyLinearVelocity
		local horizontalVelocity = Vector3.new(currentVelocity.X, 0, currentVelocity.Z)
		local verticalVelocity = math.abs(currentVelocity.Y)

		-- Calculate force relative to vehicle's orientation
		local localHorizontalForce = Vector3.new(steer * forceMagnitude, 0, throttle * -forceMagnitude)

		-- Calculate vertical force with overwritable gravity compensation
		local gravityCompensation = seat.AssemblyMass * workspace.Gravity * gravityCompensationMultiplier
		local verticalForce = (verticalThrust * verticalForceMagnitude) + gravityCompensation

		-- Transform horizontal force to world space based on vehicle's Y rotation
		local vehicleRotation = seat.CFrame.Rotation
		local worldHorizontalForce = vehicleRotation * localHorizontalForce

		-- Limit horizontal speed
		if horizontalVelocity.Magnitude >= maxHorizontalSpeed then
			local velocityDirection = horizontalVelocity.Unit
			local forceDirection = Vector3.new(worldHorizontalForce.X, 0, worldHorizontalForce.Z).Unit
			if velocityDirection:Dot(forceDirection) > 0 then
				worldHorizontalForce = worldHorizontalForce * 0.1
			end
		end

		-- Limit vertical speed
		if verticalVelocity >= maxVerticalSpeed then
			if (currentVelocity.Y > 0 and verticalThrust > 0) or (currentVelocity.Y < 0 and verticalThrust < 0) then
				verticalForce = verticalForce * 0.1
			end
		end

		-- Apply forces: horizontal forces in world space, vertical force stays the same
		local forceVector = Vector3.new(worldHorizontalForce.X, verticalForce, worldHorizontalForce.Z)
		vf.Force = forceVector
		vf.RelativeTo = Enum.ActuatorRelativeTo.World
		vf.Parent = seat
	end
end

local currentYRotation = 0 -- Track the Y rotation separately

local function applyRotationWithPitchLock()
	if seat and seat:IsDescendantOf(workspace) then
		-- Remove existing angular constraints only
		for _, child in ipairs(seat:GetChildren()) do
			if child.ClassName == "BodyAngularVelocity" and child.Name == "ControlAngular" then
				child:Destroy()
			end
		end

		-- Get rotation speed from seat or use default
		local rotateSpeed = seat:GetAttribute("RotateSpeed") or DEFAULT_ROTATE_SPEED

		-- Use BodyAngularVelocity to control ALL rotations
		local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
		bodyAngularVelocity.Name = "ControlAngular"

		-- Lock X and Z rotation to 0, allow Y rotation with input
		-- Multiply rotateSpeed by a reasonable amount (remove the *1000 multiplier)
		local targetAngularVelocity = Vector3.new(0, rotate * rotateSpeed * 10, 0)
		bodyAngularVelocity.AngularVelocity = targetAngularVelocity
		bodyAngularVelocity.MaxTorque = Vector3.new(50000, 50000, 50000) -- High torque to prevent physics rotation

		bodyAngularVelocity.Parent = seat
	end
end

game:GetService("RunService").RenderStepped:Connect(function()
	if seat and seat.Occupant == player.Character:FindFirstChildOfClass("Humanoid") then
		-- Get decay rate from seat attribute or use default
		local decayRate = seat:GetAttribute("ThrustDecayRate") or THRUST_DECAY_RATE

		-- Apply gradual decay to vertical thrust when not actively pressing X or C
		local isPressingVertical = UserInputService:IsKeyDown(Enum.KeyCode.X)
			or UserInputService:IsKeyDown(Enum.KeyCode.C)
		if not isPressingVertical and math.abs(verticalThrust) > 0.1 then -- Changed from 0.01 to 0.1
			verticalThrust = verticalThrust * decayRate
		elseif math.abs(verticalThrust) <= 0.1 then
			verticalThrust = 0.1 -- Maintain minimum hover thrust instead of 0
		end

		-- Apply decay to horizontal movement when no input
		local isPressingHorizontal = UserInputService:IsKeyDown(Enum.KeyCode.W)
			or UserInputService:IsKeyDown(Enum.KeyCode.S)
			or UserInputService:IsKeyDown(Enum.KeyCode.A)
			or UserInputService:IsKeyDown(Enum.KeyCode.D)

		if not isPressingHorizontal then
			-- Apply some drag to horizontal movement
			local currentVelocity = seat.AssemblyLinearVelocity
			local horizontalVelocity = Vector3.new(currentVelocity.X, 0, currentVelocity.Z)
			if horizontalVelocity.Magnitude > 0.1 then
				-- Apply drag force opposite to horizontal velocity (in world space)
				local dragForce = -horizontalVelocity * 500 -- Adjust drag amount
				local vf = seat:FindFirstChild("ControlForce")
				if vf then
					-- Only apply drag to horizontal components, preserve vertical force
					vf.Force = Vector3.new(dragForce.X, vf.Force.Y, dragForce.Z)
				end
			end
		end

		applyForce()
		applyRotationWithPitchLock()
		seat.Throttle = throttle
		seat.Steer = steer
	end
end)
