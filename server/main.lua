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

local playerStats = {}
local globalEventsActive = false
local adminPermissions = {}
local randomJumpscareActive = false
local nextRandomJumpscare = 0
local lastRandomTarget = nil

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

local function IsPlayerWhitelisted(source)
    if not Config.WhiteList or not Config.WhiteList.enabled then return false end

    local identifiers = GetPlayerIdentifiers(source)
    for _, id in ipairs(identifiers) do
        for _, whitelisted in ipairs(Config.WhiteList.players) do
            if id == whitelisted then
                return true
            end
        end
    end

    for _, whitelisted in ipairs(Config.WhiteList.players) do
        if whitelisted == source then
            return true
        end
    end

    return false
end

AddEventHandler('playerJoining', function()
    local source = source
    playerStats[source] = {
        totalJumpscares = 0,
        totalWhispers = 0,
        totalGhosts = 0,
        timeInZones = 0,
        currentZone = nil,
        lastEvent = nil,
        forcedEffects = false,
        immuneToHorror = false
    }
end)

AddEventHandler('playerDropped', function()
    local source = source
    if playerStats[source] then
        playerStats[source] = nil
    end
end)

RegisterNetEvent('horror:syncEvent')
AddEventHandler('horror:syncEvent', function(eventType, data)
    local source = source

    if playerStats[source] then
        playerStats[source].lastEvent = {
            type = eventType,
            time = os.time(),
            data = data
        }
    end

    if Config.SyncEvents then
        local coords = GetEntityCoords(GetPlayerPed(source))
        local players = GetPlayers()

        for _, playerId in ipairs(players) do
            local playerCoords = GetEntityCoords(GetPlayerPed(playerId))
            local distance = #(coords - playerCoords)

            if distance < 50.0 and playerId ~= source then
                TriggerClientEvent('horror:receiveSync', playerId, eventType, data)
            end
        end
    end
end)

RegisterNetEvent('horror:logEvent')
AddEventHandler('horror:logEvent', function(eventType)
    local source = source

    if not playerStats[source] then
        playerStats[source] = {
            totalJumpscares = 0,
            totalWhispers = 0,
            totalGhosts = 0,
            timeInZones = 0
        }
    end

    if eventType == "jumpscare" then
        playerStats[source].totalJumpscares = playerStats[source].totalJumpscares + 1
    elseif eventType == "whisper" then
        playerStats[source].totalWhispers = playerStats[source].totalWhispers + 1
    elseif eventType == "ghost" then
        playerStats[source].totalGhosts = playerStats[source].totalGhosts + 1
    end

    if Config.DebugMode then
        print(string.format('[HORROR] Jugador %s experimentó: %s', GetPlayerName(source), eventType))
    end
end)

RegisterNetEvent('horror:playerEnterZone')
AddEventHandler('horror:playerEnterZone', function(zoneName)
    local source = source
    if playerStats[source] then
        playerStats[source].currentZone = zoneName
        playerStats[source].zoneEnterTime = os.time()
    end
end)

RegisterNetEvent('horror:playerLeaveZone')
AddEventHandler('horror:playerLeaveZone', function()
    local source = source
    if playerStats[source] then
        if playerStats[source].zoneEnterTime then
            local timeSpent = os.time() - playerStats[source].zoneEnterTime
            playerStats[source].timeInZones = (playerStats[source].timeInZones or 0) + timeSpent
        end
        playerStats[source].currentZone = nil
        playerStats[source].zoneEnterTime = nil
    end
end)

RegisterCommand('horrorevent', function(source, args)
    if source ~= 0 and not HasAdminPermission(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "[HORROR]", "No tienes permisos para este comando" }
        })
        return
    end

    if not args[1] then
        local msg = source == 0 and print or
            function(m) TriggerClientEvent('chat:addMessage', source, { args = { "[HORROR]", m } }) end
        msg("Uso: /horrorevent [start/stop/status]")
        return
    end

    if args[1] == "start" then
        globalEventsActive = true
        TriggerClientEvent('horror:globalEventStart', -1)

        local msg = "^2[HORROR]^7 Evento global de terror iniciado en todo el servidor"
        if source == 0 then
            print(msg)
        else
            TriggerClientEvent('chat:addMessage', -1, {
                color = { 255, 0, 0 },
                multiline = true,
                args = { "[EVENTO GLOBAL]", "¡Un evento de terror ha comenzado! Los horrores están en todas partes..." }
            })
        end
    elseif args[1] == "stop" then
        globalEventsActive = false
        TriggerClientEvent('horror:globalEventStop', -1)

        local msg = "^1[HORROR]^7 Evento global de terror detenido"
        if source == 0 then
            print(msg)
        else
            TriggerClientEvent('chat:addMessage', -1, {
                color = { 0, 255, 0 },
                args = { "[EVENTO GLOBAL]", "El evento de terror ha terminado. Todo vuelve a la normalidad..." }
            })
        end
    elseif args[1] == "status" then
        local status = globalEventsActive and "^2ACTIVO^7" or "^1INACTIVO^7"
        local msg = string.format("^3[HORROR]^7 Estado del evento global: %s", status)

        if source == 0 then
            print(msg)
        else
            TriggerClientEvent('chat:addMessage', source, { args = { msg } })
        end
    end
end, true)

RegisterCommand('horrorjump', function(source, args)
    if source ~= 0 and not HasAdminPermission(source) then
        TriggerClientEvent('chat:addMessage', source, { color = { 255, 0, 0 }, args = { "[HORROR]", "Sin permisos" } })
        return
    end

    if not args[1] then
        local msg = "Uso: /horrorjump [ID] o /horrorjump all"
        if source == 0 then print(msg) else TriggerClientEvent('chat:addMessage', source, { args = { "[HORROR]", msg } }) end
        return
    end

    if args[1] == "all" then
        for _, playerId in ipairs(GetPlayers()) do
            if not IsPlayerWhitelisted(tonumber(playerId)) then
                TriggerClientEvent('horror:adminForce', playerId, 'jumpscare')
            end
        end
        local msg = "Jumpscare enviado a todos los jugadores"
        if source == 0 then
            print("^2[HORROR]^7 " .. msg)
        else
            TriggerClientEvent('chat:addMessage', source,
                { args = { "[HORROR]", msg } })
        end
    else
        local targetId = tonumber(args[1])
        if IsPlayerWhitelisted(targetId) then
            TriggerClientEvent('chat:addMessage', source, {
                color = { 255, 0, 0 },
                args = { "[HORROR]", "No puedes aplicar efectos de horror a jugadores en la WhiteList." }
            })
            return
        end

        if targetId and GetPlayerName(targetId) then
            TriggerClientEvent('horror:adminForce', targetId, 'jumpscare')
            local msg = "Jumpscare enviado a " .. GetPlayerName(targetId)
            if source == 0 then
                print("^2[HORROR]^7 " .. msg)
            else
                TriggerClientEvent('chat:addMessage', source,
                    { args = { "[HORROR]", msg } })
            end
        else
            local msg = "Jugador no encontrado"
            if source == 0 then
                print("^1[HORROR]^7 " .. msg)
            else
                TriggerClientEvent('chat:addMessage', source,
                    { args = { "[HORROR]", msg } })
            end
        end
    end
end, true)

RegisterCommand('horrorwhisper', function(source, args)
    if source ~= 0 and not HasAdminPermission(source) then
        TriggerClientEvent('chat:addMessage', source, { color = { 255, 0, 0 }, args = { "[HORROR]", "Sin permisos" } })
        return
    end

    if not args[1] then
        local msg = "Uso: /horrorwhisper [ID] o /horrorwhisper all"
        if source == 0 then print(msg) else TriggerClientEvent('chat:addMessage', source, { args = { "[HORROR]", msg } }) end
        return
    end

    if args[1] == "all" then
        for _, playerId in ipairs(GetPlayers()) do
            if not IsPlayerWhitelisted(tonumber(playerId)) then
                TriggerClientEvent('horror:adminForce', playerId, 'whisper')
            end
        end
    else
        local targetId = tonumber(args[1])
        if IsPlayerWhitelisted(targetId) then
            TriggerClientEvent('chat:addMessage', source, {
                color = { 255, 0, 0 },
                args = { "[HORROR]", "No puedes aplicar efectos de horror a jugadores en la WhiteList." }
            })
            return
        end

        if targetId and GetPlayerName(targetId) then
            TriggerClientEvent('horror:adminForce', targetId, 'whisper')
        end
    end
end, true)

RegisterCommand('horrordistort', function(source, args)
    if source ~= 0 and not HasAdminPermission(source) then
        TriggerClientEvent('chat:addMessage', source, { color = { 255, 0, 0 }, args = { "[HORROR]", "Sin permisos" } })
        return
    end

    if not args[1] then
        local msg = "Uso: /horrordistort [ID] o /horrordistort all"
        if source == 0 then print(msg) else TriggerClientEvent('chat:addMessage', source, { args = { "[HORROR]", msg } }) end
        return
    end

    if args[1] == "all" then
        for _, playerId in ipairs(GetPlayers()) do
            if not IsPlayerWhitelisted(tonumber(playerId)) then
                TriggerClientEvent('horror:adminForce', playerId, 'distortion')
            end
        end
    else
        local targetId = tonumber(args[1])
        if IsPlayerWhitelisted(targetId) then
            TriggerClientEvent('chat:addMessage', source, {
                color = { 255, 0, 0 },
                args = { "[HORROR]", "No puedes aplicar efectos de horror a jugadores en la WhiteList." }
            })
            return
        end

        if targetId and GetPlayerName(targetId) then
            TriggerClientEvent('horror:adminForce', targetId, 'distortion')
        end
    end
end, true)

RegisterCommand('horrorghost', function(source, args)
    if source ~= 0 and not HasAdminPermission(source) then
        TriggerClientEvent('chat:addMessage', source, { color = { 255, 0, 0 }, args = { "[HORROR]", "Sin permisos" } })
        return
    end

    if not args[1] then
        local msg = "Uso: /horrorghost [ID] o /horrorghost all"
        if source == 0 then print(msg) else TriggerClientEvent('chat:addMessage', source, { args = { "[HORROR]", msg } }) end
        return
    end

    if args[1] == "all" then
        for _, playerId in ipairs(GetPlayers()) do
            if not IsPlayerWhitelisted(tonumber(playerId)) then
                TriggerClientEvent('horror:adminForce', playerId, 'ghost')
            end
        end
    else
        local targetId = tonumber(args[1])
        if IsPlayerWhitelisted(targetId) then
            TriggerClientEvent('chat:addMessage', source, {
                color = { 255, 0, 0 },
                args = { "[HORROR]", "No puedes aplicar efectos de horror a jugadores en la WhiteList." }
            })
            return
        end

        if targetId and GetPlayerName(targetId) then
            TriggerClientEvent('horror:adminForce', targetId, 'ghost')
        end
    end
end, true)

RegisterCommand('horrorenv', function(source, args)
    if source ~= 0 and not HasAdminPermission(source) then
        TriggerClientEvent('chat:addMessage', source, { color = { 255, 0, 0 }, args = { "[HORROR]", "Sin permisos" } })
        return
    end

    if not args[1] then
        local msg = "Uso: /horrorenv [ID] o /horrorenv all"
        if source == 0 then print(msg) else TriggerClientEvent('chat:addMessage', source, { args = { "[HORROR]", msg } }) end
        return
    end

    if args[1] == "all" then
        for _, playerId in ipairs(GetPlayers()) do
            if not IsPlayerWhitelisted(tonumber(playerId)) then
                TriggerClientEvent('horror:adminForce', playerId, 'environmental')
            end
        end
    else
        local targetId = tonumber(args[1])
        if IsPlayerWhitelisted(targetId) then
            TriggerClientEvent('chat:addMessage', source, {
                color = { 255, 0, 0 },
                args = { "[HORROR]", "No puedes aplicar efectos de horror a jugadores en la WhiteList." }
            })
            return
        end

        if targetId and GetPlayerName(targetId) then
            TriggerClientEvent('horror:adminForce', targetId, 'environmental')
        end
    end
end, true)

RegisterCommand('horrorcombo', function(source, args)
    if source ~= 0 and not HasAdminPermission(source) then
        TriggerClientEvent('chat:addMessage', source, { color = { 255, 0, 0 }, args = { "[HORROR]", "Sin permisos" } })
        return
    end

    if not args[1] then
        local msg = "Uso: /horrorcombo [ID] - Activa TODOS los efectos en un jugador"
        if source == 0 then print(msg) else TriggerClientEvent('chat:addMessage', source, { args = { "[HORROR]", msg } }) end
        return
    end

    local targetId = tonumber(args[1])
    if IsPlayerWhitelisted(targetId) then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "[HORROR]", "No puedes aplicar efectos de horror a jugadores en la WhiteList." }
        })
        return
    end

    if targetId and GetPlayerName(targetId) then
        TriggerClientEvent('horror:adminCombo', targetId)
        local msg = "Combo de terror activado en " .. GetPlayerName(targetId)
        if source == 0 then
            print("^1[HORROR]^7 " .. msg)
        else
            TriggerClientEvent('chat:addMessage', source,
                { args = { "[HORROR]", msg } })
        end
    end
end, true)

RegisterCommand('horrorimmune', function(source, args)
    if source ~= 0 and not HasAdminPermission(source) then
        TriggerClientEvent('chat:addMessage', source, { color = { 255, 0, 0 }, args = { "[HORROR]", "Sin permisos" } })
        return
    end

    if not args[1] then
        local msg = "Uso: /horrorimmune [ID] - Activa/desactiva inmunidad"
        if source == 0 then print(msg) else TriggerClientEvent('chat:addMessage', source, { args = { "[HORROR]", msg } }) end
        return
    end

    local targetId = tonumber(args[1])
    if targetId and GetPlayerName(targetId) and playerStats[targetId] then
        playerStats[targetId].immuneToHorror = not playerStats[targetId].immuneToHorror
        TriggerClientEvent('horror:setImmunity', targetId, playerStats[targetId].immuneToHorror)

        local status = playerStats[targetId].immuneToHorror and "activada" or "desactivada"
        local msg = string.format("Inmunidad %s para %s", status, GetPlayerName(targetId))
        if source == 0 then
            print("^3[HORROR]^7 " .. msg)
        else
            TriggerClientEvent('chat:addMessage', source,
                { args = { "[HORROR]", msg } })
        end
    end
end, true)

RegisterCommand('horrortele', function(source, args)
    if source ~= 0 and not HasAdminPermission(source) then
        TriggerClientEvent('chat:addMessage', source, { color = { 255, 0, 0 }, args = { "[HORROR]", "Sin permisos" } })
        return
    end

    if not args[1] or not args[2] then
        local msg = "Uso: /horrortele [ID] [zona]\nZonas: cementerio, bosque, casa, tunel"
        if source == 0 then print(msg) else TriggerClientEvent('chat:addMessage', source, { args = { "[HORROR]", msg } }) end
        return
    end

    local targetId = tonumber(args[1])
    if IsPlayerWhitelisted(targetId) then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "[HORROR]", "No puedes teletransportar a jugadores en la WhiteList." }
        })
        return
    end

    local zoneName = args[2]:lower()

    local zones = {
        cementerio = vector3(-1705.0, -220.0, 58.0),
        bosque = vector3(-1470.0, 4975.0, 65.0),
        casa = vector3(1395.0, 1141.0, 114.0),
        tunel = vector3(-595.0, -1637.0, 20.0)
    }

    if targetId and GetPlayerName(targetId) and zones[zoneName] then
        local coords = zones[zoneName]
        SetEntityCoords(GetPlayerPed(targetId), coords.x, coords.y, coords.z)

        local msg = string.format("Teletransportado %s a zona: %s", GetPlayerName(targetId), zoneName)
        if source == 0 then
            print("^3[HORROR]^7 " .. msg)
        else
            TriggerClientEvent('chat:addMessage', source,
                { args = { "[HORROR]", msg } })
        end
    end
end, true)

RegisterCommand('horrorstats', function(source, args)
    if source == 0 then
        print("^3========== ESTADÍSTICAS DE HORROR ==========^7")
        for playerId, stats in pairs(playerStats) do
            local name = GetPlayerName(playerId)
            print(string.format("^2%s^7: Jumpscares: %d, Susurros: %d, Fantasmas: %d",
                name, stats.totalJumpscares, stats.totalWhispers, stats.totalGhosts))
        end
        print("^3==========================================^7")
    else
        if not args[1] then
            if playerStats[source] then
                local stats = playerStats[source]
                TriggerClientEvent('chat:addMessage', source, {
                    color = { 255, 100, 100 },
                    multiline = true,
                    args = { "[HORROR]", string.format("Tus estadísticas: Jumpscares: %d | Susurros: %d | Fantasmas: %d",
                        stats.totalJumpscares, stats.totalWhispers, stats.totalGhosts) }
                })
            end
        elseif HasAdminPermission(source) then
            local targetId = tonumber(args[1])
            if targetId and playerStats[targetId] then
                local stats = playerStats[targetId]
                TriggerClientEvent('chat:addMessage', source, {
                    color = { 255, 100, 100 },
                    args = { "[HORROR]", string.format("%s: J:%d S:%d F:%d",
                        GetPlayerName(targetId), stats.totalJumpscares, stats.totalWhispers, stats.totalGhosts) }
                })
            end
        end
    end
end, false)

RegisterCommand('horrorreset', function(source, args)
    if source ~= 0 and not HasAdminPermission(source) then
        TriggerClientEvent('chat:addMessage', source, { color = { 255, 0, 0 }, args = { "[HORROR]", "Sin permisos" } })
        return
    end

    if args[1] then
        local targetId = tonumber(args[1])
        if targetId and playerStats[targetId] then
            playerStats[targetId].totalJumpscares = 0
            playerStats[targetId].totalWhispers = 0
            playerStats[targetId].totalGhosts = 0
            playerStats[targetId].timeInZones = 0

            local msg = "Stats reseteadas para " .. GetPlayerName(targetId)
            if source == 0 then
                print("^2[HORROR]^7 " .. msg)
            else
                TriggerClientEvent('chat:addMessage', source,
                    { args = { "[HORROR]", msg } })
            end
        end
    else
        playerStats = {}
        local msg = "Todas las estadísticas reseteadas"
        if source == 0 then
            print("^2[HORROR]^7 " .. msg)
        else
            TriggerClientEvent('chat:addMessage', source,
                { args = { "[HORROR]", msg } })
        end
    end
end, true)

RegisterCommand('horrorhelp', function(source, args)
    if source ~= 0 and not HasAdminPermission(source) then
        TriggerClientEvent('chat:addMessage', source, { color = { 255, 0, 0 }, args = { "[HORROR]", "Sin permisos" } })
        return
    end

    local commands = {
        "^3=== COMANDOS DE ADMIN HORROR ===^7",
        "/horrorevent [start/stop/status] - Control evento global",
        "/horrorjump [ID/all] - Jumpscare",
        "/horrorwhisper [ID/all] - Susurros",
        "/horrordistort [ID/all] - Distorsión visual",
        "/horrorghost [ID/all] - Spawn fantasma",
        "/horrorenv [ID/all] - Efectos ambientales",
        "/horrorcombo [ID] - Todos los efectos",
        "/horrorimmune [ID] - Toggle inmunidad",
        "/horrortele [ID] [zona] - TP a zona",
        "/horrorstats [ID] - Ver estadísticas",
        "/horrorreset [ID] - Resetear estadísticas",
        "/horrorrandom [on/off/now/players] - Control jumpscares random",
        "^3===========================^7"
    }

    if source == 0 then
        for _, cmd in ipairs(commands) do
            print(cmd)
        end
    else
        for _, cmd in ipairs(commands) do
            TriggerClientEvent('chat:addMessage', source, { args = { "", cmd } })
        end
    end
end, true)

exports('GetPlayerStats', function(playerId)
    return playerStats[playerId]
end)

exports('GetAllStats', function()
    return playerStats
end)

exports('IsGlobalEventActive', function()
    return globalEventsActive
end)

exports('SetGlobalEvent', function(active)
    globalEventsActive = active
    if active then
        TriggerClientEvent('horror:globalEventStart', -1)
    else
        TriggerClientEvent('horror:globalEventStop', -1)
    end
end)

-- CreateThread(function()
--     print("^2========================================^7")
--     print("^2  HORROR SYSTEM - SERVER ADMIN CARGADO^7")
--     print("^2========================================^7")
--     print("^3Comandos disponibles:^7")
--     print("^3- /horrorhelp^7 - Lista todos los comandos")
--     print("^3- /horrorevent^7 - Eventos globales")
--     print("^3Debug:^7 " .. (Config.DebugMode and "^2Activado^7" or "^1Desactivado^7"))
--     print("^2========================================^7")
-- end)

local function GetEligiblePlayers()
    local players = GetPlayers()
    local eligible = {}

    for _, playerId in ipairs(players) do
        playerId = tonumber(playerId)
        local canTarget = true

        if IsPlayerWhitelisted(playerId) then
            canTarget = false
        end

        if Config.RandomPlayerJumpscares.excludeAdmins and HasAdminPermission(playerId) then
            canTarget = false
        end

        if Config.RandomPlayerJumpscares.excludeImmune and playerStats[playerId] and playerStats[playerId].immuneToHorror then
            canTarget = false
        end

        if Config.RandomPlayerJumpscares.excludeInVehicle then
            local ped = GetPlayerPed(playerId)
            if DoesEntityExist(ped) and IsPedInAnyVehicle(ped, false) then
                canTarget = false
            end
        end

        if playerId == lastRandomTarget then
            canTarget = false
        end

        if canTarget then
            table.insert(eligible, playerId)
        end
    end

    return eligible
end

local function SelectRandomPlayer()
    local eligiblePlayers = GetEligiblePlayers()

    if #eligiblePlayers == 0 then
        if Config.DebugMode then
            print("^3[HORROR]^7 No hay jugadores elegibles para jumpscare random")
        end
        return nil
    end

    local randomIndex = math.random(1, #eligiblePlayers)
    local selectedPlayer = eligiblePlayers[randomIndex]

    return selectedPlayer
end

local function ExecuteRandomJumpscare()
    if not Config.RandomPlayerJumpscares.enabled then
        return
    end

    if Config.RandomPlayerJumpscares.onlyAtNight then
        local players = GetPlayers()
        if #players == 0 then return end

        local anyPlayer = tonumber(players[1])
        local hour = lib.callback.await('horror:getClientClockHour', anyPlayer)

        if not hour then
            if Config.DebugMode then
                print("^3[HORROR]^7 No se pudo obtener la hora del cliente")
            end
            return
        end

        local startHour = Config.NightHours.start
        local endHour = Config.NightHours.finish

        local isNight
        if startHour > endHour then
            isNight = hour >= startHour or hour < endHour
        else
            isNight = hour >= startHour and hour < endHour
        end

        if not isNight then
            if Config.DebugMode then
                print(("^3[HORROR]^7 Jumpscare random cancelado: no es de noche (hora actual: %d)"):format(hour))
            end
            return
        end
    end

    local targetPlayer = SelectRandomPlayer()

    if not targetPlayer then
        if Config.DebugMode then
            print("^3[HORROR]^7 No se pudo encontrar jugador para jumpscare random")
        end
        return
    end

    local totalWeight = 0
    for _, jumpType in ipairs(Config.RandomPlayerJumpscares.jumpscareTypes) do
        totalWeight = totalWeight + (jumpType.weight or 1)
    end

    local randomWeight = math.random() * totalWeight
    local currentWeight = 0
    local selectedType = Config.RandomPlayerJumpscares.jumpscareTypes[1].id

    for _, jumpType in ipairs(Config.RandomPlayerJumpscares.jumpscareTypes) do
        currentWeight = currentWeight + (jumpType.weight or 1)
        if randomWeight <= currentWeight then
            selectedType = jumpType.id
            break
        end
    end

    TriggerClientEvent('horror:adminForce', targetPlayer, 'jumpscare')

    if playerStats[targetPlayer] then
        playerStats[targetPlayer].totalJumpscares = (playerStats[targetPlayer].totalJumpscares or 0) + 1
        playerStats[targetPlayer].lastRandomJumpscare = os.time()
    end

    lastRandomTarget = targetPlayer

    if Config.DebugMode then
        print(("^1[HORROR RANDOM]^7 Jumpscare enviado a %s (Tipo: %s)"):format(GetPlayerName(targetPlayer), selectedType))
    end
end

local function ScheduleNextRandomJumpscare()
    if not Config.RandomPlayerJumpscares.enabled then
        return
    end

    local minTime = Config.RandomPlayerJumpscares.minTimeBetween
    local maxTime = Config.RandomPlayerJumpscares.maxTimeBetween

    nextRandomJumpscare = GetGameTimer() + math.random(minTime, maxTime)

    if Config.DebugMode then
        local nextIn = math.floor((nextRandomJumpscare - GetGameTimer()) / 60000)
        print(("^3[HORROR RANDOM]^7 Próximo jumpscare programado en: %d minutos"):format(nextIn))
    end
end

CreateThread(function()
    Wait(10000)

    if Config.RandomPlayerJumpscares.enabled then
        print("^2[HORROR]^7 Sistema de jumpscares random inicializado")
        ScheduleNextRandomJumpscare()
    end

    while true do
        Wait(10000)

        if Config.RandomPlayerJumpscares.enabled and GetGameTimer() >= nextRandomJumpscare then
            ExecuteRandomJumpscare()
            ScheduleNextRandomJumpscare()
        end
    end
end)

RegisterCommand('horrorrandom', function(source, args)
    if source ~= 0 and not HasAdminPermission(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "[HORROR]", "No tienes permisos para este comando" }
        })
        return
    end

    if not args[1] then
        local status = Config.RandomPlayerJumpscares.enabled and "^2ACTIVADO^7" or "^1DESACTIVADO^7"
        local timeUntilNext = math.max(0, nextRandomJumpscare - GetGameTimer())
        local minutes = math.floor(timeUntilNext / 60000)
        local seconds = math.floor((timeUntilNext % 60000) / 1000)

        local msg = string.format(
            "Estado: %s\nPróximo en: %d:%02d\nJugadores elegibles: %d",
            status, minutes, seconds, #GetEligiblePlayers()
        )

        if source == 0 then
            print("^3[HORROR RANDOM]^7 " .. msg)
        else
            TriggerClientEvent('chat:addMessage', source, {
                color = { 255, 100, 100 },
                multiline = true,
                args = { "[HORROR RANDOM]", msg }
            })
        end
        return
    end

    local action = args[1]:lower()

    if action == "on" then
        Config.RandomPlayerJumpscares.enabled = true
        ScheduleNextRandomJumpscare()
        local msg = "Sistema de jumpscares random ^2activado^7"
        if source == 0 then
            print("^2[HORROR]^7 " .. msg)
        else
            TriggerClientEvent('chat:addMessage', source, { args = { "[HORROR]", msg } })
        end
    elseif action == "off" then
        Config.RandomPlayerJumpscares.enabled = false
        local msg = "Sistema de jumpscares random ^1desactivado^7"
        if source == 0 then
            print("^1[HORROR]^7 " .. msg)
        else
            TriggerClientEvent('chat:addMessage', source, { args = { "[HORROR]", msg } })
        end
    elseif action == "now" then
        ExecuteRandomJumpscare()
        ScheduleNextRandomJumpscare()
        local msg = "Jumpscare random ejecutado manualmente"
        if source == 0 then
            print("^2[HORROR]^7 " .. msg)
        else
            TriggerClientEvent('chat:addMessage', source, { args = { "[HORROR]", msg } })
        end
    elseif action == "players" then
        local eligible = GetEligiblePlayers()
        local msg = string.format("Jugadores elegibles (%d): ", #eligible)

        for i, playerId in ipairs(eligible) do
            msg = msg .. GetPlayerName(playerId)
            if i < #eligible then
                msg = msg .. ", "
            end
        end

        if source == 0 then
            print("^3[HORROR RANDOM]^7 " .. msg)
        else
            TriggerClientEvent('chat:addMessage', source, {
                multiline = true,
                args = { "[HORROR RANDOM]", msg }
            })
        end
    else
        local msg = "Uso: /horrorrandom [on/off/now/players]"
        if source == 0 then
            print(msg)
        else
            TriggerClientEvent('chat:addMessage', source, { args = { "[HORROR]", msg } })
        end
    end
end, true)

exports('GetRandomJumpscareStatus', function()
    return {
        enabled = Config.RandomPlayerJumpscares.enabled,
        nextJumpscare = nextRandomJumpscare,
        eligiblePlayers = #GetEligiblePlayers(),
        lastTarget = lastRandomTarget and GetPlayerName(lastRandomTarget) or "Ninguno"
    }
end)

exports('ForceRandomJumpscare', function()
    ExecuteRandomJumpscare()
    ScheduleNextRandomJumpscare()
    return true
end)

exports('GetEligiblePlayers', function()
    return GetEligiblePlayers()
end)
