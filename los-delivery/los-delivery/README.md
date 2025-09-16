# Package Delivery System

A comprehensive package delivery system for FiveM ESX servers with reputation system, Discord webhook logging, and ox_inventory integration.

## Features

- **Reputation System**: Earn reputation points and level up for better rewards
- **Random Delivery Locations**: 5 different delivery locations across the map
- **ox_lib Integration**: Modern context menus and progress bars
- **ox_inventory Support**: Cash payments through inventory system
- **Discord Webhook Logging**: Track all delivery completions
- **Persistent Data**: Reputation saves across server restarts
- **Configurable**: Easy to customize locations, payments, and settings

## Installation

1. **Download** the script and place it in your `resources` folder
2. **Import** the SQL file to your database:
   ```sql
   -- Run the SQL from package_delivery.sql
   ```
3. **Add** to your `server.cfg`:
   ```
   ensure los-delivery
   ```
4. **Configure** your Discord webhook in `server/main.lua`:
   ```lua
   local DISCORD_WEBHOOK = "YOUR_DISCORD_WEBHOOK_URL"
   ```

## Dependencies

- **es_extended** (ESX Framework)
- **ox_target** (For NPC interactions)
- **ox_lib** (For UI elements)
- **ox_inventory** (For cash payments)
- **mysql-async** (For database operations)

## Configuration

### Vehicle Settings
```lua
Config.DeliveryVehicle = 'speedo' -- Delivery vehicle
Config.VehicleSpawn = {
    coords = vector4(-1202.5, -885.0, 13.0, 125.0), -- Spawn location
    heading = 125.0
}
```

### Payment Settings
```lua
Config.Delivery = {
    basePayment = 21000, -- Base payment amount
    reputationBonus = 100, -- Bonus per reputation point
    deliveryTime = 300000, -- 5 minutes to complete
    cooldown = 600000, -- 10 minutes cooldown
}
```

### Reputation Levels
- **Nybegynder** (0-100 points): 1.0x multiplier
- **Erfaren** (101-300 points): 1.2x multiplier
- **Professionel** (301-600 points): 1.5x multiplier
- **Ekspert** (601-1000 points): 2.0x multiplier
- **Mester** (1001+ points): 2.5x multiplier

## How to Use

1. **Find the NPC**: Look for the postal worker NPC with a blip on the map
2. **Start Delivery**: Interact with the NPC using ox_target
3. **Get Vehicle**: A Speedo van will spawn for you
4. **Pick Up Package**: Use ox_target on the van to get a package
5. **Drive to Location**: Go to the random delivery location shown on map
6. **Complete Delivery**: Interact with the delivery NPC to complete
7. **Get Rewards**: Receive cash money and reputation points

## Discord Webhook Setup

1. **Create Webhook**:
   - Go to your Discord server
   - Right-click channel → Edit Channel → Integrations → Webhooks
   - Click "Create Webhook"
   - Copy the webhook URL

2. **Configure Script**:
   - Open `server/main.lua`
   - Find `local DISCORD_WEBHOOK = ""`
   - Replace with your webhook URL
   - Save and restart the resource

## Database

The script creates a `package_delivery_reputation` table with the following structure:
- `identifier` - Player identifier
- `reputation` - Current reputation points
- `total_deliveries` - Total deliveries attempted
- `successful_deliveries` - Successful deliveries completed
- `total_earned` - Total money earned
- `last_delivery` - Timestamp of last delivery

## Customization

### Adding New Delivery Locations
```lua
Config.DeliveryLocations = {
    {
        name = "New Location",
        coords = vector4(x, y, z, heading),
        blip = {sprite = 478, color = 1, scale = 0.8, name = "Delivery - New Location"}
    },
    -- Add more locations here
}
```

### Changing Payment Amounts
```lua
Config.Delivery = {
    basePayment = 25000, -- Increase base payment
    reputationBonus = 150, -- Increase reputation bonus
}
```

### Modifying Reputation Levels
```lua
Config.Reputation = {
    levels = {
        {name = "Beginner", min = 0, max = 100, multiplier = 1.0},
        {name = "Expert", min = 101, max = 500, multiplier = 2.0},
        -- Add more levels
    }
}
```

## Troubleshooting

### Common Issues

1. **NPC Not Spawning**:
   - Check if ESX is loaded properly
   - Verify ox_target is running
   - Check console for error messages

2. **Reputation Not Saving**:
   - Ensure database connection is working
   - Check if SQL table was created properly
   - Verify player identifiers are correct

3. **Discord Webhook Not Working**:
   - Verify webhook URL is correct
   - Check if webhook has proper permissions
   - Test webhook manually

4. **Menu Not Opening**:
   - Ensure ox_lib is installed and running
   - Check for JavaScript errors in F8 console
   - Verify ox_target integration

## Support

For support and updates, please check the script documentation or contact los.

## License

This script is provided as-is for FiveM server use. Please respect the terms of use and don't redistribute without permission.