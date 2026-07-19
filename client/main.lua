print('^2[bsrp-characters]^7 Character creator + spawn selector ready')

-- Chat suggestions (commands are registered server-side, admin-gated)
CreateThread(function()
    Wait(1500)
    TriggerEvent('chat:addSuggestion', '/charselect', 'Admin: open character select (self or player id)', {
        { name = 'id', help = 'Optional server id (default: you)' },
    })
    TriggerEvent('chat:addSuggestion', '/characters', 'Admin: open character select', {
        { name = 'id', help = 'Optional server id' },
    })
    TriggerEvent('chat:addSuggestion', '/multichar', 'Admin: open character select', {
        { name = 'id', help = 'Optional server id' },
    })
end)

-- Command for reopening spawn (debug / admin)
RegisterCommand('spawnselect', function()
    if GetResourceState('bsrp') ~= 'started' then return end
    local data = exports.bsrp:GetPlayerData()
    if data then
        OpenSpawnSelector(data)
    end
end, false)

RegisterCommand('charditor', function()
    -- Re-edit appearance (keeps name)
    local data = exports.bsrp and exports.bsrp:GetPlayerData()
    OpenCharacterCreator({
        suggested = data and data.name or GetPlayerName(PlayerId()),
        isNew = false,
        maxName = Config.MaxNameLength,
    })
end, false)
