-- Game Configuration Module
-- Shared constants and configuration values used by both client and server
-- Centralizes all game settings for easy maintenance

local GameConfig = {}

-- === WEAPON SYSTEM CONFIGURATION ===
GameConfig.Weapons = {
	-- Default weapon attributes
	DEFAULT_ARMOR_PEN = 10,
	DEFAULT_DAMAGE = 25,
	DEFAULT_AFTERPEN_DELAY = 0.5,
	DEFAULT_AIRBURST_TIME = 2.0,
	DEFAULT_DETECT_RANGE = 15,
	DEFAULT_EXPLOSION_RADIUS = 20,
	DEFAULT_EXPLOSION_DAMAGE = 50,
	
	-- Projectile physics
	PROJECTILE_VELOCITY = 200,
	PROJECTILE_LIFETIME = 10, -- seconds
	
	-- Explosion system
	EXPLOSION_COOLDOWN_TIME = 0.5, -- seconds between explosions at same position
	EXPLOSION_SPHERE_LIFETIME = 3, -- seconds
	EXPLOSION_SPHERE_TRANSPARENCY = 0.7,
	
	-- Ammo type colors
	AMMO_COLORS = {
		standard = "Dark stone grey",
		high_explosive = "Bright red",
		airburst = "Bright yellow"
	}
}

-- === VEHICLE SYSTEM CONFIGURATION ===
GameConfig.Vehicles = {
	-- Default vehicle attributes
	DEFAULT_FORCE_MAGNITUDE = 3000,
	DEFAULT_ROTATE_SPEED = 0.1,
	DEFAULT_GRAVITY_COMPENSATION = 0.8,
	DEFAULT_VERTICAL_FORCE_UP = 3000,
	DEFAULT_VERTICAL_FORCE_DOWN = 3000,
	DEFAULT_MAX_HORIZONTAL_SPEED = 50,
	DEFAULT_MAX_VERTICAL_SPEED = 50,
	
	-- Hover system
	HOVER_UPDATE_INTERVAL = 0.2, -- seconds
	HOVER_BODY_POSITION_P = 100000,
	HOVER_BODY_POSITION_D = 10000,
	HOVER_ANGULAR_VELOCITY_P = 100000,
	
	-- Seat types
	SEAT_TYPES = {
		cruiser = "cruiser",
		turret = "turret",
		dual_turret = "2xturret"
	}
}

-- === HEALTH SYSTEM CONFIGURATION ===
GameConfig.Health = {
	-- Default health attributes
	DEFAULT_HEALTH = 100,
	DEFAULT_ARMOR = 5,
	
	-- Health bar settings
	HEALTH_BAR_LIFETIME = 3, -- seconds
	HEALTH_BAR_SIZE = UDim2.fromScale(2, 0.5),
	HEALTH_BAR_OFFSET = Vector3.new(0, 1, 0), -- studs above part
	
	-- Health bar colors
	HEALTH_COLORS = {
		high = Color3.new(0, 1, 0), -- Green (>60%)
		medium = Color3.new(1, 1, 0), -- Yellow (30-60%)
		low = Color3.new(1, 0, 0) -- Red (<30%)
	},
	
	-- Health thresholds
	HEALTH_THRESHOLDS = {
		high = 0.6,
		medium = 0.3
	},
	
	-- Part destruction
	FADE_TIME = 3, -- seconds for part destruction fade
	MINIMUM_EXPLOSION_DAMAGE = 0.1 -- 10% of base damage at maximum range
}

-- === INSPECTION TOOLS CONFIGURATION ===
GameConfig.Inspection = {
	-- Chamber inspector
	CHAMBER_INSPECTION_RANGE = 10, -- studs
	CHAMBER_UPDATE_INTERVAL = 0.2, -- seconds
	CHAMBER_GUI_SIZE = UDim2.fromOffset(300, 200),
	CHAMBER_GUI_OFFSET = Vector3.new(0, 3, 0), -- studs above chamber
	CHAMBER_GUI_COLOR = Color3.fromRGB(255, 255, 0), -- Yellow theme
	
	-- Health inspector
	HEALTH_INSPECTION_RANGE = 8, -- studs
	HEALTH_UPDATE_INTERVAL = 0.3, -- seconds
	HEALTH_GUI_SIZE = UDim2.fromOffset(250, 100),
	HEALTH_GUI_OFFSET = Vector3.new(0, 2, 0), -- studs above part
	HEALTH_GUI_COLOR = Color3.fromRGB(0, 255, 0), -- Green theme
	
	-- Common GUI settings
	GUI_BACKGROUND_COLOR = Color3.fromRGB(0, 0, 0),
	GUI_BACKGROUND_TRANSPARENCY = 0.3,
	GUI_BORDER_COLOR = Color3.fromRGB(255, 255, 255),
	GUI_BORDER_SIZE = 2,
	GUI_TEXT_COLOR = Color3.fromRGB(255, 255, 255)
}

-- === INPUT CONFIGURATION ===
GameConfig.Input = {
	-- Vehicle controls
	MOVEMENT_KEYS = {
		forward = Enum.KeyCode.W,
		backward = Enum.KeyCode.S,
		left = Enum.KeyCode.A,
		right = Enum.KeyCode.D,
		rotate_left = Enum.KeyCode.Q,
		rotate_right = Enum.KeyCode.E,
		up = Enum.KeyCode.X,
		down = Enum.KeyCode.C
	},
	
	-- Vehicle functions
	FUNCTION_KEYS = {
		fire = Enum.KeyCode.Space,
		hover_toggle = Enum.KeyCode.F,
		position_lock = Enum.KeyCode.G,
		debug = Enum.KeyCode.V
	},
	
	-- Inspection tools
	INSPECTION_KEYS = {
		chamber_inspector = Enum.KeyCode.T,
		health_inspector = Enum.KeyCode.H
	},
	
	-- Turret controls
	TURRET_DEADZONE_RADIUS = 50, -- pixels from screen center
	TURRET_ROTATION_SPEED = 5,
	TURRET_DUAL_AXIS_SPEED = 8,
	TURRET_MAX_PITCH = 1.2 -- radians (~70 degrees)
}

-- === ATTRIBUTE INITIALIZATION ===
GameConfig.Attributes = {
	-- Update intervals
	CHAMBER_INIT_INTERVAL = 1.0, -- seconds
	PART_INIT_INTERVAL = 1.0, -- seconds
	VEHICLE_INIT_INTERVAL = 1.0, -- seconds
	
	-- Default chamber attributes
	CHAMBER_DEFAULTS = {
		ammotype = "standard",
		armor_pen = 10,
		damage = 25,
		afterpen = 0.5,
		airburst_time = 2.0,
		detect_range = 15,
		explosion_radius = 20,
		explosive_radius_damage = 50,
		weapontype = "Cannon"
	},
	
	-- Default part attributes
	PART_DEFAULTS = {
		armor = 5,
		health = 100
	},
	
	-- Default vehicle seat attributes
	VEHICLE_DEFAULTS = {
		seattype = "cruiser",
		weapontype = "None",
		GravityCompensation = 0.8,
		PositionLocked = false,
		ForceMagnitude = 3000,
		RotateSpeed = 0.1,
		VerticalForceUp = 3000,
		VerticalForceDown = 3000,
		MaxHorizontalSpeed = 50,
		MaxVerticalSpeed = 50
	}
}

-- === SOUND CONFIGURATION ===
GameConfig.Sounds = {
	-- Weapon sounds
	WEAPON_FIRE = "rbxasset://sounds/impact_water.mp3",
	ARMOR_PENETRATION = "rbxasset://sounds/impact_water.mp3",
	ARMOR_RICOCHET = "rbxasset://sounds/electronicpingshort.wav",
	EXPLOSION_BLOCKED = "rbxasset://sounds/electronicbeep.mp3",
	
	-- Volume and pitch settings
	DEFAULT_VOLUME = 0.5,
	PENETRATION_VOLUME = 0.7,
	RICOCHET_VOLUME = 0.6,
	EXPLOSION_VOLUME = 0.5,
	
	DEFAULT_PITCH = 1.0,
	PENETRATION_PITCH = 1.0,
	RICOCHET_PITCH = 1.8,
	EXPLOSION_PITCH = 0.8,
	
	-- Sound lifetime
	SOUND_LIFETIME = 3 -- seconds
}

-- === DEBUG CONFIGURATION ===
GameConfig.Debug = {
	-- Debug output intervals
	VEHICLE_DEBUG_CHANCE = 100, -- 1 in 100 chance per update
	HOVER_DEBUG_CHANCE = 300, -- 1 in 300 chance per update (less frequent)
	
	-- Console prefixes
	CLIENT_PREFIX = "CLIENT:",
	SERVER_PREFIX = "SERVER:",
	
	-- Debug categories
	CATEGORIES = {
		weapon = "WEAPON",
		vehicle = "VEHICLE",
		health = "HEALTH",
		inspection = "INSPECTION",
		explosion = "EXPLOSION"
	}
}

-- === UTILITY FUNCTIONS ===
GameConfig.Utils = {
	-- Get health bar color based on percentage
	getHealthColor = function(healthPercent)
		if healthPercent > GameConfig.Health.HEALTH_THRESHOLDS.high then
			return GameConfig.Health.HEALTH_COLORS.high
		elseif healthPercent > GameConfig.Health.HEALTH_THRESHOLDS.medium then
			return GameConfig.Health.HEALTH_COLORS.medium
		else
			return GameConfig.Health.HEALTH_COLORS.low
		end
	end,
	
	-- Get ammo color based on type
	getAmmoColor = function(ammoType)
		return GameConfig.Weapons.AMMO_COLORS[ammoType] or GameConfig.Weapons.AMMO_COLORS.standard
	end,
	
	-- Format debug message
	formatDebugMessage = function(prefix, category, message)
		return string.format("%s [%s] %s", prefix, category, message)
	end,
	
	-- Calculate damage falloff
	calculateDamageFalloff = function(distance, maxRadius)
		return math.max(GameConfig.Health.MINIMUM_EXPLOSION_DAMAGE, 1 - (distance / maxRadius))
	end
}

return GameConfig
