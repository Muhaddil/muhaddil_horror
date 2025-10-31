local activePumpkins = {}
local nearbyPumpkins = {}
local menuOpen = false
local collectingPumpkin = false

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

local function DrawText3D(coords, text)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)

    if onScreen then
        SetTextScale(Config.PumpkinHunt.text3D.scale, Config.PumpkinHunt.text3D.scale)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(true)
        AddTextComponentString(text)
        DrawText(x, y)

        local factor = (string.len(text)) / 370
        DrawRect(x, y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 75)
    end
end

local function ShowNotification(message, type)
    if lib and lib.notify then
        local oxType = "info"
        if type == "success" then
            oxType = "success"
        elseif type == "error" then
            oxType = "error"
        end
        lib.notify({
            title = "Pumpkin Hunt",
            description = message,
            type = oxType,
            duration = 5000
        })
    else
        if type == "success" then
            SetNotificationTextEntry("STRING")
            AddTextComponentString(message)
            DrawNotification(false, false)
        elseif type == "error" then
            SetNotificationTextEntry("STRING")
            AddTextComponentString("~r~" .. message)
            DrawNotification(false, false)
        else
            SetNotificationTextEntry("STRING")
            AddTextComponentString(message)
            DrawNotification(false, false)
        end
    end
end


local function PlayCollectEffects(coords)
    if Config.PumpkinHunt.collectEffects.particle then
        RequestNamedPtfxAsset(Config.PumpkinHunt.collectEffects.particleDict)
        while not HasNamedPtfxAssetLoaded(Config.PumpkinHunt.collectEffects.particleDict) do
            Wait(0)
        end

        UseParticleFxAssetNextCall(Config.PumpkinHunt.collectEffects.particleDict)
        StartParticleFxNonLoopedAtCoord(
            Config.PumpkinHunt.collectEffects.particleName,
            coords.x, coords.y, coords.z,
            0.0, 0.0, 0.0,
            1.0,
            false, false, false
        )
    end

    if Config.PumpkinHunt.collectEffects.sound then
        PlaySoundFrontend(
            -1,
            Config.PumpkinHunt.collectEffects.soundName,
            Config.PumpkinHunt.collectEffects.soundSet,
            true
        )
    end

    if Config.PumpkinHunt.collectEffects.screenEffect then
        StartScreenEffect(
            Config.PumpkinHunt.collectEffects.screenEffectName,
            0,
            false
        )

        SetTimeout(Config.PumpkinHunt.collectEffects.screenEffectDuration, function()
            StopScreenEffect(Config.PumpkinHunt.collectEffects.screenEffectName)
        end)
    end
end

RegisterNetEvent('pumpkin:spawn')
AddEventHandler('pumpkin:spawn', function(pumpkinId, position, model)
    activePumpkins[pumpkinId] = {
        id = pumpkinId,
        position = position,
        model = model,
        object = nil
    }

    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end

    local obj = CreateObject(model, position.x, position.y, position.z, false, false, false)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, false, false)

    activePumpkins[pumpkinId].object = obj
    local objCoords = GetEntityCoords(obj)
    activePumpkins[pumpkinId].position = objCoords

    if Config.DebugMode then
        print(string.format("^2[PUMPKIN]^7 Calabaza #%d spawneada en cliente", pumpkinId))
    end
end)

RegisterNetEvent('pumpkin:remove')
AddEventHandler('pumpkin:remove', function(pumpkinId)
    local pumpkin = activePumpkins[pumpkinId]
    if pumpkin and pumpkin.object and DoesEntityExist(pumpkin.object) then
        NetworkRequestControlOfEntity(pumpkin.object)
        SetEntityAsMissionEntity(pumpkin.object, true, true)
        DeleteEntity(pumpkin.object)
    end
    activePumpkins[pumpkinId] = nil
end)

RegisterNetEvent('pumpkin:syncAll')
AddEventHandler('pumpkin:syncAll', function(pumpkins)
    for id, pumpkin in pairs(activePumpkins) do
        if DoesEntityExist(pumpkin.object) then
            DeleteObject(pumpkin.object)
        end
    end
    activePumpkins = {}

    for id, pumpkinData in pairs(pumpkins) do
        TriggerEvent('pumpkin:spawn', id, pumpkinData.position, pumpkinData.model)
    end
end)

RegisterNetEvent('pumpkin:clearAll')
AddEventHandler('pumpkin:clearAll', function()
    for id, pumpkin in pairs(activePumpkins) do
        if DoesEntityExist(pumpkin.object) then
            DeleteObject(pumpkin.object)
        end
    end
    activePumpkins = {}
end)

CreateThread(function()
    if not Config.PumpkinHunt.enabled then return end

    local notifiedPumpkins = {}

    while true do
        local sleep = 500
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        nearbyPumpkins = {}

        for id, pumpkin in pairs(activePumpkins) do
            local distance = #(playerCoords - pumpkin.position)

            if distance <= Config.PumpkinHunt.showDistance then
                sleep = 0
                table.insert(nearbyPumpkins, {
                    id = id,
                    distance = distance,
                    position = pumpkin.position,
                    object = pumpkin.object
                })

                if distance <= Config.PumpkinHunt.warningNotificationDistance and not notifiedPumpkins[id] then
                    lib.notify({
                        title = "¡Cuidado!",
                        description = "Hay una calabaza cerca.",
                        type = "info"
                    })
                    notifiedPumpkins[id] = true
                end

                if distance > Config.PumpkinHunt.notificationResetDistance and notifiedPumpkins[id] then
                    notifiedPumpkins[id] = nil
                end
            end
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    if not Config.PumpkinHunt.enabled then return end

    local wasInVehicle = false
    local lastVehicleNotification = 0
    local notificationCooldown = 5000

    while true do
        local sleep = 500

        if #nearbyPumpkins > 0 then
            sleep = 0
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local isInVehicle = IsPedInAnyVehicle(playerPed, false)
            local currentTime = GetGameTimer()
            local canInteract = false

            for _, pumpkin in ipairs(nearbyPumpkins) do
                DrawMarker(
                    Config.PumpkinHunt.marker.type,
                    pumpkin.position.x,
                    pumpkin.position.y,
                    pumpkin.position.z + 1.0,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    Config.PumpkinHunt.marker.scale.x,
                    Config.PumpkinHunt.marker.scale.y,
                    Config.PumpkinHunt.marker.scale.z,
                    Config.PumpkinHunt.marker.color.r,
                    Config.PumpkinHunt.marker.color.g,
                    Config.PumpkinHunt.marker.color.b,
                    Config.PumpkinHunt.marker.color.a,
                    Config.PumpkinHunt.marker.bobUpAndDown,
                    Config.PumpkinHunt.marker.faceCamera,
                    2,
                    Config.PumpkinHunt.marker.rotate,
                    nil,
                    nil,
                    Config.PumpkinHunt.marker.drawOnEnts
                )

                if Config.PumpkinHunt.text3D.enabled and pumpkin.distance <= Config.PumpkinHunt.text3D.distance then
                    DrawText3D(pumpkin.position, Config.PumpkinHunt.text3D.text)
                end

                if pumpkin.distance <= Config.PumpkinHunt.interactionDistance then
                    canInteract = true

                    if not isInVehicle then
                        if IsControlJustPressed(0, 38) and not collectingPumpkin then -- E key
                            collectingPumpkin = true
                            CollectPumpkin(pumpkin.id, pumpkin.position)
                        end
                    end
                end
            end

            if isInVehicle and canInteract then
                if (not wasInVehicle or IsControlJustPressed(0, 38)) and
                    (currentTime - lastVehicleNotification) > notificationCooldown then
                    ShowNotification("No puedes recoger calabazas desde un vehículo", "error")
                    lastVehicleNotification = currentTime
                end
            end

            wasInVehicle = isInVehicle
        else
            wasInVehicle = false
        end

        Wait(sleep)
    end
end)

function CollectPumpkin(pumpkinId, position)
    local playerPed = PlayerPedId()

    if Config.PumpkinHunt.animations.collect then
        RequestAnimDict(Config.PumpkinHunt.animations.collect.dict)
        while not HasAnimDictLoaded(Config.PumpkinHunt.animations.collect.dict) do
            Wait(0)
        end

        TaskPlayAnim(
            playerPed,
            Config.PumpkinHunt.animations.collect.dict,
            Config.PumpkinHunt.animations.collect.anim,
            8.0, -8.0,
            Config.PumpkinHunt.animations.collect.duration,
            Config.PumpkinHunt.animations.collect.flag,
            0,
            false, false, false
        )

        Wait(Config.PumpkinHunt.animations.collect.duration)
    end

    lib.callback('pumpkin:collect', false, function(result)
        collectingPumpkin = false

        if result.success then
            PlayCollectEffects(position)

            ShowNotification(result.message, "success")

            if result.newRewards then
                ShowNotification("🎁 " .. result.rewardName .. " desbloqueado!", "success")
            end
        else
            ShowNotification(result.message, "error")
        end
    end, pumpkinId)
end

RegisterCommand(Config.PumpkinHunt.menuCommand, function()
    if not Config.PumpkinHunt.enabled then
        ShowNotification("El sistema de calabazas está desactivado", "error")
        return
    end

    OpenPumpkinMenu()
end, false)

if Config.PumpkinHunt.menuKey and Config.PumpkinHunt.menuKey ~= false then
    RegisterCommand('+openPumpkinMenu', function()
        if not Config.PumpkinHunt.enabled then return end
        OpenPumpkinMenu()
    end, false)

    RegisterCommand('-openPumpkinMenu', function() end, false)

    RegisterKeyMapping('+openPumpkinMenu', 'Abrir menú de calabazas', 'keyboard', Config.PumpkinHunt.menuKey)
end

function OpenPumpkinMenu()
    if menuOpen then return end

    lib.callback('pumpkin:openMenu', false, function(result)
        if not result.success then
            ShowNotification(result.message, "error")
            return
        end

        menuOpen = true
        SetNuiFocus(true, true)

        SendNUIMessage({
            type = 'openPumpkinMenu',
            data = result
        })
    end)
end

-- Callbacks NUI
RegisterNUICallback('closePumpkinMenu', function(data, cb)
    menuOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('claimPumpkinReward', function(data, cb)
    lib.callback('pumpkin:claimReward', false, function(result)
        if result.success then
            ShowNotification(result.message, "success")

            SendNUIMessage({
                type = 'updatePumpkinStats',
                data = {
                    player = result.playerData,
                    rewards = result.rewards,
                    leaderboard = result.leaderboard
                }
            })

            SendNUIMessage({
                type = 'updatePumpkinLeaderboard',
                data = result.leaderboard
            })
        else
            ShowNotification(result.message, "error")
        end
    end, data.pumpkinsRequired)
    cb('ok')
end)


RegisterNetEvent('pumpkin:updateLeaderboard')
AddEventHandler('pumpkin:updateLeaderboard', function(leaderboard)
    if menuOpen then
        SendNUIMessage({
            type = 'updateLeaderboard',
            data = leaderboard
        })
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for id, pumpkin in pairs(activePumpkins) do
            if DoesEntityExist(pumpkin.object) then
                DeleteObject(pumpkin.object)
            end
        end

        if menuOpen then
            SetNuiFocus(false, false)
        end
    end
end)

exports('GetActivePumpkins', function()
    return activePumpkins
end)

exports('GetNearbyPumpkins', function()
    return nearbyPumpkins
end)

exports('OpenMenu', OpenPumpkinMenu)

lib.callback.register('pumpkin:getGroundZ', function(coords)
    if not coords then
        print("^1[ERROR]^7 coords es nil en pumpkin:getGroundZ")
        return vector3(0, 0, 0)
    end

    local x, y, z = coords.x, coords.y, coords.z or 500.0

    if not x or not y then
        print("^1[ERROR]^7 Coordenadas inválidas")
        return vector3(0, 0, z)
    end

    local function isValidZ(zValue)
        return zValue and zValue ~= 0.0 and zValue > -100.0 and zValue < 3000.0
    end

    local function isReasonableZ(zValue, referenceZ, maxDiff)
        maxDiff = maxDiff or 150
        return math.abs(zValue - referenceZ) <= maxDiff
    end

    if Config.DebugGroundCheck then
        print(string.format("^6[INICIO]^7 Buscando suelo en (%.2f, %.2f, %.2f)", x, y, z))
    end

    local loadRadii = { 0, 2, 5, 8, 10, 15, 20, 25, 30, 40, 50, 60, 75, 90, 100, 125, 150, 175, 200, 250, 300 }
    local loadHeights = {
        z - 200, z - 150, z - 100, z - 50, z, z + 25, z + 50, z + 75, z + 100,
        z + 150, z + 200, z + 300, z + 500,
        -50, 0, 50, 100, 150, 200, 300, 500, 800, 1000, 1500, 2000
    }

    for _, radius in ipairs(loadRadii) do
        if radius == 0 then
            for _, height in ipairs(loadHeights) do
                RequestAdditionalCollisionAtCoord(x, y, height)
            end
        else
            local numAngles = math.min(16, math.max(8, math.floor(360 / (radius / 5))))
            for angle = 0, 360, 360 / numAngles do
                local rad = math.rad(angle)
                local offsetX = math.cos(rad) * radius
                local offsetY = math.sin(rad) * radius
                for _, height in ipairs(loadHeights) do
                    RequestAdditionalCollisionAtCoord(x + offsetX, y + offsetY, height)
                end
            end
        end
    end

    for iteration = 1, 12 do
        local waitTime = iteration <= 4 and 200 or iteration <= 8 and 150 or 100
        Wait(waitTime)

        local focusRadii = iteration <= 4 and { 0, 10, 25, 50 } or iteration <= 8 and { 75, 100, 150 } or { 200, 250 }
        for _, radius in ipairs(focusRadii) do
            for angle = 0, 360, 45 do
                local rad = math.rad(angle)
                local offsetX = math.cos(rad) * radius
                local offsetY = math.sin(rad) * radius
                for _, heightOffset in ipairs({ -100, 0, 50, 100, 200 }) do
                    RequestAdditionalCollisionAtCoord(x + offsetX, y + offsetY, z + heightOffset)
                end
            end
        end
    end

    local groundZ = nil
    local candidateZs = {}
    local rayConfigs = {
        { start = z + 500, endZ = z - 300, flags = 1,          name = "local_terrain" },
        { start = z + 300, endZ = z - 200, flags = -1,         name = "local_all" },
        { start = z + 200, endZ = z - 150, flags = 17,         name = "local_terrain+veh" },

        { start = 2500,    endZ = -200,    flags = 1,          name = "terrain_max" },
        { start = 2000,    endZ = -150,    flags = 1,          name = "terrain_high" },
        { start = 1500,    endZ = -100,    flags = -1,         name = "all_high" },
        { start = 1000,    endZ = -100,    flags = -1,         name = "all_mid" },
        { start = 800,     endZ = -100,    flags = 17,         name = "terrain+veh_mid" },
        { start = 500,     endZ = -50,     flags = 1,          name = "terrain_low" },
        { start = 300,     endZ = -50,     flags = -1,         name = "all_low" },

        { start = 1500,    endZ = -200,    flags = 4294967295, name = "everything_high" },
        { start = 1000,    endZ = -150,    flags = 4294967295, name = "everything_mid" },
        { start = 500,     endZ = -100,    flags = 4294967295, name = "everything_low" },
    }

    local directHeights = {}

    for offset = -200, 500, 5 do
        table.insert(directHeights, z + offset)
    end

    for h = 2500, -150, -10 do
        table.insert(directHeights, h)
    end

    local uniqueHeights = {}
    local seen = {}
    for _, h in ipairs(directHeights) do
        local rounded = math.floor(h + 0.5)
        if not seen[rounded] then
            seen[rounded] = true
            table.insert(uniqueHeights, h)
        end
    end

    table.sort(uniqueHeights, function(a, b)
        return math.abs(a - z) < math.abs(b - z)
    end)

    for _, startHeight in ipairs(uniqueHeights) do
        local directOk, directZ = GetGroundZFor_3dCoord(x, y, startHeight, false)
        if directOk and isValidZ(directZ) then
            if isReasonableZ(directZ, z, 150) then
                groundZ = directZ
                if Config.DebugGroundCheck then
                    print(string.format("^2[DIRECTO]^7 Suelo encontrado desde altura %.1f -> Z=%.3f", startHeight,
                        groundZ))
                end
                break
            else
                table.insert(candidateZs,
                    { z = directZ, method = "directo", detail = string.format("altura %.1f", startHeight) })
            end
        end
    end

    if not groundZ then
        local radialPoints = {}

        for radius = 1, 150 do
            local angleStep = math.max(1, math.floor(180 / math.max(1, radius)))
            for angle = 0, 360, angleStep do
                local rad = math.rad(angle)
                local offsetX = math.cos(rad) * radius
                local offsetY = math.sin(rad) * radius
                table.insert(radialPoints, { x = offsetX, y = offsetY, dist = radius })
            end
        end

        table.sort(radialPoints, function(a, b) return a.dist < b.dist end)

        for _, point in ipairs(radialPoints) do
            local testX = x + point.x
            local testY = y + point.y

            local testHeights = {
                z, z + 25, z + 50, z + 100, z + 150, z + 200, z + 300,
                z - 25, z - 50, z - 100,
                500, 1000, 1500, 300, 100, 50, 0
            }

            for _, testHeight in ipairs(testHeights) do
                local nearOk, nearZ = GetGroundZFor_3dCoord(testX, testY, testHeight, false)
                if nearOk and isValidZ(nearZ) then
                    if isReasonableZ(nearZ, z, 150) then
                        groundZ = nearZ
                        if Config.DebugGroundCheck then
                            print(string.format("^5[RADIAL]^7 Suelo a %.1fm offset(%.0f,%.0f) -> Z=%.3f",
                                point.dist, point.x, point.y, groundZ))
                        end
                        break
                    else
                        table.insert(candidateZs,
                            { z = nearZ, method = "radial", detail = string.format("%.1fm", point.dist) })
                    end
                end
            end

            if groundZ then break end
        end
    end

    if not groundZ then
        for _, cfg in ipairs(rayConfigs) do
            local rayHandle = StartShapeTestRay(x, y, cfg.start, x, y, cfg.endZ, cfg.flags, 0, 7)
            Wait(0)
            local _, hit, hitCoords = GetShapeTestResult(rayHandle)

            if hit and hitCoords and isValidZ(hitCoords.z) then
                local verifyOk, verifyZ = GetGroundZFor_3dCoord(x, y, hitCoords.z + 2.0, false)
                local finalZ = (verifyOk and isValidZ(verifyZ)) and verifyZ or hitCoords.z

                if isReasonableZ(finalZ, z, 150) then
                    groundZ = finalZ
                    if Config.DebugGroundCheck then
                        print(string.format("^3[RAYCAST]^7 Suelo (%s) -> Z=%.3f", cfg.name, groundZ))
                    end
                    break
                else
                    table.insert(candidateZs, { z = finalZ, method = "raycast", detail = cfg.name })
                end
            end
        end

        if not groundZ then
            local rayRadii = {}
            for r = 2, 100, 3 do
                for angle = 0, 360, 30 do
                    local rad = math.rad(angle)
                    table.insert(rayRadii, { x = math.cos(rad) * r, y = math.sin(rad) * r, dist = r })
                end
            end

            for _, offset in ipairs(rayRadii) do
                for _, cfg in ipairs(rayConfigs) do
                    local rayHandle = StartShapeTestRay(
                        x + offset.x, y + offset.y, cfg.start,
                        x + offset.x, y + offset.y, cfg.endZ,
                        cfg.flags, 0, 7
                    )
                    Wait(0)
                    local _, hit, hitCoords = GetShapeTestResult(rayHandle)

                    if hit and hitCoords and isValidZ(hitCoords.z) then
                        if isReasonableZ(hitCoords.z, z, 150) then
                            groundZ = hitCoords.z
                            if Config.DebugGroundCheck then
                                print(string.format("^3[RAYCAST]^7 Suelo (%s) offset(%.0f,%.0f) -> Z=%.3f",
                                    cfg.name, offset.x, offset.y, groundZ))
                            end
                            break
                        else
                            table.insert(candidateZs,
                                { z = hitCoords.z, method = "raycast", detail = string.format("%s offset %.0f", cfg.name,
                                    offset.dist) })
                        end
                    end
                end
                if groundZ then break end
            end
        end
    end

    if not groundZ then
        if Config.DebugGroundCheck then
            print(string.format("^3[BÚSQUEDA EXPANDIDA]^7 No se encontró suelo cercano, buscando sin límites..."))
        end

        for _, startHeight in ipairs(uniqueHeights) do
            local directOk, directZ = GetGroundZFor_3dCoord(x, y, startHeight, false)
            if directOk and isValidZ(directZ) then
                groundZ = directZ
                if Config.DebugGroundCheck then
                    print(string.format("^3[EXPANDIDO]^7 Suelo directo desde altura %.1f -> Z=%.3f (diff: %.1f)",
                        startHeight, groundZ, math.abs(groundZ - z)))
                end
                break
            end
        end

        if not groundZ then
            for radius = 1, 200, 3 do
                local found = false
                for angle = 0, 360, 20 do
                    local rad = math.rad(angle)
                    local testX = x + math.cos(rad) * radius
                    local testY = y + math.sin(rad) * radius

                    for _, testHeight in ipairs({ z, z + 100, z + 200, 500, 1000, 300, 100, 0 }) do
                        local nearOk, nearZ = GetGroundZFor_3dCoord(testX, testY, testHeight, false)
                        if nearOk and isValidZ(nearZ) then
                            groundZ = nearZ
                            if Config.DebugGroundCheck then
                                print(string.format("^3[EXPANDIDO]^7 Suelo radial a %.1fm -> Z=%.3f (diff: %.1f)",
                                    radius, groundZ, math.abs(groundZ - z)))
                            end
                            found = true
                            break
                        end
                    end
                    if found then break end
                end
                if found then break end
            end
        end

        if not groundZ then
            for _, cfg in ipairs(rayConfigs) do
                local rayHandle = StartShapeTestRay(x, y, cfg.start, x, y, cfg.endZ, cfg.flags, 0, 7)
                Wait(0)
                local _, hit, hitCoords = GetShapeTestResult(rayHandle)

                if hit and hitCoords and isValidZ(hitCoords.z) then
                    groundZ = hitCoords.z
                    if Config.DebugGroundCheck then
                        print(string.format("^3[EXPANDIDO]^7 Raycast (%s) -> Z=%.3f (diff: %.1f)",
                            cfg.name, groundZ, math.abs(groundZ - z)))
                    end
                    break
                end
            end
        end

        if not groundZ then
            for r = 5, 150, 10 do
                for angle = 0, 360, 45 do
                    local rad = math.rad(angle)
                    local offsetX = math.cos(rad) * r
                    local offsetY = math.sin(rad) * r

                    for _, cfg in ipairs({ { start = 1500, endZ = -200, flags = -1 }, { start = 1000, endZ = -100, flags = 1 } }) do
                        local rayHandle = StartShapeTestRay(
                            x + offsetX, y + offsetY, cfg.start,
                            x + offsetX, y + offsetY, cfg.endZ,
                            cfg.flags, 0, 7
                        )
                        Wait(0)
                        local _, hit, hitCoords = GetShapeTestResult(rayHandle)

                        if hit and hitCoords and isValidZ(hitCoords.z) then
                            groundZ = hitCoords.z
                            if Config.DebugGroundCheck then
                                print(string.format("^3[EXPANDIDO]^7 Raycast radial %.1fm -> Z=%.3f (diff: %.1f)",
                                    r, groundZ, math.abs(groundZ - z)))
                            end
                            break
                        end
                    end
                    if groundZ then break end
                end
                if groundZ then break end
            end
        end
    end

    if not groundZ and #candidateZs > 0 then
        table.sort(candidateZs, function(a, b)
            return math.abs(a.z - z) < math.abs(b.z - z)
        end)

        groundZ = candidateZs[1].z
        if Config.DebugGroundCheck then
            print(string.format("^3[CANDIDATO]^7 Usando mejor candidato: %s %s -> Z=%.3f (diff: %.1f)",
                candidateZs[1].method, candidateZs[1].detail, groundZ, math.abs(groundZ - z)))
        end
    end

    if groundZ then
        local bestZ = groundZ
        local bestDiff = math.abs(groundZ - z)

        for offset = -20.0, 20.0, 0.2 do
            local testZ = groundZ + offset
            local ok, zFound = GetGroundZFor_3dCoord(x, y, testZ, false)
            if ok and isValidZ(zFound) then
                local diff = math.abs(zFound - z)
                if diff < bestDiff then
                    bestZ = zFound
                    bestDiff = diff
                end
            end
        end

        if math.abs(bestZ - groundZ) > 0.1 then
            if Config.DebugGroundCheck then
                print(string.format("^6[REFINADO]^7 Z refinado: %.3f -> %.3f (mejora: %.3f)",
                    groundZ, bestZ, math.abs(groundZ - bestZ)))
            end
            groundZ = bestZ
        end
    end

    local onWater, waterZ = GetWaterHeight(x, y, z)
    if onWater and waterZ and waterZ > -100.0 and waterZ < 1000.0 then
        if not groundZ or (waterZ > groundZ + 0.5) then
            if Config.DebugGroundCheck then
                print(string.format("^6[AGUA]^7 En (%.2f, %.2f) -> waterZ=%.3f", x, y, waterZ))
            end
            return vector3(x, y, waterZ + 0.5)
        end
    end

    if not groundZ or not isValidZ(groundZ) then
        if z > -50 and z < 2000 then
            local rayHandle = StartShapeTestRay(x, y, z + 50, x, y, z - 50, -1, 0, 7)
            Wait(0)
            local _, hit, hitCoords = GetShapeTestResult(rayHandle)

            if hit and hitCoords then
                if Config.DebugGroundCheck then
                    print(string.format("^3[FALLBACK-VERIFICADO]^7 Usando Z verificado %.2f en (%.2f, %.2f)",
                        hitCoords.z, x, y))
                end
                return vector3(x, y, hitCoords.z + 0.1)
            end

            if Config.DebugGroundCheck then
                print(string.format("^3[FALLBACK]^7 Usando Z original %.2f en (%.2f, %.2f)", z, x, y))
            end
            return vector3(x, y, z + 0.1)
        end

        local safeZ = 50.0
        if Config.DebugGroundCheck then
            print(string.format("^1[ERROR]^7 Sin suelo válido en (%.2f, %.2f). Usando Z seguro: %.1f", x, y, safeZ))
        end
        return vector3(x, y, safeZ)
    end

    if Config.DebugGroundCheck then
        local diff = math.abs(groundZ - z)
        local status = diff > 100 and "^1[GRAN DIFF]^7" or diff > 20 and "^3[DIFF]^7" or "^2[OK]^7"
        print(string.format("%s Suelo en (%.2f, %.2f) -> Z=%.3f (orig: %.2f) diff: %.1f",
            status, x, y, groundZ, z, diff))
    end

    return vector3(x, y, groundZ + 0.1)
end)