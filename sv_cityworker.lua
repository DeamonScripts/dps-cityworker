local Config = lib.require('config')
local Server = lib.require('sv_config')
local Players = {}
local SectorHealth = {} -- Runtime cache for Grid Health

--------------------------------------------------------------------------------
-- DATABASE / XP SYSTEM (Mocking SQL for safety, uncomment to use oxmysql)
--------------------------------------------------------------------------------
local function GetPlayerStats(source)
    -- In a real scenario, fetch from DB:
    -- local result = MySQL.single.await('SELECT rank, xp FROM city_worker_users WHERE citizenid = ?', {cid})
    -- For now, we return default level 1 stats so the script works immediately
    return { rank = 1, xp = 0 }
end

local function SavePlayerStats(source, rank, xp)
    -- MySQL.update.await('UPDATE city_worker_users SET rank = ?, xp = ? WHERE citizenid = ?', {rank, xp, cid})
    -- print(('Saved stats for %s: Rank %d, XP %d'):format(GetPlayerName(source), rank, xp))
end

--------------------------------------------------------------------------------
-- SECTOR / GRID MANAGEMENT
--------------------------------------------------------------------------------
-- Initialize Sectors
for id, data in pairs(Config.Sectors) do
    SectorHealth[id] = 100.0 -- Default to 100% health on restart
end

-- Decay Loop: Lowers infrastructure health over time
CreateThread(function()
    while true do
        Wait(60000 * 10) -- Run every 10 minutes
        for id, data in pairs(Config.Sectors) do
            if SectorHealth[id] > 0 then
                -- Calculate decay for 10 mins based on hourly rate
                local decayAmount = (data.decayRate / 6) 
                SectorHealth[id] = math.max(0, SectorHealth[id] - decayAmount)
                
                -- Check for Blackout Threshold
                if SectorHealth[id] <= data.blackoutThreshold then
                    TriggerClientEvent('dps-cityworker:client:TriggerBlackout', -1, id)
                    print(('[GRID ALERT] Sector %s has failed! Rolling blackouts initiated.'):format(data.label))
                end
            end
        end
    end
end)

local function RepairSector(coords, amount)
    for id, data in pairs(Config.Sectors) do
        local sectorPos = data.coords
        if #(coords - sectorPos) < data.radius then
            SectorHealth[id] = math.min(100.0, SectorHealth[id] + amount)
            -- Trigger visual update to Control Room (future feature)
            return id, SectorHealth[id]
        end
    end
    return nil, 0
end

--------------------------------------------------------------------------------
-- CORE JOB LOGIC
--------------------------------------------------------------------------------
local function createWorkVehicle(source)
    local spawn = Server.VehicleSpawn
    local model = Server.Vehicle

    -- Create vehicle at the specific coordinates from sv_config
    local veh = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.w, true, true)
    
    local ped = GetPlayerPed(source)
    while not DoesEntityExist(veh) do Wait(10) end 
    TaskWarpPedIntoVehicle(ped, veh, -1)
    
    return NetworkGetNetworkIdFromEntity(veh)
end

lib.callback.register('dps-cityworker:server:spawnVehicle', function(source)
    if Players[source] then return false end

    local src = source
    local netid = createWorkVehicle(src)
    
    -- Pick a random location from the long list in sv_config
    local newDelivery = Server.Locations[math.random(#Server.Locations)]
    
    -- Load Player Stats
    local stats = GetPlayerStats(src)

    Players[src] = {
        entity = NetworkGetEntityFromNetworkId(netid),
        location = newDelivery,
        rank = stats.rank,
        xp = stats.xp
    }

    return netid, Players[src]
end)

lib.callback.register('dps-cityworker:server:clockOut', function(source)
    local src = source
    if Players[src] then
        local ent = Players[src].entity
        if DoesEntityExist(ent) then DeleteEntity(ent) end
        Players[src] = nil
        return true
    end
    return false
end)

lib.callback.register('dps-cityworker:server:Payment', function(source)
    local src = source
    local ped = GetPlayerPed(src)
    local pos = GetEntityCoords(ped)

    if not Players[src] then return false end
    
    -- 1. Calculate Pay based on Rank
    local rankData = Config.Ranks[Players[src].rank] or Config.Ranks[1]
    local payment = math.floor(Config.Economy.BasePay * rankData.payMultiplier)

    -- 2. Add Money (Bridge Function)
    local success = AddMoney(src, Config.Economy.Account or 'cash', payment)
    
    if success then
         -- print(('[LOG] Paid %s $%d'):format(GetCharacterName(src), payment))
    else
        print(('[ERROR] Failed to pay %s (Player not found or invalid account)'):format(src))
    end

    -- 3. Handle Progression (XP)
    local xpGain = math.random(15, 25)
    Players[src].xp = Players[src].xp + xpGain
    
    -- Check for Rank Up (Simple logic: Rank * 1000 XP needed)
    if Players[src].xp >= (Players[src].rank * 1000) then
        if Config.Ranks[Players[src].rank + 1] then
            Players[src].rank = Players[src].rank + 1
            Players[src].xp = 0
            TriggerClientEvent('ox_lib:notify', src, {type='success', description='PROMOTION: You are now a '..Config.Ranks[Players[src].rank].label})
        end
    end

    -- Save Data
    SavePlayerStats(src, Players[src].rank, Players[src].xp)

    -- 4. Repair the City Grid
    local sectorId, newHealth = RepairSector(pos, 5.0) -- Repair 5% health
    if sectorId then
        TriggerClientEvent('ox_lib:notify', src, {type='info', description=('Sector %s Health: %.1f%%'):format(sectorId, newHealth)})
    end

    -- 5. Assign Next Task
    CreateThread(function()
        Wait(Server.Timeout)
        
        -- Generate next random location from sv_config list
        local newDelivery = Server.Locations[math.random(#Server.Locations)]
        Players[src].location = newDelivery
        
        TriggerClientEvent("dps-cityworker:client:generatedLocation", src, Players[src])
    end)

    return true
end)

-- Cleanup on drop
AddEventHandler("playerDropped", function()
    local src = source
    if Players[src] then
        if DoesEntityExist(Players[src].entity) then DeleteEntity(Players[src].entity) end
        Players[src] = nil
    end
end)
