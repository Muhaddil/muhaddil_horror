local activePumpkins = {}
local playerPumpkinData = {}
local pumpkinIdCounter = 0
local leaderboardCache = {}
local lastLeaderboardUpdate = 0

if Config.FrameWork == "auto" then
    if GetResourceState('es_extended') == 'started' then
        ESX = exports['es_extended']:getSharedObject()
        FrameWork = 'esx'
    elseif GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
        FrameWork = 'qb'
    end
elseif Config.FrameWork == "esx" and GetResourceState('es_extended') == 'started' then
    ESX = exports['es_extended']:getSharedObject()
    FrameWork = 'esx'
elseif Config.FrameWork == "qb" and GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
    FrameWork = 'qb'
else
    print('===NO SUPPORTED FRAMEWORK FOUND===')
end

local function HasAdminPermission(source)
    local src = source
    if FrameWork == 'qb' then
        for _, group in ipairs(Config.AllowedGroups.qb) do
            if QBCore.Functions.HasPermission(src, group) then
                return true
            end
        end
    end

    if FrameWork == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            for _, group in ipairs(Config.AllowedGroups.esx) do
                if xPlayer.getGroup() == group then
                    return true
                end
            end
        end
    end

    for _, aceGroup in ipairs(Config.AllowedGroups.ace) do
        if IsPlayerAceAllowed(src, aceGroup) then
            return true
        end
    end

    return false
end

CreateThread(function()
    if not Config.PumpkinHunt.enabled then return end

    if Config.PumpkinHunt.database.autoCreateTable then
        MySQL.Async.execute([[
            CREATE TABLE IF NOT EXISTS pumpkin_hunt_data (
                identifier VARCHAR(60) PRIMARY KEY,
                player_name VARCHAR(100),
                collected INT DEFAULT 0,
                rewards_claimed TEXT,
                last_collection TIMESTAMP NULL,
                last_collection_location VARCHAR(200),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
        ]], {}, function(result)
            print("^2[PUMPKIN HUNT]^7 Tabla de base de datos creada/verificada")
        end)
    end
end)

local function GetPlayerIdentifier(source)
    if FrameWork == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        return xPlayer and xPlayer.identifier
    elseif FrameWork == 'qb' then
        local Player = QBCore.Functions.GetPlayer(source)
        return Player and Player.PlayerData.citizenid
    else
        local identifiers = GetPlayerIdentifiers(source)
        for _, id in ipairs(identifiers) do
            if string.match(id, "license:") then
                return id
            end
        end
    end
    return nil
end

local function LoadPlayerData(source, callback)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then
        callback(nil)
        return
    end

    MySQL.Async.fetchAll('SELECT * FROM pumpkin_hunt_data WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    }, function(result)
        if result[1] then
            local rewardsClaimed = {}
            if result[1].rewards_claimed and result[1].rewards_claimed ~= '' then
                rewardsClaimed = json.decode(result[1].rewards_claimed)
            end

            callback({
                identifier = result[1].identifier,
                collected = result[1].collected or 0,
                rewardsClaimed = rewardsClaimed,
                lastCollection = result[1].last_collection,
                lastLocation = result[1].last_collection_location
            })
        else
            MySQL.Async.execute([[
                INSERT INTO pumpkin_hunt_data (identifier, player_name, collected, rewards_claimed)
                VALUES (@identifier, @name, 0, '[]')
            ]], {
                ['@identifier'] = identifier,
                ['@name'] = GetPlayerName(source)
            }, function()
                callback({
                    identifier = identifier,
                    collected = 0,
                    rewardsClaimed = {},
                    lastCollection = nil,
                    lastLocation = nil
                })
            end)
        end
    end)
end

local function LoadPlayerDataAwait(source)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then
        return nil
    end

    local done, data = false, nil

    MySQL.Async.fetchAll('SELECT * FROM pumpkin_hunt_data WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    }, function(result)
        if result[1] then
            local rewardsClaimed = {}
            if result[1].rewards_claimed and result[1].rewards_claimed ~= '' then
                rewardsClaimed = json.decode(result[1].rewards_claimed)
            end

            data = {
                identifier = result[1].identifier,
                collected = result[1].collected or 0,
                rewardsClaimed = rewardsClaimed,
                lastCollection = result[1].last_collection,
                lastLocation = result[1].last_collection_location
            }
            done = true
        else
            MySQL.Async.execute([[
                INSERT INTO pumpkin_hunt_data (identifier, player_name, collected, rewards_claimed)
                VALUES (@identifier, @name, 0, '[]')
            ]], {
                ['@identifier'] = identifier,
                ['@name'] = GetPlayerName(source)
            }, function()
                data = {
                    identifier = identifier,
                    collected = 0,
                    rewardsClaimed = {},
                    lastCollection = nil,
                    lastLocation = nil
                }
                done = true
            end)
        end
    end)

    while not done do
        Wait(0)
    end

    return data
end

local function timestampToDatetime(ms)
    local num = tonumber(ms)
    if not num then return nil end
    local seconds = math.floor(num / 1000)
    return os.date("%Y-%m-%d %H:%M:%S", seconds)
end

local function SavePlayerData(source, data)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return end

    local datetime = timestampToDatetime(data.lastCollection) or os.date("%Y-%m-%d %H:%M:%S")

    MySQL.Async.execute([[
        UPDATE pumpkin_hunt_data
        SET collected = @collected,
            rewards_claimed = @rewards,
            player_name = @name,
            last_collection = @lastCollection,
            last_collection_location = @lastLocation
        WHERE identifier = @identifier
    ]], {
        ['@identifier'] = identifier,
        ['@collected'] = data.collected,
        ['@rewards'] = json.encode(data.rewardsClaimed),
        ['@name'] = GetPlayerName(source),
        ['@lastCollection'] = datetime,
        ['@lastLocation'] = data.lastLocation
    })
end

local function IsEventActive()
    if not Config.PumpkinHunt.checkDateOnCollection then
        return true
    end

    local currentDate = os.date("%Y-%m-%d")
    local startDate = Config.PumpkinHunt.eventStartDate
    local endDate = Config.PumpkinHunt.eventEndDate

    print(currentDate >= startDate and currentDate <= endDate)

    return currentDate >= startDate and currentDate <= endDate
end

local function GenerateRandomPosition(zone)
    local players = GetPlayers()
    if #players == 0 then return end

    local anyPlayer = tonumber(players[1])
    local angle = math.random() * 2 * math.pi
    local distance = math.random() * zone.radius

    local x = zone.center.x + math.cos(angle) * distance
    local y = zone.center.y + math.sin(angle) * distance
    local z = zone.center.z

    local position = lib.callback.await('pumpkin:getGroundZ', anyPlayer, vector3(x, y, z))
    return position
end

local function SpawnPumpkin(zoneIndex)
    if #activePumpkins >= Config.PumpkinHunt.maxActivePumpkins then
        return
    end

    local zone = Config.PumpkinHunt.spawnZones[zoneIndex]
    if not zone then return end

    local zoneCount = 0
    for _, pumpkin in pairs(activePumpkins) do
        if pumpkin.zone == zoneIndex then
            zoneCount = zoneCount + 1
        end
    end

    if zoneCount >= zone.maxPumpkins then
        return
    end

    pumpkinIdCounter = pumpkinIdCounter + 1
    local pumpkinId = pumpkinIdCounter

    local position = GenerateRandomPosition(zone)
    local model = Config.PumpkinHunt.models[math.random(#Config.PumpkinHunt.models)]

    activePumpkins[pumpkinId] = {
        id = pumpkinId,
        position = position,
        model = model,
        zone = zoneIndex,
        zoneName = zone.name,
        spawnTime = os.time(),
        collected = false
    }

    TriggerClientEvent('pumpkin:spawn', -1, pumpkinId, position, model)

    if Config.DebugMode then
        print(string.format("^2[PUMPKIN]^7 Calabaza #%d spawneada en %s", pumpkinId, zone.name))
    end

    SetTimeout(Config.PumpkinHunt.despawnTime, function()
        if activePumpkins[pumpkinId] and not activePumpkins[pumpkinId].collected then
            activePumpkins[pumpkinId] = nil
            TriggerClientEvent('pumpkin:remove', -1, pumpkinId)

            if Config.DebugMode then
                print(string.format("^3[PUMPKIN]^7 Calabaza #%d expiró", pumpkinId))
            end
        end
    end)
end

CreateThread(function()
    if not Config.PumpkinHunt.enabled then return end

    Wait(5000)

    for i = 1, #Config.PumpkinHunt.spawnZones do
        for j = 1, math.floor(Config.PumpkinHunt.spawnZones[i].maxPumpkins / 2) do
            SpawnPumpkin(i)
            Wait(500)
        end
    end

    while true do
        Wait(Config.PumpkinHunt.spawnInterval)

        if IsEventActive() then
            local randomZone = math.random(1, #Config.PumpkinHunt.spawnZones)
            SpawnPumpkin(randomZone)
        end
    end
end)

local function UpdateLeaderboard()
    MySQL.Async.fetchAll([[
        SELECT identifier, player_name, collected
        FROM pumpkin_hunt_data
        ORDER BY collected DESC
        LIMIT @limit
    ]], {
        ['@limit'] = Config.PumpkinHunt.leaderboard.topPlayersCount
    }, function(result)
        leaderboardCache = result
        lastLeaderboardUpdate = os.time()

        TriggerClientEvent('pumpkin:updateLeaderboard', -1, leaderboardCache)
    end)
end

CreateThread(function()
    if not Config.PumpkinHunt.enabled or not Config.PumpkinHunt.leaderboard.enabled then return end

    while true do
        Wait(Config.PumpkinHunt.leaderboard.updateInterval)
        UpdateLeaderboard()
    end
end)

AddEventHandler('playerJoining', function()
    local source = source
    Wait(2000)

    if not Config.PumpkinHunt.enabled then return end

    LoadPlayerData(source, function(data)
        if data then
            playerPumpkinData[source] = data

            TriggerClientEvent('pumpkin:syncAll', source, activePumpkins)

            if Config.PumpkinHunt.leaderboard.enabled then
                TriggerClientEvent('pumpkin:updateLeaderboard', source, leaderboardCache)
            end
        end
    end)
end)

AddEventHandler('playerDropped', function()
    local source = source
    if playerPumpkinData[source] then
        SavePlayerData(source, playerPumpkinData[source])
        playerPumpkinData[source] = nil
    end
end)

lib.callback.register('pumpkin:openMenu', function(source)
    if not Config.PumpkinHunt.enabled then
        return { success = false, message = "El sistema de calabazas está desactivado" }
    end

    if not IsEventActive() then
        return {
            success = false,
            message = Config.PumpkinHunt.notifications.eventNotActive
        }
    end

    local data = LoadPlayerDataAwait(source)
    if not data then
        return { success = false, message = "Error cargando datos" }
    end

    playerPumpkinData[source] = data

    local rank, statsDone, stats = nil, false, nil

    MySQL.Async.fetchScalar([[
        SELECT COUNT(*) + 1
        FROM pumpkin_hunt_data
        WHERE collected > @collected
    ]], { ['@collected'] = data.collected }, function(result)
        rank = result
        statsDone = true
    end)

    while not statsDone do Wait(0) end

    local globalStats = MySQL.Sync and MySQL.Sync.fetchAll and MySQL.Sync.fetchAll([[
        SELECT
            COUNT(DISTINCT identifier) as totalPlayers,
            SUM(collected) as totalCollected
        FROM pumpkin_hunt_data
    ]], {})[1] or { totalPlayers = 0, totalCollected = 0 }

    local timeRemaining = 0
    if Config.PumpkinHunt.checkDateOnCollection then
        local currentTime = os.time()
        local endDate = os.time({
            year = tonumber(string.sub(Config.PumpkinHunt.eventEndDate, 1, 4)),
            month = tonumber(string.sub(Config.PumpkinHunt.eventEndDate, 6, 7)),
            day = tonumber(string.sub(Config.PumpkinHunt.eventEndDate, 9, 10)),
            hour = 23,
            min = 59,
            sec = 59
        })
        timeRemaining = math.max(0, endDate - currentTime)
    end

    return {
        success = true,
        player = {
            collected = data.collected,
            rewardsClaimed = data.rewardsClaimed,
            rank = rank
        },
        rewards = Config.PumpkinHunt.rewards,
        leaderboard = leaderboardCache,
        activePumpkins = #activePumpkins,
        totalPlayers = globalStats.totalPlayers,
        totalCollectedGlobal = globalStats.totalCollected,
        timeRemaining = timeRemaining,
        eventStart = Config.PumpkinHunt.eventStartDate,
        eventEnd = Config.PumpkinHunt.eventEndDate
    }
end)

lib.callback.register('pumpkin:collect', function(source, pumpkinId)
    if not Config.PumpkinHunt.enabled then
        return { success = false, message = "Sistema desactivado" }
    end

    if not IsEventActive() then
        return { success = false, message = Config.PumpkinHunt.notifications.eventNotActive }
    end

    local pumpkin = activePumpkins[pumpkinId]
    if not pumpkin or pumpkin.collected then
        return { success = false, message = Config.PumpkinHunt.notifications.alreadyCollected }
    end

    pumpkin.collected = true
    activePumpkins[pumpkinId] = nil

    local identifier = GetPlayerIdentifier(source)
    if not identifier then
        return { success = false, message = "Error cargando datos" }
    end

    local result = MySQL.Sync.fetchAll('SELECT * FROM pumpkin_hunt_data WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    })

    local data
    if result[1] then
        local rewardsClaimed = result[1].rewards_claimed ~= '' and json.decode(result[1].rewards_claimed) or {}
        data = {
            identifier = result[1].identifier,
            collected = result[1].collected + 1,
            rewardsClaimed = rewardsClaimed,
            lastCollection = os.date("%Y-%m-%d %H:%M:%S"),
            lastLocation = pumpkin.zoneName
        }
        MySQL.Sync.execute([[
            UPDATE pumpkin_hunt_data
            SET collected=@collected, last_collection=@lastCollection, last_collection_location=@lastLocation
            WHERE identifier=@identifier
        ]], {
            ['@collected'] = data.collected,
            ['@lastCollection'] = data.lastCollection,
            ['@lastLocation'] = data.lastLocation,
            ['@identifier'] = data.identifier
        })
    else
        MySQL.Sync.execute([[
            INSERT INTO pumpkin_hunt_data (identifier, player_name, collected, rewards_claimed, last_collection, last_collection_location)
            VALUES (@identifier, @name, 1, '[]', @lastCollection, @lastLocation)
        ]], {
            ['@identifier'] = identifier,
            ['@name'] = GetPlayerName(source),
            ['@lastCollection'] = os.date("%Y-%m-%d %H:%M:%S"),
            ['@lastLocation'] = pumpkin.zoneName
        })
        data = {
            identifier = identifier,
            collected = 1,
            rewardsClaimed = {},
            lastCollection = os.date("%Y-%m-%d %H:%M:%S"),
            lastLocation = pumpkin.zoneName
        }
    end

    playerPumpkinData[source] = data
    TriggerClientEvent('pumpkin:remove', -1, pumpkinId)
    UpdateLeaderboard()

    local newRewards = {}
    for _, reward in ipairs(Config.PumpkinHunt.rewards) do
        if data.collected >= reward.pumpkinsRequired and not table.contains(data.rewardsClaimed, reward.pumpkinsRequired) then
            table.insert(newRewards, reward)
        end
    end

    local message = string.format(
        Config.PumpkinHunt.notifications.collected,
        data.collected,
        Config.PumpkinHunt.rewards[#Config.PumpkinHunt.rewards].pumpkinsRequired
    )

    return {
        success = true,
        message = message,
        collected = data.collected,
        newRewards = #newRewards > 0,
        rewardName = #newRewards > 0 and newRewards[1].name or nil
    }
end)

local function GiveRewards(source, rewards)
    local useOxInventory = GetResourceState('ox_inventory') == 'started'

    for _, reward in ipairs(rewards) do
        if reward.type == "money" then
            if FrameWork == 'esx' then
                local xPlayer = ESX.GetPlayerFromId(source)
                if xPlayer then
                    xPlayer.addMoney(reward.amount)
                end
            elseif FrameWork == 'qb' then
                local Player = QBCore.Functions.GetPlayer(source)
                if Player then
                    Player.Functions.AddMoney(Config.PumpkinHunt.framework.qb.moneyType, reward.amount)
                end
            end
        elseif reward.type == "black_money" then
            if FrameWork == 'esx' then
                local xPlayer = ESX.GetPlayerFromId(source)
                if xPlayer then
                    xPlayer.addAccountMoney(Config.PumpkinHunt.framework.esx.blackMoneyAccount, reward.amount)
                end
            elseif FrameWork == 'qb' then
                local Player = QBCore.Functions.GetPlayer(source)
                if Player then
                    Player.Functions.AddMoney(Config.PumpkinHunt.framework.qb.blackMoneyType, reward.amount)
                end
            end
        elseif reward.type == "item" then
            if useOxInventory then
                exports.ox_inventory:AddItem(source, reward.name, reward.amount)
            elseif FrameWork == 'esx' then
                local xPlayer = ESX.GetPlayerFromId(source)
                if xPlayer then
                    xPlayer.addInventoryItem(reward.name, reward.amount)
                end
            elseif FrameWork == 'qb' then
                local Player = QBCore.Functions.GetPlayer(source)
                if Player then
                    Player.Functions.AddItem(reward.name, reward.amount)
                end
            end
        elseif reward.type == "weapon" then
            if useOxInventory then
                exports.ox_inventory:AddItem(source, reward.name, 1)
                if reward.ammo and reward.ammo > 0 then
                    GiveWeaponToPed(GetPlayerPed(source), GetHashKey(reward.name), reward.ammo, false, false)
                end
            elseif FrameWork == 'esx' then
                local xPlayer = ESX.GetPlayerFromId(source)
                if xPlayer then
                    xPlayer.addWeapon(reward.name, reward.ammo or 0)
                end
            elseif FrameWork == 'qb' then
                local Player = QBCore.Functions.GetPlayer(source)
                if Player then
                    Player.Functions.AddItem(reward.name, 1)
                    if reward.ammo and reward.ammo > 0 then
                        GiveWeaponToPed(GetPlayerPed(source), GetHashKey(reward.name), reward.ammo, false, false)
                    end
                end
            end
        end
    end
end

lib.callback.register('pumpkin:claimReward', function(source, pumpkinsRequired)
    if not Config.PumpkinHunt.enabled then
        return { success = false, message = "Sistema desactivado" }
    end

    local identifier = GetPlayerIdentifier(source)
    if not identifier then
        return { success = false, message = "Error cargando datos" }
    end

    local result = MySQL.Sync.fetchAll('SELECT * FROM pumpkin_hunt_data WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    })

    local data
    if result[1] then
        local rewardsClaimed = result[1].rewards_claimed ~= '' and json.decode(result[1].rewards_claimed) or {}
        data = {
            identifier = result[1].identifier,
            collected = result[1].collected,
            rewardsClaimed = rewardsClaimed
        }
    else
        return { success = false, message = "No se encontraron datos del jugador" }
    end

    if data.collected < pumpkinsRequired then
        return { success = false, message = "No tienes suficientes calabazas" }
    end

    if table.contains(data.rewardsClaimed, pumpkinsRequired) then
        return { success = false, message = "Ya has reclamado esta recompensa" }
    end

    local rewardData
    for _, reward in ipairs(Config.PumpkinHunt.rewards) do
        if reward.pumpkinsRequired == pumpkinsRequired then
            rewardData = reward
            break
        end
    end

    if not rewardData then
        return { success = false, message = "Recompensa no encontrada" }
    end

    GiveRewards(source, rewardData.rewards)

    table.insert(data.rewardsClaimed, pumpkinsRequired)
    local rewardsJSON = json.encode(data.rewardsClaimed)

    MySQL.Sync.execute([[
        UPDATE pumpkin_hunt_data
        SET rewards_claimed=@rewardsClaimed
        WHERE identifier=@identifier
    ]], {
        ['@rewardsClaimed'] = rewardsJSON,
        ['@identifier'] = identifier
    })

    playerPumpkinData[source] = data

    if Config.DebugMode then
        print(("[PUMPKIN] %s reclamó recompensa: %s"):format(GetPlayerName(source), rewardData.name))
    end

    UpdateLeaderboard()

    return {
        success = true,
        message = Config.PumpkinHunt.notifications.rewardUnlocked,
        rewardName = rewardData.name,
        playerData = data,
        rewards = Config.PumpkinHunt.rewards,
        leaderboard = leaderboardCache
    }
end)

function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

RegisterCommand('pumpkinadmin', function(source, args)
    if source ~= 0 and not HasAdminPermission(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "[PUMPKIN]", "Sin permisos" }
        })
        return
    end

    if not args[1] then
        local msg = [[
^3=== COMANDOS ADMIN CALABAZAS ===^7
/pumpkinadmin spawn [zona] - Spawnear calabaza
/pumpkinadmin clear - Limpiar todas las calabazas
/pumpkinadmin stats [id] - Ver estadísticas
/pumpkinadmin reset [id] - Resetear progreso
/pumpkinadmin give [id] [cantidad] - Dar calabazas
/pumpkinadmin info - Info del sistema
^3================================^7
        ]]

        if source == 0 then
            print(msg)
        else
            TriggerClientEvent('chat:addMessage', source, { args = { msg } })
        end
        return
    end

    local action = args[1]:lower()

    if action == "spawn" then
        local zoneIndex = tonumber(args[2]) or math.random(1, #Config.PumpkinHunt.spawnZones)
        SpawnPumpkin(zoneIndex)

        local msg = string.format("^2Calabaza spawneada en zona %d^7", zoneIndex)
        if source == 0 then print(msg) else TriggerClientEvent('chat:addMessage', source, { args = { "[PUMPKIN]", msg } }) end
    elseif action == "clear" then
        local count = 0
        for id, _ in pairs(activePumpkins) do
            activePumpkins[id] = nil
            count = count + 1
        end
        TriggerClientEvent('pumpkin:clearAll', -1)

        local msg = string.format("^2Limpiadas %d calabazas^7", count)
        if source == 0 then print(msg) else TriggerClientEvent('chat:addMessage', source, { args = { "[PUMPKIN]", msg } }) end
    elseif action == "stats" then
        local targetId = tonumber(args[2])
        if not targetId or not GetPlayerName(targetId) then
            local msg = "Jugador no encontrado"
            if source == 0 then print(msg) else TriggerClientEvent('chat:addMessage', source,
                    { args = { "[PUMPKIN]", msg } }) end
            return
        end

        LoadPlayerData(targetId, function(data)
            if data then
                local msg = string.format(
                    "^3%s^7: %d calabazas | %d recompensas reclamadas",
                    GetPlayerName(targetId), data.collected, #data.rewardsClaimed
                )
                if source == 0 then print(msg) else TriggerClientEvent('chat:addMessage', source,
                        { args = { "[PUMPKIN]", msg } }) end
            end
        end)
    elseif action == "reset" then
        local targetId = tonumber(args[2])
        if not targetId or not GetPlayerName(targetId) then
            local msg = "Jugador no encontrado"
            if source == 0 then print(msg) else TriggerClientEvent('chat:addMessage', source,
                    { args = { "[PUMPKIN]", msg } }) end
            return
        end

        local identifier = GetPlayerIdentifier(targetId)
        if identifier then
            MySQL.Async.execute([[
                UPDATE pumpkin_hunt_data
                SET collected = 0, rewards_claimed = '[]'
                WHERE identifier = @identifier
            ]], {
                ['@identifier'] = identifier
            }, function()
                if playerPumpkinData[targetId] then
                    playerPumpkinData[targetId].collected = 0
                    playerPumpkinData[targetId].rewardsClaimed = {}
                end

                local msg = string.format("^2Progreso reseteado para %s^7", GetPlayerName(targetId))
                if source == 0 then print(msg) else TriggerClientEvent('chat:addMessage', source,
                        { args = { "[PUMPKIN]", msg } }) end
            end)
        end
    elseif action == "give" then
        local targetId = tonumber(args[2])
        local amount = tonumber(args[3]) or 1

        if not targetId or not GetPlayerName(targetId) then
            local msg = "Jugador no encontrado"
            if source == 0 then print(msg) else TriggerClientEvent('chat:addMessage', source,
                    { args = { "[PUMPKIN]", msg } }) end
            return
        end

        LoadPlayerData(targetId, function(data)
            if data then
                data.collected = data.collected + amount
                playerPumpkinData[targetId] = data
                SavePlayerData(targetId, data)

                local msg = string.format("^2Dadas %d calabazas a %s (Total: %d)^7",
                    amount, GetPlayerName(targetId), data.collected)
                if source == 0 then print(msg) else TriggerClientEvent('chat:addMessage', source,
                        { args = { "[PUMPKIN]", msg } }) end
            end
        end)
    elseif action == "info" then
        local msg = string.format([[
^3=== INFO SISTEMA CALABAZAS ===^7
Activas: %d / %d
Zonas: %d
Evento activo: %s
Jugadores con datos: %d
^3==============================^7
        ]],
            #activePumpkins,
            Config.PumpkinHunt.maxActivePumpkins,
            #Config.PumpkinHunt.spawnZones,
            IsEventActive() and "Sí" or "No",
            #playerPumpkinData
        )

        if source == 0 then print(msg) else TriggerClientEvent('chat:addMessage', source, { args = { msg } }) end
    end
end, true)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for source, data in pairs(playerPumpkinData) do
            SavePlayerData(source, data)
        end
        print("^2[PUMPKIN HUNT]^7 Datos guardados al detener el recurso")
    end
end)

exports('GetPlayerPumpkins', function(source)
    return playerPumpkinData[source] and playerPumpkinData[source].collected or 0
end)

exports('GetActivePumpkins', function()
    return activePumpkins
end)

exports('SpawnPumpkin', SpawnPumpkin)

exports('IsEventActive', IsEventActive)

AddEventHandler('onResourceStart', function(resourceName)
  if (GetCurrentResourceName() ~= resourceName) then
    return
  end
  UpdateLeaderboard()
end)