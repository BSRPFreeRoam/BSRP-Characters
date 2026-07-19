--[[
    Multi-character select + create (up to bsrp Config.MaxCharacters)
]]

local function notify(src, msg, nType)
    TriggerClientEvent('bsrp:client:notify', src, msg, nType or 'info')
end

local function maxSlots()
    local n = 5
    if GetResourceState('bsrp') == 'started' then
        local ok, v = pcall(function()
            return exports.bsrp:GetMaxCharacters()
        end)
        if ok and tonumber(v) then
            n = tonumber(v)
        end
    end
    if Config and tonumber(Config.MaxCharacters) then
        -- keep characters config in sync as soft floor if bsrp export missing
        if not (GetResourceState('bsrp') == 'started') then
            n = tonumber(Config.MaxCharacters) or n
        end
    end
    if n < 1 then n = 1 end
    if n > 12 then n = 12 end
    return n
end

local function pushLoaded(src)
    local player = exports.bsrp:GetPlayer(src)
    if not player then return end
    TriggerClientEvent('bsrp:client:playerLoaded', src, exports.bsrp:BuildClientPayload(player))
end

local function sendSelect(src)
    local account = exports.bsrp:GetIdentifier(src)
    if not account then return end
    local list = exports.bsrp:BuildCharacterList(account)
    local max = maxSlots()

    -- Guarantee every slot 1..max is present (empty placeholders for free slots)
    local bySlot = {}
    for _, c in ipairs(list or {}) do
        if c and c.slot then
            bySlot[tonumber(c.slot)] = c
        end
    end
    local full = {}
    for slot = 1, max do
        full[slot] = bySlot[slot] or { slot = slot, empty = true, name = nil }
    end

    TriggerClientEvent('bsrp-characters:client:openSelect', src, {
        characters = full,
        maxSlots = max,
        maxName = Config.MaxNameLength or 24,
        suggested = GetPlayerName(src),
    })
end

RegisterNetEvent('bsrp-characters:server:requestSelect', function()
    local src = source
    if GetResourceState('bsrp') ~= 'started' then return end
    -- Already in a character → only allow after logout
    if exports.bsrp:GetPlayer(src) then
        return
    end
    sendSelect(src)
end)

--- Staff check: bsrp admin level, or ACE (works even before a character is loaded)
local function isStaff(src)
    if src == 0 then return true end
    if IsPlayerAceAllowed(src, 'command') then return true end
    if IsPlayerAceAllowed(src, 'bsrp.admin') then return true end
    if IsPlayerAceAllowed(src, 'group.admin') then return true end
    if GetResourceState('bsrp') == 'started' then
        local ok, level = pcall(function()
            return exports.bsrp:GetAdminLevel(src)
        end)
        if ok and (tonumber(level) or 0) >= 1 then
            return true
        end
    end
    return false
end

--- Force character select for a player (logout if needed, always re-send UI)
local function forceOpenSelect(target)
    if not target or not GetPlayerName(target) then
        return false, 'invalid'
    end
    if GetResourceState('bsrp') ~= 'started' then
        return false, 'framework'
    end

    TriggerClientEvent('bsrp-characters:client:forceSelectPrep', target)

    if exports.bsrp:GetPlayer(target) then
        -- Soft logout → client will also request select; we re-send after unload
        pcall(function()
            exports.bsrp:Logout(target, 'admin_charselect')
        end)
        SetTimeout(900, function()
            if GetPlayerName(target) then
                sendSelect(target)
            end
        end)
    else
        -- Stuck on join / never loaded — open immediately
        SetTimeout(150, function()
            if GetPlayerName(target) then
                sendSelect(target)
            end
        end)
    end
    return true
end

--- Admin-only: open character select for yourself or another player
--- /charselect            → yourself
--- /charselect [id]       → target player
--- Aliases: /characters, /multichar, /chardselect
local function adminCharSelectCmd(source, args)
    local src = source
    local target = src

    if src == 0 then
        target = tonumber(args[1])
        if not target then
            print('[bsrp-characters] Usage: charselect [player id]')
            return
        end
    else
        if not isStaff(src) then
            notify(src, 'Admin only — character select command', 'error')
            return
        end
        if args[1] and args[1] ~= '' then
            target = tonumber(args[1])
            if not target then
                notify(src, 'Usage: /charselect [optional player id]', 'error')
                return
            end
        end
    end

    local ok, err = forceOpenSelect(target)
    if not ok then
        local msg = (err == 'invalid' and 'Invalid player')
            or (err == 'framework' and 'BSRP framework not started')
            or 'Could not open character select'
        if src == 0 then
            print('[bsrp-characters] ' .. msg)
        else
            notify(src, msg, 'error')
        end
        return
    end

    if src == 0 then
        print(('[bsrp-characters] Forced character select for id %s'):format(target))
    elseif target == src then
        notify(src, 'Opening character select…', 'success')
    else
        notify(src, ('Opening character select for ID %s'):format(target), 'success')
        notify(target, 'Staff opened character select for you', 'info')
    end
end

RegisterCommand('charselect', adminCharSelectCmd, false)
RegisterCommand('characters', adminCharSelectCmd, false)
RegisterCommand('multichar', adminCharSelectCmd, false)
RegisterCommand('chardselect', adminCharSelectCmd, false)

-- Networked admin request (from client suggestion / keybind if added later)
RegisterNetEvent('bsrp-characters:server:adminOpenSelect', function(targetId)
    local src = source
    if not isStaff(src) then
        notify(src, 'Admin only', 'error')
        return
    end
    local target = tonumber(targetId) or src
    local ok = forceOpenSelect(target)
    if ok then
        if target == src then
            notify(src, 'Opening character select…', 'success')
        else
            notify(src, ('Opening character select for ID %s'):format(target), 'success')
        end
    else
        notify(src, 'Could not open character select', 'error')
    end
end)

-- Also open select when framework asks via export
-- (OpenSelectFor already points at sendSelect)

exports('ForceOpenSelect', forceOpenSelect)
exports('IsStaff', isStaff)

--- Play existing character in a slot
RegisterNetEvent('bsrp-characters:server:select', function(slot)
    local src = source
    slot = tonumber(slot)
    if not slot then return end
    if GetResourceState('bsrp') ~= 'started' then
        notify(src, 'Framework not ready', 'error')
        return
    end
    if exports.bsrp:GetPlayer(src) then
        notify(src, 'Already loaded', 'error')
        return
    end

    if slot < 1 or slot > maxSlots() then
        notify(src, 'Invalid character slot', 'error')
        sendSelect(src)
        return
    end

    local ok, err = exports.bsrp:LoadCharacterSlot(src, slot, false)
    if not ok then
        if err == 'empty_slot' then
            notify(src, 'That slot is empty — create a character', 'error')
        else
            notify(src, 'Could not load character', 'error')
        end
        sendSelect(src)
        return
    end
end)

--- Create character in empty slot (name + skin from creator)
RegisterNetEvent('bsrp-characters:server:create', function(name, skin, slot)
    local src = source
    if GetResourceState('bsrp') ~= 'started' then
        notify(src, 'Framework not ready', 'error')
        return
    end

    name = tostring(name or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #name < 2 or #name > 48 then
        notify(src, 'Invalid name', 'error')
        return
    end
    if type(skin) ~= 'table' then
        notify(src, 'Invalid appearance data', 'error')
        return
    end

    skin.model = skin.model or skin.modelName or 'mp_m_freemode_01'
    skin.modelName = skin.modelName or skin.model
    if not skin.components then skin.components = {} end
    if not skin.props then skin.props = {} end

    local account = exports.bsrp:GetIdentifier(src)
    if not account then
        notify(src, 'No account', 'error')
        return
    end

    -- Already loaded = edit appearance of current character
    local player = exports.bsrp:GetPlayer(src)
    if player then
        exports.bsrp:SetName(src, name)
        exports.bsrp:SetSkin(src, skin, true)
        pushLoaded(src)
        print(('^2[bsrp-characters]^7 Updated character for %s'):format(name))
        return
    end

    local list = exports.bsrp:BuildCharacterList(account)
    local max = maxSlots()
    slot = tonumber(slot)
    if not slot then
        for _, c in ipairs(list) do
            if c.empty then
                slot = c.slot
                break
            end
        end
    end

    if not slot or slot < 1 or slot > max then
        notify(src, ('No free character slots (max %s)'):format(max), 'error')
        sendSelect(src)
        return
    end

    for _, c in ipairs(list) do
        if c.slot == slot and not c.empty then
            notify(src, 'Slot already in use', 'error')
            sendSelect(src)
            return
        end
    end

    local ok = exports.bsrp:LoadPlayer(src, name, true, slot)
    if not ok then
        notify(src, 'Failed to create character', 'error')
        return
    end

    player = exports.bsrp:GetPlayer(src)
    if not player then
        notify(src, 'Failed to create character', 'error')
        return
    end

    exports.bsrp:SetSkin(src, skin, true)
    pushLoaded(src)
    print(('^2[bsrp-characters]^7 Created character %s slot=%s (%s)'):format(name, slot, player.identifier))
end)

RegisterNetEvent('bsrp-characters:server:delete', function(slot)
    local src = source
    slot = tonumber(slot)
    if not slot then return end
    if GetResourceState('bsrp') ~= 'started' then return end

    local ok, err = exports.bsrp:DeleteCharacterSlot(src, slot)
    if not ok then
        if err == 'logged_in' then
            notify(src, 'Log out first to delete a character', 'error')
        else
            notify(src, 'Could not delete character', 'error')
        end
        return
    end
    notify(src, ('Deleted character slot %s'):format(slot), 'success')
    sendSelect(src)
end)

RegisterNetEvent('bsrp-characters:server:saveSkin', function(skin)
    local src = source
    if type(skin) ~= 'table' then return end
    if GetResourceState('bsrp') ~= 'started' then return end
    if not exports.bsrp:GetPlayer(src) then return end
    skin.model = skin.model or skin.modelName
    skin.modelName = skin.modelName or skin.model
    exports.bsrp:SetSkin(src, skin, true)
    notify(src, 'Appearance saved', 'success')
end)

exports('SaveSkin', function(src, skin)
    if type(skin) ~= 'table' then return false end
    return exports.bsrp:SetSkin(src, skin, true)
end)

exports('OpenSelectFor', sendSelect)
