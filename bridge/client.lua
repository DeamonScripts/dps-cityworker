-- =====================================
-- CLIENT-SIDE BRIDGE
-- Unified framework abstraction layer
-- =====================================

local Config = lib.require('config')
local QBCore, ESX = nil, nil

-- Initialize framework connection
CreateThread(function()
    if Bridge.Framework == 'qb' or Bridge.Framework == 'qbx' then
        QBCore = exports['qb-core']:GetCoreObject()
    elseif Bridge.Framework == 'esx' then
        ESX = exports['es_extended']:getSharedObject()
    end
end)

-- =====================================
-- PLAYER DATA
-- =====================================

function Bridge.HasPlayerLoaded()
    if Bridge.Framework == 'qb' or Bridge.Framework == 'qbx' then
        local PlayerData = QBCore and QBCore.Functions.GetPlayerData() or {}
        return PlayerData.job ~= nil
    elseif Bridge.Framework == 'esx' then
        return ESX and ESX.IsPlayerLoaded()
    end
    return true
end

function Bridge.GetPlayerData()
    if Bridge.Framework == 'qb' or Bridge.Framework == 'qbx' then
        return QBCore and QBCore.Functions.GetPlayerData() or {}
    elseif Bridge.Framework == 'esx' then
        return ESX and ESX.GetPlayerData() or {}
    end
    return {}
end

-- =====================================
-- VEHICLE KEYS
-- =====================================

function Bridge.GiveVehicleKeys(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle)

    if Bridge.Framework == 'qb' or Bridge.Framework == 'qbx' then
        TriggerEvent('vehiclekeys:client:SetOwner', plate)
    elseif Bridge.Framework == 'esx' then
        -- ESX: Basic unlock behavior
        SetVehicleDoorsLocked(vehicle, 1)
        SetVehicleDoorsLockedForAllPlayers(vehicle, false)
    end
end

-- =====================================
-- NOTIFICATIONS
-- =====================================

function Bridge.Notify(message, type)
    type = type or 'inform'

    if Config.Notify == 'ox_lib' then
        lib.notify({
            title = 'City Worker',
            description = message,
            type = type,
            duration = 5000
        })
    elseif Bridge.Framework == 'qb' or Bridge.Framework == 'qbx' then
        QBCore.Functions.Notify(message, type)
    elseif Bridge.Framework == 'esx' then
        ESX.ShowNotification(message)
    end
end

-- =====================================
-- JOB FUNCTIONS
-- =====================================

function Bridge.GetJob()
    local data = Bridge.GetPlayerData()

    if Bridge.Framework == 'qb' or Bridge.Framework == 'qbx' then
        return data.job or {}
    elseif Bridge.Framework == 'esx' then
        return data.job or {}
    end
    return {}
end

function Bridge.HasJob(jobName)
    local job = Bridge.GetJob()
    return job.name == jobName
end

function Bridge.IsOnDuty()
    local job = Bridge.GetJob()
    if Bridge.Framework == 'qb' or Bridge.Framework == 'qbx' then
        return job.onduty or false
    end
    return true
end

-- =====================================
-- EVENT HANDLERS (Override in main script)
-- =====================================

function OnPlayerLoaded()
    -- Override in cl_cityworker.lua
end

function OnPlayerUnload()
    -- Override in cl_cityworker.lua
end

-- Framework-specific event listeners
if Bridge.Framework == 'qb' or Bridge.Framework == 'qbx' then
    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
        OnPlayerLoaded()
    end)

    RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
        OnPlayerUnload()
    end)
elseif Bridge.Framework == 'esx' then
    RegisterNetEvent('esx:playerLoaded', function(xPlayer)
        OnPlayerLoaded()
    end)

    RegisterNetEvent('esx:onPlayerLogout', function()
        OnPlayerUnload()
    end)
end

-- =====================================
-- BACKWARDS COMPATIBILITY ALIASES
-- =====================================

function hasPlyLoaded()
    return Bridge.HasPlayerLoaded()
end

function handleVehicleKeys(vehicle)
    Bridge.GiveVehicleKeys(vehicle)
end

function DoNotification(text, type)
    Bridge.Notify(text, type)
end

-- =====================================
-- EXPORTS
-- =====================================

exports('IsPlayerLoaded', Bridge.HasPlayerLoaded)
exports('GetPlayerJob', Bridge.GetJob)
exports('HasJob', Bridge.HasJob)
exports('IsOnDuty', Bridge.IsOnDuty)
-- Note: IsPlayerOnDuty export is in cl_cityworker.lua (has access to isHired variable)
