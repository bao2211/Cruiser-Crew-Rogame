# Cruiser-Crew-Rogame

A modular Roblox vehicle combat game featuring advanced weapon systems, vehicle controls, and inspection tools. Built with a clean, maintainable architecture using separate client and server modules.

## 🚀 Features

### 🎮 Vehicle Control System
- **Multi-Seat Support**: Cruiser, turret, and dual-turret seat types
- **Advanced Controls**: WASD movement, mouse turret control, hover toggle
- **Position Locking**: Lock vehicle position while maintaining rotation
- **Gravity Compensation**: Configurable hover forces and physics

### 🔫 Weapon System
- **Multiple Ammo Types**: Standard, High Explosive, and Airburst rounds
- **Realistic Ballistics**: Armor penetration, damage falloff, and ricochet
- **Explosion Effects**: Visual explosion spheres with area damage
- **Sound Effects**: Impact sounds, ricochets, and explosions

### 🔍 Inspection Tools
- **Chamber Inspector**: View weapon attributes and configurations (T key)
- **Health Inspector**: Monitor part health and damage status (H key)
- **Real-Time Updates**: Dynamic GUIs that update as you move around

### 💊 Health System
- **Part Health**: Individual health and armor values for all parts
- **Visual Feedback**: Color-coded health bars and damage indicators
- **Destruction System**: Parts fade out and are destroyed when health reaches zero

## 📁 Project Structure

```
src/
├── client/                 # Client-side scripts
│   ├── VehicleControl.client.luau      # Vehicle movement and controls
│   ├── ChamberInspector.client.luau    # Weapon inspection tool
│   └── HealthInspector.client.luau     # Health monitoring tool
│
├── server/                 # Server-side scripts
│   ├── ServerCoordinator.server.luau   # RemoteEvent setup and coordination
│   ├── WeaponSystem.server.luau        # Weapon firing and projectiles
│   ├── VehicleHoverSystem.server.luau  # Vehicle physics and hover
│   └── AttributeInitializer.server.luau # Default attribute setup
│
└── shared/                 # Shared modules
    ├── GameConfig.luau      # Centralized configuration
    ├── GameUtils.luau       # Utility functions library
    ├── RemoteManager.luau   # Remote event management
    └── README.md           # Shared modules documentation
```

## 🛠️ Development Setup

### Prerequisites
- [Rojo](https://github.com/rojo-rbx/rojo) 7.5.1+
- Roblox Studio
- [Rokit](https://github.com/rojo-rbx/rokit) (optional)

### Building the Project

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd Cruiser-Crew-Rogame
   ```

2. **Build the place file**:
   ```bash
   rojo build -o "Cruiser-Crew-Rogame.rbxlx"
   ```

3. **Open in Roblox Studio**:
   - Open `Cruiser-Crew-Rogame.rbxlx` in Roblox Studio
   - Start the Rojo server for live sync:
     ```bash
     rojo serve
     ```

4. **Connect Rojo in Studio**:
   - In Studio, go to Plugins → Rojo → Connect
   - The project will sync automatically when you save files

## 🎮 How to Play

### Vehicle Controls
- **Movement**: WASD keys for forward/backward/strafe
- **Rotation**: Q/E keys for cruiser seats, mouse for turret seats
- **Vertical**: X/C keys for up/down thrust
- **Functions**: F (hover toggle), G (position lock), Space (fire weapon)

### Inspection Tools
- **Chamber Inspector**: Press T to toggle, walk near chambers to see attributes
- **Health Inspector**: Press H to toggle, walk near parts to see health status

### Weapon System
- **Standard Rounds**: Direct damage, silent penetration
- **High Explosive**: Area damage with delayed explosion after penetration
- **Airburst**: Proximity and timer-based explosions for anti-aircraft

## ⚙️ Configuration

### Weapon Attributes (Chamber Parts)
- `ammotype`: "standard", "high_explosive", or "airburst"
- `armor_pen`: Armor penetration value (default: 10)
- `damage`: Direct damage dealt (default: 25)
- `afterpen`: HE explosion delay in seconds (default: 0.5)
- `airburst_time`: Airburst timer in seconds (default: 2.0)
- `detect_range`: Proximity detection range (default: 15)
- `explosion_radius`: Blast radius in studs (default: 20)
- `explosive_radius_damage`: Explosion damage (default: 50)

### Vehicle Attributes (VehicleSeat Parts)
- `seattype`: "cruiser", "turret", or "2xturret"
- `weapontype`: "None" or "Cannon"
- `GravityCompensation`: Hover force multiplier (default: 0.8)
- `PositionLocked`: Lock position toggle (default: false)
- `ForceMagnitude`: Movement force strength (default: 3000)
- `RotateSpeed`: Rotation speed (default: 0.1)

### Part Attributes (All Parts)
- `health`: Current health value (default: 100)
- `max_health`: Maximum health capacity (auto-set from current health)
- `armor`: Armor protection value (default: 5)

## 🔧 Customization

### Adding New Weapon Types
1. Update `GameConfig.luau` with new ammo type configuration
2. Add handling logic in `WeaponSystem.server.luau`
3. Update attribute initialization in `AttributeInitializer.server.luau`

### Creating New Vehicle Types
1. Add new seat type to `GameConfig.luau`
2. Implement control logic in `VehicleControl.client.luau`
3. Update server-side physics in `VehicleHoverSystem.server.luau`

### Modifying Inspection Tools
1. Adjust ranges and intervals in `GameConfig.luau`
2. Customize GUI appearance using `GameUtils.luau` functions
3. Add new inspection modes by extending existing client scripts

## 📚 Documentation

- **[Shared Modules](src/shared/README.md)**: Detailed documentation for GameConfig, GameUtils, and RemoteManager
- **[Settable Attributes](SETTABLE_ATTRIBUTES.md)**: Complete attribute reference and usage guide
- **[Server Managed Attributes](SERVER_MANAGED_ATTRIBUTES.md)**: Server-side attribute management documentation

## 🏗️ Architecture Benefits

### 🎯 **Modular Design**
- Each system is self-contained and focused on a single responsibility
- Easy to modify or extend individual features without affecting others
- Clear separation between client and server logic

### 🔧 **Maintainability**
- Centralized configuration through shared modules
- Reusable utility functions reduce code duplication
- Consistent coding patterns and naming conventions

### 👥 **Team Development**
- Multiple developers can work on different systems simultaneously
- Clear ownership of functionality and reduced merge conflicts
- Well-documented interfaces and APIs

### 🚀 **Performance**
- Optimized algorithms for part detection and GUI management
- Efficient remote event communication
- Memory-safe cleanup and resource management

## 🐛 Troubleshooting

### Common Issues

**"RemoteEvents not found" Error**:
- Ensure ServerCoordinator.server.luau is running first
- Check that RemoteEvents folder exists in ReplicatedStorage

**Vehicle Not Responding**:
- Verify VehicleSeat has correct `seattype` and `weapontype` attributes
- Check that VehicleHoverSystem.server.luau is running
- Ensure player is properly seated in the vehicle

**Weapons Not Firing**:
- Confirm chamber part exists and has `ammotype` attribute
- Verify WeaponSystem.server.luau is loaded
- Check console for error messages

**Inspection Tools Not Working**:
- Make sure you're within range of target parts
- Verify parts have the required attributes (health, ammotype, etc.)
- Check that inspection mode is enabled (T or H key)

### Debug Console Output
The game provides extensive console logging:
- `CLIENT:` prefix for client-side messages
- `SERVER:` prefix for server-side messages
- Category tags like `[WEAPON]`, `[VEHICLE]`, `[HEALTH]` for filtering

## 🤝 Contributing

1. Follow the existing modular architecture
2. Use shared modules (GameConfig, GameUtils, RemoteManager) when possible
3. Add appropriate console logging for debugging
4. Update documentation when adding new features
5. Test thoroughly in both single-player and multiplayer scenarios

## 📄 License

This project is open source. Feel free to use, modify, and distribute as needed.

---

**Built with ❤️ using Rojo and modern Roblox development practices**