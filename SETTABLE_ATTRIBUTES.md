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

---

## Chamber Part Attributes (Parts named "chamber")

### Ammunition Configuration
| Attribute | Type | Default | Options | Description |
|-----------|------|---------|---------|-------------|
| `ammotype` | string | "standard" | "standard", "high_explosive", "airburst", "high_penetration_explosive" | Projectile behavior type |
| `afterpen` | number | 0.5 | Any positive number | Delay (seconds) before HE explosion after armor penetration |
| `airburst_time` | number | 2.0 | Any positive number | Time (seconds) before airburst explosion |
| `armor_pen` | number | 10 | Any positive number | Armor penetration value |

**Ammo Type Behaviors:**
- **"standard"**: Dark grey projectiles, penetrate/pass through, no explosion
- **"high_explosive"**: Red projectiles, always explode on any contact
- **"airburst"**: Yellow projectiles, explode after airburst_time OR on contact (also proximity detection within 10 studs)
- **"high_penetration_explosive"**: Orange projectiles, afterpen timer behavior (explode after delay if penetrate, explode immediately if blocked)

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

---

## Usage Notes

1. **Hover Activation**: Set `GravityCompensation ≥ 1.0` to enable hover mode
2. **Weapon Firing**: Requires `weapontype = "Cannon"` and a "chamber" part in the vehicle
3. **Armor Penetration**: Compare `armor_pen` vs `armor` to determine penetration
4. **Health System**: Parts are destroyed when `health ≤ 0`
5. **Airburst Timer**: Airburst rounds explode after timer OR on contact (whichever first)
6. **Afterpen Delay**: Only applies to HE rounds that penetrate armor (armor > 0)

---

## Attribute Initialization

All attributes are automatically initialized with default values by the server if not already set. You can override these defaults by setting the attributes manually on the appropriate parts.

**Server initializes:**
- VehicleSeat: `seattype`, `weapontype`
- Chamber parts: `ammotype`, `afterpen`, `airburst_time`, `armor_pen`
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

### Ammo Type Behaviors:

- ammo: standard
- when hit a part check that part armor if it is less than the ammo armor_pen then it will pass thought and deal damage to the part until it hit a part with armor greater than the ammo armor_pen then it will ricochet and not deal damage to the part and get destroyed

-- ammo: high_explosive
- when hit a part explode 

-- ammo: airburst
- when fire check around the bullet 10 stud if there a part then explode

-- ammo: high_penetration_explosive
- when hit a part check that part armor if it is less then the ammo armor_pen then it will pass thought and start the afterpen timer when timer finish explode if it is more then the ammo armor_pen then it will not pass thought but explode on contact

### Damage and Destruction:
- Parts take damage when penetrated by projectiles
- Default damage: 25 health points per hit
- Parts are destroyed when health ≤ 0
- Destroyed parts fade to transparent over 3 seconds
- All joints (welds, constraints) are removed during destruction
- Health bars provide real-time visual feedback
