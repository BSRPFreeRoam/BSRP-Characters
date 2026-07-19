CreatorState = {
    active = false,
    gender = 'male',
    name = '',
    headBlend = {
        shapeFirst = 0, shapeSecond = 21, shapeThird = 0,
        skinFirst = 0, skinSecond = 0, skinThird = 0,
        shapeMix = 0.5, skinMix = 0.5, thirdMix = 0.0,
    },
    faceFeatures = {},
    overlays = {},
    eyeColor = 0,
    hair = 0,
    hairColor = 0,
    hairHighlight = 0,
    cam = nil,
}

local function setGenderModel(gender)
    CreatorState.gender = gender == 'female' and 'female' or 'male'
    local model = CreatorState.gender == 'female' and 'mp_f_freemode_01' or 'mp_m_freemode_01'
    local skin = SkinUtil.Default(CreatorState.gender)
    skin.headBlend = CreatorState.headBlend
    ApplySkin(skin)
    ApplyPresetComponents(CreatorState.gender, 'casual')
    refreshHead()
end

function refreshHead()
    local ped = PlayerPedId()
    local hb = CreatorState.headBlend
    SetPedHeadBlendData(
        ped,
        hb.shapeFirst, hb.shapeSecond, hb.shapeThird,
        hb.skinFirst, hb.skinSecond, hb.skinThird,
        hb.shapeMix + 0.0, hb.skinMix + 0.0, hb.thirdMix + 0.0,
        false
    )
    for i = 0, 19 do
        local v = CreatorState.faceFeatures[tostring(i)] or 0.0
        SetPedFaceFeature(ped, i, v + 0.0)
    end
    -- Hair
    SetPedComponentVariation(ped, 2, CreatorState.hair or 0, 0, 0)
    SetPedHairColor(ped, CreatorState.hairColor or 0, CreatorState.hairHighlight or 0)
    if CreatorState.eyeColor then
        SetPedEyeColor(ped, CreatorState.eyeColor)
    end
    -- Beard / blemish overlays
    for id, o in pairs(CreatorState.overlays) do
        local i = tonumber(id)
        if i and o then
            SetPedHeadOverlay(ped, i, o.index or 255, (o.opacity or 1.0) + 0.0)
            if o.colorType then
                SetPedHeadOverlayColor(ped, i, o.colorType, o.firstColor or 0, o.secondColor or 0)
            end
        end
    end
end

local function loadFranklinInterior()
    local cfg = Config.CreatorInterior
    if not cfg or cfg.enabled == false then
        return Config.CreatorCoords
    end

    local house = (cfg.house == 'aunt') and cfg.aunt or cfg.hills
    local coords = house and house.coords or Config.CreatorCoords
    local interiorId = house and house.interiorId

    -- Request collision + pin interior
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    if interiorId then
        PinInteriorInMemory(interiorId)
        RefreshInterior(interiorId)
    end

    -- bob74_ipl helpers when present
    if GetResourceState('bob74_ipl') == 'started' then
        pcall(function()
            if cfg.house == 'aunt' then
                local Aunt = exports['bob74_ipl']:GetFranklinAuntObject()
                if Aunt and Aunt.LoadDefault then Aunt.LoadDefault() end
            else
                local Frank = exports['bob74_ipl']:GetFranklinObject()
                if Frank then
                    if Frank.Style and Frank.Style.Set then
                        Frank.Style.Set(Frank.Style.settled or Frank.Style.empty, false)
                    end
                    if Frank.GlassDoor and Frank.GlassDoor.Set then
                        Frank.GlassDoor.Set(Frank.GlassDoor.opened, false)
                    end
                    if Frank.LoadDefault then
                        -- settled already applied; still refresh
                    end
                    if interiorId then RefreshInterior(interiorId) end
                end
            end
        end)
    end

    return coords
end

local function createCam()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local offset = Config.CreatorCamOffset or vector3(0.0, 1.85, 0.45)
    local rad = math.rad(heading)
    local cx = coords.x + offset.y * math.sin(-rad)
    local cy = coords.y + offset.y * math.cos(-rad)
    local cz = coords.z + offset.z

    if CreatorState.cam then
        DestroyCam(CreatorState.cam, false)
    end
    CreatorState.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(CreatorState.cam, cx, cy, cz)
    PointCamAtEntity(CreatorState.cam, ped, 0.0, 0.0, 0.55, true)
    SetCamActive(CreatorState.cam, true)
    RenderScriptCams(true, true, 500, true, true)
end

local function destroyCam()
    if CreatorState.cam then
        RenderScriptCams(false, true, 400, true, true)
        DestroyCam(CreatorState.cam, false)
        CreatorState.cam = nil
    end
end

function OpenCharacterCreator(info)
    if CreatorState.active then return end
    CreatorState.active = true
    CreatorState.name = (info and info.suggested) or ''
    for i = 0, 19 do
        CreatorState.faceFeatures[tostring(i)] = 0.0
    end
    CreatorState.overlays = {}
    CreatorState.hair = 0
    CreatorState.hairColor = 0
    CreatorState.hairHighlight = 0
    CreatorState.eyeColor = 0
    CreatorState.slot = info and tonumber(info.slot) or nil

    DoScreenFadeOut(300)
    Wait(350)

    local c = loadFranklinInterior()
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, c.x, c.y, c.z, false, false, false)
    SetEntityHeading(ped, c.w or 113.0)

    -- Wait for interior/collision so you don't fall through
    local t = 0
    RequestCollisionAtCoord(c.x, c.y, c.z)
    while not HasCollisionLoadedAroundEntity(ped) and t < 100 do
        Wait(50)
        t = t + 1
    end
    SetEntityCoordsNoOffset(ped, c.x, c.y, c.z, false, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetEntityVisible(ped, true, false)
    DisplayRadar(false)

    local existing = info and info.skin
    if type(existing) == 'table' then
        -- Resume / switch character with saved appearance
        if existing.headBlend then CreatorState.headBlend = existing.headBlend end
        if existing.faceFeatures then CreatorState.faceFeatures = existing.faceFeatures end
        if existing.overlays then CreatorState.overlays = existing.overlays end
        if existing.eyeColor then CreatorState.eyeColor = existing.eyeColor end
        if existing.hairColor then
            CreatorState.hairColor = existing.hairColor.primary or 0
            CreatorState.hairHighlight = existing.hairColor.highlight or 0
        end
        if existing.components and existing.components['2'] then
            CreatorState.hair = existing.components['2'].drawable or 0
        end
        CreatorState.gender = existing.gender
            or ((existing.modelName or existing.model or ''):find('mp_f') and 'female' or 'male')
        ApplySkin(existing)
        refreshHead()
    else
        setGenderModel('male')
    end
    createCam()

    TriggerEvent('bsrp:client:closeLoadingScreen')
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    -- Interior is already loaded above; safe to reveal for creator camera
    DoScreenFadeIn(500)

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openCreator',
        data = {
            name = CreatorState.name,
            maxName = (info and info.maxName) or Config.MaxNameLength or 24,
            faceFeatures = Config.FaceFeatures,
            presets = {
                male = Config.Presets.male,
                female = Config.Presets.female,
            },
            isNew = info and info.isNew,
            logout = info and info.logout,
            slot = CreatorState.slot,
        },
    })
end

function CloseCharacterCreator()
    CreatorState.active = false
    SetNuiFocus(false, false)
    destroyCam()
    DisplayRadar(true)
    SendNUIMessage({ action = 'closeCreator' })
end

RegisterNetEvent('bsrp-characters:client:openCreator', function(info)
    OpenCharacterCreator(info or {})
end)

-- NUI callbacks
RegisterNUICallback('creator:setGender', function(data, cb)
    setGenderModel(data and data.gender or 'male')
    createCam()
    cb({ ok = true })
end)

RegisterNUICallback('creator:update', function(data, cb)
    if not data then cb({ ok = false }) return end

    if data.headBlend then
        for k, v in pairs(data.headBlend) do
            CreatorState.headBlend[k] = v
        end
    end
    if data.faceFeature and data.faceFeature.id ~= nil then
        CreatorState.faceFeatures[tostring(data.faceFeature.id)] = data.faceFeature.value + 0.0
    end
    if data.faceFeatures then
        for k, v in pairs(data.faceFeatures) do
            CreatorState.faceFeatures[tostring(k)] = v + 0.0
        end
    end
    if data.hair ~= nil then CreatorState.hair = tonumber(data.hair) or 0 end
    if data.hairColor ~= nil then CreatorState.hairColor = tonumber(data.hairColor) or 0 end
    if data.hairHighlight ~= nil then CreatorState.hairHighlight = tonumber(data.hairHighlight) or 0 end
    if data.eyeColor ~= nil then CreatorState.eyeColor = tonumber(data.eyeColor) or 0 end
    if data.overlay then
        local o = data.overlay
        CreatorState.overlays[tostring(o.id)] = {
            index = o.index or 255,
            opacity = o.opacity or 1.0,
            colorType = o.colorType or 1,
            firstColor = o.firstColor or 0,
            secondColor = o.secondColor or 0,
        }
    end
    if data.preset then
        ApplyPresetComponents(CreatorState.gender, data.preset)
    end
    if data.rotate then
        local ped = PlayerPedId()
        SetEntityHeading(ped, GetEntityHeading(ped) + (data.rotate + 0.0))
    end

    refreshHead()
    cb({ ok = true })
end)

RegisterNUICallback('creator:finish', function(data, cb)
    local name = data and data.name or CreatorState.name
    if not name or #name:gsub('%s', '') < 2 then
        cb({ ok = false, error = 'name' })
        return
    end

    refreshHead()
    local skin = CaptureSkin()
    skin.gender = CreatorState.gender
    skin.headBlend = CreatorState.headBlend
    skin.faceFeatures = CreatorState.faceFeatures
    skin.overlays = CreatorState.overlays
    skin.eyeColor = CreatorState.eyeColor

    local slot = data and tonumber(data.slot) or CreatorState.slot

    CloseCharacterCreator()
    DoScreenFadeOut(300)
    Wait(350)

    TriggerServerEvent('bsrp-characters:server:create', name, skin, slot)
    cb({ ok = true })
end)

RegisterNUICallback('creator:cancel', function(_, cb)
    CloseCharacterCreator()
    -- Back to multi-character select (never leave player stuck in create)
    TriggerServerEvent('bsrp-characters:server:requestSelect')
    cb({ ok = true })
end)
