ESX = exports["es_extended"]:getSharedObject()

-- Player reputation data cache
local playerReputation = {}

-- Discord Webhook Configuration
local DISCORD_WEBHOOK = "https://discord.com/api/webhooks/1414266466370322552/wq05UStLEpzJb7bQ2_cqw2hWU4vuISsW6Jprx4Hsygh1mPAd66pd1NC3MDDlUSCZBS1C" -- Put your Discord webhook URL here
local DISCORD_BOT_NAME = "Package Delivery System"
local DISCORD_AVATAR_URL = "https://cdn.discordapp.com/attachments/your-avatar-url.png" -- Optional: Custom avatar

-- Get player reputation level
local function getReputationLevel(reputation)
    for i, level in ipairs(Config.Reputation.levels) do
        if reputation >= level.min and reputation <= level.max then
            return level
        end
    end
    return Config.Reputation.levels[1] -- Default to first level
end

-- Discord Webhook Function
local function sendDiscordLog(title, description, color, fields)
    if DISCORD_WEBHOOK == "" or DISCORD_WEBHOOK == nil then
        return -- No webhook configured
    end
    
    local embed = {
        {
            ["title"] = title,
            ["description"] = description,
            ["type"] = "rich",
            ["color"] = color or 65280, -- Default green color
            ["fields"] = fields or {},
            ["footer"] = {
                ["text"] = "Package Delivery System • " .. os.date("%Y-%m-%d %H:%M:%S"),
            },
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
    }
    
    local data = {
        ["username"] = DISCORD_BOT_NAME,
        ["avatar_url"] = DISCORD_AVATAR_URL,
        ["embeds"] = embed
    }
    
    PerformHttpRequest(DISCORD_WEBHOOK, function(err, text, headers) end, 'POST', json.encode(data), { ['Content-Type'] = 'application/json' })
end

-- Initialize player reputation data
local function initPlayerReputation(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    local identifier = xPlayer.identifier
    
    MySQL.Async.fetchAll('SELECT * FROM package_delivery_reputation WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    }, function(result)
        if result[1] then
            -- Load existing reputation data
            playerReputation[source] = {
                identifier = result[1].identifier,
                reputation = result[1].reputation,
                total_deliveries = result[1].total_deliveries,
                successful_deliveries = result[1].successful_deliveries,
                total_earned = result[1].total_earned,
                last_delivery = result[1].last_delivery,
                level = getReputationLevel(result[1].reputation)
            }
        else
            -- Create new reputation entry
            MySQL.Async.execute('INSERT INTO package_delivery_reputation (identifier, reputation, total_deliveries, successful_deliveries, total_earned) VALUES (@identifier, 0, 0, 0, 0)', {
                ['@identifier'] = identifier
            })
            playerReputation[source] = {
                identifier = identifier,
                reputation = 0,
                total_deliveries = 0,
                successful_deliveries = 0,
                total_earned = 0,
                last_delivery = nil,
                level = getReputationLevel(0)
            }
        end
    end)
end

-- Calculate payment based on reputation
local function calculatePayment(reputation)
    local level = getReputationLevel(reputation)
    local basePayment = Config.Delivery.basePayment
    local reputationBonus = Config.Delivery.reputationBonus * (reputation / 10) -- More rewarding
    local totalPayment = math.floor((basePayment + reputationBonus) * level.multiplier)
    
    -- Minimum payment of base amount
    if totalPayment < basePayment then
        totalPayment = basePayment
    end
    
    return totalPayment
end

-- Save player reputation to database
local function savePlayerReputation(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not playerReputation[source] then return false end
    
    local identifier = xPlayer.identifier
    local repData = playerReputation[source]
    
    
    MySQL.Async.execute('UPDATE package_delivery_reputation SET reputation = @reputation, total_deliveries = @total_deliveries, successful_deliveries = @successful_deliveries, total_earned = @total_earned, last_delivery = @last_delivery WHERE identifier = @identifier', {
        ['@reputation'] = repData.reputation,
        ['@total_deliveries'] = repData.total_deliveries,
        ['@successful_deliveries'] = repData.successful_deliveries,
        ['@total_earned'] = repData.total_earned,
        ['@last_delivery'] = repData.last_delivery and os.date('%Y-%m-%d %H:%M:%S', repData.last_delivery) or nil,
        ['@identifier'] = identifier
    }, function(affectedRows)
        if affectedRows > 0 then
        else
        end
    end)
    
    return true
end

-- Update player reputation
local function updateReputation(source, reputationGain, moneyEarned)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    local identifier = xPlayer.identifier
    local currentRep = playerReputation[source].reputation
    local newRep = currentRep + reputationGain
    
    -- Update cache first
    playerReputation[source].reputation = newRep
    playerReputation[source].total_deliveries = playerReputation[source].total_deliveries + 1
    playerReputation[source].successful_deliveries = playerReputation[source].successful_deliveries + 1
    playerReputation[source].total_earned = playerReputation[source].total_earned + moneyEarned
    playerReputation[source].last_delivery = os.time()
    playerReputation[source].level = getReputationLevel(newRep)
    
    -- Update database
    MySQL.Async.execute('UPDATE package_delivery_reputation SET reputation = @reputation, total_deliveries = @total_deliveries, successful_deliveries = @successful_deliveries, total_earned = @total_earned, last_delivery = NOW() WHERE identifier = @identifier', {
        ['@reputation'] = newRep,
        ['@total_deliveries'] = playerReputation[source].total_deliveries,
        ['@successful_deliveries'] = playerReputation[source].successful_deliveries,
        ['@total_earned'] = playerReputation[source].total_earned,
        ['@identifier'] = identifier
    }, function(affectedRows)
        if affectedRows > 0 then
        else
        end
    end)
    
    -- Check for level up
    local oldLevel = getReputationLevel(currentRep)
    local newLevel = getReputationLevel(newRep)
    
    if newLevel.name ~= oldLevel.name then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Niveau Opgradering!',
            description = string.format('Tillykke! Du har nået %s niveau!', newLevel.name),
            type = 'success'
        })
    end
    
    return newRep
end

-- Player joining event to load reputation
AddEventHandler('esx:playerLoaded', function(source, xPlayer)
    Wait(2000) -- Wait for player to be fully loaded
    initPlayerReputation(source)
end)

-- Alternative player joining event (for newer ESX versions)
AddEventHandler('esx:onPlayerJoined', function(source)
    Wait(2000) -- Wait for player to be fully loaded
    initPlayerReputation(source)
end)

-- Player leaving event to save and clean up reputation data
AddEventHandler('playerDropped', function(reason)
    local source = source
    if playerReputation[source] then
        savePlayerReputation(source)
        Wait(1000) -- Give time for database save
        playerReputation[source] = nil
    end
end)

-- Events
RegisterNetEvent('los_package_delivery:startDelivery')
AddEventHandler('los_package_delivery:startDelivery', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end
    
    -- Check if player has reputation data
    if not playerReputation[source] then
        initPlayerReputation(source)
        Wait(1000) -- Wait for data to load
    end
    
    -- Check cooldown
    local lastDelivery = playerReputation[source].lastDelivery
    if lastDelivery then
        local timeDiff = os.time() - lastDelivery
        if timeDiff < (Config.Delivery.cooldown / 1000) then
            local remainingTime = math.ceil((Config.Delivery.cooldown / 1000) - timeDiff)
            local minutes = math.ceil(remainingTime / 60)
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Cooldown',
                description = string.format('Du er på cooldown. Vent %s minutter før du starter en ny levering.', minutes),
                type = 'error'
            })
            return
        end
    end
    
    -- Start delivery on client (simplified)
    TriggerClientEvent('los_package_delivery:startClientDelivery', source)
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Pakke Levering',
        description = 'Levering startet! Tag pakken ud af varen og kør til lufthavnen.',
        type = 'success'
    })
end)

RegisterNetEvent('los_package_delivery:completeDelivery')
AddEventHandler('los_package_delivery:completeDelivery', function(deliveryData)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    -- Validate delivery data
    if not deliveryData or not deliveryData.completed then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Pakke Levering',
            description = 'Fejl: Ugyldig leveringsdata',
            type = 'error'
        })
        return
    end
    
    -- Get player identifiers for logging
    local steamName = GetPlayerName(source)
    local steamId = nil
    local discordId = nil
    local license = nil
    
    -- Get all player identifiers
    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local identifier = GetPlayerIdentifier(source, i)
        if identifier then
            if string.sub(identifier, 1, string.len("steam:")) == "steam:" then
                steamId = identifier
            elseif string.sub(identifier, 1, string.len("discord:")) == "discord:" then
                discordId = identifier
            elseif string.sub(identifier, 1, string.len("license:")) == "license:" then
                license = identifier
            end
        end
    end
    
    -- Log delivery completion trigger to Discord
    local fields = {
        {
            ["name"] = "Player Information",
            ["value"] = "**Name:** " .. (steamName or "Unknown") .. "\n**ID:** " .. source,
            ["inline"] = true
        },
        {
            ["name"] = "Identifiers",
            ["value"] = "**Steam:** " .. (steamId or "Not Found") .. "\n**Discord:** " .. (discordId or "Not Found") .. "\n**License:** " .. (license or "Not Found"),
            ["inline"] = true
        },
        {
            ["name"] = "ESX Data",
            ["value"] = "**Identifier:** " .. (xPlayer and xPlayer.identifier or "Not Found"),
            ["inline"] = true
        }
    }
    
    sendDiscordLog(
        "📦 Package Delivery Completion Triggered",
        "A player has triggered the delivery completion event",
        16776960, -- Yellow color
        fields
    )
    
    if not xPlayer then 
        return 
    end
    
    
    if not playerReputation[source] then
        initPlayerReputation(source)
        Wait(1000)
    else
    end
    
    local reputation = 0
    if playerReputation[source] then
        reputation = playerReputation[source].reputation or 0
    end
    local payment = calculatePayment(reputation)
    local reputationGain = math.random(10, 25)
    
    -- Give cash money to player using ox_inventory

    local moneyGiven = false
    
    -- Try ox_inventory first
    if GetResourceState('ox_inventory') == 'started' then
        
        local success, result = pcall(function()
            -- Give money item directly
            exports.ox_inventory:AddItem(source, 'money', payment)
            return true
        end)
        
        if success then
            moneyGiven = true
        else
        end
    else
    end
    
    -- Fallback to ESX money if ox_inventory failed
    if not moneyGiven then
        xPlayer.addMoney(payment)
    end
    
    
    -- Update reputation
    local newRep = updateReputation(source, reputationGain, payment)
    
    -- Get reputation level for payment breakdown
    local level = getReputationLevel(reputation)
    
    -- Notify player with ox_lib
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Pakke Levering Gennemført!',
        description = string.format('Du tjente $%s (Niveau: %s x%.1f)', payment, level.name, level.multiplier),
        type = 'success'
    })
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Omdømme',
        description = string.format('Du fik %s omdømmepoint! (Total: %s)', reputationGain, newRep),
        type = 'inform'
    })
    
    -- Send completion confirmation to client
    TriggerClientEvent('los_package_delivery:deliveryCompleted', source)
    
    -- Log final delivery results to Discord
    local completionFields = {
        {
            ["name"] = "Player",
            ["value"] = "**" .. steamName .. "** (ID: " .. source .. ")",
            ["inline"] = true
        },
        {
            ["name"] = "Payment",
            ["value"] = "**$" .. payment .. "**",
            ["inline"] = true
        },
        {
            ["name"] = "Reputation",
            ["value"] = "**+" .. reputationGain .. "** points",
            ["inline"] = true
        },
        {
            ["name"] = "New Total",
            ["value"] = "**" .. newRep .. "** points",
            ["inline"] = true
        },
        {
            ["name"] = "Level",
            ["value"] = "**" .. level.name .. "**",
            ["inline"] = true
        },
        {
            ["name"] = "Identifiers",
            ["value"] = "**Steam:** " .. (steamId or "N/A") .. "\n**Discord:** " .. (discordId or "N/A"),
            ["inline"] = true
        }
    }
    
    sendDiscordLog(
        "✅ Package Delivery Completed Successfully",
        "A player has successfully completed a package delivery and received their reward",
        65280, -- Green color
        completionFields
    )
    
end)

-- Test command to give money item
RegisterCommand('givemoney', function(source, args)
    local amount = tonumber(args[1]) or 1000
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end
    
    local moneyGiven = false
    
    -- Try ox_inventory first
    if GetResourceState('ox_inventory') == 'started' then
        local success, result = pcall(function()
            exports.ox_inventory:AddItem(source, 'money', amount)
            return true
        end)
        
        if success then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Test Money',
                description = 'Gave $' .. amount .. ' money item',
                type = 'success'
            })
            moneyGiven = true
        else
        end
    else
    end
    
    -- Fallback to ESX money
    if not moneyGiven then
        xPlayer.addMoney(amount)
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Test Money',
            description = 'Gave $' .. amount .. ' via ESX money',
            type = 'success'
        })
    end
    
end, true)

-- Alternative test using giveitem command format
RegisterCommand('testmoney', function(source, args)
    local amount = tonumber(args[1]) or 1000
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end
    
    
    -- Use the same method as the delivery system
    local success, errorMsg = pcall(function()
        if exports.ox_inventory:CanCarryItem(source, 'money', amount) then
            exports.ox_inventory:AddItem(source, 'money', amount)
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Test Money',
                description = 'Gave $' .. amount .. ' money item',
                type = 'success'
            })
            return true
        else
            return false
        end
    end)
    
    if not success then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Test Money',
            description = 'ox_inventory failed: ' .. tostring(errorMsg),
            type = 'error'
        })
    end
end, true)

-- Test command to check if money item exists
RegisterCommand('checkmoneyitem', function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    if GetResourceState('ox_inventory') == 'started' then
        
        -- Try to check if money item exists
        local success, result = pcall(function()
            return exports.ox_inventory:CanCarryItem(source, 'money', 1)
        end)
        
        if success then
            if result then
                TriggerClientEvent('ox_lib:notify', source, {
                    title = 'Money Item Check',
                    description = 'Money item exists and is available',
                    type = 'success'
                })
            else
                TriggerClientEvent('ox_lib:notify', source, {
                    title = 'Money Item Check',
                    description = 'Money item not available',
                    type = 'error'
                })
            end
        else
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Money Item Check',
                description = 'Error: ' .. tostring(result),
                type = 'error'
            })
        end
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Money Item Check',
            description = 'ox_inventory not available',
            type = 'error'
        })
    end
    
end, true)

-- Test command to simulate delivery completion
RegisterCommand('testdelivery', function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    -- Simulate delivery completion
    TriggerEvent('los_package_delivery:completeDelivery', {
        completed = true,
        time = 50000
    })
    
end, true)

-- Command to manually save reputation data
RegisterCommand('saverep', function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    if playerReputation[source] then
        local success = savePlayerReputation(source)
        if success then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Reputation',
                description = 'Reputation data saved successfully',
                type = 'success'
            })
        else
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Reputation',
                description = 'Failed to save reputation data',
                type = 'error'
            })
        end
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Reputation',
            description = 'No reputation data found',
            type = 'error'
        })
    end
    
end, true)

-- Command to check reputation data in database
RegisterCommand('checkrep', function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    
    MySQL.Async.fetchAll('SELECT * FROM package_delivery_reputation WHERE identifier = @identifier', {
        ['@identifier'] = xPlayer.identifier
    }, function(result)
        if result[1] then
            
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Database Reputation',
                description = 'Rep: ' .. result[1].reputation .. ' | Deliveries: ' .. result[1].successful_deliveries,
                type = 'inform'
            })
        else
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Database Reputation',
                description = 'No data found in database',
                type = 'error'
            })
        end
    end)
    
end, true)

-- Command to add test reputation
RegisterCommand('addrep', function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    local amount = tonumber(args[1]) or 50
    if not playerReputation[source] then
        initPlayerReputation(source)
        Wait(1000)
    end
    
    if playerReputation[source] then
        local oldRep = playerReputation[source].reputation
        playerReputation[source].reputation = playerReputation[source].reputation + amount
        playerReputation[source].total_deliveries = playerReputation[source].total_deliveries + 1
        playerReputation[source].successful_deliveries = playerReputation[source].successful_deliveries + 1
        playerReputation[source].total_earned = playerReputation[source].total_earned + 1000
        playerReputation[source].last_delivery = os.time()
        playerReputation[source].level = getReputationLevel(playerReputation[source].reputation)
        
        -- Save to database
        savePlayerReputation(source)
        
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Test Reputation',
            description = 'Added ' .. amount .. ' reputation points',
            type = 'success'
        })
        
    end
    
end, true)

RegisterNetEvent('los_package_delivery:failedDelivery')
AddEventHandler('los_package_delivery:failedDelivery', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end
    
    -- Update database (failed delivery)
    MySQL.Async.execute('UPDATE package_delivery_reputation SET total_deliveries = total_deliveries + 1, last_delivery = NOW() WHERE identifier = @identifier', {
        ['@identifier'] = xPlayer.identifier
    })
    
    -- Update cache
    if playerReputation[source] then
        playerReputation[source].total_deliveries = playerReputation[source].total_deliveries + 1
    end
    
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Pakke Levering',
        description = 'Levering mislykkedes! Du gennemførte ikke i tide.',
        type = 'error'
    })
end)

-- Get player reputation
RegisterNetEvent('los_package_delivery:getReputation')
AddEventHandler('los_package_delivery:getReputation', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end
    
    if not playerReputation[source] then
        initPlayerReputation(source)
        Wait(1000)
    end
    
    local repData = playerReputation[source]
    if repData then
        local level = getReputationLevel(repData.reputation)
        TriggerClientEvent('los_package_delivery:reputationData', source, {
            reputation = repData.reputation,
            level = level,
            totalDeliveries = repData.total_deliveries,
            successfulDeliveries = repData.successful_deliveries,
            totalEarned = repData.total_earned,
            lastDelivery = repData.last_delivery
        })
    end
end)

-- Player disconnect cleanup
AddEventHandler('playerDropped', function()
    local source = source
    playerReputation[source] = nil
end)

-- Initialize reputation for players already online
AddEventHandler('esx:playerLoaded', function(source)
    Wait(5000) -- Wait for player to fully load
    initPlayerReputation(source)
end)

-- Save all player reputation data when resource stops (server restart)
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        
        for source, _ in pairs(playerReputation) do
            if playerReputation[source] then
                savePlayerReputation(source)
            end
        end
        
    end
end)
