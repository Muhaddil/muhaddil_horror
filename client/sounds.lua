local activeSounds = {}
local ambientLoops = {}

function PlaySound3D(soundName, coords, volume, range)
    local soundId = GetSoundId()
    
    if soundId == -1 then
        if Config.DebugMode then
            print("^1[HORROR]^7 Error: No se pudo obtener ID de sonido")
        end
        return nil
    end
    
    PlaySoundFromCoord(soundId, soundName, coords.x, coords.y, coords.z, "", false, range or Config.Sound3D.maxDistance, false)
    
    table.insert(activeSounds, {
        id = soundId,
        name = soundName,
        coords = coords,
        startTime = GetGameTimer()
    })
    
    return soundId
end

function PlaySoundNearPlayer(soundName, distance, volume)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local playerHeading = GetEntityHeading(playerPed)
    
    local angle = math.random() * 2 * math.pi
    local x = playerCoords.x + math.cos(angle) * distance
    local y = playerCoords.y + math.sin(angle) * distance
    
    local rayHandle = StartShapeTestRay(x, y, playerCoords.z + 50.0, x, y, playerCoords.z - 50.0, 1, playerPed, 0)
    local _, hit, hitCoords = GetShapeTestResult(rayHandle)
    
    local z = hit and hitCoords.z or playerCoords.z
    local soundCoords = vector3(x, y, z)
    
    return PlaySound3D(soundName, soundCoords, volume, distance + 10.0)
end

function PlayDirectionalSound(soundName, direction, distance)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local playerHeading = GetEntityHeading(playerPed)
    
    local angleOffset = 0
    if direction == "front" then
        angleOffset = 0
    elseif direction == "back" then
        angleOffset = 180
    elseif direction == "left" then
        angleOffset = -90
    elseif direction == "right" then
        angleOffset = 90
    end
    
    local angle = math.rad(playerHeading + angleOffset)
    local x = playerCoords.x + math.sin(angle) * distance
    local y = playerCoords.y + math.cos(angle) * distance
    local z = playerCoords.z
    
    local soundCoords = vector3(x, y, z)
    return PlaySound3D(soundName, soundCoords, 1.0, distance + 5.0)
end

function PlayAmbientLoop(soundName, volume, fadeIn)
    StopAmbientLoop()
    
    local soundId = GetSoundId()
    if soundId == -1 then return nil end
    
    PlaySound(soundId, soundName, "", false, 0, true)
    SetVariableOnSound(soundId, "volume", volume or 0.3)
    
    ambientLoops.current = {
        id = soundId,
        name = soundName,
        volume = volume or 0.3
    }
    
    if fadeIn then
        CreateThread(function()
            for i = 0, volume or 0.3, 0.05 do
                if ambientLoops.current and ambientLoops.current.id == soundId then
                    SetVariableOnSound(soundId, "volume", i)
                    Wait(100)
                else
                    break
                end
            end
        end)
    end
    
    return soundId
end

function StopSound3D(soundId)
    if not soundId then return end
    
    StopSound(soundId)
    ReleaseSoundId(soundId)
    
    for i, sound in ipairs(activeSounds) do
        if sound.id == soundId then
            table.remove(activeSounds, i)
            break
        end
    end
end

function StopAmbientLoop(fadeOut)
    if not ambientLoops.current then return end
    
    local currentLoop = ambientLoops.current
    ambientLoops.current = nil
    
    if fadeOut then
        CreateThread(function()
            local volume = currentLoop.volume
            for i = volume, 0, -0.05 do
                if DoesEntityExist(PlayerPedId()) then
                    SetVariableOnSound(currentLoop.id, "volume", i)
                    Wait(50)
                else
                    break
                end
            end
            StopSound(currentLoop.id)
            ReleaseSoundId(currentLoop.id)
        end)
    else
        StopSound(currentLoop.id)
        ReleaseSoundId(currentLoop.id)
    end
end

function StopAllHorrorSounds()
    for _, sound in ipairs(activeSounds) do
        StopSound(sound.id)
        ReleaseSoundId(sound.id)
    end
    activeSounds = {}
    
    StopAmbientLoop()
end

function PlayRandomWhisperAround()
    local numWhispers = math.random(2, 4)
    
    for i = 1, numWhispers do
        CreateThread(function()
            Wait(math.random(0, 2000))
            PlaySoundNearPlayer("whisper" .. math.random(1, 2), math.random(5, 15), 0.4)
        end)
    end
end

function PlaySurroundScream()
    local directions = {"front", "back", "left", "right"}
    local direction = directions[math.random(#directions)]
    
    PlayDirectionalSound("scream" .. math.random(1, 3), direction, math.random(10, 20))
end

function PlayHeartbeatSequence()
    CreateThread(function()
        for i = 1, 10 do
            PlaySoundFrontend(-1, "TIMER_STOP", "HUD_MINI_GAME_SOUNDSET", true)
            Wait(800 - (i * 30))
        end
    end)
end

CreateThread(function()
    while true do
        Wait(10000)
        
        local currentTime = GetGameTimer()
        local soundsToRemove = {}
        
        for i, sound in ipairs(activeSounds) do
            if currentTime - sound.startTime > 30000 then
                StopSound(sound.id)
                ReleaseSoundId(sound.id)
                table.insert(soundsToRemove, i)
            end
        end
        
        for i = #soundsToRemove, 1, -1 do
            table.remove(activeSounds, soundsToRemove[i])
        end
    end
end)

RegisterNetEvent('horror:leaveZone')
AddEventHandler('horror:leaveZone', function()
    StopAllHorrorSounds()
end)

exports('PlaySound3D', PlaySound3D)
exports('PlaySoundNearPlayer', PlaySoundNearPlayer)
exports('PlayDirectionalSound', PlayDirectionalSound)
exports('PlayAmbientLoop', PlayAmbientLoop)
exports('StopSound3D', StopSound3D)
exports('StopAmbientLoop', StopAmbientLoop)
exports('StopAllHorrorSounds', StopAllHorrorSounds)
exports('PlayRandomWhisperAround', PlayRandomWhisperAround)
exports('PlaySurroundScream', PlaySurroundScream)
exports('PlayHeartbeatSequence', PlayHeartbeatSequence)