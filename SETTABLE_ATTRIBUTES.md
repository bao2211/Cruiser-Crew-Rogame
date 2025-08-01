# Settable Attributes Documentation
## Cruiser-Crew-Rogame Project

This document lists all user-configurable attributes that can be set on various parts to customize vehicle behavior, weapons, and systems.

---

## VehicleSeat Attributes

### Movement & Control Attributes
| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `ForceMagnitude` | number | 3000 | Horizontal movement force strength |
| `VerticalForceUp` | number | 3000 | Upward thrust force strength |
| `VerticalForceDown` | number | 3000 | Downward thrust force strength |
| `MaxHorizontalSpeed` | number | 50 | Maximum horizontal speed limit (studs/s) |
| `MaxVerticalSpeed` | number | 50 | Maximum vertical speed limit (studs/s) |
| `RotateSpeed` | number | 0.1 | Rotation speed multiplier |
| `GravityCompensation` | number | 0.8 | Gravity compensation multiplier (≥1.0 enables hover) |

### Seat Type Attributes
| Attribute | Type | Default | Options | Description |
|-----------|------|---------|---------|-------------|
| `seattype` | string | "cruiser" | "cruiser", "turret", "2xturret" | Controls rotation behavior |

**Seat Type Behaviors:**
- **"cruiser"**: Normal keyboard rotation (Q/E, A/D keys)
- **"turret"**: Mouse-controlled horizontal rotation only
- **"2xturret"**: Full 3D mouse tracking with deadzone and pitch limiting

### Weapon System Attributes
| Attribute | Type | Default | Options | Description |
|-----------|------|---------|---------|-------------|
| `weapontype` | string | "None" | "None", "Cannon" | Enables weapon firing capability |
| `aiturret` | boolean | false | true, false | Enables AI automatic target detection and firing |

### AI Turret Configuration Attributes
| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `ai_update_interval` | number | 0.05 | How often (seconds) the turret checks for targets (lower = more responsive) |
| `tracking_speed` | number | 15 | How fast the turret rotates to track targets (higher = faster rotation) |
| `target_cache_time` | number | 0.1 | How long (seconds) to cache target search results (0 = no caching, instant response) |
| `max_target_distance` | number | 200 | Maximum distance (studs) to detect and engage targets |

---

## Chamber Part Attributes (Parts named "chamber")

### Ammunition Configuration
| Attribute | Type | Default | Options | Description |
|-----------|------|---------|---------|-------------|
| `ammotype` | string | "standard" | "standard", "high_explosive", "airburst", "rocket" | Projectile behavior type |
| `afterpen` | number | 0.5 | Any positive number | Delay (seconds) before HE explosion after armor penetration |
| `airburst_time` | number | 2.0 | Any positive number | Time (seconds) before airburst explosion |
| `detect_range` | number | 15 | Any positive number | Proximity detection range (studs) for airburst rounds |
| `armor_pen` | number | 10 | Any positive number | Armor penetration value |
| `explosion_radius` | number | 20 | Any positive number | Radius (studs) of explosion area effect |
| `explosive_radius_damage` | number | 50 | Any positive number | Base damage dealt to parts within explosion radius |
| `projectile_speed` | number | 100 | Any positive number | Projectile velocity (studs/second) |
| `projectile_health` | number | 50 | Any positive number | Health points of projectiles - can be damaged and destroyed |
| `bullet_count` | number | 10 | Any positive number | Current bullets in magazine |
| `max_bullet_count` | number | 10 | Any positive number | Maximum magazine capacity |
| `firerate` | number | 1.0 | Any positive number | Fire rate (shots per second) |
| `reload` | number | 2.0 | Any positive number | Reload time (seconds) to refill magazine |

**Ammo Type Behaviors:**
- **"standard"**: Dark grey projectiles, deal direct damage on penetration, no explosion
- **"high_explosive"**: Red projectiles, no direct damage, explode after afterpen delay when penetrating or immediately when blocked
- **"airburst"**: Yellow projectiles, no direct damage, explode after airburst_time OR on contact OR when within detect_range of any part
- **"rocket"**: Bright orange guided projectiles, follow player mouse cursor, explode on contact OR after airburst_time

**Damage System:**
- **Standard Rounds**: Deal direct damage to hit parts, pass through until blocked by armor
- **All Explosive Rounds**: No direct damage, all damage comes from explosion sphere only
- **Explosion Sphere**: Semi-transparent red sphere shows explosion area, auto-destroys after 3 seconds
- **Armor-Based Explosion Damage**: Only parts with `armor < projectile_armor_pen` take explosion damage
- **Distance Falloff**: Explosion damage decreases with distance from explosion center
- **Damage Formula**: `final_damage = explosive_radius_damage × max(0.1, 1 - distance/explosion_radius)`
- **Minimum Damage**: 10% of base damage at maximum range
- **Sphere Duration**: Visual explosion sphere auto-destroys after exactly 3 seconds
- **Sphere Cleanup**: Multiple backup systems ensure no permanent spheres remain

**Projectile Health System:**
- **Destructible Projectiles**: All projectiles have health and can be damaged/destroyed by other projectiles or explosions
- **Projectile-on-Projectile Combat**: Bullets can hit and damage rockets, rockets can hit other rockets
- **Explosion Damage to Projectiles**: Explosions damage all projectiles within blast radius
- **Destruction Behavior**: When projectile health reaches 0:
  - Standard/Airburst projectiles: Simply destroyed with no explosion
  - Rocket/High Explosive projectiles: Explode when destroyed (chain reactions possible)
- **Chain Reactions**: Destroying explosive projectiles can trigger cascading explosions
- **Defensive Applications**: AI turrets and players can shoot down incoming rockets

**Ammunition Management System:**
- **Magazine-Based Ammo**: Weapons have limited bullets per magazine (bullet_count)
- **Fire Rate Control**: Weapons fire at configurable rate (shots per second)
- **Manual Reload**: Players can manually reload to refill magazine
- **Auto-Reload (AI)**: AI turrets automatically reload when magazine is empty
- **Enhanced AI Defense**: AI turrets fire 3x faster when targeting rockets
- **Realistic Combat**: No more infinite ammo - tactical ammunition management required

---

## Part Attributes (Any BasePart)

### Armor & Health System
| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `armor` | number | 5 | Armor protection value (0 = unarmored) |
| `health` | number | 100 | Current health points |
| `max_health` | number | 100 | Maximum health for repair systems |

**Armor Mechanics:**
- If `projectile.armor_pen > part.armor`: Projectile penetrates and deals damage
- If `projectile.armor_pen ≤ part.armor`: Projectile ricochets, no damage
- Unarmored parts (`armor = 0`) allow all projectiles to pass through

---

## Configuration Examples

### High-Performance Fighter
```lua
-- VehicleSeat configuration
vehicleSeat:SetAttribute("ForceMagnitude", 5000)
vehicleSeat:SetAttribute("MaxHorizontalSpeed", 100)
vehicleSeat:SetAttribute("MaxVerticalSpeed", 80)
vehicleSeat:SetAttribute("GravityCompensation", 1.2)
vehicleSeat:SetAttribute("seattype", "2xturret")
vehicleSeat:SetAttribute("weapontype", "Cannon")
```

### Heavy Tank Cannon
```lua
-- Chamber configuration
chamber:SetAttribute("ammotype", "high_explosive")
chamber:SetAttribute("armor_pen", 25)
chamber:SetAttribute("afterpen", 0.3)
```

### High-Performance AI Turret (Anti-Missile Defense)
```lua
-- VehicleSeat configuration
vehicleSeat:SetAttribute("aiturret", true)
vehicleSeat:SetAttribute("weapontype", "Cannon")
vehicleSeat:SetAttribute("ai_update_interval", 0.02)  -- 50 FPS - very responsive
vehicleSeat:SetAttribute("tracking_speed", 30)        -- Very fast tracking
vehicleSeat:SetAttribute("target_cache_time", 0)      -- No cache - instant response
vehicleSeat:SetAttribute("max_target_distance", 250)  -- Long range

-- Chamber configuration for anti-missile
chamber:SetAttribute("ammotype", "standard")
chamber:SetAttribute("firerate", 10.0) -- Very fast firing
chamber:SetAttribute("armor_pen", 15)
```

### Heavy Defense AI Turret
```lua
-- VehicleSeat configuration
vehicleSeat:SetAttribute("aiturret", true)
vehicleSeat:SetAttribute("weapontype", "Cannon")
vehicleSeat:SetAttribute("ai_update_interval", 0.08)  -- 12.5 FPS - moderate
vehicleSeat:SetAttribute("tracking_speed", 10)        -- Slow but steady
vehicleSeat:SetAttribute("target_cache_time", 0.15)   -- Some caching
vehicleSeat:SetAttribute("max_target_distance", 180)  -- Medium range

-- Chamber configuration for area denial
chamber:SetAttribute("ammotype", "high_explosive")
chamber:SetAttribute("firerate", 2.0) -- Slower but powerful
chamber:SetAttribute("armor_pen", 25)
chamber:SetAttribute("explosion_radius", 30)
```

### Long-Range Sniper AI Turret
```lua
-- VehicleSeat configuration
vehicleSeat:SetAttribute("aiturret", true)
vehicleSeat:SetAttribute("weapontype", "Cannon")
vehicleSeat:SetAttribute("ai_update_interval", 0.1)   -- 10 FPS - patient
vehicleSeat:SetAttribute("tracking_speed", 8)         -- Slow, precise tracking
vehicleSeat:SetAttribute("target_cache_time", 0.2)    -- Longer cache for stability
vehicleSeat:SetAttribute("max_target_distance", 350)  -- Very long range

-- Chamber configuration for precision
chamber:SetAttribute("ammotype", "standard")
chamber:SetAttribute("firerate", 1.0) -- Deliberate firing
chamber:SetAttribute("armor_pen", 30) -- High penetration
chamber:SetAttribute("projectile_speed", 150) -- Fast projectiles
```

### Anti-Aircraft Gun
```lua
-- Chamber configuration
chamber:SetAttribute("ammotype", "airburst")
chamber:SetAttribute("airburst_time", 1.5)
chamber:SetAttribute("armor_pen", 8)
```

### Armored Hull Section
```lua
-- Part configuration
armorPlate:SetAttribute("armor", 20)
armorPlate:SetAttribute("health", 300)
armorPlate:SetAttribute("max_health", 300)
```

### Light Reconnaissance Vehicle
```lua
-- VehicleSeat configuration
vehicleSeat:SetAttribute("ForceMagnitude", 2000)
vehicleSeat:SetAttribute("MaxHorizontalSpeed", 75)
vehicleSeat:SetAttribute("RotateSpeed", 0.15)
vehicleSeat:SetAttribute("seattype", "turret")
vehicleSeat:SetAttribute("weapontype", "Cannon")

-- Chamber configuration (fast-firing gun)
chamber:SetAttribute("ammotype", "standard")
chamber:SetAttribute("armor_pen", 12)
```

### Guided Rocket Launcher
```lua
-- VehicleSeat configuration
vehicleSeat:SetAttribute("ForceMagnitude", 2500)
vehicleSeat:SetAttribute("seattype", "turret")
vehicleSeat:SetAttribute("weapontype", "Cannon")

-- Chamber configuration (guided rockets)
chamber:SetAttribute("ammotype", "rocket")
chamber:SetAttribute("projectile_speed", 80)
chamber:SetAttribute("explosion_radius", 25)
chamber:SetAttribute("explosive_radius_damage", 75)
chamber:SetAttribute("airburst_time", 5.0)
chamber:SetAttribute("reload", 2.0)
```

---

## AI Turret System Setup

### Required Components
1. **VehicleSeat** with `aiturret = true` and `weapontype = "Cannon"`
2. **Chamber part** named "chamber" in the same parent model as VehicleSeat
3. **AIrange part** named "AIrange" in the same parent model as VehicleSeat

### AIrange Part Setup
- **Purpose**: Defines the detection area for the AI turret
- **Size**: The part's size determines the detection volume (X, Y, Z dimensions)
- **Position**: Should be positioned where you want the center of detection
- **Transparency**: Recommended to set to 1.0 (invisible) for clean appearance
- **CanCollide**: Should be false to avoid interference

### AI Turret Performance Tuning

#### For Maximum Responsiveness (Anti-Missile Defense):
```lua
vehicleSeat:SetAttribute("ai_update_interval", 0.02)  -- 50 FPS
vehicleSeat:SetAttribute("target_cache_time", 0)      -- No caching
```

#### For Balanced Performance:
```lua
vehicleSeat:SetAttribute("ai_update_interval", 0.05)  -- 20 FPS (default)
vehicleSeat:SetAttribute("target_cache_time", 0.1)    -- Light caching (default)
```

#### For CPU-Friendly Operation (Many Turrets):
```lua
vehicleSeat:SetAttribute("ai_update_interval", 0.1)   -- 10 FPS
vehicleSeat:SetAttribute("target_cache_time", 0.3)    -- More caching
```

### AI Turret Targeting Behavior
- **Priority 1**: Enemy rockets (for missile defense)
- **Priority 2**: Enemy vehicles and parts with health, sorted by distance
- **Self-Targeting Prevention**: Turrets will not target their own vehicle or projectiles
- **Health Requirement**: Only targets parts with health > 0
- **Armor Consideration**: Turrets consider armor penetration when engaging

### AI Turret Automatic Features
- **Auto-Reload**: Turrets automatically reload when ammunition runs out
- **Smart Fire Rate**: 3x faster firing when targeting rockets
- **Rocket Cooldown**: Prevents rocket spam with 1-second minimum between rocket fires
- **Smooth Tracking**: Easing and deadzone for natural turret movement
- **Range Validation**: Re-validates targets are in range before firing

---

## Attribute Initialization

All attributes are automatically initialized with default values by the server if not already set. You can override these defaults by setting the attributes manually on the appropriate parts.

**Server initializes:**
- VehicleSeat: `seattype`, `weapontype`, movement attributes (`ForceMagnitude`, `VerticalForceUp`, etc.)
- Chamber parts: `ammotype`, `afterpen`, `airburst_time`, `armor_pen`, `projectile_speed`, `reload`, `detect_range`, `explosion_radius`, `explosive_radius_damage`
- All parts: `armor`, `health`, `max_health`

---

## Health and Armor System

**Every part in the game now has health and armor attributes:**

### Health System Behavior:
- When a part's health reaches 0, it begins a 3-second destruction sequence
- During destruction: part slowly becomes transparent (fade effect)
- When transparency reaches 1.0, the part is completely destroyed
- Health bars appear above damaged parts showing current/max health
- Health bars are color-coded: Green (>60%), Yellow (30-60%), Red (<30%)

### Updated Ammo Type Behaviors:

**Standard Rounds:**
- Deal direct damage to parts on penetration
- Pass through parts where `armor_pen > part_armor`
- Ricochet and destroy when blocked by armor
- No explosion effects
- Silent penetration through unarmored parts

**High Explosive Rounds:**
- No direct damage to hit parts
- Explode after 0.1 seconds when penetrating
- Explode immediately when blocked by armor
- All damage comes from explosion sphere
- Area effect damage with distance falloff

**Airburst Rounds:**
- No direct damage to hit parts
- Three explosion triggers: timer, contact, or proximity (10 studs)
- Explode after `airburst_time` seconds OR on any contact
- Proximity detection checks every 0.1 seconds
- All damage comes from explosion sphere

**High Penetration Explosive Rounds:**
- No direct damage to hit parts
- Explode after `afterpen` delay when penetrating
- Explode immediately when blocked by armor
- Designed to penetrate multiple armor layers before exploding
- All damage comes from explosion sphere

### Damage and Destruction:

**Direct Damage (Standard Rounds Only):**
- Standard rounds deal direct damage to parts they penetrate
- Default damage: 25 health points per hit
- Only applies when `armor_pen > part_armor`

**Explosion Damage (All Explosive Rounds):**
- Base damage from `explosive_radius_damage` attribute (default: 50)
- Distance falloff: damage decreases with distance from explosion center
- Minimum damage: 10% at edge of explosion radius
- Only affects parts where `armor_pen > part_armor`

**Part Destruction:**
- Parts are destroyed when health ≤ 0
- Destroyed parts fade to transparent over 3 seconds
- All joints (welds, constraints) are removed during destruction
- Health bars provide real-time visual feedback
- Health bars are color-coded: Green (>60%), Yellow (30-60%), Red (<30%)

---

## Explosion System

### Visual Effects:
- **Explosion Sphere**: Semi-transparent red sphere shows blast radius
- **Sphere Size**: Diameter = `explosion_radius × 2`
- **Sphere Duration**: Auto-destroys after exactly 3 seconds
- **Non-Interactive**: Projectiles pass through spheres without collision
- **Multiple Cleanup Systems**: Debris service + backup timers + global cleanup

### Explosion Prevention:
- **Single Explosion Per Projectile**: Each bullet can only explode once
- **Explosion Flag System**: `has_exploded` attribute prevents multiple explosions
- **Cooldown System**: 0.5-second cooldown per explosion location
- **Performance Optimized**: Prevents infinite explosion loops

### Damage Calculation:
```lua
-- Explosion damage formula
final_damage = explosive_radius_damage × max(0.1, 1 - distance/explosion_radius)

-- Armor check
if projectile_armor_pen > part_armor then
    -- Apply damage
else
    -- Blocked by armor
end
```

### Explosion Triggers:

**High Explosive:**
- Penetration: 0.1 second delay
- Blocked: Immediate explosion

**Airburst:**
- Timer: After `airburst_time` seconds
- Contact: On any collision
- Proximity: Within 10 studs of any part

**High Penetration Explosive:**
- Penetration: After `afterpen` delay
- Blocked: Immediate explosion

**Rocket:**
- Contact: Immediate explosion on any collision
- Timer: After `airburst_time` seconds if no contact
- Guidance: Follows player mouse cursor with 15% guidance strength

### Console Debug Output:
- `"SERVER: Explosion sphere created with ID: [id] - will destroy in 3 seconds"`
- `"SERVER: [AmmoType] already exploded, ignoring hit"` (prevention system)
- `"SERVER: Global cleanup destroying orphaned sphere: [id]"` (backup cleanup)
- `"SERVER: Explosion damaged [part] for [damage] damage (distance: [X] armor: [Y])"`
