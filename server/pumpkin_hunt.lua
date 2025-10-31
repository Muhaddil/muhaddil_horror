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

local function CountActivePumpkins()
    local count = 0
    for id, pumpkin in pairs(activePumpkins) do
        if not pumpkin.collected then
            count = count + 1
        end
    end
    return count
end

local function CountPumpkinsInZone(zoneIndex)
    local count = 0
    for _, pumpkin in pairs(activePumpkins) do
        if pumpkin.zone == zoneIndex and not pumpkin.collected then
            count = count + 1
        end
    end
    return count
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
            ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
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

    return currentDate >= startDate and currentDate <= endDate
end

local function GenerateRandomPosition(zone)
    local position = nil
    local tries = 10

    for i = 1, tries do
        local angle = math.random() * 2 * math.pi
        local distance = math.random() * zone.radius

        local x = zone.center.x + math.cos(angle) * distance
        local y = zone.center.y + math.sin(angle) * distance
        local z = zone.center.z

        local nearbyPlayers = {}
        local players = GetPlayers()

        for _, playerId in ipairs(players) do
            local playerPed = GetPlayerPed(playerId)
            local playerCoords = GetEntityCoords(playerPed)
            local distanceToPos = #(vector3(x, y, z) - playerCoords)

            if distanceToPos < 300.0 then
                table.insert(nearbyPlayers, {
                    id = playerId,
                    distance = distanceToPos,
                    coords = playerCoords
                })
            end
        end

        if #nearbyPlayers > 0 then
            table.sort(nearbyPlayers, function(a, b) return a.distance < b.distance end)
            local closestPlayer = nearbyPlayers[1].id

            if Config.DebugMode then
                print(string.format("^6[PUMPKIN]^7 Jugador más cercano: %d a %.1fm de (%.2f, %.2f)", 
                    closestPlayer, nearbyPlayers[1].distance, x, y))
            end

            local ok, res = pcall(function()
                return lib.callback.await('pumpkin:getGroundZ', closestPlayer, vector3(x, y, z))
            end)

            if ok and res then
                position = vector3(x, y, res.z)
                if Config.DebugMode then
                    print(string.format("^2[PUMPKIN]^7 Posición válida encontrada en intento %d: (%.2f, %.2f, %.2f)", 
                        i, position.x, position.y, position.z))
                end
                break
            else
                if Config.DebugMode then
                    print(string.format("^3[PUMPKIN]^7 Falló groundZ en intento %d en (%.2f, %.2f)", i, x, y))
                end
            end
        else
            if Config.DebugMode then
                print(string.format("^3[PUMPKIN]^7 No hay jugadores cercanos en (%.2f, %.2f) - intento %d", x, y, i))
            end
        end

        Wait(10)
    end

    if not position and Config.DebugMode then
        print(string.format("^1[PUMPKIN]^7 No se pudo generar posición válida después de %d intentos", tries))
    end

    return position
end

local function SpawnPumpkin(zoneIndex)
    if CountActivePumpkins() >= Config.PumpkinHunt.maxActivePumpkins then
        if Config.DebugMode then
            print(string.format("^3[PUMPKIN]^7 Límite global alcanzado (%d/%d)",
                CountActivePumpkins(), Config.PumpkinHunt.maxActivePumpkins))
        end
        return
    end

    local zone = Config.PumpkinHunt.spawnZones[zoneIndex]
    if not zone then
        if Config.DebugMode then print("^1[PUMPKIN]^7 SpawnPumpkin: zona inválida: " .. tostring(zoneIndex)) end
        return
    end

    local playersInZone = false
    local players = GetPlayers()
    local zoneCenter = vector3(zone.center.x, zone.center.y, zone.center.z)
    
    for _, playerId in ipairs(players) do
        local playerPed = GetPlayerPed(playerId)
        local playerCoords = GetEntityCoords(playerPed)
        local distanceToZone = #(zoneCenter - playerCoords)
        
        if distanceToZone < (zone.radius + 100.0) then
            playersInZone = true
            break
        end
    end
    
    if not playersInZone then
        if Config.DebugMode then
            print(string.format("^3[PUMPKIN]^7 No hay jugadores en zona %s - omitiendo spawn", zone.name))
        end
        return
    end

    local zoneCount = CountPumpkinsInZone(zoneIndex)
    if zoneCount >= zone.maxPumpkins then
        if Config.DebugMode then
            print(string.format("^3[PUMPKIN]^7 Límite de zona alcanzado en %s (%d/%d)",
                zone.name, zoneCount, zone.maxPumpkins))
        end
        return
    end

    local position = GenerateRandomPosition(zone)
    if not position then
        if Config.DebugMode then
            print(string.format("^1[PUMPKIN]^7 SpawnPumpkin: posición inválida para zona %s; abortando spawn", zone.name))
        end
        return
    end

    pumpkinIdCounter = pumpkinIdCounter + 1
    local pumpkinId = pumpkinIdCounter
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
        print(string.format("^2[PUMPKIN]^7 Calabaza #%d spawneada en %s (%.2f, %.2f, %.2f) (Total: %d)",
            pumpkinId, zone.name, position.x, position.y, position.z, CountActivePumpkins()))
    end

    SetTimeout(Config.PumpkinHunt.despawnTime, function()
        local p = activePumpkins[pumpkinId]
        if p and not p.collected then
            activePumpkins[pumpkinId] = nil
            TriggerClientEvent('pumpkin:remove', -1, pumpkinId)
            if Config.DebugMode then
                print(string.format("^3[PUMPKIN]^7 Calabaza #%d expiró por timeout", pumpkinId))
            end
        end
    end)
end

local function CleanupStalePumpkins()
    local now = os.time()
    local removed = 0
    for id, p in pairs(activePumpkins) do
        if (not p.position) or (p.spawnTime and (now - p.spawnTime) > (Config.PumpkinHunt.despawnTime * 2)) then
            activePumpkins[id] = nil
            TriggerClientEvent('pumpkin:remove', -1, id)
            removed = removed + 1
            if Config.DebugMode then
                print(string.format("^1[PUMPKIN]^7 Removed stale pumpkin #%d (pos nil or too old)", id))
            end
        end
    end
    return removed
end

CreateThread(function()
    if not Config.PumpkinHunt.enabled then return end
    while true do
        Wait(60 * 1000)
        if Config.DebugMode then
            local removed = CleanupStalePumpkins()
            if removed > 0 then
                print(string.format("^3[PUMPKIN]^7 Limpieza periódica: removidas %d entradas", removed))
            end
        else
            CleanupStalePumpkins()
        end
    end
end)

CreateThread(function()
    if not Config.PumpkinHunt.enabled then return end

    Wait(5000)

    for i = 1, #Config.PumpkinHunt.spawnZones do
        local initialSpawns = math.floor(Config.PumpkinHunt.spawnZones[i].maxPumpkins / 2)
        for j = 1, initialSpawns do
            SpawnPumpkin(i)
            Wait(500)
        end
    end

    while true do
        Wait(Config.PumpkinHunt.spawnInterval)

        if IsEventActive() then
            for zoneIndex, zone in ipairs(Config.PumpkinHunt.spawnZones) do
                local currentInZone = CountPumpkinsInZone(zoneIndex)
                local toSpawn = zone.maxPumpkins - currentInZone

                for i = 1, toSpawn do
                    if CountActivePumpkins() < Config.PumpkinHunt.maxActivePumpkins then
                        SpawnPumpkin(zoneIndex)
                        Wait(200)
                    else
                        break
                    end
                end
            end
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

local function SyncPumpkinsToPlayer(source)
    if not Config.PumpkinHunt.enabled then return end

    local activeCount = CountActivePumpkins()

    if activeCount == 0 then
        if Config.DebugMode then
            print(string.format("^3[PUMPKIN]^7 No hay calabazas activas para sincronizar a %s", GetPlayerName(source)))
        end
        return
    end

    for id, pumpkin in pairs(activePumpkins) do
        if not pumpkin.collected then
            TriggerClientEvent('pumpkin:spawn', source, id, pumpkin.position, pumpkin.model)
        end
    end

    if Config.DebugMode then
        print(string.format("^2[PUMPKIN]^7 Sincronizadas %d calabazas a %s",
            activeCount, GetPlayerName(source)))
    end
end

if FrameWork == 'esx' then
    AddEventHandler('esx:playerLoaded', function(playerId, xPlayer, isNew)
        local source = playerId

        if not Config.PumpkinHunt.enabled then return end

        SetTimeout(2000, function()
            LoadPlayerData(source, function(data)
                if data then
                    playerPumpkinData[source] = data

                    SyncPumpkinsToPlayer(source)

                    if Config.PumpkinHunt.leaderboard.enabled then
                        TriggerClientEvent('pumpkin:updateLeaderboard', source, leaderboardCache)
                    end

                    if Config.DebugMode then
                        local status = isNew and "NUEVO" or "EXISTENTE"
                        print(string.format("^2[PUMPKIN]^7 Jugador %s cargado [%s]: %d calabazas recolectadas",
                            xPlayer.getName(), status, data.collected))
                    end
                end
            end)
        end)
    end)
else
    AddEventHandler('playerJoining', function()
        local source = source
        Wait(2000)

        if not Config.PumpkinHunt.enabled then return end

        LoadPlayerData(source, function(data)
            if data then
                playerPumpkinData[source] = data

                SyncPumpkinsToPlayer(source)

                if Config.PumpkinHunt.leaderboard.enabled then
                    TriggerClientEvent('pumpkin:updateLeaderboard', source, leaderboardCache)
                end

                if Config.DebugMode then
                    print(string.format("^2[PUMPKIN]^7 Datos cargados para %s: %d calabazas",
                        GetPlayerName(source), data.collected))
                end
            end
        end)
    end)
end

RegisterCommand('pumpkinresync', function(source, args)
    if source == 0 then return end

    if not Config.PumpkinHunt.enabled then
        TriggerClientEvent('chat:addMessage', source, {
            args = { "[PUMPKIN]", "Sistema desactivado" }
        })
        return
    end

    TriggerClientEvent('pumpkin:clearAll', source)

    SetTimeout(500, function()
        SyncPumpkinsToPlayer(source)
        TriggerClientEvent('chat:addMessage', source, {
            color = { 0, 255, 0 },
            args = { "[PUMPKIN]", string.format("Resincronizadas %d calabazas", CountActivePumpkins()) }
        })
    end)
end, false)

exports('ResyncPlayerPumpkins', function(source)
    SyncPumpkinsToPlayer(source)
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
        activePumpkins = CountActivePumpkins(),
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
    if not pumpkin then
        return { success = false, message = Config.PumpkinHunt.notifications.alreadyCollected }
    end

    if pumpkin.collected then
        return { success = false, message = Config.PumpkinHunt.notifications.alreadyCollected }
    end

    pumpkin.collected = true

    local identifier = GetPlayerIdentifier(source)
    if not identifier then
        activePumpkins[pumpkinId] = nil
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

    activePumpkins[pumpkinId] = nil

    TriggerClientEvent('pumpkin:remove', -1, pumpkinId)

    UpdateLeaderboard()

    if Config.DebugMode then
        print(string.format("^2[PUMPKIN]^7 %s recolectó calabaza #%d (Total: %d/%d activas)",
            GetPlayerName(source), pumpkinId, CountActivePumpkins(), Config.PumpkinHunt.maxActivePumpkins))
    end

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
/pumpkinadmin list - Mostrar coordenadas de calabazas activas
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
            if source == 0 then
                print(msg)
            else
                TriggerClientEvent('chat:addMessage', source, { args = { "[PUMPKIN]", msg } })
            end
            return
        end

        LoadPlayerData(targetId, function(data)
            if data then
                local msg = string.format(
                    "^3%s^7: %d calabazas | %d recompensas reclamadas",
                    GetPlayerName(targetId), data.collected, #data.rewardsClaimed
                )
                if source == 0 then
                    print(msg)
                else
                    TriggerClientEvent('chat:addMessage', source, { args = { "[PUMPKIN]", msg } })
                end
            end
        end)
    elseif action == "list" then
        if next(activePumpkins) == nil then
            local msg = "^1No hay calabazas activas actualmente.^7"
            if source == 0 then print(msg) else TriggerClientEvent('chat:addMessage', source,
                    { args = { "[PUMPKIN]", msg } }) end
            return
        end

        local msgHeader = "^3=== COORDENADAS DE CALABAZAS ACTIVAS ===^7"
        if source == 0 then print(msgHeader) else TriggerClientEvent('chat:addMessage', source,
                { args = { "[PUMPKIN]", msgHeader } }) end

        for id, data in pairs(activePumpkins) do
            if not data.collected then
                local coords = string.format("ID %d: (x=%.2f, y=%.2f, z=%.2f) - %s",
                    id, data.position.x, data.position.y, data.position.z, data.zoneName)
                if source == 0 then
                    print(coords)
                else
                    TriggerClientEvent('chat:addMessage', source, { args = { "[PUMPKIN]", coords } })
                end
            end
        end

        local msgFooter = string.format("^3Total activas: %d/%d^7", CountActivePumpkins(),
            Config.PumpkinHunt.maxActivePumpkins)
        if source == 0 then print(msgFooter) else TriggerClientEvent('chat:addMessage', source,
                { args = { "[PUMPKIN]", msgFooter } }) end
    elseif action == "reset" then
        local targetId = tonumber(args[2])
        if not targetId or not GetPlayerName(targetId) then
            local msg = "Jugador no encontrado"
            if source == 0 then
                print(msg)
            else
                TriggerClientEvent('chat:addMessage', source, { args = { "[PUMPKIN]", msg } })
            end
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
                if source == 0 then
                    print(msg)
                else
                    TriggerClientEvent('chat:addMessage', source, { args = { "[PUMPKIN]", msg } })
                end
            end)
        end
    elseif action == "give" then
        local targetId = tonumber(args[2])
        local amount = tonumber(args[3]) or 1

        if not targetId or not GetPlayerName(targetId) then
            local msg = "Jugador no encontrado"
            if source == 0 then
                print(msg)
            else
                TriggerClientEvent('chat:addMessage', source, { args = { "[PUMPKIN]", msg } })
            end
            return
        end

        LoadPlayerData(targetId, function(data)
            if data then
                data.collected = data.collected + amount
                playerPumpkinData[targetId] = data
                SavePlayerData(targetId, data)

                local msg = string.format("^2Dadas %d calabazas a %s (Total: %d)^7",
                    amount, GetPlayerName(targetId), data.collected)
                if source == 0 then
                    print(msg)
                else
                    TriggerClientEvent('chat:addMessage', source, { args = { "[PUMPKIN]", msg } })
                end
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
            CountActivePumpkins(),
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

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    UpdateLeaderboard()
end)

exports('GetPlayerPumpkins', function(source)
    return playerPumpkinData[source] and playerPumpkinData[source].collected or 0
end)

exports('GetActivePumpkins', function()
    return activePumpkins
end)

exports('GetActivePumpkinsCount', function()
    return CountActivePumpkins()
end)

exports('SpawnPumpkin', SpawnPumpkin)

exports('IsEventActive', IsEventActive)
