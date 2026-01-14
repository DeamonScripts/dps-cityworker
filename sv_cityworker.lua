local Config = lib.require('config')
local Server = lib.require('sv_config')
local Players = {}
local SectorHealth = {}

-- =====================================
-- DATABASE / PERSISTENCE
-- =====================================

-- Load sector health from database on start
CreateThread(function()
    Wait(1000) -- Wait for MySQL to initialize

    local results = MySQL.query.await('SELECT sector_id, health FROM city_infrastructure')
    if results then
        for _, row in ipairs(results) do
            SectorHealth[row.sector_id] = row.health
        end
        print('[dps-cityworker] ^2Loaded sector health from database^0')
    end

    -- Initialize any missing sectors
    for id, data in pairs(Config.Sectors) do
        if not SectorHealth[id] then
            SectorHealth[id] = 100.0
            MySQL.insert.await('INSERT IGNORE INTO city_infrastructure (sector_id, health) VALUES (?, ?)', {id, 100.0})
        end
    end
end)

-- Save sector health to database
local function SaveSectorHealth(sectorId)
    if SectorHealth[sectorId] then
        MySQL.update.await('UPDATE city_infrastructure SET health = ? WHERE sector_id = ?', {SectorHealth[sectorId], sectorId})
    end
end

-- Save all sectors (called periodically)
local function SaveAllSectors()
    for id, health in pairs(SectorHealth) do
        MySQL.update.await('UPDATE city_infrastructure SET health = ? WHERE sector_id = ?', {health, id})
    end
end

-- =====================================
-- PLAYER STATS
-- =====================================

local function GetPlayerStats(source)
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return { rank = 1, xp = 0, total_repairs = 0 } end

    local result = MySQL.single.await('SELECT rank, xp, total_repairs, total_earnings FROM city_worker_users WHERE identifier = ?', {identifier})

    if result then
        return result
    end

    return { rank = 1, xp = 0, total_repairs = 0, total_earnings = 0 }
end

local function SavePlayerStats(source, data)
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return end

    MySQL.insert.await([[
        INSERT INTO city_worker_users (identifier, rank, xp, total_repairs, total_earnings)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE rank = VALUES(rank), xp = VALUES(xp), total_repairs = VALUES(total_repairs), total_earnings = VALUES(total_earnings)
    ]], {identifier, data.rank, data.xp, data.total_repairs or 0, data.total_earnings or 0})
end

-- =====================================
-- SECTOR / GRID MANAGEMENT
-- =====================================

-- Decay Loop: Lowers infrastructure health over time
CreateThread(function()
    while true do
        Wait(60000 * 10) -- Run every 10 minutes

        for id, data in pairs(Config.Sectors) do
            if SectorHealth[id] and SectorHealth[id] > 0 then
                local decayAmount = (data.decayRate / 6)
                SectorHealth[id] = math.max(0, SectorHealth[id] - decayAmount)

                -- Check for Blackout Threshold
                if SectorHealth[id] <= data.blackoutThreshold then
                    TriggerClientEvent('dps-cityworker:client:TriggerBlackout', -1, id)
                    print(('[dps-cityworker] ^1GRID ALERT: Sector %s has failed!^0'):format(data.label))
                end

                SaveSectorHealth(id)
            end
        end

        -- Broadcast updated health to all clients with Control Room open
        TriggerClientEvent('dps-cityworker:client:UpdateSectorHealth', -1, SectorHealth)
    end
end)

-- Periodic save
CreateThread(function()
    while true do
        Wait(300000) -- Save every 5 minutes
        SaveAllSectors()
    end
end)

local function RepairSector(coords, amount)
    for id, data in pairs(Config.Sectors) do
        local sectorPos = data.coords
        if #(coords - sectorPos) < data.radius then
            SectorHealth[id] = math.min(100.0, SectorHealth[id] + amount)
            SaveSectorHealth(id)
            return id, SectorHealth[id]
        end
    end
    return nil, 0
end

local function GetSectorForCoords(coords)
    for id, data in pairs(Config.Sectors) do
        if #(coords - data.coords) < data.radius then
            return id
        end
    end
    return nil
end

-- =====================================
-- WORK VEHICLE
-- =====================================

local function createWorkVehicle(source)
    local spawn = Server.VehicleSpawn
    local model = Server.Vehicle

    local veh = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.w, true, true)

    local ped = GetPlayerPed(source)
    while not DoesEntityExist(veh) do Wait(10) end
    TaskWarpPedIntoVehicle(ped, veh, -1)

    return NetworkGetNetworkIdFromEntity(veh)
end

-- =====================================
-- TASK SYSTEM
-- =====================================

-- Task types with different properties
local TaskTypes = {
    -- Basic Tasks (Rank 1)
    pipe = { label = 'Water Pipe Repair', xp = 20, repairAmount = 2.0, difficulty = 'easy', minRank = 1, category = 'maintenance' },
    pothole = { label = 'Pothole Repair', xp = 15, repairAmount = 1.5, difficulty = 'easy', minRank = 1, category = 'road' },
    meter_reading = { label = 'Meter Reading', xp = 10, repairAmount = 0.5, difficulty = 'easy', minRank = 1, category = 'utility' },
    graffiti = { label = 'Graffiti Removal', xp = 18, repairAmount = 1.0, difficulty = 'easy', minRank = 1, category = 'cleanup' },
    trash = { label = 'Trash Collection', xp = 12, repairAmount = 0.5, difficulty = 'easy', minRank = 1, category = 'cleanup' },

    -- Intermediate Tasks (Rank 2)
    streetlight = { label = 'Streetlight Repair', xp = 25, repairAmount = 2.5, difficulty = 'medium', minRank = 2, category = 'electrical' },
    hydrant = { label = 'Fire Hydrant Inspection', xp = 22, repairAmount = 1.5, difficulty = 'medium', minRank = 2, category = 'maintenance' },
    sign_repair = { label = 'Road Sign Repair', xp = 20, repairAmount = 1.0, difficulty = 'medium', minRank = 2, category = 'road' },
    manhole = { label = 'Manhole Inspection', xp = 28, repairAmount = 2.0, difficulty = 'medium', minRank = 2, category = 'sewer' },
    storm_drain = { label = 'Storm Drain Clearing', xp = 25, repairAmount = 2.0, difficulty = 'medium', minRank = 2, category = 'sewer' },

    -- Advanced Tasks (Rank 3)
    electrical = { label = 'Electrical Box Repair', xp = 35, repairAmount = 3.0, difficulty = 'medium', minRank = 3, category = 'electrical' },
    traffic_control = { label = 'Traffic Control Setup', xp = 30, repairAmount = 1.5, difficulty = 'medium', minRank = 3, category = 'road' },
    tree_trimming = { label = 'Tree Trimming', xp = 35, repairAmount = 2.5, difficulty = 'medium', minRank = 3, category = 'maintenance' },
    cable_install = { label = 'Cable Installation', xp = 40, repairAmount = 3.0, difficulty = 'medium', minRank = 3, category = 'utility' },

    -- Expert Tasks (Rank 4)
    transformer = { label = 'Transformer Maintenance', xp = 50, repairAmount = 5.0, difficulty = 'hard', minRank = 4, category = 'electrical' },
    hazmat = { label = 'Hazmat Cleanup', xp = 60, repairAmount = 4.0, difficulty = 'hard', minRank = 4, category = 'cleanup' },
    bridge_inspection = { label = 'Bridge Inspection', xp = 55, repairAmount = 4.0, difficulty = 'hard', minRank = 4, category = 'maintenance' },
    utility_locating = { label = 'Utility Locating', xp = 45, repairAmount = 2.0, difficulty = 'hard', minRank = 4, category = 'utility' },

    -- Emergency Tasks (Can be assigned to any rank during emergencies)
    water_main = { label = 'Water Main Break', xp = 80, repairAmount = 8.0, difficulty = 'hard', minRank = 2, category = 'emergency', isEmergency = true },
    gas_leak = { label = 'Gas Leak Response', xp = 100, repairAmount = 10.0, difficulty = 'hard', minRank = 3, category = 'emergency', isEmergency = true },
    downed_lines = { label = 'Downed Power Lines', xp = 90, repairAmount = 9.0, difficulty = 'hard', minRank = 4, category = 'emergency', isEmergency = true },
    fallen_tree = { label = 'Fallen Tree Removal', xp = 70, repairAmount = 6.0, difficulty = 'medium', minRank = 2, category = 'emergency', isEmergency = true },
}

local function GetTaskForRank(rank, includeEmergency)
    local available = {}
    for taskId, task in pairs(TaskTypes) do
        -- Skip emergency tasks unless specifically requested
        if not task.isEmergency or includeEmergency then
            if rank >= task.minRank then
                table.insert(available, taskId)
            end
        end
    end

    if #available == 0 then return 'pipe' end
    return available[math.random(#available)]
end

-- =====================================
-- EMERGENCY EVENT SYSTEM
-- =====================================

local ActiveEmergencies = {}
local EmergencyLocations = {}

local function TriggerEmergencyEvent(eventType, sectorId)
    if ActiveEmergencies[sectorId] then return false end -- Already active emergency

    local sector = Config.Sectors[sectorId]
    if not sector then return false end

    local task = TaskTypes[eventType]
    if not task or not task.isEmergency then return false end

    -- Generate random location within sector
    local angle = math.random() * 2 * math.pi
    local distance = math.random() * (sector.radius * 0.7)
    local emergencyCoords = vec3(
        sector.coords.x + math.cos(angle) * distance,
        sector.coords.y + math.sin(angle) * distance,
        sector.coords.z
    )

    ActiveEmergencies[sectorId] = {
        type = eventType,
        coords = emergencyCoords,
        startTime = os.time(),
        resolved = false,
    }

    -- Reduce sector health significantly
    local healthPenalty = task.repairAmount * 2
    SectorHealth[sectorId] = math.max(0, SectorHealth[sectorId] - healthPenalty)
    SaveSectorHealth(sectorId)

    -- Alert all workers
    TriggerClientEvent('dps-cityworker:client:EmergencyAlert', -1, {
        type = eventType,
        label = task.label,
        sector = sectorId,
        sectorLabel = sector.label,
        coords = emergencyCoords,
        xpBonus = task.xp,
    })

    print(('[dps-cityworker] ^1EMERGENCY: %s in %s!^0'):format(task.label, sector.label))
    return true
end

local function ResolveEmergency(sectorId, source)
    if not ActiveEmergencies[sectorId] then return false end

    local emergency = ActiveEmergencies[sectorId]
    local task = TaskTypes[emergency.type]

    -- Bonus XP and payment for emergency response
    if source and Players[source] then
        local bonusXp = task.xp * 1.5
        local bonusPayment = math.floor(Config.Economy.BasePay * 2)

        Players[source].xp = Players[source].xp + bonusXp
        Bridge.AddMoney(source, Server.Account or 'cash', bonusPayment, 'emergency-response-bonus')
        Bridge.Notify(source, ('Emergency resolved! Bonus: +$%d, +%d XP'):format(bonusPayment, bonusXp), 'success')
    end

    -- Restore sector health
    SectorHealth[sectorId] = math.min(100, SectorHealth[sectorId] + task.repairAmount)
    SaveSectorHealth(sectorId)

    ActiveEmergencies[sectorId] = nil

    -- Notify all clients
    TriggerClientEvent('dps-cityworker:client:EmergencyResolved', -1, sectorId)

    return true
end

-- Random emergency event spawner
CreateThread(function()
    Wait(300000) -- Wait 5 minutes before first potential emergency

    while true do
        Wait(600000) -- Check every 10 minutes

        -- 15% chance of emergency per check
        if math.random(100) <= 15 then
            local sectors = {}
            for id, _ in pairs(Config.Sectors) do
                if not ActiveEmergencies[id] then
                    table.insert(sectors, id)
                end
            end

            if #sectors > 0 then
                local randomSector = sectors[math.random(#sectors)]
                local emergencyTypes = {'water_main', 'gas_leak', 'downed_lines', 'fallen_tree'}
                local randomEmergency = emergencyTypes[math.random(#emergencyTypes)]

                TriggerEmergencyEvent(randomEmergency, randomSector)
            end
        end
    end
end)

-- =====================================
-- WEATHER-TRIGGERED EVENTS
-- =====================================

local LastWeatherEvent = 0
local WeatherEventCooldown = 300 -- 5 minutes between weather-triggered emergencies

RegisterNetEvent('dps-cityworker:server:WeatherEvent', function(weatherType)
    local source = source
    if not Players[source] then return end

    local currentTime = os.time()
    if currentTime - LastWeatherEvent < WeatherEventCooldown then return end

    -- Random chance to trigger weather-related emergency
    local chance = math.random(100)

    if weatherType == 'rain' then
        -- 30% chance of storm drain issue during rain
        if chance <= 30 then
            local sectors = {}
            for id, _ in pairs(Config.Sectors) do
                if not ActiveEmergencies[id] then
                    table.insert(sectors, id)
                end
            end

            if #sectors > 0 then
                local randomSector = sectors[math.random(#sectors)]
                -- Flooding isn't quite an emergency, but increase storm drain tasks
                -- Just notify workers
                TriggerClientEvent('dps-cityworker:client:WeatherTaskBonus', -1, {
                    type = 'storm_drain',
                    label = 'Storm Drain Clearing',
                    message = 'Heavy rainfall causing drainage issues. Storm drain tasks pay 25% bonus!',
                })
                LastWeatherEvent = currentTime
            end
        end
    elseif weatherType == 'storm' then
        -- 40% chance of emergency during storms
        if chance <= 40 then
            local sectors = {}
            for id, _ in pairs(Config.Sectors) do
                if not ActiveEmergencies[id] then
                    table.insert(sectors, id)
                end
            end

            if #sectors > 0 then
                local randomSector = sectors[math.random(#sectors)]
                local stormEmergencies = {'fallen_tree', 'downed_lines'}
                local randomEmergency = stormEmergencies[math.random(#stormEmergencies)]

                TriggerEmergencyEvent(randomEmergency, randomSector)
                LastWeatherEvent = currentTime
            end
        end
    end
end)

local function GetRandomLocation(category)
    -- Try to get category-specific location first
    if category and Server.CategoryLocations and Server.CategoryLocations[category] then
        local categoryLocs = Server.CategoryLocations[category]
        if #categoryLocs > 0 then
            return categoryLocs[math.random(#categoryLocs)]
        end
    end

    -- Fallback to generic locations
    return Server.Locations[math.random(#Server.Locations)]
end

local function GetLocationForTask(taskType)
    local task = TaskTypes[taskType]
    if task and task.category then
        return GetRandomLocation(task.category)
    end
    return GetRandomLocation()
end

-- Teamwork bonus calculation (defined here so Payment callback can use it)
local function CalculateTeamworkBonus(source)
    local sourcePed = GetPlayerPed(source)
    if not sourcePed then return 1.0 end

    local sourceCoords = GetEntityCoords(sourcePed)
    local nearbyCount = 0

    for playerId, _ in pairs(Players) do
        if playerId ~= source then
            local ped = GetPlayerPed(playerId)
            if ped and DoesEntityExist(ped) then
                local coords = GetEntityCoords(ped)
                if #(sourceCoords - coords) <= 30.0 then
                    nearbyCount = nearbyCount + 1
                end
            end
        end
    end

    -- 10% bonus per nearby worker, max 30%
    return 1.0 + math.min(nearbyCount * 0.10, 0.30)
end

-- =====================================
-- CALLBACKS
-- =====================================

lib.callback.register('dps-cityworker:server:spawnVehicle', function(source)
    if Players[source] then return false end

    local netid = createWorkVehicle(source)
    local stats = GetPlayerStats(source)
    local taskType = GetTaskForRank(stats.rank)
    local task = TaskTypes[taskType]
    local location = GetLocationForTask(taskType)

    Players[source] = {
        entity = NetworkGetEntityFromNetworkId(netid),
        location = location,
        rank = stats.rank,
        xp = stats.xp,
        total_repairs = stats.total_repairs or 0,
        total_earnings = stats.total_earnings or 0,
        taskType = taskType,
    }

    -- Return task details for client
    local taskData = {
        location = location,
        taskType = taskType,
        label = task.label,
        category = task.category,
        difficulty = task.difficulty,
        rank = stats.rank,
    }

    return netid, taskData
end)

lib.callback.register('dps-cityworker:server:clockOut', function(source)
    if Players[source] then
        -- Save stats before clocking out
        SavePlayerStats(source, Players[source])

        local ent = Players[source].entity
        if DoesEntityExist(ent) then DeleteEntity(ent) end
        Players[source] = nil
        return true
    end
    return false
end)

lib.callback.register('dps-cityworker:server:Payment', function(source)
    local ped = GetPlayerPed(source)
    local pos = GetEntityCoords(ped)

    if not Players[source] then return false, nil end

    local playerData = Players[source]
    local taskType = playerData.taskType or 'pipe'
    local task = TaskTypes[taskType] or TaskTypes.pipe

    -- 1. Calculate Pay based on Rank + Teamwork Bonus
    local rankData = Config.Ranks[playerData.rank] or Config.Ranks[1]
    local teamworkBonus = CalculateTeamworkBonus(source)
    local payment = math.floor(Config.Economy.BasePay * rankData.payMultiplier * teamworkBonus)

    -- 2. Add Money
    local success = Bridge.AddMoney(source, Server.Account or 'cash', payment, 'city-worker-payment')

    if not success then
        print(('[dps-cityworker] ^1ERROR: Failed to pay %s^0'):format(source))
        return false, nil
    end

    -- 3. Repair sector health
    local sectorId, newHealth = RepairSector(pos, task.repairAmount)

    -- 4. Handle XP and Progression
    local xpGain = task.xp + math.random(-5, 10)
    playerData.xp = playerData.xp + xpGain
    playerData.total_repairs = (playerData.total_repairs or 0) + 1
    playerData.total_earnings = (playerData.total_earnings or 0) + payment

    -- 5. Check for Rank Up
    local xpNeeded = playerData.rank * 1000
    local rankUp = false

    if playerData.xp >= xpNeeded and Config.Ranks[playerData.rank + 1] then
        playerData.rank = playerData.rank + 1
        rankUp = true
        Bridge.Notify(source, 'Promoted to ' .. Config.Ranks[playerData.rank].label .. '!', 'success')
    end

    -- 6. Get next task
    local newTaskType = GetTaskForRank(playerData.rank)
    local newLocation = GetLocationForTask(newTaskType)
    playerData.taskType = newTaskType
    playerData.location = newLocation

    -- 7. Save stats
    SavePlayerStats(source, playerData)

    return true, {
        payment = payment,
        xp = xpGain,
        totalXp = playerData.xp,
        rank = playerData.rank,
        rankUp = rankUp,
        sectorId = sectorId,
        sectorHealth = newHealth,
        nextTask = {
            type = newTaskType,
            label = TaskTypes[newTaskType].label,
            category = TaskTypes[newTaskType].category,
            difficulty = TaskTypes[newTaskType].difficulty,
            location = newLocation,
        }
    }
end)

lib.callback.register('dps-cityworker:server:GetNextTask', function(source)
    if not Players[source] then return nil end

    local playerData = Players[source]
    local newTaskType = GetTaskForRank(playerData.rank)
    local newLocation = GetLocationForTask(newTaskType)

    playerData.taskType = newTaskType
    playerData.location = newLocation

    return {
        type = newTaskType,
        label = TaskTypes[newTaskType].label,
        difficulty = TaskTypes[newTaskType].difficulty,
        category = TaskTypes[newTaskType].category,
        location = newLocation,
    }
end)

lib.callback.register('dps-cityworker:server:GetSectorHealth', function(source)
    local data = {}
    for id, health in pairs(SectorHealth) do
        data[id] = {
            health = health,
            label = Config.Sectors[id] and Config.Sectors[id].label or id,
        }
    end
    return data
end)

lib.callback.register('dps-cityworker:server:GetPlayerStats', function(source)
    if Players[source] then
        return {
            rank = Players[source].rank,
            rankLabel = Config.Ranks[Players[source].rank].label,
            xp = Players[source].xp,
            xpNeeded = Players[source].rank * 1000,
            total_repairs = Players[source].total_repairs,
            total_earnings = Players[source].total_earnings,
        }
    end
    return GetPlayerStats(source)
end)

-- =====================================
-- CONTROL ROOM (FOREMAN ONLY)
-- =====================================

lib.callback.register('dps-cityworker:server:OpenControlRoom', function(source)
    if not Players[source] then return false, nil end

    local rank = Players[source].rank
    if rank < 5 then
        Bridge.Notify(source, 'Only Foremen can access the Control Room', 'error')
        return false, nil
    end

    local data = {}
    for id, health in pairs(SectorHealth) do
        data[id] = {
            health = health,
            label = Config.Sectors[id] and Config.Sectors[id].label or id,
        }
    end

    return true, data
end)

lib.callback.register('dps-cityworker:server:DispatchCrew', function(source, sectorId)
    if not Players[source] or Players[source].rank < 5 then
        return false, 'Insufficient rank'
    end

    if not Config.Sectors[sectorId] then
        return false, 'Invalid sector'
    end

    -- Broadcast dispatch to all workers
    TriggerClientEvent('dps-cityworker:client:DispatchAlert', -1, {
        sector = sectorId,
        label = Config.Sectors[sectorId].label,
        coords = Config.Sectors[sectorId].coords,
    })

    return true, 'Dispatch sent'
end)

-- =====================================
-- DAMAGE REPORTS
-- =====================================

lib.callback.register('dps-cityworker:server:ReportDamage', function(source, damageType, coords)
    local identifier = Bridge.GetIdentifier(source)
    local sectorId = GetSectorForCoords(coords)

    if not sectorId then
        return false, 'Not in a managed sector'
    end

    MySQL.insert.await([[
        INSERT INTO city_damage_reports (sector_id, damage_type, coords_x, coords_y, coords_z, reported_by)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {sectorId, damageType, coords.x, coords.y, coords.z, identifier})

    -- Reduce sector health slightly when damage is reported
    SectorHealth[sectorId] = math.max(0, SectorHealth[sectorId] - 0.5)
    SaveSectorHealth(sectorId)

    return true, 'Damage reported'
end)

-- =====================================
-- ADMIN COMMANDS
-- =====================================

lib.addCommand('setsectorhealth', {
    help = 'Set a sector\'s health percentage (Admin)',
    params = {
        { name = 'sector', type = 'string', help = 'Sector ID (legion, mirror_park, sandy_shores)' },
        { name = 'health', type = 'number', help = 'Health percentage (0-100)' },
    },
    restricted = 'group.admin',
}, function(source, args)
    local sector = args.sector
    local health = math.min(100, math.max(0, args.health))

    if not Config.Sectors[sector] then
        Bridge.Notify(source, 'Invalid sector ID', 'error')
        return
    end

    SectorHealth[sector] = health
    SaveSectorHealth(sector)
    TriggerClientEvent('dps-cityworker:client:UpdateSectorHealth', -1, SectorHealth)

    Bridge.Notify(source, ('Set %s health to %d%%'):format(Config.Sectors[sector].label, health), 'success')
end)

lib.addCommand('workstatus', {
    help = 'Check your city worker stats',
}, function(source)
    local stats = GetPlayerStats(source)
    local rankLabel = Config.Ranks[stats.rank] and Config.Ranks[stats.rank].label or 'Unknown'

    Bridge.Notify(source, ('Rank: %s | XP: %d/%d | Repairs: %d'):format(
        rankLabel,
        stats.xp,
        stats.rank * 1000,
        stats.total_repairs or 0
    ), 'inform')
end)

lib.addCommand('controlroom', {
    help = 'Open the Control Room dashboard (Foreman only)',
}, function(source)
    TriggerClientEvent('dps-cityworker:client:OpenControlRoom', source)
end)

lib.addCommand('reportdamage', {
    help = 'Report infrastructure damage at your location',
    params = {
        { name = 'type', type = 'string', help = 'Damage type (pothole, streetlight, pipe, electrical)', optional = true },
    },
}, function(source, args)
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local damageType = args.type or 'general'

    local success, msg = lib.callback.await('dps-cityworker:server:ReportDamage', source, damageType, coords)

    if success then
        Bridge.Notify(source, 'Damage reported to dispatch', 'success')
    else
        Bridge.Notify(source, msg or 'Failed to report damage', 'error')
    end
end)

lib.addCommand('triggeremergency', {
    help = 'Trigger an emergency event (Admin)',
    params = {
        { name = 'type', type = 'string', help = 'Emergency type (water_main, gas_leak, downed_lines, fallen_tree)' },
        { name = 'sector', type = 'string', help = 'Sector ID (legion, mirror_park, sandy_shores)' },
    },
    restricted = 'group.admin',
}, function(source, args)
    local emergencyType = args.type
    local sectorId = args.sector

    if not TaskTypes[emergencyType] or not TaskTypes[emergencyType].isEmergency then
        Bridge.Notify(source, 'Invalid emergency type', 'error')
        return
    end

    if not Config.Sectors[sectorId] then
        Bridge.Notify(source, 'Invalid sector ID', 'error')
        return
    end

    local success = TriggerEmergencyEvent(emergencyType, sectorId)
    if success then
        Bridge.Notify(source, ('Triggered %s in %s'):format(emergencyType, sectorId), 'success')
    else
        Bridge.Notify(source, 'Failed to trigger emergency (already active?)', 'error')
    end
end)

-- =====================================
-- EMERGENCY CALLBACKS
-- =====================================

lib.callback.register('dps-cityworker:server:GetActiveEmergencies', function(source)
    local emergencies = {}
    for sectorId, emergency in pairs(ActiveEmergencies) do
        local task = TaskTypes[emergency.type]
        emergencies[sectorId] = {
            type = emergency.type,
            label = task and task.label or emergency.type,
            coords = emergency.coords,
            startTime = emergency.startTime,
            sectorLabel = Config.Sectors[sectorId] and Config.Sectors[sectorId].label or sectorId,
        }
    end
    return emergencies
end)

lib.callback.register('dps-cityworker:server:RespondToEmergency', function(source, sectorId)
    if not Players[source] then return false, 'Not on duty' end
    if not ActiveEmergencies[sectorId] then return false, 'No active emergency' end

    local emergency = ActiveEmergencies[sectorId]
    local task = TaskTypes[emergency.type]

    -- Check rank requirement
    if Players[source].rank < task.minRank then
        return false, ('Requires rank %d'):format(task.minRank)
    end

    return true, {
        type = emergency.type,
        label = task.label,
        coords = emergency.coords,
        difficulty = task.difficulty,
        xp = task.xp,
    }
end)

lib.callback.register('dps-cityworker:server:CompleteEmergency', function(source, sectorId)
    if not Players[source] then return false end
    if not ActiveEmergencies[sectorId] then return false end

    return ResolveEmergency(sectorId, source)
end)

-- =====================================
-- CREW/TEAM SYSTEM
-- =====================================

lib.callback.register('dps-cityworker:server:GetActiveWorkers', function(source)
    local workers = {}
    for playerId, data in pairs(Players) do
        local ped = GetPlayerPed(playerId)
        if ped and DoesEntityExist(ped) then
            local coords = GetEntityCoords(ped)
            workers[playerId] = {
                name = Bridge.GetCharacterName(playerId),
                rank = data.rank,
                rankLabel = Config.Ranks[data.rank] and Config.Ranks[data.rank].label or 'Unknown',
                coords = coords,
                taskType = data.taskType,
            }
        end
    end
    return workers
end)

lib.callback.register('dps-cityworker:server:GetNearbyWorkers', function(source, radius)
    radius = radius or 50.0
    local sourcePed = GetPlayerPed(source)
    if not sourcePed then return {} end

    local sourceCoords = GetEntityCoords(sourcePed)
    local nearby = {}

    for playerId, data in pairs(Players) do
        if playerId ~= source then
            local ped = GetPlayerPed(playerId)
            if ped and DoesEntityExist(ped) then
                local coords = GetEntityCoords(ped)
                local dist = #(sourceCoords - coords)
                if dist <= radius then
                    table.insert(nearby, {
                        id = playerId,
                        name = Bridge.GetCharacterName(playerId),
                        rank = data.rank,
                        distance = dist,
                    })
                end
            end
        end
    end

    return nearby
end)

-- Foreman crew management
lib.callback.register('dps-cityworker:server:AssignWorkerTask', function(source, targetId, taskType)
    if not Players[source] or Players[source].rank < 5 then
        return false, 'Only Foremen can assign tasks'
    end

    if not Players[targetId] then
        return false, 'Worker not on duty'
    end

    local task = TaskTypes[taskType]
    if not task then
        return false, 'Invalid task type'
    end

    if Players[targetId].rank < task.minRank then
        return false, 'Worker rank too low for this task'
    end

    local location = GetLocationForTask(taskType)

    Players[targetId].taskType = taskType
    Players[targetId].location = location

    -- Notify the target worker
    TriggerClientEvent('dps-cityworker:client:TaskAssigned', targetId, {
        type = taskType,
        label = task.label,
        location = location,
        assignedBy = Bridge.GetCharacterName(source),
    })

    return true, 'Task assigned'
end)

-- =====================================
-- EXPORTS
-- =====================================

exports('GetSectorHealth', function(sectorId)
    return SectorHealth[sectorId]
end)

exports('GetAllSectorHealth', function()
    return SectorHealth
end)

exports('TriggerBlackout', function(sectorId)
    if Config.Sectors[sectorId] then
        TriggerClientEvent('dps-cityworker:client:TriggerBlackout', -1, sectorId)
        return true
    end
    return false
end)

exports('GetPlayerSeniority', function(source)
    if Players[source] then
        return Players[source].rank
    end
    local stats = GetPlayerStats(source)
    return stats.rank
end)

exports('RepairSector', RepairSector)
exports('TriggerEmergency', TriggerEmergencyEvent)
exports('GetActiveEmergencies', function() return ActiveEmergencies end)
exports('ResolveEmergency', ResolveEmergency)
