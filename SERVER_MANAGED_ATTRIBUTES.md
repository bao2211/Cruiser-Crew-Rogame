# Server-Managed Attributes Documentation
## Cruiser-Crew-Rogame Project

This document lists all attributes that are managed by the server scripts and should NOT be manually modified by users. These attributes are used for internal state management and synchronization.

---

## VehicleSeat Server-Managed Attributes

### Position & State Management
| Attribute | Type | Purpose | Managed By |
|-----------|------|---------|------------|
| `PositionLocked` | boolean | Tracks if vehicle position is locked | VehicleHover.server.luau |
| `LockedPosition` | Vector3 | Stores locked position coordinates | VehicleHover.server.luau |
| `LockedCFrame` | CFrame | Stores locked rotation and position | VehicleHover.server.luau |

### Internal Connection Tracking
| Attribute | Type | Purpose | Managed By |
|-----------|------|---------|------------|
| `_gravityConnection` | RBXScriptConnection | Tracks gravity change listeners | jetvehiclecontrol.client.luau |
| `_lockConnection` | RBXScriptConnection | Tracks position lock listeners | jetvehiclecontrol.client.luau |

---

## Projectile Server-Managed Attributes

### Weapon System Data
| Attribute | Type | Purpose | Managed By |
|-----------|------|---------|------------|
| `ammotype` | string | Copied from chamber to projectile | jetvehiclecontrol.client.luau |
| `armor_pen` | number | Copied from chamber to projectile | Server weapon system |
| `damage` | number | Damage value for projectile | Server weapon system |
| `airburst_time` | number | Copied from chamber to projectile | Server weapon system |
| `afterpen` | number | Copied from chamber to projectile | Server weapon system |

---

## Part Server-Managed Attributes

### Health System Tracking
| Attribute | Type | Purpose | Managed By |
|-----------|------|---------|------------|
| `health` | number | Current health (modified during combat) | Server damage system |

**Note**: While `health` is settable for initial configuration, it becomes server-managed during gameplay as the damage system modifies it.

---

## Server State Management Functions

### VehicleHover.server.luau Functions

#### `maintainHover()`
**Manages:**
- `PositionLocked` state enforcement
- `LockedPosition` and `LockedCFrame` storage
- Automatic attribute initialization

**Behavior:**
```lua
-- Position Lock Management
if command == "lock_position" then
    vehicleSeat:SetAttribute("PositionLocked", true)
    vehicleSeat:SetAttribute("LockedPosition", vehicleSeat.Position)
    vehicleSeat:SetAttribute("LockedCFrame", vehicleSeat.CFrame)
end

-- Position Unlock Management
if command == "unlock_position" then
    vehicleSeat:SetAttribute("PositionLocked", false)
end
```

#### `initializeChambers()`
**Manages:**
- Automatic chamber attribute initialization
- Default value assignment for missing attributes

**Behavior:**
```lua
-- Chamber Attribute Initialization
if not obj:GetAttribute("ammotype") then
    obj:SetAttribute("ammotype", "standard")
end
```

### Client State Management Functions

#### Attribute Change Listeners
**Manages:**
- `_gravityConnection` and `_lockConnection` tracking
- Automatic cleanup of old connections
- Synchronization with server state

**Behavior:**
```lua
-- Connection Management
gravityConnection = seat:GetAttributeChangedSignal("GravityCompensation"):Connect(function()
    -- Handle gravity changes
end)

lockConnection = seat:GetAttributeChangedSignal("PositionLocked"):Connect(function()
    -- Handle position lock changes
end)
```

---

## Server-Client Synchronization

### RemoteEvent Communication
The server manages state through RemoteEvent handlers:

#### HoverToggle RemoteEvent
**Commands Handled:**
- `"lock_position"` → Sets `PositionLocked = true`
- `"unlock_position"` → Sets `PositionLocked = false`
- `true` → Sets `GravityCompensation = 1.0`
- `false` → Sets `GravityCompensation = 0.8`
- `"player_exited"` → Cleans up forces but preserves state

#### FireWeapon RemoteEvent
**Data Managed:**
- Projectile attribute inheritance from chambers
- Server-side validation and processing
- Authoritative damage and destruction

---

## Automatic Initialization System

### Server Initialization (Every 0.2 seconds)
```lua
-- VehicleSeat Defaults
if not obj:GetAttribute("seattype") then
    obj:SetAttribute("seattype", "cruiser")
end

if not obj:GetAttribute("weapontype") then
    obj:SetAttribute("weapontype", "None")
end

-- Chamber Defaults
if not obj:GetAttribute("ammotype") then
    obj:SetAttribute("ammotype", "standard")
end
```

### Part Registration System
**Manages:**
- Vehicle part tracking for unweld detection
- Position-based destruction system
- Health reduction on structural failure

---

## Important Warnings

### ⚠️ DO NOT MODIFY THESE ATTRIBUTES MANUALLY:

1. **`PositionLocked`** - Managed by hover system, manual changes will be overridden
2. **`LockedPosition`** - Used for position restoration, corruption will break locking
3. **`LockedCFrame`** - Used for rotation restoration, corruption will break locking
4. **`_gravityConnection`** - Internal connection tracking, modification will cause memory leaks
5. **`_lockConnection`** - Internal connection tracking, modification will cause memory leaks

### ⚠️ READ-ONLY DURING GAMEPLAY:

1. **Projectile attributes** - Set by server during weapon firing, client modifications ignored
2. **`health` during combat** - Modified by damage system, manual changes will be overridden

---

## Debugging Server-Managed Attributes

### Console Output Patterns
```lua
-- Server State Changes
"SERVER: Position locked for [VehicleSeat] by [Player]"
"SERVER: Position unlocked for [VehicleSeat] by [Player]"
"SERVER: Hover enabled for [VehicleSeat] by [Player]"
"SERVER: Hover disabled for [VehicleSeat] by [Player]"

-- Attribute Initialization
"SERVER: Initialized chamber [name] with ammotype: standard"
"SERVER: Initialized VehicleSeat [name] with seattype: cruiser"

-- Health System
"SERVER: Part [name] health reduced to [value] due to damage"
"SERVER: Part [name] destroyed due to health <= 0"
```

### State Validation
The server continuously validates and enforces these managed attributes. Any manual modifications will be detected and corrected during the next maintenance cycle (every 0.2 seconds).

---

## Integration with User-Settable Attributes

Server-managed attributes work alongside user-settable attributes:

- **User sets**: `GravityCompensation = 1.2` (hover strength)
- **Server manages**: `PositionLocked = true/false` (lock state)
- **Result**: Hover behavior with server-controlled locking

This separation ensures that user customization doesn't interfere with critical system state management while providing full control over vehicle behavior parameters.
