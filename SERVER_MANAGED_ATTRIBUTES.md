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

### AI Turret Internal State
| Attribute | Type | Purpose | Managed By |
|-----------|------|---------|------------|
| `_aiTurretRegistered` | boolean | Tracks if turret is registered in system | AITurretSystem.server.luau |
| `_lastTargetSearchTime` | number | Timestamp of last target search | AITurretSystem.server.luau |
| `_lastFireTime` | number | Timestamp of last weapon fire | AITurretSystem.server.luau |
| `_lastRocketFireTime` | number | Timestamp of last rocket fire (spam prevention) | AITurretSystem.server.luau |

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
| `firing_vehicle` | string | Vehicle identifier that fired this projectile | AITurretSystem.server.luau |
| `has_exploded` | boolean | Prevents multiple explosions from same projectile | AITurretSystem.server.luau |

---

## Part Server-Managed Attributes

### Health System Tracking
| Attribute | Type | Purpose | Managed By |
|-----------|------|---------|------------|
| `health` | number | Current health (modified during combat) | Server damage system |
| `being_destroyed` | boolean | Marks parts in destruction sequence | AITurretSystem.server.luau |

### Explosion System Tracking
| Attribute | Type | Purpose | Managed By |
|-----------|------|---------|------------|
| `is_explosion_sphere` | boolean | Identifies temporary explosion visual spheres | AITurretSystem.server.luau |

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

### AITurretSystem.server.luau Functions

#### `updateAITurrets()`
**Manages:**
- Target detection and caching
- Turret rotation and tracking
- Weapon firing and cooldowns
- Performance scaling based on turret count

**Behavior:**
```lua
-- AI Turret Registration
aiTurrets[turretId] = {
    vehicleSeat = obj,
    airange = airange,
    chamber = chamber,
}

-- Target Cache Management
targetCache[turretId] = targets
lastTargetSearchTime[turretId] = currentTime

-- Fire Rate Management
lastFireTimes[turretId] = currentTime
lastRocketFireTimes[turretId] = currentTime -- Rocket spam prevention
```

#### `createExplosion()`
**Manages:**
- Explosion sphere creation with `is_explosion_sphere = true`
- Part destruction sequence with `being_destroyed = true`
- Projectile explosion prevention with `has_exploded = true`
- Health reduction and damage application

**Behavior:**
```lua
-- Explosion Sphere Management
explosionSphere:SetAttribute("is_explosion_sphere", true)

-- Part Destruction Sequence
obj:SetAttribute("being_destroyed", true)

-- Projectile Explosion Prevention
projectile:SetAttribute("has_exploded", true)
```

#### `fireAtTarget()`
**Manages:**
- Projectile attribute inheritance from chambers
- Vehicle identifier assignment for self-targeting prevention
- Automatic reloading for AI turrets

**Behavior:**
```lua
-- Projectile Vehicle Tracking
projectile:SetAttribute("firing_vehicle", tostring(vehicleSeat.Parent))

-- AI Auto-Reload Management
chamber:SetAttribute("is_reloading", true)
-- After reload time:
chamber:SetAttribute("is_reloading", false)
chamber:SetAttribute("bullet_count", maxBullets)
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
6. **`_aiTurretRegistered`** - AI turret system state, manual changes will be overridden
7. **`_lastTargetSearchTime`** - Performance optimization data, modification will break caching
8. **`_lastFireTime`** - Fire rate control, manual changes will break weapon timing
9. **`_lastRocketFireTime`** - Spam prevention, manual changes will break rocket cooldowns
10. **`firing_vehicle`** - Self-targeting prevention, manual changes will break AI logic
11. **`has_exploded`** - Explosion prevention, manual changes can cause infinite explosions
12. **`being_destroyed`** - Destruction sequence control, manual changes will break fade effects
13. **`is_explosion_sphere`** - Cleanup system identifier, manual changes will break cleanup

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

-- AI Turret System
"SERVER: Registered AI Turret: [VehicleSeat] with AIrange: [AIrange] and Chamber: [chamber]"
"SERVER: AI Turret found [X] targets. Closest: [part] at distance: [Y]"
"SERVER: AI Turret fired [ammotype] round at [target]"
"SERVER: AI Turret auto-reloading - duration: [X] seconds"
"SERVER: AI Turret reload complete - bullets: [X]"
"SERVER: AI Explosion created at [position] with radius [X] damage [Y] armor pen [Z]"
"SERVER: AI Explosion damaged [part] for [X] damage (health: [Y])"
"SERVER: Projectile [name] destroyed by AI explosion!"
"SERVER: AI explosion destroyed part [name] after fade"
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
