--[[
    Skin format — same shape used by the clothing resource so both
    read/write bsrp_players.skin without conversion.

    {
      model / modelName: "mp_m_freemode_01" | "mp_f_freemode_01",
      components: { ["0"] = { drawable, texture, palette }, ... },
      props: { ["0"] = { drawable, texture }, ... },
      hairColor: { primary, highlight },
      headBlend: { shapeFirst, shapeSecond, shapeThird, skinFirst, skinSecond, skinThird, shapeMix, skinMix, thirdMix },
      faceFeatures: { ["0"] = float, ... },  -- -1.0 .. 1.0
      overlays: { ["1"] = { index, opacity, colorType, firstColor, secondColor }, ... },
      eyeColor: number,
      gender: "male" | "female",
    }
]]

SkinUtil = {}

function SkinUtil.Default(gender)
    gender = gender == 'female' and 'female' or 'male'
    local model = gender == 'female' and 'mp_f_freemode_01' or 'mp_m_freemode_01'
    local features = {}
    for i = 0, 19 do
        features[tostring(i)] = 0.0
    end
    return {
        model = model,
        modelName = model,
        gender = gender,
        components = {},
        props = {},
        hairColor = { primary = 0, highlight = 0 },
        headBlend = {
            shapeFirst = 0,
            shapeSecond = 0,
            shapeThird = 0,
            skinFirst = 0,
            skinSecond = 0,
            skinThird = 0,
            shapeMix = 0.5,
            skinMix = 0.5,
            thirdMix = 0.0,
        },
        faceFeatures = features,
        overlays = {},
        eyeColor = 0,
    }
end
