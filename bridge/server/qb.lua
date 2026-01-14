local QBCore = exports['qb-core']:GetCoreObject()

function GetPlayer(source)
    return QBCore.Functions.GetPlayer(source)
end

function AddMoney(source, account, amount)
    local player = GetPlayer(source)
    if player then
        player.Functions.AddMoney(account, amount, "city-worker-pay")
        return true
    end
    return false
end

function GetCharacterName(source)
    local player = GetPlayer(source)
    if player then
        return player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
    end
    return GetPlayerName(source)
end
