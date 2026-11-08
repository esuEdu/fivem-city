dofile('harness.lua')

local appearance = require 'shared.appearance'

local options = { blocked = { m = { [11] = { 55, { 100, 110 } }, p0 = { 46 } }, f = {} }, eyeColors = 13 }

local function draft(extra)
    local base = {
        sex = 'm',
        heritage = { mother = 21, father = 0, shapeMix = 0.5, skinMix = 0.25 },
        features = { noseWidth = 0.333, chinHole = -1 },
        overlays = { eyebrows = { style = 3, opacity = 1, color = 2, secondColor = 2 } },
        hair = { style = 4, texture = 1, color = 3, highlight = 5 },
        eyeColor = 2,
        components = { ['11'] = { drawable = 4, texture = 0 }, ['4'] = { drawable = 10, texture = 2 } },
        props = { ['0'] = { drawable = -1, texture = 0 }, ['1'] = { drawable = 5, texture = 1 } },
    }
    for k, v in pairs(extra or {}) do base[k] = v end
    return base
end

local function find(list, key, id)
    for i = 1, #list do
        if list[i][key] == id then return list[i] end
    end
end

-- A good draft becomes the illenium format
local look = assert(appearance.build(draft(), options))
check(look.model == 'mp_m_freemode_01')
check(look.headBlend.shapeFirst == 21 and look.headBlend.shapeSecond == 0)
check(look.headBlend.skinFirst == 21 and look.headBlend.skinSecond == 0, 'skin parents default to the shape parents')
check(look.faceFeatures.noseWidth == 0.33, 'floats rounded to two decimals')
check(look.faceFeatures.chinHole == -1)
check(look.faceFeatures.neckThickness == 0, 'missing features are 0')
check(#look.components == 12 and #look.props == 5)
check(find(look.components, 'component_id', 2).drawable == 4, 'hair goes into component 2')
check(find(look.components, 'component_id', 11).drawable == 4)
check(find(look.components, 'component_id', 4).texture == 2)
check(find(look.components, 'component_id', 6).drawable == 0, 'missing components are 0')
check(find(look.props, 'prop_id', 0).drawable == -1 and find(look.props, 'prop_id', 0).texture == -1)
check(find(look.props, 'prop_id', 1).drawable == 5)
check(find(look.props, 'prop_id', 6).drawable == -1, 'missing props are off')
check(look.headOverlays.eyebrows.style == 3)
check(look.headOverlays.beard.opacity == 0, 'missing overlays are off')
check(look.hair.highlight == 5 and look.eyeColor == 2)
check(next(look.tattoos) == nil)

-- Separate skin parents
local skin = assert(appearance.build(draft({ heritage = { mother = 21, father = 0, skinMother = 45, skinFather = 3, shapeMix = 0, skinMix = 1 } }), options))
check(skin.headBlend.skinFirst == 45 and skin.headBlend.skinSecond == 3)

-- Female model
check(appearance.build(draft({ sex = 'f' }), options).model == 'mp_f_freemode_01')

-- Refusals
check(not appearance.build(nil, options))
check(not appearance.build(draft({ sex = 'x' }), options))
check(not appearance.build(draft({ heritage = { mother = 46, father = 0, shapeMix = 0.5, skinMix = 0.5 } }), options))
check(not appearance.build(draft({ heritage = { mother = 1.5, father = 0, shapeMix = 0.5, skinMix = 0.5 } }), options))
check(not appearance.build(draft({ heritage = { mother = 1, father = 0, shapeMix = 2, skinMix = 0.5 } }), options))
check(not appearance.build(draft({ heritage = { mother = 1, father = 0, shapeMix = 0 / 0, skinMix = 0.5 } }), options), 'NaN')
check(not appearance.build(draft({ features = { noseWidth = 1.5 } }), options))
check(not appearance.build(draft({ features = { noseWidth = 'big' } }), options))
check(not appearance.build(draft({ overlays = { beard = { style = 29, opacity = 1 } } }), options), 'overlay style past the last one')
check(not appearance.build(draft({ overlays = { beard = { style = 1, opacity = -0.1 } } }), options))
check(not appearance.build(draft({ overlays = { beard = { style = 1, opacity = 1, color = 64 } } }), options))
check(not appearance.build(draft({ hair = { style = -1, texture = 0, color = 0, highlight = 0 } }), options))
check(not appearance.build(draft({ eyeColor = 13 }), options), 'costume lenses are not offered')
check(not appearance.build(draft({ components = { ['11'] = { drawable = 55, texture = 0 } } }), options), 'blocked drawable')
check(not appearance.build(draft({ components = { ['11'] = { drawable = 105, texture = 0 } } }), options), 'blocked range')
check(appearance.build(draft({ components = { ['11'] = { drawable = 111, texture = 0 } } }), options), 'past the range is fine')
check(not appearance.build(draft({ components = { ['11'] = { drawable = -1, texture = 0 } } }), options))
check(not appearance.build(draft({ components = { ['11'] = { drawable = 3, texture = 1000 } } }), options))
check(not appearance.build(draft({ props = { ['0'] = { drawable = 46, texture = 0 } } }), options), 'blocked prop')
check(not appearance.build(draft({ props = { ['1'] = { drawable = 3, texture = -1 } } }), options), 'a worn prop needs a texture')
check(appearance.build(draft({ sex = 'f', components = { ['11'] = { drawable = 55, texture = 0 } } }), options), 'block lists are per sex')
