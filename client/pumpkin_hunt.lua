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

    if Config.DebugMode then
        print(string.format("^2[PUMPKIN]^7 Calabaza #%d spawneada en cliente", pumpkinId))
    end
end)

RegisterNetEvent('pumpkin:remove')
AddEventHandler('pumpkin:remove', function(pumpkinId)
    if activePumpkins[pumpkinId] then
        if DoesEntityExist(activePumpkins[pumpkinId].object) then
            DeleteObject(activePumpkins[pumpkinId].object)
        end
        activePumpkins[pumpkinId] = nil
    end
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
                
                if distance <= 20.0 and not notifiedPumpkins[id] then
                    lib.notify({
                        title = "¡Cuidado!",
                        description = "Hay una calabaza cerca.",
                        type = "info"
                    })
                    notifiedPumpkins[id] = true
                end

                if distance > 500.0 and notifiedPumpkins[id] then
                    notifiedPumpkins[id] = nil
                end
            end
        end

        Wait(sleep)
    end
end)


CreateThread(function()
    if not Config.PumpkinHunt.enabled then return end

    while true do
        local sleep = 500

        if #nearbyPumpkins > 0 then
            sleep = 0
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)

            for _, pumpkin in ipairs(nearbyPumpkins) do
                DrawMarker(
                    Config.PumpkinHunt.marker.type,
                    pumpkin.position.x,
                    pumpkin.position.y,
                    pumpkin.position.z + 1.5,
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
                    if IsControlJustPressed(0, 38) and not collectingPumpkin then -- E key
                        collectingPumpkin = true
                        CollectPumpkin(pumpkin.id, pumpkin.position)
                    end
                end
            end
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
        print("^1[ERROR] coords es nil en pumpkin:getGroundZ^7")
        return vector3(0, 0, 0)
    end

    local x, y, z = coords.x, coords.y, coords.z + 50.0
    local found, groundZ = GetGroundZFor_3dCoord(x, y, z, false)
    if not found then groundZ = z end
    return vector3(x, y, groundZ)
end)
