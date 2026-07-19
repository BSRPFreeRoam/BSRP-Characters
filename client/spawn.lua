local spawnOpen = false

function OpenSpawnSelector(playerData)
    if spawnOpen then return end
    spawnOpen = true

    pcall(function() exports.spawnmanager:setAutoSpawn(false) end)

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetEntityVisible(ped, false, false)
    DisplayRadar(false)

    -- Stay black under opaque spawn NUI
    if not IsScreenFadedOut() then
        DoScreenFadeOut(0)
    end
    Wait(50)

    -- Park ped off-map-ish while UI is open (invisible)
    SetEntityCoords(ped, -75.0, -818.0, 326.0, false, false, false, false)
    FreezeEntityPosition(ped, true)

    TriggerEvent('bsrp:client:closeLoadingScreen')

    local last = playerData and playerData.position or nil
    local spawns = {}
    for _, s in ipairs(Config.Spawns) do
        local entry = {
            id = s.id,
            label = s.label,
            description = s.description,
            icon = s.icon,
            useLast = s.useLast == true,
        }
        if s.useLast and last and last.x then
            entry.hasLast = true
            entry.coords = { x = last.x, y = last.y, z = last.z, w = last.w or 0.0 }
        elseif s.coords then
            entry.coords = {
                x = s.coords.x, y = s.coords.y, z = s.coords.z, w = s.coords.w or 0.0,
            }
            entry.hasLast = true
        else
            entry.hasLast = false
        end
        spawns[#spawns + 1] = entry
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openSpawn',
        data = {
            name = playerData and playerData.name or 'Racer',
            spawns = spawns,
        },
    })
    Wait(200)
    SendNUIMessage({
        action = 'openSpawn',
        data = {
            name = playerData and playerData.name or 'Racer',
            spawns = spawns,
        },
    })
    Wait(100)

    DoScreenFadeIn(300)
    while not IsScreenFadedIn() do Wait(0) end
    SetNuiFocus(true, true)
end

function CloseSpawnSelector()
    spawnOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeSpawn' })
end

RegisterNetEvent('bsrp-characters:client:openSpawn', function(data)
    OpenSpawnSelector(data)
end)

AddEventHandler('bsrp-characters:client:openSpawn', function(data)
    OpenSpawnSelector(data)
end)

RegisterNUICallback('spawn:select', function(data, cb)
    if not data then cb({ ok = false }) return end

    local pos = data.coords
    if not pos or pos.x == nil then
        local d = Config.Spawns[2] and Config.Spawns[2].coords
        if d then
            pos = { x = d.x, y = d.y, z = d.z, w = d.w }
        else
            pos = { x = -1037.74, y = -2738.04, z = 20.17, w = 330.0 }
        end
    end

    CloseSpawnSelector()
    -- Stay black until finishSpawn collision settle + single FadeIn
    DoScreenFadeOut(200)
    Wait(250)

    local payload = {
        x = pos.x + 0.0,
        y = pos.y + 0.0,
        z = pos.z + 0.0,
        w = (pos.w or 0.0) + 0.0,
    }
    TriggerEvent('bsrp:client:doSpawn', payload)

    cb({ ok = true })
end)
