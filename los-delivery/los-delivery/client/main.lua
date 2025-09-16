ESX = exports["es_extended"]:getSharedObject()
local lib = exports.ox_lib

-- Variables
local npc = nil
local npcBlip = nil
local deliveryNPC = nil
local deliveryBlip = nil
local deliveryVehicle = nil
local isOnDelivery = false
local deliveryTimer = nil
local playerReputation = nil
local hasPackage = false
local packageProp = nil
local currentDeliveryLocation = nil
local deliveryCompletionSent = false
local deliveryCompleted = false -- FIXED: Track if delivery to this NPC is already completed

-- Get reputation level (client-side)
local function getReputationLevel(reputation)
    for _, level in ipairs(Config.Reputation.levels) do
        if reputation >= level.min and reputation <= level.max then
            return level
        end
    end
    return Config.Reputation.levels[1] -- Default to first level
end

-- Calculate estimated payment (client-side)
local function calculateEstimatedPayment(reputation)
    local basePayment = Config.Delivery.basePayment
    local reputationBonus = Config.Delivery.reputationBonus * (reputation / 10)
    
    -- Get reputation level multiplier
    local multiplier = 1.0
    if reputation >= 1001 then
        multiplier = 2.5
    elseif reputation >= 601 then
        multiplier = 2.0
    elseif reputation >= 301 then
        multiplier = 1.5
    elseif reputation >= 101 then
        multiplier = 1.2
    end
    
    return math.floor((basePayment + reputationBonus) * multiplier)
end

-- Give package to player
local function givePackageToPlayer()
    
    if hasPackage then 
        return 
    end
    
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    
    -- Create package prop
    local model = GetHashKey('prop_cs_cardbox_01')
    RequestModel(model)
    
    local attempts = 0
    while not HasModelLoaded(model) and attempts < 50 do
        Wait(100)
        attempts = attempts + 1
    end
    
    if not HasModelLoaded(model) then
        return
    end
    
    packageProp = CreateObject(model, coords.x, coords.y, coords.z, true, true, true)
    
    if not packageProp or packageProp == 0 then
        return
    end
    
    
    -- Attach package to player
    local boneIndex = GetPedBoneIndex(playerPed, 57005)
    AttachEntityToEntity(packageProp, playerPed, boneIndex, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    
    hasPackage = true
    
    lib:notify({
        title = 'Pakke',
        description = 'Du har taget pakken ud af varen. Gå nu til leveringsstedet.',
        type = 'success'
    })
    
end

-- Remove package from player
local function removePackageFromPlayer()
    if packageProp and DoesEntityExist(packageProp) then
        DeleteEntity(packageProp)
        packageProp = nil
    end
    hasPackage = false
end

-- FIXED: Make delivery NPC walk away immediately and clean up quickly
local function makeDeliveryNPCWalkAway()
    if not deliveryNPC or not DoesEntityExist(deliveryNPC) then
        return
    end
    
    
    -- Remove blip immediately
    if deliveryBlip then
        RemoveBlip(deliveryBlip)
        deliveryBlip = nil
    end
    
    -- Unfreeze the NPC so it can move
    FreezeEntityPosition(deliveryNPC, false)
    SetBlockingOfNonTemporaryEvents(deliveryNPC, false)
    
    -- Get a random direction to walk away quickly
    local npcCoords = GetEntityCoords(deliveryNPC)
    local randomAngle = math.random(0, 360)
    local walkDistance = 30.0 -- Shorter distance
    
    local targetX = npcCoords.x + math.cos(math.rad(randomAngle)) * walkDistance
    local targetY = npcCoords.y + math.sin(math.rad(randomAngle)) * walkDistance
    local targetZ = npcCoords.z
    
    -- Make NPC walk away faster
    TaskGoStraightToCoord(deliveryNPC, targetX, targetY, targetZ, 2.0, 5000, GetEntityHeading(deliveryNPC), 0.5) -- Faster speed and shorter timeout
    
    -- FIXED: Much shorter cleanup timer
    CreateThread(function()
        Wait(3000) -- Wait only 3 seconds for NPC to start walking away
        
        if deliveryNPC and DoesEntityExist(deliveryNPC) then
            DeleteEntity(deliveryNPC)
            deliveryNPC = nil
        end
    end)
    
end

-- Show main delivery menu (ox_lib context menu)
local function showDeliveryMenu()
    
    -- Use current reputation data if available, otherwise use defaults
    local reputation = playerReputation and playerReputation.reputation or 0
    local level = getReputationLevel(reputation)
    local estimatedPayment = calculateEstimatedPayment(reputation)
    
    local contextMenu = {
        {
            title = 'Start Pakke Levering',
            description = 'Start en ny pakke levering',
            icon = 'fas fa-truck',
            onSelect = function()
                TriggerEvent('los_package_delivery:startDelivery')
            end
        },
        {
            title = 'Omdømme Information',
            description = 'Din omdømmestatus: ' .. level.name .. ' (' .. reputation .. ' point)',
            icon = 'fas fa-star',
            onSelect = function()
                showReputationDetails()
            end
        },
        {
            title = 'Estimeret Betaling',
            description = 'Næste levering: $' .. estimatedPayment,
            icon = 'fas fa-dollar-sign',
            disabled = true
        }
    }
    
    if isOnDelivery then
        table.insert(contextMenu, 1, {
            title = 'Aktuel Levering',
            description = 'Du er i gang med en levering',
            icon = 'fas fa-clock',
            disabled = true
        })
    end
    
    -- Request fresh reputation data in background
    TriggerServerEvent('los_package_delivery:getReputation')
    
    lib:registerContext({
        id = 'delivery_menu',
        title = 'Pakke Levering System',
        options = contextMenu
    })
    
    lib:showContext('delivery_menu')
end

-- Show reputation details (ox_lib context menu)
local function showReputationDetails()
    
    -- Use current reputation data if available, otherwise use defaults
    local contextMenu = {}
    
    if playerReputation then
        local level = getReputationLevel(playerReputation.reputation or 0)
        contextMenu = {
            {
                title = 'Omdømme Niveau',
                description = level.name,
                icon = 'fas fa-star',
                disabled = true
            },
            {
                title = 'Omdømme Point',
                description = tostring(playerReputation.reputation or 0),
                icon = 'fas fa-chart-line',
                disabled = true
            },
            {
                title = 'Totale Leveringer',
                description = tostring(playerReputation.totalDeliveries or 0),
                icon = 'fas fa-truck',
                disabled = true
            },
            {
                title = 'Succesfulde Leveringer',
                description = tostring(playerReputation.successfulDeliveries or 0),
                icon = 'fas fa-check-circle',
                disabled = true
            },
            {
                title = 'Total Tjent',
                description = '$' .. tostring(playerReputation.totalEarned or 0),
                icon = 'fas fa-dollar-sign',
                disabled = true
            },
            {
                title = 'Tilbage',
                description = 'Gå tilbage til hovedmenu',
                icon = 'fas fa-arrow-left',
                onSelect = function()
                    showDeliveryMenu()
                end
            }
        }
    else
        contextMenu = {
            {
                title = 'Fejl',
                description = 'Kunne ikke hente omdømmedata',
                icon = 'fas fa-exclamation-triangle',
                disabled = true
            },
            {
                title = 'Prøv igen',
                description = 'Forsøg at hente data igen',
                icon = 'fas fa-redo',
                onSelect = function()
                    TriggerServerEvent('los_package_delivery:getReputation')
                    Wait(1000)
                    showReputationDetails()
                end
            },
            {
                title = 'Tilbage',
                description = 'Gå tilbage til hovedmenu',
                icon = 'fas fa-arrow-left',
                onSelect = function()
                    showDeliveryMenu()
                end
            }
        }
    end
    
    -- Request fresh reputation data in background
    TriggerServerEvent('los_package_delivery:getReputation')
    
    lib:registerContext({
        id = 'reputation_details_menu',
        title = 'Omdømme Detaljer',
        options = contextMenu
    })
    
    lib:showContext('reputation_details_menu')
end

-- Create main NPC
local function createNPC()
    local model = GetHashKey(Config.NPC.model)
    
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(1)
    end
    
    npc = CreatePed(4, model, Config.NPC.coords.x, Config.NPC.coords.y, Config.NPC.coords.z - 1.0, Config.NPC.coords.w, false, true)
    FreezeEntityPosition(npc, true)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    
    
    -- Create blip
    npcBlip = AddBlipForCoord(Config.NPC.coords.x, Config.NPC.coords.y, Config.NPC.coords.z)
    SetBlipSprite(npcBlip, Config.NPC.blip.sprite)
    SetBlipDisplay(npcBlip, 4)
    SetBlipScale(npcBlip, Config.NPC.blip.scale)
    SetBlipColour(npcBlip, Config.NPC.blip.color)
    SetBlipAsShortRange(npcBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.NPC.blip.name)
    EndTextCommandSetBlipName(npcBlip)
    
    
    -- Wait a moment for NPC to be fully created
    Wait(1000)
    
    -- Add ox_target interaction
    if GetResourceState('ox_target') == 'started' then
        
        exports.ox_target:addBoxZone({
            coords = vector3(Config.NPC.coords.x, Config.NPC.coords.y, Config.NPC.coords.z),
            size = vector3(2.0, 2.0, 2.0),
            rotation = Config.NPC.coords.w,
            debug = false,
            options = {
                {
                    name = 'package_delivery_menu',
                    onSelect = function()
                        showDeliveryMenu()
                    end,
                    icon = 'fas fa-truck',
                    label = 'Pakke Levering',
                    distance = 2.0
                }
            }
        })
    else
    end
end

-- Create delivery NPC at random location
local function createDeliveryNPC()
    
    -- Select random delivery location
    currentDeliveryLocation = Config.DeliveryLocations[math.random(1, #Config.DeliveryLocations)]
    
    local model = GetHashKey('s_m_m_postal_02')
    
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(1)
    end
    
    deliveryNPC = CreatePed(4, model, currentDeliveryLocation.coords.x, currentDeliveryLocation.coords.y, currentDeliveryLocation.coords.z - 1.0, currentDeliveryLocation.coords.w, false, true)
    FreezeEntityPosition(deliveryNPC, true)
    SetEntityInvincible(deliveryNPC, true)
    SetBlockingOfNonTemporaryEvents(deliveryNPC, true)
    
    -- Reset delivery completion status for new NPC
    deliveryCompleted = false
    
    
    -- Create blip
    deliveryBlip = AddBlipForCoord(currentDeliveryLocation.coords.x, currentDeliveryLocation.coords.y, currentDeliveryLocation.coords.z)
    SetBlipSprite(deliveryBlip, currentDeliveryLocation.blip.sprite)
    SetBlipDisplay(deliveryBlip, 4)
    SetBlipScale(deliveryBlip, currentDeliveryLocation.blip.scale)
    SetBlipColour(deliveryBlip, currentDeliveryLocation.blip.color)
    SetBlipAsShortRange(deliveryBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(currentDeliveryLocation.blip.name)
    EndTextCommandSetBlipName(deliveryBlip)
    
    
    -- Wait a moment for NPC to be fully created
    Wait(1000)
    
    -- Add ox_target interaction for delivery
    if GetResourceState('ox_target') == 'started' then
        
        -- Wait for NPC to be fully created
        Wait(500)
        
        exports.ox_target:addLocalEntity(deliveryNPC, {
            {
                name = 'package_delivery_complete',
                onSelect = function()
                    TriggerEvent('los_package_delivery:completeDelivery')
                end,
                icon = 'fas fa-check',
                label = 'Lever Pakke',
                distance = 2.0
            }
        })
    end
end

-- Spawn delivery vehicle
local function spawnDeliveryVehicle()
    local model = GetHashKey(Config.DeliveryVehicle)
    
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(1)
    end
    
    deliveryVehicle = CreateVehicle(model, Config.VehicleSpawn.coords.x, Config.VehicleSpawn.coords.y, Config.VehicleSpawn.coords.z, Config.VehicleSpawn.coords.w, true, false)
    SetEntityAsMissionEntity(deliveryVehicle, true, true)
    SetVehicleOnGroundProperly(deliveryVehicle)
    
    
    -- Add ox_target interaction to vehicle
    if GetResourceState('ox_target') == 'started' then
        exports.ox_target:addLocalEntity(deliveryVehicle, {
            {
                name = 'package_delivery_vehicle',
                onSelect = function()
                    givePackageToPlayer()
                end,
                icon = 'fas fa-box',
                label = 'Tag Pakke',
                distance = 2.0
            }
        })
    end
end

-- Start delivery timer
local function startDeliveryTimer()
    deliveryTimer = GetGameTimer()
    
    CreateThread(function()
        while isOnDelivery and deliveryTimer do
            Wait(30000) -- Check every 30 seconds
            
            if deliveryTimer then
                local timeLeft = Config.Delivery.deliveryTime - (GetGameTimer() - deliveryTimer)
                
                if timeLeft <= 0 then
                    -- Delivery failed
                    lib:notify({
                        title = 'Pakke Levering',
                        description = 'Levering fejlede! Du brugte for lang tid.',
                        type = 'error'
                    })
                    endDelivery()
                    break
                else
                    local minutesLeft = math.ceil(timeLeft / 60000)
                    lib:notify({
                        title = 'Pakke Levering',
                        description = 'Du har ' .. minutesLeft .. ' minutter tilbage til at levere pakken.',
                        type = 'inform'
                    })
                end
            end
        end
    end)
end

-- End delivery
local function endDelivery()
    isOnDelivery = false
    deliveryTimer = nil
    currentDeliveryLocation = nil
    deliveryCompleted = false -- FIXED: Reset delivery completion status
    
    -- Remove package from player
    removePackageFromPlayer()
    
    -- Remove ox_target from delivery NPC before deleting (if still exists)
    if deliveryNPC and DoesEntityExist(deliveryNPC) and GetResourceState('ox_target') == 'started' then
        exports.ox_target:removeLocalEntity(deliveryNPC, 'package_delivery_complete')
    end
    
    -- Remove delivery NPC and blip (if still exists - may have been removed immediately)
    if deliveryNPC and DoesEntityExist(deliveryNPC) then
        DeleteEntity(deliveryNPC)
        deliveryNPC = nil
    end
    
    if deliveryBlip then
        RemoveBlip(deliveryBlip)
        deliveryBlip = nil
    end
    
    -- Remove delivery vehicle
    if deliveryVehicle and DoesEntityExist(deliveryVehicle) then
        DeleteEntity(deliveryVehicle)
        deliveryVehicle = nil
    end
    
    -- Clear waypoint
    SetWaypointOff()
    
end

-- Events
RegisterNetEvent('los_package_delivery:startDelivery')
AddEventHandler('los_package_delivery:startDelivery', function()
    if isOnDelivery then
        lib:notify({
            title = 'Pakke Levering',
            description = 'Du er allerede på en levering!',
            type = 'error'
        })
        return
    end
    
    -- Show progress bar
    lib:progressBar({
        duration = 3000, -- 3 seconds
        label = 'Forbereder levering...',
        useWhileDead = false,
        canCancel = false,
        disable = {
            car = true,
            move = true,
            combat = true
        }
    })
    
    -- Wait for progress bar to complete
    Wait(3000)
    
    -- Spawn delivery vehicle
    spawnDeliveryVehicle()
    
    -- Create delivery NPC in Sandy Shores
    createDeliveryNPC()
    
    -- Start delivery
    isOnDelivery = true
    deliveryCompletionSent = false
    deliveryCompleted = false -- FIXED: Reset completion status for new delivery
    startDeliveryTimer()
    
    -- Set waypoint to delivery location
    SetNewWaypoint(currentDeliveryLocation.coords.x, currentDeliveryLocation.coords.y)
    
    lib:notify({
        title = 'Pakke Levering',
        description = 'Levering startet! Tag pakken ud af varen og kør til ' .. currentDeliveryLocation.name .. '. Waypoint sat!',
        type = 'success'
    })
end)

RegisterNetEvent('los_package_delivery:completeDelivery')
AddEventHandler('los_package_delivery:completeDelivery', function()
    if packageProp then
    end
    
    if not isOnDelivery then
        lib:notify({
            title = 'Pakke Levering',
            description = 'Du er ikke på en levering!',
            type = 'error'
        })
        return
    end
    
    -- FIXED: Check if delivery to this NPC was already completed
    if deliveryCompleted then
        lib:notify({
            title = 'Pakke Levering',
            description = 'Du har allerede leveret til denne NPC!',
            type = 'error'
        })
        return
    end
    
    if not hasPackage then
        
        -- Try to fix the package status
        if packageProp and DoesEntityExist(packageProp) then
            hasPackage = true
        else
            lib:notify({
                title = 'Pakke Levering',
                description = 'Du skal have en pakke for at levere! Gå tilbage til varen og tag pakken.',
                type = 'error'
            })
            return
        end
    end
    
    -- Double-check package status before proceeding
    if not hasPackage then
        lib:notify({
            title = 'Pakke Levering',
            description = 'Fejl: Pakke status kunne ikke bekræftes. Prøv igen.',
            type = 'error'
        })
        return
    end
    
    -- FIXED: Mark delivery as completed immediately to prevent multiple completions
    deliveryCompleted = true
    
    -- FIXED: Remove ox_target from delivery NPC immediately to prevent multiple interactions
    if deliveryNPC and DoesEntityExist(deliveryNPC) and GetResourceState('ox_target') == 'started' then
        exports.ox_target:removeLocalEntity(deliveryNPC, 'package_delivery_complete')
    end
    
    -- Show progress bar for delivery completion
    lib:progressBar({
        duration = 5000, -- 5 seconds
        label = 'Leverer pakke...',
        useWhileDead = false,
        canCancel = false,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'mp_common',
            clip = 'givetake1_a'
        }
    })
    
    -- Wait for progress bar to complete
    Wait(5000)
    
    -- Remove package from player
    removePackageFromPlayer()
    
    -- FIXED: Make delivery NPC walk away instead of disappearing immediately
    makeDeliveryNPCWalkAway()
    
    -- Complete delivery on server
    local deliveryTime = 0
    if deliveryTimer then
        deliveryTime = GetGameTimer() - deliveryTimer
    end
    
    deliveryCompletionSent = true
    TriggerServerEvent('los_package_delivery:completeDelivery', {
        completed = true,
        time = deliveryTime
    })
    
    -- Set a timeout to end delivery if server doesn't respond
    CreateThread(function()
        Wait(10000) -- Wait 10 seconds for server response
        
        if isOnDelivery and deliveryCompletionSent then
            endDelivery()
            lib:notify({
                title = 'Pakke Levering',
                description = 'Levering afsluttet (server timeout)',
                type = 'inform'
            })
        end
    end)
    
    -- Don't end delivery here - let server handle completion and send success notification
    -- endDelivery() will be called when server sends success notification
end)

RegisterNetEvent('los_package_delivery:reputationData')
AddEventHandler('los_package_delivery:reputationData', function(data)
    playerReputation = data
end)

-- Handle delivery completion success from server
RegisterNetEvent('los_package_delivery:deliveryCompleted')
AddEventHandler('los_package_delivery:deliveryCompleted', function()
    deliveryCompletionSent = false -- Reset the flag
    endDelivery()
end)

-- Main thread
CreateThread(function()
    
    -- Check if config is loaded
    if not Config or not Config.NPC then
        return
    end
    
    
    -- Wait for ESX to load
    while ESX.GetPlayerData() == nil do
        Wait(10)
    end
    
    
    -- Wait a bit more to ensure everything is loaded
    Wait(2000)
    
    -- Create main NPC
    createNPC()
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if npc and DoesEntityExist(npc) then
            DeleteEntity(npc)
        end
        
        if npcBlip then
            RemoveBlip(npcBlip)
        end
        
        if deliveryNPC and DoesEntityExist(deliveryNPC) then
            DeleteEntity(deliveryNPC)
        end
        
        if deliveryBlip then
            RemoveBlip(deliveryBlip)
        end
        
        if deliveryVehicle and DoesEntityExist(deliveryVehicle) then
            DeleteEntity(deliveryVehicle)
        end
        
        if packageProp and DoesEntityExist(packageProp) then
            DeleteEntity(packageProp)
        end
    end
end)