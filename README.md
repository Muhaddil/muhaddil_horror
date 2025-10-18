# FiveM Horror System (Work-In-Progress)

A comprehensive horror experience system for FiveM servers that adds atmospheric effects, jumpscares, whispers, ghost appearances, and more to designated zones in your server.

## 📋 Features

### 🌑 Horror Zones
- **Predefined Horror Zones**: Cemetery, Haunted Forest, Abandoned House, Dark Tunnel
- **Zone-based Intensity**: Each zone has configurable intensity levels (low, medium, high)
- **Progressive Intensity**: Horror effects intensify the longer players stay in zones
- **Visual Indicators**: Custom UI elements show when entering/leaving zones

### 👻 Horror Effects
- **Jumpscares**: Random ghost, demon, zombie, shadow, and clown appearances
- **Whispers & Sounds**: Directional 3D audio effects including whispers, screams, and laughs
- **Visual Distortions**: Static, blur, chromatic aberration, and darkness effects
- **Ghost Appearances**: Hostile ghost entities that chase players
- **Environmental Effects**: Fog, thunder, footsteps, heartbeats, and door sounds
- **Paranormal Objects**: Floating objects, shadow figures, and bloody messages

### 🧠 Sanity System
- **Dynamic Sanity**: Player sanity decreases while in horror zones
- **Visual Representation**: Sanity meter with color-coded indicators
- **Recovery System**: Sanity recovers when outside horror zones
- **Low Sanity Effects**: Additional horror effects when sanity is low

### 🔧 Admin Commands
- `/horrorevent [start/stop/status]` - Control global horror events
- `/horrorjump [ID/all]` - Trigger jumpscares
- `/horrorwhisper [ID/all]` - Trigger whispers
- `/horrordistort [ID/all]` - Trigger visual distortions
- `/horrorghost [ID/all]` - Spawn ghost entities
- `/horrorenv [ID/all]` - Trigger environmental effects
- `/horrorcombo [ID]` - Trigger all effects at once
- `/horrorimmune [ID]` - Toggle player immunity
- `/horrortele [ID] [zone]` - Teleport player to horror zone
- `/horrorstats [ID]` - View player horror statistics
- `/horrorreset [ID]` - Reset player statistics
- `/horrorhelp` - List all commands

## 🛠️ Installation

1. Download the resource
2. Place it in your server's resources directory
3. Add `ensure muhaddil_horror` to your server.cfg
4. Make sure you have the dependency `PolyZone` installed
5. Restart your server

## ⚙️ Configuration

The system is highly configurable through the `config.lua` file:

### General Settings
```lua
Config.EnableHorrorSystem = true  -- Master toggle
Config.DebugMode = false          -- Enable debug information
Config.OnlyAtNight = true         -- Only active at night
Config.NightHours = {
    start = 20,                   -- 8 PM
    finish = 6                    -- 6 AM
}
```

### Horror Zones
Configure custom horror zones with different shapes (poly, box) and intensity levels:

```lua
Config.HorrorZones = {
    {
        name = "Cemetery",
        type = "poly",
        points = { ... },         -- Polygon points
        minZ = 50.0,
        maxZ = 69.0,
        intensity = "high",
        enableGhosts = true
    },
    -- More zones...
}
```

### Event Configuration
Adjust probabilities, cooldowns, and types for each horror effect:

```lua
Config.Events = {
    jumpscares = {
        enabled = true,
        baseChance = 8,           -- Base probability
        cooldown = 180000,        -- 3 minutes cooldown
        minTimeInZone = 30000,    -- 30 seconds minimum time
        types = { ... }           -- Jumpscare types with weights
    },
    -- More event types...
}
```

## 🎮 Usage

### For Players
1. Enter one of the horror zones
2. Experience random horror effects based on zone intensity
3. Your sanity will decrease while in horror zones
4. Leave the zone to recover sanity and escape the horror

### For Admins
1. Use admin commands to control the horror system
2. Trigger specific effects on players
3. Start global horror events affecting all players
4. Monitor player statistics

## 🔊 Sound System

The system includes a comprehensive audio manager with:

- 3D positional audio
- Ambient sound loops
- Directional sounds (front, back, left, right)
- Volume control with fade in/out effects
- Preloaded critical sounds for performance

## 🎨 Visual Effects

- Vignette effects based on zone intensity
- Screen distortions (static, chromatic aberration)
- Jumpscare overlays with animations
- Environmental visual effects (fog, lightning)
- Sanity meter UI

## 🔌 Exports

```lua
-- Client exports
exports['muhaddil_horror']:IsInHorrorZone()       -- Returns if player is in horror zone
exports['muhaddil_horror']:GetCurrentZone()       -- Returns current zone data
exports['muhaddil_horror']:GetPlayerSanity()      -- Returns player sanity level
exports['muhaddil_horror']:GetIntensity()         -- Returns current intensity
exports['muhaddil_horror']:IsImmune()             -- Returns if player is immune
exports['muhaddil_horror']:ForceEvent(eventType)  -- Force a specific event

-- Server exports
exports['muhaddil_horror']:GetPlayerStats(id)     -- Get player statistics
exports['muhaddil_horror']:GetAllStats()          -- Get all player statistics
exports['muhaddil_horror']:IsGlobalEventActive()  -- Check if global event is active
exports['muhaddil_horror']:SetGlobalEvent(bool)   -- Set global event state
```

## 🔄 Integration

### ESX Integration
The system integrates with ESX for admin permissions:

```lua
local xPlayer = ESX.GetPlayerFromId(source)
if xPlayer.getGroup() == 'admin' then
    -- Admin permissions granted
end
```

### Custom Integration
You can integrate with other scripts using the provided exports.

## 📊 Performance

The system is designed with performance in mind:

- Configurable update intervals
- Entity cleanup system
- Disabled in vehicles option
- Limited active entities
- Preloaded critical sounds

## 📝 License

This resource is licensed under the [MIT License](LICENSE).

## 🙏 Credits

- Sound effects from [Mixkit](https://mixkit.co/)
- PolyZone dependency by [mkafrin](https://github.com/mkafrin/PolyZone)
- Created by Muhaddil