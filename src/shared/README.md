# Shared Modules Documentation

This directory contains shared modules that can be used by both client and server scripts in the Cruiser-Crew-Rogame project. These modules provide centralized configuration, utilities, and communication systems.

## 📁 Module Overview

### 🔧 GameConfig.luau
**Centralized Configuration System**

Contains all game constants, default values, and configuration settings used throughout the project.

**Key Features:**
- Weapon system configuration (damage, explosion radius, ammo types)
- Vehicle system settings (hover forces, rotation speeds, seat types)
- Health system parameters (default health, armor, color thresholds)
- Inspection tool settings (ranges, update intervals, GUI sizes)
- Input key bindings and control schemes
- Sound effect configurations
- Debug output settings

**Usage Example:**
```lua
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

-- Get default weapon damage
local damage = GameConfig.Weapons.DEFAULT_DAMAGE

-- Get health bar color for 75% health
local color = GameConfig.Utils.getHealthColor(0.75)

-- Get chamber inspection range
local range = GameConfig.Inspection.CHAMBER_INSPECTION_RANGE
```

**Benefits:**
- ✅ Single source of truth for all game settings
- ✅ Easy to modify game balance without touching code
- ✅ Consistent values across client and server
- ✅ Built-in utility functions for common calculations

---

### 🛠️ GameUtils.luau
**Utility Functions Library**

Provides reusable functions for common operations like GUI creation, sound management, math calculations, and object manipulation.

**Key Categories:**

**GUI Utilities:**
- `createBillboardGui()` - Standardized floating GUIs
- `createFrame()` - Styled frames with borders and corners
- `createTextLabel()` - Consistent text labels
- `createScrollingFrame()` - Auto-sizing scrollable lists
- `createHealthBar()` - Visual health bars with color coding

**Sound Utilities:**
- `createSound()` - Play sounds with automatic cleanup
- `playSoundAtPosition()` - 3D positioned sound effects

**Math Utilities:**
- `getDistance()` - Calculate distance between positions
- `calculateDamageFalloff()` - Damage reduction over distance
- `clamp()` - Constrain values to ranges
- `lerp()` - Linear interpolation

**Part Utilities:**
- `findPartsWithAttribute()` - Search for parts by attributes
- `findPartsInRadius()` - Efficient radius-based part detection
- `partNameContains()` - Name pattern matching

**Attribute Utilities:**
- `getAttribute()` - Safe attribute access with defaults
- `setDefaultAttribute()` - Initialize missing attributes
- `initializeAttributes()` - Bulk attribute initialization

**Usage Example:**
```lua
local GameUtils = require(ReplicatedStorage.Shared.GameUtils)

-- Create a health bar GUI
local gui = GameUtils.createBillboardGui(part, UDim2.fromOffset(200, 50))
local frame = GameUtils.createFrame(gui, Color3.fromRGB(0, 0, 0))
local bgBar, healthBar = GameUtils.createHealthBar(frame, 0.75, Color3.fromRGB(0, 255, 0))

-- Play a sound effect
GameUtils.createSound(part, "rbxasset://sounds/impact_water.mp3", 0.5, 1.0)

-- Find all chambers in the workspace
local chambers = GameUtils.findPartsWithAttribute(workspace, "ammotype")

-- Initialize default attributes
GameUtils.initializeAttributes(chamber, {
    ammotype = "standard",
    damage = 25,
    armor_pen = 10
})
```

**Benefits:**
- ✅ Reduces code duplication across scripts
- ✅ Consistent GUI styling and behavior
- ✅ Optimized algorithms for common operations
- ✅ Built-in error handling and validation

---

### 📡 RemoteManager.luau
**Remote Event Communication System**

Manages all RemoteEvent creation and provides type-safe communication between client and server scripts.

**Key Features:**
- Automatic RemoteEvent creation and discovery
- Type-safe wrapper functions for specific events
- Error handling and timeout protection
- Centralized remote event definitions
- Debug and monitoring capabilities

**Available Remote Events:**
- `HoverToggle` - Vehicle hover and position lock control
- `FireWeapon` - Weapon firing requests
- `HealthUpdate` - Part health synchronization
- `DebugMessage` - Debug information exchange

**Usage Example:**

**Server Side:**
```lua
local RemoteManager = require(ReplicatedStorage.Shared.RemoteManager)

-- Handle hover toggle requests
RemoteManager.Vehicle.onHoverToggle(function(player, hoverEnabled, positionLocked)
    print("Player", player.Name, "toggled hover:", hoverEnabled)
    -- Handle hover logic here
end)

-- Send health update to all clients
RemoteManager.Health.updateHealthAll("EnginePart", 75, 100)
```

**Client Side:**
```lua
local RemoteManager = require(ReplicatedStorage.Shared.RemoteManager)

-- Request hover toggle
RemoteManager.Vehicle.toggleHover(true, false)

-- Handle health updates from server
RemoteManager.Health.onHealthUpdate(function(partName, currentHealth, maxHealth)
    print("Health update:", partName, currentHealth .. "/" .. maxHealth)
    -- Update GUI here
end)
```

**Type-Safe Wrappers:**
- `RemoteManager.Vehicle.*` - Vehicle control functions
- `RemoteManager.Weapon.*` - Weapon system functions
- `RemoteManager.Health.*` - Health system functions
- `RemoteManager.Debug.*` - Debug message functions

**Benefits:**
- ✅ Eliminates RemoteEvent setup boilerplate
- ✅ Type-safe function calls prevent errors
- ✅ Automatic timeout and error handling
- ✅ Centralized communication management
- ✅ Easy to add new remote events

---

## 🔄 Integration with Existing Systems

### Client Scripts
The modular client scripts can now use these shared modules:

```lua
-- In VehicleControl.client.luau
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local RemoteManager = require(ReplicatedStorage.Shared.RemoteManager)

-- Use configuration values
local hoverKey = GameConfig.Input.FUNCTION_KEYS.hover_toggle

-- Use remote manager for communication
RemoteManager.Vehicle.toggleHover(true, false)
```

### Server Scripts
The modular server scripts can leverage shared utilities:

```lua
-- In WeaponSystem.server.luau
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameUtils = require(ReplicatedStorage.Shared.GameUtils)

-- Use default values from config
local defaultDamage = GameConfig.Weapons.DEFAULT_DAMAGE

-- Use utility functions
local nearbyParts = GameUtils.findPartsInRadius(explosionPos, radius)
```

## 📈 Benefits of Shared Modules

### 🎯 **Consistency**
- All scripts use the same configuration values
- Consistent GUI styling and behavior
- Standardized communication patterns

### 🔧 **Maintainability**
- Single place to update game settings
- Reusable functions reduce code duplication
- Centralized remote event management

### 🚀 **Performance**
- Optimized utility functions
- Efficient part detection algorithms
- Reduced memory usage through code reuse

### 👥 **Team Development**
- Clear separation of concerns
- Well-documented interfaces
- Easy to extend and modify

### 🐛 **Debugging**
- Centralized error handling
- Consistent debug output formatting
- Built-in validation functions

## 🔮 Future Enhancements

### Potential Additions:
- **DataManager.luau** - Player data persistence and management
- **EffectsManager.luau** - Visual effects and particle systems
- **NetworkOptimizer.luau** - Bandwidth optimization for multiplayer
- **SecurityManager.luau** - Anti-exploit and validation systems
- **LocalizationManager.luau** - Multi-language support

### Configuration Expansions:
- **Weapon Balancing** - More detailed weapon statistics
- **Vehicle Physics** - Advanced movement parameters
- **Visual Settings** - Customizable GUI themes and effects
- **Performance Tuning** - Adjustable quality settings

## 📝 Usage Guidelines

### Best Practices:
1. **Always use GameConfig** for constants instead of hardcoding values
2. **Leverage GameUtils** for common operations to ensure consistency
3. **Use RemoteManager** for all client-server communication
4. **Import modules at the top** of scripts for clarity
5. **Check module documentation** before implementing custom solutions

### Performance Tips:
1. **Cache frequently used values** from GameConfig
2. **Reuse GUI elements** created with GameUtils
3. **Batch remote events** when possible with RemoteManager
4. **Use appropriate utility functions** for part detection and manipulation

This shared module system provides a solid foundation for the Cruiser-Crew-Rogame project, making it easier to maintain, extend, and collaborate on the codebase.
