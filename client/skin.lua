--[[
    Apply / capture freemode appearance (clothing-compatible + face data)
]]

local function requestModel(name)
    local hash = type(name) == 'number' and name or joaat(name)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do
        Wait(10)
        t = t + 1
    end
    return HasModelLoaded(hash), hash
end

function ApplySkin(skin)
    if type(skin) ~= 'table' then return false end

    local modelName = skin.modelName or skin.model or 'mp_m_freemode_01'
    local ok, hash = requestModel(modelName)
    if not ok then return false end

    SetPlayerModel(PlayerId(), hash)
    SetModelAsNoLongerNeeded(hash)

    local ped = PlayerPedId()
    SetPedDefaultComponentVariation(ped)

    -- Head blend
    local hb = skin.headBlend
    if type(hb) == 'table' then
        SetPedHeadBlendData(
            ped,
            hb.shapeFirst or 0, hb.shapeSecond or 0, hb.shapeThird or 0,
            hb.skinFirst or 0, hb.skinSecond or 0, hb.skinThird or 0,
            (hb.shapeMix or 0.5) + 0.0,
            (hb.skinMix or 0.5) + 0.0,
            (hb.thirdMix or 0.0) + 0.0,
            false
        )
    end

    -- Face features
    if type(skin.faceFeatures) == 'table' then
        for i = 0, 19 do
            local v = skin.faceFeatures[tostring(i)] or skin.faceFeatures[i]
            if v ~= nil then
                SetPedFaceFeature(ped, i, v + 0.0)
            end
        end
    end

    -- Overlays (beard, makeup, etc.)
    if type(skin.overlays) == 'table' then
        for i = 0, 12 do
            local o = skin.overlays[tostring(i)] or skin.overlays[i]
            if o then
                local idx = o.index or 255
                local opacity = o.opacity or 1.0
                SetPedHeadOverlay(ped, i, idx, opacity + 0.0)
                if o.colorType and o.firstColor then
                    SetPedHeadOverlayColor(ped, i, o.colorType, o.firstColor or 0, o.secondColor or 0)
                end
            end
        end
    end

    -- Components (clothing)
    if type(skin.components) == 'table' then
        for i = 0, 11 do
            local c = skin.components[tostring(i)] or skin.components[i]
            if c then
                local drawable = c.drawable or c[1] or 0
                local texture = c.texture or c[2] or 0
                local palette = c.palette or c[3] or 0
                SetPedComponentVariation(ped, i, drawable, texture, palette)
            end
        end
    end

    -- Props
    if type(skin.props) == 'table' then
        for _, prop in ipairs({ 0, 1, 2, 6, 7 }) do
            local p = skin.props[tostring(prop)] or skin.props[prop]
            if p then
                local drawable = p.drawable or p[1] or -1
                if drawable < 0 then
                    ClearPedProp(ped, prop)
                else
                    SetPedPropIndex(ped, prop, drawable, p.texture or p[2] or 0, true)
                end
            end
        end
    end

    if skin.hairColor then
        SetPedHairColor(ped, skin.hairColor.primary or 0, skin.hairColor.highlight or 0)
    end

    if skin.eyeColor ~= nil then
        SetPedEyeColor(ped, skin.eyeColor)
    end

    return true
end

function CaptureSkin()
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    local modelName = 'mp_m_freemode_01'
    if model == `mp_f_freemode_01` then
        modelName = 'mp_f_freemode_01'
    elseif model == `mp_m_freemode_01` then
        modelName = 'mp_m_freemode_01'
    end

    local components = {}
    for i = 0, 11 do
        components[tostring(i)] = {
            drawable = GetPedDrawableVariation(ped, i),
            texture = GetPedTextureVariation(ped, i),
            palette = GetPedPaletteVariation(ped, i),
        }
    end

    local props = {}
    for _, prop in ipairs({ 0, 1, 2, 6, 7 }) do
        local d = GetPedPropIndex(ped, prop)
        props[tostring(prop)] = {
            drawable = d,
            texture = d >= 0 and GetPedPropTextureIndex(ped, prop) or 0,
        }
    end

    local faceFeatures = {}
    for i = 0, 19 do
        faceFeatures[tostring(i)] = GetPedFaceFeature(ped, i)
    end

    -- Head blend (native returns via memory; use stored CreatorState if available)
    local headBlend = CreatorState and CreatorState.headBlend or {
        shapeFirst = 0, shapeSecond = 0, shapeThird = 0,
        skinFirst = 0, skinSecond = 0, skinThird = 0,
        shapeMix = 0.5, skinMix = 0.5, thirdMix = 0.0,
    }

    local overlays = CreatorState and CreatorState.overlays or {}

    return {
        model = modelName,
        modelName = modelName,
        gender = modelName == 'mp_f_freemode_01' and 'female' or 'male',
        components = components,
        props = props,
        hairColor = {
            primary = GetPedHairColor(ped),
            highlight = GetPedHairHighlightColor(ped),
        },
        headBlend = headBlend,
        faceFeatures = faceFeatures,
        overlays = overlays,
        eyeColor = CreatorState and CreatorState.eyeColor or 0,
    }
end

function ApplyPresetComponents(gender, presetKey)
    local bag = Config.Presets[gender]
    if not bag then return end
    local preset = bag[presetKey]
    if not preset or not preset.components then return end
    local ped = PlayerPedId()
    for comp, data in pairs(preset.components) do
        local drawable = data[1] or data.drawable or 0
        local texture = data[2] or data.texture or 0
        SetPedComponentVariation(ped, tonumber(comp), drawable, texture, 0)
    end
end

exports('ApplySkin', ApplySkin)
exports('CaptureSkin', CaptureSkin)
