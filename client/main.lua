local inHorrorZone = false
local currentZone = nil
local timeInZone = 0
local zones = {}
local isImmuneToHorror = false
local globalEvent = false
local isGhostActive = false
local currentGhostData = {}

local cooldowns = {
    jumpscare = 0,
    whisper = 0,
    distortion = 0,
    ghost = 0,
    environmental = 0,
    paranormal = 0
}

local playerState = {
    sanity = 100,
    intensity = 0,
    lastPosition = nil,
    isInVehicle = false
}

local activeEntities = {
    ghosts = {},
    objects = {},
    sounds = {}
}

function IsNightTime()
    if not Config.OnlyAtNight then
        return true
    end

    local hour = GetClockHours()
    local startHour = Config.NightHours.start
    local endHour = Config.NightHours.finish

    if startHour > endHour then
        return hour >= startHour or hour < endHour
    else
        return hour >= startHour and hour < endHour
    end
end

CreateThread(function()
    Wait(1000)

    for _, zoneData in pairs(Config.HorrorZones) do
        local zone

        if zoneData.type == "poly" then
            zone = PolyZone:Create(zoneData.points, {
                name = zoneData.name,
                minZ = zoneData.minZ,
                maxZ = zoneData.maxZ,
                debugPoly = Config.DebugMode
            })
        elseif zoneData.type == "box" then
            zone = BoxZone:Create(zoneData.center, zoneData.length, zoneData.width, {
                name = zoneData.name,
                heading = zoneData.heading,
                minZ = zoneData.minZ,
                maxZ = zoneData.maxZ,
                debugPoly = Config.DebugMode
            })
        end

        if zone then
            zone:onPlayerInOut(function(isPointInside)
                if isPointInside then
                    EnterHorrorZone(zoneData)
                else
                    if currentZone and currentZone.name == zoneData.name then
                        LeaveHorrorZone()
                    end
                end
            end)
            table.insert(zones, zone)
        end
    end

    if Config.DebugMode then
        print(("^2[HORROR]^7 %d zonas cargadas correctamente"):format(#zones))
    end
end)

function EnterHorrorZone(zone)
    inHorrorZone = true
    currentZone = zone
    timeInZone = 0
    playerState.intensity = 0

    for k, _ in pairs(cooldowns) do
        cooldowns[k] = 0
    end

    TriggerServerEvent('horror:playerEnterZone', zone.name)
    TriggerEvent("horror:enterZone", zone)
    local ped = PlayerPedId()

    if IsPedInAnyVehicle(ped, false) and not Config.HorrorZonesAllowVehicles then
        local veh = GetVehiclePedIsIn(ped, false)
        TaskLeaveVehicle(ped, veh, 4160)
        SetVehicleEngineOn(veh, false, true, true)
    end

    SetTimecycleModifier(Config.HorrorZonesTimeCycleModifier)
    SetTimecycleModifierStrength(1.0)

    if Config.DebugMode then
        print(("^3[HORROR]^7 Jugador entró en: %s"):format(zone.name))
    end
end

Citizen.CreateThread(function()
    while true do
        Wait(0)
        local ped = PlayerPedId()
        if inHorrorZone and IsPedInAnyVehicle(ped, false) and not Config.HorrorZonesAllowVehicles then
            local veh = GetVehiclePedIsIn(ped, false)
            DisableControlAction(0, 71, true)  -- acelerar
            DisableControlAction(0, 72, true)  -- frenar
            DisableControlAction(0, 63, true)  -- girar izq
            DisableControlAction(0, 64, true)  -- girar der
            SetVehicleEngineOn(veh, false, true, true)
        end
    end
end)

function LeaveHorrorZone()
    inHorrorZone = false
    timeInZone = 0
    playerState.intensity = 0

    CleanupAllEntities()

    TriggerServerEvent('horror:playerLeaveZone')
    TriggerEvent("horror:leaveZone")

    ClearTimecycleModifier()

    if Config.DebugMode then
        print("^2[HORROR]^7 Jugador salió de zona de terror")
    end

    currentZone = nil
end

function CalculateIntensity()
    if not Config.IntensityProgression.enabled then
        return 1.0
    end

    local progress = math.min(timeInZone / Config.IntensityProgression.timeToMaxIntensity, 1.0)
    local baseMultiplier = Config.IntensityProgression.multipliers[currentZone.intensity] or 1.0

    return progress * baseMultiplier
end

function GetModifiedChance(baseChance)
    local intensity = CalculateIntensity()
    return math.floor(baseChance * (0.5 + intensity * 0.5))
end

function GetWeightedRandom(itemsTable)
    local totalWeight = 0
    for _, item in ipairs(itemsTable) do
        totalWeight = totalWeight + (item.weight or 1)
    end

    local random = math.random() * totalWeight
    local currentWeight = 0

    for _, item in ipairs(itemsTable) do
        currentWeight = currentWeight + (item.weight or 1)
        if random <= currentWeight then
            return item.id or item
        end
    end

    return itemsTable[1].id or itemsTable[1]
end

CreateThread(function()
    while true do
        local sleep = Config.Performance.updateInterval

        if isImmuneToHorror then
            Wait(sleep)
            goto continue
        end

        if inHorrorZone and currentZone and Config.EnableHorrorSystem then
            if (not IsNightTime() and not globalEvent) then
                Wait(sleep)
                goto continue
            end

            local playerPed = PlayerPedId()
            playerState.isInVehicle = IsPedInAnyVehicle(playerPed, false)

            if Config.Performance.disableInVehicle and playerState.isInVehicle then
                Wait(sleep)
                goto continue
            end

            local currentTime = GetGameTimer()
            timeInZone = timeInZone + sleep
            playerState.intensity = CalculateIntensity()

            if Config.SanitySystem.enabled then
                UpdateSanity()
            end

            if Config.Events.jumpscares.enabled and timeInZone >= Config.Events.jumpscares.minTimeInZone then
                if currentTime - cooldowns.jumpscare > Config.Events.jumpscares.cooldown then
                    local chance = GetModifiedChance(Config.Events.jumpscares.baseChance)
                    if math.random(100) <= chance then
                        TriggerEvent('horror:jumpscare')
                        TriggerServerEvent('horror:logEvent', 'jumpscare')
                        cooldowns.jumpscare = currentTime
                    end
                end
            end

            if Config.Events.whispers.enabled and timeInZone >= Config.Events.whispers.minTimeInZone then
                if currentTime - cooldowns.whisper > Config.Events.whispers.cooldown then
                    local chance = GetModifiedChance(Config.Events.whispers.baseChance)
                    if math.random(100) <= chance then
                        TriggerEvent('horror:whisper')
                        TriggerServerEvent('horror:logEvent', 'whisper')
                        cooldowns.whisper = currentTime
                    end
                end
            end

            if Config.Events.visualDistortion.enabled and timeInZone >= Config.Events.visualDistortion.minTimeInZone then
                if currentTime - cooldowns.distortion > Config.Events.visualDistortion.cooldown then
                    local chance = GetModifiedChance(Config.Events.visualDistortion.baseChance)
                    if math.random(100) <= chance then
                        TriggerEvent('horror:distortion')
                        cooldowns.distortion = currentTime
                    end
                end
            end

            if Config.Events.ghostAppearance.enabled and currentZone.enableGhosts then
                if timeInZone >= Config.Events.ghostAppearance.minTimeInZone then
                    if currentTime - cooldowns.ghost > Config.Events.ghostAppearance.cooldown then
                        local chance = GetModifiedChance(Config.Events.ghostAppearance.baseChance)
                        if math.random(100) <= chance then
                            TriggerEvent('horror:ghostAppearance')
                            TriggerServerEvent('horror:logEvent', 'ghost')
                            cooldowns.ghost = currentTime
                        end
                    end
                end
            end

            if Config.Events.environmental.enabled and timeInZone >= Config.Events.environmental.minTimeInZone then
                if currentTime - cooldowns.environmental > Config.Events.environmental.cooldown then
                    local chance = GetModifiedChance(Config.Events.environmental.baseChance)
                    if math.random(100) <= chance then
                        TriggerEvent('horror:environmental')
                        cooldowns.environmental = currentTime
                    end
                end
            end

            if Config.Events.paranormalObjects.enabled and timeInZone >= Config.Events.paranormalObjects.minTimeInZone then
                if currentTime - cooldowns.paranormal > Config.Events.paranormalObjects.cooldown then
                    local chance = GetModifiedChance(Config.Events.paranormalObjects.baseChance)
                    if math.random(100) <= chance then
                        TriggerEvent('horror:paranormal')
                        cooldowns.paranormal = currentTime
                    end
                end
            end
        end

        ::continue::
        Wait(sleep)
    end
end)

function UpdateSanity()
    if inHorrorZone then
        playerState.sanity = math.max(0,
            playerState.sanity - (Config.SanitySystem.drainRate * (Config.Performance.updateInterval / 1000)))

        if playerState.sanity < 30 and Config.SanitySystem.effectsAtLowSanity then
            if math.random(100) < 5 then
                TriggerEvent('horror:whisper')
            end
        end
    else
        playerState.sanity = math.min(100,
            playerState.sanity + (Config.SanitySystem.recoveryRate * (Config.Performance.updateInterval / 1000)))
    end

    SendNUIMessage({
        type = "updateSanity",
        sanity = playerState.sanity
    })
end

RegisterNetEvent('horror:enterZone')
AddEventHandler('horror:enterZone', function(zone)
    if Config.OnlyAtNight and not IsNightTime() then
        if Config.NUI.showNotifications then
            SendNUIMessage({
                type = "notification",
                message = Config.Texts.nightOnly,
                isWarning = true
            })
        end
        return
    end

    if Config.NUI.showNotifications then
        SendNUIMessage({
            type = "notification",
            message = Config.Texts.enterZone,
            zoneName = Config.Texts.zoneNames[zone.name] or zone.name,
            intensity = zone.intensity
        })
    end

    SendNUIMessage({
        type = "enterZone",
        zone = zone.name,
        intensity = zone.intensity
    })

    if zone.ambientSound and Config.AmbientSounds and Config.AmbientSounds[zone.ambientSound] then
        SendNUIMessage({
            type = "playAmbient",
            ambientType = zone.ambientSound
        })
    end
end)

RegisterNetEvent('horror:leaveZone')
AddEventHandler('horror:leaveZone', function()
    if Config.NUI.showNotifications then
        SendNUIMessage({
            type = "notification",
            message = Config.Texts.leaveZone,
            isLeaving = true
        })
    end

    SendNUIMessage({
        type = "leaveZone"
    })

    StopAmbientSound()
end)

RegisterNetEvent('horror:jumpscare')
AddEventHandler('horror:jumpscare', function()
    local jumpscareType = GetWeightedRandom(Config.Events.jumpscares.types)

    SendNUIMessage({
        type = "jumpscare",
        jumpscareType = jumpscareType
    })

    if Config.CameraEffects.enabled and Config.CameraEffects.shakeOnJumpscare then
        ShakeGameplayCam('LARGE_EXPLOSION_SHAKE', Config.CameraEffects.shakeIntensity)
    end

    PlaySoundFrontend(-1, "CHECKPOINT_MISSED", "HUD_MINI_GAME_SOUNDSET", true)
end)

RegisterNetEvent('horror:whisper')
AddEventHandler('horror:whisper', function()
    local sound = GetWeightedRandom(Config.Events.whispers.sounds)

    SendNUIMessage({
        type = "whisper",
        sound = sound
    })

    if Config.Sound3D.enabled then
        PlaySound3DNear(sound, math.random(5, 15))
    end
end)

RegisterNetEvent('horror:distortion')
AddEventHandler('horror:distortion', function()
    local distortionType = GetWeightedRandom(Config.Events.visualDistortion.types)

    SendNUIMessage({
        type = "distortion",
        distortionType = distortionType,
        duration = Config.Events.visualDistortion.duration
    })

    if distortionType == "darkness" then
        SetTimecycleModifier("REDMIST_blend")
        SetTimecycleModifierStrength(0.5)
        CreateThread(function()
            Wait(Config.Events.visualDistortion.duration)
            ClearTimecycleModifier()
        end)
    elseif distortionType == "static" then
        SetTimecycleModifier("NG_filmic19")
        SetTimecycleModifierStrength(0.7)
        CreateThread(function()
            Wait(Config.Events.visualDistortion.duration)
            ClearTimecycleModifier()
        end)
    end
end)

RegisterNetEvent('horror:ghostAppearance')
AddEventHandler('horror:ghostAppearance', function()
    if isGhostActive then
        return
    end

    if #activeEntities.ghosts >= Config.Performance.maxActiveGhosts then
        return
    end

    local playerPed = PlayerPedId()
    if IsPedInAnyVehicle(playerPed, false) then return end

    isGhostActive = true

    local playerCoords = GetEntityCoords(playerPed)
    local playerHeading = GetEntityHeading(playerPed)

    local ghostModel = Config.Events.ghostAppearance.models[math.random(#Config.Events.ghostAppearance.models)]
    RequestModel(ghostModel)

    local timeout = 0
    while not HasModelLoaded(ghostModel) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end

    if not HasModelLoaded(ghostModel) then
        isGhostActive = false
        return
    end

    local distance = math.random(10, 15)
    local angle = math.rad(playerHeading + math.random(-45, 45))
    local spawnX = playerCoords.x + math.sin(angle) * distance
    local spawnY = playerCoords.y + math.cos(angle) * distance
    local spawnZ = playerCoords.z

    local ghostPed = CreatePed(4, ghostModel, spawnX, spawnY, spawnZ, playerHeading + 180.0, true, true)

    if not DoesEntityExist(ghostPed) then
        SetModelAsNoLongerNeeded(ghostModel)
        isGhostActive = false
        return
    end

    currentGhostData = {
        ped = ghostPed,
        startTime = GetGameTimer(),
        isBeingRemoved = false
    }

    table.insert(activeEntities.ghosts, ghostPed)

    SetEntityAsMissionEntity(ghostPed, true, true)
    SetEntityInvincible(ghostPed, true)
    SetEntityCollision(ghostPed, false, false)
    FreezeEntityPosition(ghostPed, false)
    SetBlockingOfNonTemporaryEvents(ghostPed, true)
    SetEntityCanBeDamaged(ghostPed, false)
    SetPedCanRagdoll(ghostPed, false)
    SetPedCanBeTargetted(ghostPed, false)
    SetPedCanBeDraggedOut(ghostPed, false)
    SetPedConfigFlag(ghostPed, 17, true)
    SetPedConfigFlag(ghostPed, 32, false)
    SetEntityProofs(ghostPed, true, true, true, true, true, true, true, true)

    Wait(500)

    local weapons = {
        "WEAPON_KNIFE",
        "WEAPON_SWITCHBLADE",
        "WEAPON_MACHETE",
        "WEAPON_BOTTLE",
        "WEAPON_HAMMER",
        "WEAPON_BAT",
        "WEAPON_CROWBAR",
        "WEAPON_WRENCH",
    }
    local randomWeapon = weapons[math.random(#weapons)]
    local weaponHash = GetHashKey(randomWeapon)

    GiveWeaponToPed(ghostPed, weaponHash, 1, false, true)
    SetCurrentPedWeapon(ghostPed, weaponHash, true)
    SetPedCanSwitchWeapon(ghostPed, false)

    SetPedCombatAttributes(ghostPed, 46, true)
    SetPedCombatAbility(ghostPed, 100)
    SetPedCombatRange(ghostPed, 2)
    SetPedCombatMovement(ghostPed, 2)

    RequestAnimDict("melee@knife@streamed_core")
    local animTimeout = 0
    while not HasAnimDictLoaded("melee@knife@streamed_core") and animTimeout < 50 do
        Wait(50)
        animTimeout = animTimeout + 1
    end

    if HasAnimDictLoaded("melee@knife@streamed_core") then
        TaskPlayAnim(ghostPed, "melee@knife@streamed_core", "ground_attack_on_spot", 8.0, -8.0, -1, 49, 0, false, false,
            false)
    end

    PlaySoundFrontend(-1, "TIMER_STOP", "HUD_MINI_GAME_SOUNDSET", true)

    if Config.CameraEffects.slowMotionOnGhost then
        SetTimeScale(0.5)
        Wait(1000)
        SetTimeScale(1.0)
    end

    ClearPedTasksImmediately(ghostPed)
    TaskSetBlockingOfNonTemporaryEvents(ghostPed, false)
    TaskGoToEntity(ghostPed, playerPed, -1, 0.0, Config.Events.ghostAppearance.chaseSpeed, 0, 0)

    CreateThread(function()
        local startTime = GetGameTimer()
        local lastValidCheck = startTime
        local stuckCheckTimer = startTime
        local lastGhostPos = GetEntityCoords(ghostPed)

        while DoesEntityExist(ghostPed) and not currentGhostData.isBeingRemoved do
            Wait(200)

            if not DoesEntityExist(ghostPed) or IsPedDeadOrDying(ghostPed, true) then
                RemoveGhost(ghostPed)
                break
            end

            local ghostPos = GetEntityCoords(ghostPed)
            local playerPos = GetEntityCoords(PlayerPedId())
            local dist = #(ghostPos - playerPos)
            local elapsed = GetGameTimer() - startTime

            if GetGameTimer() - stuckCheckTimer > 3000 then
                local movementDist = #(ghostPos - lastGhostPos)
                if movementDist < 1.0 and dist > 5.0 then
                    ClearPedTasksImmediately(ghostPed)
                    TaskGoToEntity(ghostPed, PlayerPedId(), -1, 0.0, Config.Events.ghostAppearance.chaseSpeed, 0, 0)
                end
                lastGhostPos = ghostPos
                stuckCheckTimer = GetGameTimer()
            end

            if GetGameTimer() - lastValidCheck > 5000 then
                if DoesEntityExist(ghostPed) and dist > 2.0 then
                    ClearPedTasksImmediately(ghostPed)
                    TaskGoToEntity(ghostPed, PlayerPedId(), -1, 0.0, Config.Events.ghostAppearance.chaseSpeed, 0, 0)
                end
                lastValidCheck = GetGameTimer()
            end

            if dist <= 2.0 then
                DoScreenFadeOut(800)
                TriggerEvent('horror:jumpscare')
                Wait(1500)

                if DoesEntityExist(PlayerPedId()) then
                    SetPedToRagdoll(PlayerPedId(), 3000, 3000, 0, false, false, false)
                end

                RemoveGhost(ghostPed)
                Wait(3000)
                DoScreenFadeIn(2000)
                break
            end

            if elapsed > Config.Events.ghostAppearance.duration or dist > Config.Events.ghostAppearance.maxChaseDistance then
                RemoveGhost(ghostPed)
                break
            end

            if elapsed > (Config.Events.ghostAppearance.duration + 10000) then
                RemoveGhost(ghostPed)
                break
            end
        end

        if DoesEntityExist(ghostPed) then
            RemoveGhost(ghostPed)
        end
    end)

    SetModelAsNoLongerNeeded(ghostModel)
end)

function RemoveGhost(ghost)
    if currentGhostData.isBeingRemoved then
        return
    end

    if not DoesEntityExist(ghost) then
        isGhostActive = false
        currentGhostData = {}
        return
    end

    currentGhostData.isBeingRemoved = true

    ClearPedTasksImmediately(ghost)
    FreezeEntityPosition(ghost, true)

    for i = 200, 0, -20 do
        if DoesEntityExist(ghost) then
            SetEntityAlpha(ghost, i, false)
        end
        Wait(50)
    end

    local deleteAttempts = 0
    while DoesEntityExist(ghost) and deleteAttempts < 5 do
        SetEntityAsMissionEntity(ghost, false, true)
        DeleteEntity(ghost)

        if DoesEntityExist(ghost) then
            DeletePed(ghost)
        end

        deleteAttempts = deleteAttempts + 1
        Wait(100)
    end

    if DoesEntityExist(ghost) then
        SetEntityAsNoLongerNeeded(ghost)
        SetPedAsNoLongerNeeded(ghost)
    end

    for i, g in ipairs(activeEntities.ghosts) do
        if g == ghost then
            table.remove(activeEntities.ghosts, i)
            break
        end
    end

    -- Resetear flags globales
    isGhostActive = false
    currentGhostData = {}
end

CreateThread(function()
    while true do
        Wait(1000)

        if isGhostActive and currentGhostData.ped then
            local playerPed = PlayerPedId()

            if IsPedInAnyVehicle(playerPed, false) then
                if DoesEntityExist(currentGhostData.ped) then
                    RemoveGhost(currentGhostData.ped)
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if currentGhostData.ped and DoesEntityExist(currentGhostData.ped) then
            DeleteEntity(currentGhostData.ped)
        end

        for _, ghost in ipairs(activeEntities.ghosts) do
            if DoesEntityExist(ghost) then
                DeleteEntity(ghost)
            end
        end

        activeEntities.ghosts = {}
    end
end)

RegisterNetEvent('horror:environmental')
AddEventHandler('horror:environmental', function()
    local effect = GetWeightedRandom(Config.Events.environmental.effects)

    SendNUIMessage({
        type = "environmental",
        effect = effect
    })

    if effect == "fog" then
        SetWeatherTypePersist("FOGGY")
        SetWeatherTypeNow("FOGGY")
        SetWeatherTypeNowPersist("FOGGY")

        CreateThread(function()
            Wait(30000)
            SetWeatherTypeNowPersist("CLEAR")
        end)
    elseif effect == "thunder" then
        ForceLightningFlash()
        Wait(math.random(500, 2000))
        ForceLightningFlash()
    end
end)

RegisterNetEvent('horror:paranormal')
AddEventHandler('horror:paranormal', function()
    local type = Config.Events.paranormalObjects.types[math.random(#Config.Events.paranormalObjects.types)]

    SendNUIMessage({
        type = "paranormal",
        effectType = type
    })
end)

function CleanupAllEntities()
    for _, ghost in ipairs(activeEntities.ghosts) do
        if DoesEntityExist(ghost) then
            DeleteEntity(ghost)
        end
    end
    activeEntities.ghosts = {}

    for _, obj in ipairs(activeEntities.objects) do
        if DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
    end
    activeEntities.objects = {}

    ClearWeatherTypePersist()
    SetWeatherTypeNowPersist("CLEAR")
end

CreateThread(function()
    while true do
        Wait(Config.Performance.cleanupInterval)

        if not inHorrorZone then
            CleanupAllEntities()
        end
    end
end)

if Config.AdminCommands.enabled then
    RegisterCommand(Config.AdminCommands.testCommand, function(source, args)
        if args[1] == "jumpscare" then
            TriggerEvent('horror:jumpscare')
        elseif args[1] == "whisper" then
            TriggerEvent('horror:whisper')
        elseif args[1] == "distortion" then
            TriggerEvent('horror:distortion')
        elseif args[1] == "ghost" then
            TriggerEvent('horror:ghostAppearance')
        elseif args[1] == "env" then
            TriggerEvent('horror:environmental')
        elseif args[1] == "paranormal" then
            TriggerEvent('horror:paranormal')
        end
    end, false)

    RegisterCommand(Config.AdminCommands.toggleCommand, function()
        Config.EnableHorrorSystem = not Config.EnableHorrorSystem
        local status = Config.EnableHorrorSystem and "^2activado^7" or "^1desactivado^7"
        print(("^3[HORROR]^7 Sistema %s"):format(status))
    end, false)
end

function PlaySound3DNear(soundName, distance)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    local angle = math.random() * 2 * math.pi
    local x = playerCoords.x + math.cos(angle) * distance
    local y = playerCoords.y + math.sin(angle) * distance
    local z = playerCoords.z + math.random(-2, 2)

    local soundId = GetSoundId()
    PlaySoundFromCoord(soundId, soundName, x, y, z, "", false, Config.Sound3D.maxDistance, false)

    table.insert(activeEntities.sounds, soundId)

    CreateThread(function()
        Wait(5000)
        StopSound(soundId)
        ReleaseSoundId(soundId)
    end)
end

function PlayAmbientSound(soundType)
    SendNUIMessage({
        type = "playAmbient",
        ambientType = soundType
    })
end

function StopAmbientSound()
    SendNUIMessage({
        type = "stopAmbient"
    })
end

exports('IsInHorrorZone', function()
    return inHorrorZone
end)

exports('GetCurrentZone', function()
    return currentZone
end)

exports('GetPlayerSanity', function()
    return playerState.sanity
end)

exports('GetIntensity', function()
    return playerState.intensity
end)

RegisterNetEvent('horror:globalEventStart')
AddEventHandler('horror:globalEventStart', function()
    if not inHorrorZone then
        currentZone = {
            name = "Evento Global",
            intensity = "high",
            enableGhosts = true
        }
        inHorrorZone = true
        timeInZone = 50000
        globalEvent = true
        playerState.intensity = 1.0

        SendNUIMessage({
            type = "notification",
            message = "⚠️ ¡EVENTO GLOBAL DE TERROR ACTIVADO!",
            isWarning = true
        })

        SendNUIMessage({
            type = "enterZone",
            zone = "Evento Global",
            intensity = "high"
        })
    end

    if Config.DebugMode then
        print("^1[HORROR]^7 Evento global iniciado")
    end
end)

RegisterNetEvent('horror:globalEventStop')
AddEventHandler('horror:globalEventStop', function()
    if currentZone and currentZone.name == "Evento Global" then
        inHorrorZone = false
        currentZone = nil
        timeInZone = 0
        globalEvent = false
        playerState.intensity = 0

        CleanupAllEntities()

        SendNUIMessage({
            type = "notification",
            message = "✅ Evento global terminado",
            isLeaving = true
        })

        SendNUIMessage({
            type = "leaveZone"
        })
    end

    if Config.DebugMode then
        print("^2[HORROR]^7 Evento global detenido")
    end
end)

RegisterNetEvent('horror:adminForce')
AddEventHandler('horror:adminForce', function(effectType)
    if isImmuneToHorror then
        if Config.DebugMode then
            print("^3[HORROR]^7 Efecto bloqueado por inmunidad")
        end
        return
    end

    if effectType == 'jumpscare' then
        local jumpscareType = GetWeightedRandom(Config.Events.jumpscares.types)

        SendNUIMessage({
            type = "jumpscare",
            jumpscareType = jumpscareType
        })

        if Config.CameraEffects.enabled and Config.CameraEffects.shakeOnJumpscare then
            ShakeGameplayCam('LARGE_EXPLOSION_SHAKE', Config.CameraEffects.shakeIntensity)
        end

        PlaySoundFrontend(-1, "CHECKPOINT_MISSED", "HUD_MINI_GAME_SOUNDSET", true)
    elseif effectType == 'whisper' then
        local sound = GetWeightedRandom(Config.Events.whispers.sounds)

        SendNUIMessage({
            type = "whisper",
            sound = sound
        })

        if Config.Sound3D.enabled then
            PlaySound3DNear(sound, math.random(5, 15))
        end
    elseif effectType == 'distortion' then
        local distortionType = GetWeightedRandom(Config.Events.visualDistortion.types)

        SendNUIMessage({
            type = "distortion",
            distortionType = distortionType,
            duration = Config.Events.visualDistortion.duration
        })

        if distortionType == "darkness" then
            SetTimecycleModifier("REDMIST_blend")
            SetTimecycleModifierStrength(0.5)
            CreateThread(function()
                Wait(Config.Events.visualDistortion.duration)
                ClearTimecycleModifier()
            end)
        elseif distortionType == "static" then
            SetTimecycleModifier("NG_filmic19")
            SetTimecycleModifierStrength(0.7)
            CreateThread(function()
                Wait(Config.Events.visualDistortion.duration)
                ClearTimecycleModifier()
            end)
        end
    elseif effectType == 'ghost' then
        if #activeEntities.ghosts >= Config.Performance.maxActiveGhosts then
            for _, ghost in ipairs(activeEntities.ghosts) do
                if DoesEntityExist(ghost) then
                    DeleteEntity(ghost)
                end
            end
            activeEntities.ghosts = {}
        end

        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local playerHeading = GetEntityHeading(playerPed)

        local ghostModel = Config.Events.ghostAppearance.models[math.random(#Config.Events.ghostAppearance.models)]
        RequestModel(ghostModel)

        local timeout = 0
        while not HasModelLoaded(ghostModel) and timeout < 50 do
            Wait(100)
            timeout = timeout + 1
        end

        if not HasModelLoaded(ghostModel) then return end

        local distance = math.random(10, 15)
        local angle = math.rad(playerHeading + math.random(-45, 45))
        local spawnX = playerCoords.x + math.sin(angle) * distance
        local spawnY = playerCoords.y + math.cos(angle) * distance
        local spawnZ = playerCoords.z

        local ghostPed = CreatePed(4, ghostModel, spawnX, spawnY, spawnZ, playerHeading + 180.0, true, true)

        if not DoesEntityExist(ghostPed) then
            SetModelAsNoLongerNeeded(ghostModel)
            return
        end

        table.insert(activeEntities.ghosts, ghostPed)

        SetEntityAsMissionEntity(ghostPed, true, true)
        SetEntityInvincible(ghostPed, true)
        SetEntityCollision(ghostPed, true, true)
        FreezeEntityPosition(ghostPed, false)
        SetBlockingOfNonTemporaryEvents(ghostPed, true)

        Wait(500)

        local weapons = {
            "WEAPON_KNIFE", "WEAPON_SWITCHBLADE", "WEAPON_MACHETE",
            "WEAPON_BOTTLE", "WEAPON_HAMMER", "WEAPON_BAT",
            "WEAPON_CROWBAR", "WEAPON_WRENCH"
        }
        local weaponHash = GetHashKey(weapons[math.random(#weapons)])

        GiveWeaponToPed(ghostPed, weaponHash, 1, false, true)
        SetCurrentPedWeapon(ghostPed, weaponHash, true)
        SetPedCanSwitchWeapon(ghostPed, false)

        SetPedCombatAttributes(ghostPed, 46, true)
        SetPedCombatAbility(ghostPed, 100)
        SetPedCombatRange(ghostPed, 2)
        SetPedCombatMovement(ghostPed, 2)

        RequestAnimDict("melee@knife@streamed_core")
        while not HasAnimDictLoaded("melee@knife@streamed_core") do Wait(50) end
        TaskPlayAnim(ghostPed, "melee@knife@streamed_core", "ground_attack_on_spot", 8.0, -8.0, -1, 49, 0, false, false,
            false)

        PlaySoundFrontend(-1, "TIMER_STOP", "HUD_MINI_GAME_SOUNDSET", true)

        if Config.CameraEffects.slowMotionOnGhost then
            SetTimeScale(0.5)
            Wait(1000)
            SetTimeScale(1.0)
        end

        ClearPedTasksImmediately(ghostPed)
        TaskSetBlockingOfNonTemporaryEvents(ghostPed, false)
        TaskGoToEntity(ghostPed, playerPed, -1, 0.0, Config.Events.ghostAppearance.chaseSpeed, 0, 0)

        CreateThread(function()
            local startTime = GetGameTimer()

            while DoesEntityExist(ghostPed) do
                Wait(200)

                local ghostPos = GetEntityCoords(ghostPed)
                local playerPos = GetEntityCoords(PlayerPedId())
                local dist = #(ghostPos - playerPos)
                local elapsed = GetGameTimer() - startTime

                if dist <= 2.0 then
                    DoScreenFadeOut(800)
                    TriggerEvent('horror:jumpscare')
                    Wait(1500)

                    SetPedToRagdoll(PlayerPedId(), 3000, 3000, 0, false, false, false)
                    RemoveGhost(ghostPed)
                    Wait(3000)
                    DoScreenFadeIn(2000)
                    break
                end

                if elapsed > Config.Events.ghostAppearance.duration or dist > Config.Events.ghostAppearance.maxChaseDistance then
                    RemoveGhost(ghostPed)
                    break
                end
            end
        end)

        SetModelAsNoLongerNeeded(ghostModel)
    elseif effectType == 'environmental' then
        local effect = GetWeightedRandom(Config.Events.environmental.effects)

        SendNUIMessage({
            type = "environmental",
            effect = effect
        })

        if effect == "fog" then
            SetWeatherTypePersist("FOGGY")
            SetWeatherTypeNow("FOGGY")
            SetWeatherTypeNowPersist("FOGGY")

            CreateThread(function()
                Wait(30000)
                SetWeatherTypeNowPersist("CLEAR")
            end)
        elseif effect == "thunder" then
            ForceLightningFlash()
            Wait(math.random(500, 2000))
            ForceLightningFlash()
        end
    end

    if Config.DebugMode then
        print(("^3[HORROR]^7 Efecto forzado por admin: %s"):format(effectType))
    end
end)

RegisterNetEvent('horror:adminCombo')
AddEventHandler('horror:adminCombo', function()
    if isImmuneToHorror then return end


    if Config.NUI.showNotifications then
        SendNUIMessage({
            type = "notification",
            message = "⚠️ ¡COMBO DE TERROR ACTIVADO!",
            isWarning = true
        })
    end

    CreateThread(function()
        Wait(500)
        TriggerEvent('horror:adminForce', 'distortion')

        Wait(2000)
        TriggerEvent('horror:adminForce', 'whisper')

        Wait(2000)
        TriggerEvent('horror:adminForce', 'environmental')

        Wait(3000)
        TriggerEvent('horror:adminForce', 'jumpscare')

        Wait(2000)
        TriggerEvent('horror:adminForce', 'ghost')
    end)
end)

RegisterNetEvent('horror:setImmunity')
AddEventHandler('horror:setImmunity', function(immune)
    isImmuneToHorror = immune

    if immune then
        CleanupAllEntities()
        ClearTimecycleModifier()
        StopAmbientSound()


        if Config.NUI.showNotifications then
            SendNUIMessage({
                type = "notification",
                message = "🛡️ Inmunidad al terror activada",
                isLeaving = true
            })

            SendNUIMessage({
                type = "leaveZone"
            })
        end
    else
        if Config.NUI.showNotifications then
            SendNUIMessage({
                type = "notification",
                message = "⚠️ Inmunidad al terror desactivada",
                isWarning = true
            })
        end
    end

    if Config.DebugMode then
        print(("^3[HORROR]^7 Inmunidad: %s"):format(immune and "ACTIVADA" or "DESACTIVADA"))
    end
end)

RegisterNetEvent('horror:receiveSync')
AddEventHandler('horror:receiveSync', function(eventType, data)
    if isImmuneToHorror then return end

    if Config.DebugMode then
        print(("^3[HORROR]^7 Evento sincronizado recibido: %s"):format(eventType))
    end

    if eventType == "jumpscare" then
        PlaySoundFrontend(-1, "CHALLENGE_UNLOCKED", "HUD_AWARDS", false)
    elseif eventType == "ghost" then
        SetTimecycleModifier("NG_filmic19")
        SetTimecycleModifierStrength(0.2)
        CreateThread(function()
            Wait(2000)
            ClearTimecycleModifier()
        end)
    end
end)

-- RegisterCommand('mizona', function()
--     if inHorrorZone and currentZone then
--         local zoneName = Config.Texts.zoneNames[currentZone.name] or currentZone.name
--         local timeMin = math.floor(timeInZone / 60000)
--         local timeSec = math.floor((timeInZone % 60000) / 1000)

--         TriggerEvent('chat:addMessage', -1, {
--             color = { 255, 100, 100 },
--             multiline = true,
--             args = { "[HORROR]", string.format("📍 Zona: %s\n⏱️ Tiempo: %dm %ds\n📊 Intensidad: %.1f%%\n🧠 Cordura: %.0f%%",
--                 zoneName,
--                 timeMin,
--                 timeSec,
--                 playerState.intensity * 100,
--                 playerState.sanity
--             ) }
--         })
--     else
--         TriggerEvent('chat:addMessage', -1, {
--             color = { 100, 255, 100 },
--             args = { "[HORROR]", "No estás en ninguna zona de terror" }
--         })
--     end
-- end, false)

-- if Config.DebugMode then
--     RegisterCommand('horrorcooldowns', function()
--         local currentTime = GetGameTimer()
--         local msg = "⏲️ Cooldowns activos:\n"

--         for eventType, cooldownTime in pairs(cooldowns) do
--             local remaining = math.max(0, cooldownTime - currentTime)
--             if remaining > 0 then
--                 msg = msg .. string.format("• %s: %ds\n", eventType, math.ceil(remaining / 1000))
--             else
--                 msg = msg .. string.format("• %s: ✅ Disponible\n", eventType)
--             end
--         end

--         TriggerEvent('chat:addMessage', -1, {
--             color = { 100, 200, 255 },
--             multiline = true,
--             args = { "[HORROR DEBUG]", msg }
--         })
--     end, false)
-- end

exports('IsImmune', function()
    return isImmuneToHorror
end)

exports('ForceEvent', function(eventType)
    TriggerEvent('horror:adminForce', eventType)
end)

lib.callback.register('horror:getClientClockHour', function()
    return GetClockHours()
end)
