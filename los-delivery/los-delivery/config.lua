Config = {}

-- General Settings
Config.Locale = 'da'
Config.Debug = false

-- NPC Settings
Config.NPC = {
    model = 's_m_m_postal_01',
    coords = vector4(844.9734, -894.3922, 25.2515, 270.7057), -- Post Office
    blip = {
        sprite = 480,
        color = 2,
        scale = 0.8,
        name = "Hemmeligt sted"
    }
}

-- Vehicle Settings
Config.DeliveryVehicle = 'speedo' -- Van for deliveries
Config.VehicleSpawn = {
    coords = vector4(852.5580, -902.6224, 25.2938, 265.2162), -- Van spawn location
    heading = 125.0
}

-- Reputation System
Config.Reputation = {
    levels = {
        {name = "Nybegynder", min = 0, max = 100, multiplier = 1.0},
        {name = "Erfaren", min = 101, max = 300, multiplier = 1.2},
        {name = "Professionel", min = 301, max = 600, multiplier = 1.5},
        {name = "Ekspert", min = 601, max = 1000, multiplier = 2.0},
        {name = "Mester", min = 1001, max = 9999, multiplier = 2.5}
    }
}

-- Delivery Settings
Config.Delivery = {
    basePayment = 17510, -- Base payment amount
    reputationBonus = 75, -- Bonus per reputation point
    maxPackages = 3, -- Maximum packages per delivery
    deliveryTime = 300000, -- 5 minutes to complete delivery
    cooldown = 600000, -- 10 minutes cooldown between deliveries
}

-- Delivery Locations (5 random locations)
Config.DeliveryLocations = {
    {
        name = "Lufthavn",
        coords = vector4(-791.0599, -2874.0024, 13.9474, 342.3025),
        blip = {sprite = 478, color = 1, scale = 0.8, name = "Levering - Lufthavn"}
    },
    {
        name = "Sandy Shores",
        coords = vector4(1728.2062, 3322.8364, 41.2235, 190.5801),
        blip = {sprite = 478, color = 1, scale = 0.8, name = "Levering - Sandy Shores"}
    },
    {
        name = "Paleto Bay",
        coords = vector4(-339.9851, 6231.0981, 31.4881, 356.6098),
        blip = {sprite = 478, color = 1, scale = 0.8, name = "Levering - Paleto Bay"}
    },
    {
        name = "Vinewood Hills",
        coords = vector4(-1838.0165, 791.5581, 138.7056, 128.6572),
        blip = {sprite = 478, color = 1, scale = 0.8, name = "Levering - Vinewood Hills"}
    },
    {
        name = "Mirror Park",
        coords = vector4(1141.8223, -427.3407, 67.2956, 252.5857),
        blip = {sprite = 478, color = 1, scale = 0.8, name = "Levering - Mirror Park"}
    }
}

-- Notifications
Config.Notifications = {
    startDelivery = "Pakke levering startet! Tjek dit kort for leveringssteder.",
    deliveryComplete = "Levering gennemført! Du tjente $%s og %s omdømmepoint.",
    deliveryFailed = "Levering mislykkedes! Du gennemførte ikke i tide.",
    noVehicle = "Du skal være i et leveringskøretøj for at starte en levering.",
    onCooldown = "Du er på cooldown. Vent %s minutter før du starter en ny levering.",
    reputationGained = "Du fik %s omdømmepoint!",
    levelUp = "Tillykke! Du har nået %s niveau!"
}
