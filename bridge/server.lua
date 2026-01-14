-- =====================================
-- SERVER-SIDE BRIDGE
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
-- PLAYER FUNCTIONS
-- =====================================

function Bridge.GetPlayer(source)
    if Bridge.Framework == 'qb' or Bridge.Framework == 'qbx' then
        return QBCore and QBCore.Functions.GetPlayer(source)
    elseif Bridge.Framework == 'esx' then
        return ESX and ESX.GetPlayerFromId(source)
    end
    return nil
end

function Bridge.GetIdentifier(source)
    local player = Bridge.GetPlayer(source)
    if not player then return nil end

    if Bridge.Framework == 'qb' or Bridge.Framework == 'qbx' then
        return player.PlayerData.citizenid
    elseif Bridge.Framework == 'esx' then
        return player.identifier
    end
    return nil
end

function Bridge.GetCharacterName(source)
    local player = Bridge.GetPlayer(source)
    if not player then return GetPlayerName(source) end

    if Bridge.Framework == 'qb' or Bridge.Framework == 'qbx' then
        local charinfo = player.PlayerData.charinfo
        return charinfo.firstname .. ' ' .. charinfo.lastname
    elseif Bridge.Framework == 'esx' then
        return player.getName()
    end
    return GetPlayerName(source)
end

-- =====================================
-- MONEY FUNCTIONS
-- =====================================

function Bridge.AddMoney(source, account, amount, reason)
    local player = Bridge.GetPlayer(source)
    if not player then return false end

    reason = reason or 'city-worker-payment'

    if Bridge.Framework == 'qb' or Bridge.Framework == 'qbx' then
        player.Functions.AddMoney(account, amount, reason)
        return true
    elseif Bridge.Framework == 'esx' then
        if account == 'cash' or account == 'money' then
            player.addMoney(amount, reason)
        else
            player.addAccountMoney(account, amount, reason)
        end
        return true
    end
    return false
end

function Bridge.RemoveMoney(source, account, amount, reason)
    local player = Bridge.GetPlayer(source)
    if not player then return false end

    reason = reason or 'city-worker-expense'

    if Bridge.Framework == 'qb' or Bridge.Framework == 'qbx' then
        return player.Functions.RemoveMoney(account, amount, reason)
    elseif Bridge.Framework == 'esx' then
        if account == 'cash' or account == 'money' then
            player.removeMoney(amount, reason)
        else
            player.removeAccountMoney(account, amount, reason)
        end
        return true
    end
    return false
end

function Bridge.GetMoney(source, account)
    local player = Bridge.GetPlayer(source)
    if not player then return 0 end

    if Bridge.Framework == 'qb' or Bridge.Framework == 'qbx' then
        return player.PlayerData.money[account] or 0
    elseif Bridge.Framework == 'esx' then
        if account == 'cash' or account == 'money' then
            return player.getMoney()
        else
            return player.getAccount(account).money or 0
        end
    end
    return 0
end

-- =====================================
-- JOB FUNCTIONS
-- =====================================

function Bridge.GetJobName(source)
    local player = Bridge.GetPlayer(source)
    if not player then return nil end

    if Bridge.Framework == 'qb' or Bridge.Framework == 'qbx' then
        return player.PlayerData.job.name
    elseif Bridge.Framework == 'esx' then
        return player.job.name
    end
    return nil
end

function Bridge.GetJobGrade(source)
    local player = Bridge.GetPlayer(source)
    if not player then return 0 end

    if Bridge.Framework == 'qb' or Bridge.Framework == 'qbx' then
        return player.PlayerData.job.grade.level or 0
    elseif Bridge.Framework == 'esx' then
        return player.job.grade or 0
    end
    return 0
end

function Bridge.HasJob(source, jobName)
    return Bridge.GetJobName(source) == jobName
end

function Bridge.IsOnDuty(source)
    local player = Bridge.GetPlayer(source)
    if not player then return false end

    if Bridge.Framework == 'qb' or Bridge.Framework == 'qbx' then
        return player.PlayerData.job.onduty or false
    end
    return true
end

-- =====================================
-- NOTIFICATION
-- =====================================

function Bridge.Notify(source, message, type)
    type = type or 'inform'

    if Config.Notify == 'ox_lib' then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'City Worker',
            description = message,
            type = type
        })
    elseif Bridge.Framework == 'qb' or Bridge.Framework == 'qbx' then
        TriggerClientEvent('QBCore:Notify', source, message, type)
    elseif Bridge.Framework == 'esx' then
        TriggerClientEvent('esx:showNotification', source, message)
    end
end

-- =====================================
-- BACKWARDS COMPATIBILITY ALIASES
-- =====================================

function GetPlayer(source)
    return Bridge.GetPlayer(source)
end

function AddMoney(source, account, amount)
    return Bridge.AddMoney(source, account, amount)
end

function GetCharacterName(source)
    return Bridge.GetCharacterName(source)
end

function GetCid(source)
    return Bridge.GetIdentifier(source)
end

-- =====================================
-- EXPORTS
-- =====================================

exports('GetPlayer', Bridge.GetPlayer)
exports('GetIdentifier', Bridge.GetIdentifier)
exports('GetCharacterName', Bridge.GetCharacterName)
exports('AddMoney', Bridge.AddMoney)
exports('RemoveMoney', Bridge.RemoveMoney)
exports('GetMoney', Bridge.GetMoney)
exports('GetJobName', Bridge.GetJobName)
exports('GetJobGrade', Bridge.GetJobGrade)
exports('HasJob', Bridge.HasJob)
exports('IsOnDuty', Bridge.IsOnDuty)
exports('GetPlayerSeniority', function(source)
    -- Will be implemented in sv_cityworker
    return 1
end)
