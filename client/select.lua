--[[
    Character select screen client
    Stay black under opaque NUI — only ONE FadeIn when select is ready.
]]

local selectOpen = false

local function closeSelect()
    selectOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeSelect' })
end

function OpenCharacterSelect(data)
    selectOpen = true
    DisplayRadar(false)
    DisplayHud(false)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openSelect',
        data = data or {},
    })
end

--- Prep client state before a forced (admin) character select open
RegisterNetEvent('bsrp-characters:client:forceSelectPrep', function()
    selectOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeSelect' })
    SendNUIMessage({ action = 'closeCreator' })
    SendNUIMessage({ action = 'closeSpawn' })

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetEntityVisible(ped, false, false)
    ClearPedTasksImmediately(ped)
    DisplayRadar(false)
    DisplayHud(false)

    if not IsScreenFadedOut() then
        DoScreenFadeOut(0)
    end

    TriggerEvent('bsrp:client:closeLoadingScreen')
end)

RegisterNetEvent('bsrp-characters:client:openSelect', function(data)
    pcall(function() exports.spawnmanager:setAutoSpawn(false) end)

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetEntityVisible(ped, false, false)
    DisplayRadar(false)
    DisplayHud(false)

    -- Hold black while loadscreen tears down + NUI paints (no early FadeIn flicker)
    if not IsScreenFadedOut() then
        DoScreenFadeOut(0)
    end
    Wait(50)

    TriggerEvent('bsrp:client:closeLoadingScreen')

    OpenCharacterSelect(data)
    -- Let CEF paint the opaque select panel before revealing
    Wait(250)
    SendNUIMessage({ action = 'openSelect', data = data or {} })
    Wait(100)

    SetNuiFocus(true, true)
    DoScreenFadeIn(350)
    while not IsScreenFadedIn() do Wait(0) end
    SetNuiFocus(true, true)
end)

-- Client can re-request select if server message was missed during join race
CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(100) end
    Wait(2500)
    if selectOpen then return end
    if GetResourceState('bsrp') ~= 'started' then return end
    local loaded = false
    pcall(function()
        loaded = exports.bsrp:IsPlayerLoaded()
    end)
    if loaded then return end
    TriggerServerEvent('bsrp-characters:server:requestSelect')
end)

RegisterNUICallback('select:play', function(data, cb)
    local slot = data and tonumber(data.slot)
    if not slot then
        cb({ ok = false })
        return
    end
    closeSelect()
    -- Stay black until spawn selector / world is ready
    DoScreenFadeOut(200)
    TriggerServerEvent('bsrp-characters:server:select', slot)
    cb({ ok = true })
end)

RegisterNUICallback('select:create', function(data, cb)
    local slot = data and tonumber(data.slot)
    closeSelect()
    OpenCharacterCreator({
        suggested = data and data.suggested or GetPlayerName(PlayerId()),
        isNew = true,
        maxName = (data and data.maxName) or Config.MaxNameLength or 24,
        slot = slot,
    })
    cb({ ok = true })
end)

RegisterNUICallback('select:delete', function(data, cb)
    local slot = data and tonumber(data.slot)
    if not slot then
        cb({ ok = false })
        return
    end
    TriggerServerEvent('bsrp-characters:server:delete', slot)
    cb({ ok = true })
end)

RegisterNUICallback('select:close', function(_, cb)
    cb({ ok = true })
end)

exports('OpenCharacterSelect', OpenCharacterSelect)
