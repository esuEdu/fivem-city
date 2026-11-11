dofile('harness.lua')

local look = require 'shared.look'

local clothing = {
    { id = 'tops', kind = 'component', slot = 11 },
    { id = 'pants', kind = 'component', slot = 4 },
    { id = 'hats', kind = 'prop', slot = 0 },
}

local withArms = {
    { id = 'tops', kind = 'component', slot = 11 },
    { id = 'arms', kind = 'component', slot = 3, freeWith = { 'tops' } },
}

local barber = {
    { id = 'hair', kind = 'hair', slot = 2 },
    { id = 'beard', kind = 'overlay', slot = 1, sex = 'm' },
    { id = 'makeup', kind = 'overlay', slot = 4 },
}

local options = {
    prices = { arms = 40, tops = 120, pants = 90, hats = 45, hair = 60, beard = 30, makeup = 35 },
    blocked = { m = { [11] = { 55, { 100, 110 } }, p0 = { 46 } }, f = {} },
}

local function skin(model)
    return {
        model = model or 'mp_m_freemode_01',
        components = {
            { component_id = 0, drawable = 0, texture = 0 },
            { component_id = 2, drawable = 4, texture = 0 },
            { component_id = 11, drawable = 4, texture = 0 },
            { component_id = 4, drawable = 10, texture = 2 },
        },
        props = { { prop_id = 0, drawable = -1, texture = -1 } },
        hair = { style = 4, texture = 0, color = 3, highlight = 3 },
        headOverlays = { beard = { style = 0, opacity = 0, color = 0, secondColor = 0 } },
        faceFeatures = { noseWidth = 0.2 },
    }
end

local function find(list, key, id)
    for i = 1, #list do
        if list[i][key] == id then return list[i] end
    end
end

-- Nothing changed: nothing to pay
local new, changes, total = look.buy(skin(), {
    components = { ['11'] = { drawable = 4, texture = 0 }, ['4'] = { drawable = 10, texture = 2 } },
    props = { ['0'] = { drawable = -1, texture = -1 } },
}, clothing, options)
check(new and #changes == 0 and total == 0, 'same look costs nothing')

-- A new top and a hat: two categories charged, pants untouched
new, changes, total = look.buy(skin(), {
    components = { ['11'] = { drawable = 20, texture = 3 }, ['4'] = { drawable = 10, texture = 2 } },
    props = { ['0'] = { drawable = 7, texture = 1 } },
}, clothing, options)
check(new and total == 165 and #changes == 2, 'top + hat priced from the server table')
check(find(new.components, 'component_id', 11).drawable == 20)
check(find(new.components, 'component_id', 11).texture == 3)
check(find(new.props, 'prop_id', 0).drawable == 7)
check(new.faceFeatures.noseWidth == 0.2, 'the rest of the look is kept')

-- Arms fitted under a new top are free; arms alone are not
new, changes, total = look.buy(skin(), { components = { ['11'] = { drawable = 20, texture = 0 }, ['3'] = { drawable = 4, texture = 0 } } }, withArms, options)
check(total == 120 and #changes == 2, 'arms free with a top')
new, changes, total = look.buy(skin(), { components = { ['3'] = { drawable = 4, texture = 0 } } }, withArms, options)
check(total == 40, 'arms alone are charged')

-- Only a color change still counts as a change
new, changes, total = look.buy(skin(), { components = { ['4'] = { drawable = 10, texture = 0 } } }, clothing, options)
check(total == 90, 'texture change is charged')

-- The saved look is never changed in place
local original = skin()
look.buy(original, { components = { ['11'] = { drawable = 1, texture = 0 } } }, clothing, options)
check(find(original.components, 'component_id', 11).drawable == 4, 'input skin untouched')

-- A clothing store ignores barber fields, and the reverse
new, changes = look.buy(skin(), { hair = { style = 9, texture = 0, color = 1, highlight = 1 } }, clothing, options)
check(new and #changes == 0, 'clothing store does not cut hair')
new, changes = look.buy(skin(), { components = { ['11'] = { drawable = 1, texture = 0 } } }, barber, options)
check(new and #changes == 0, 'barber does not sell tops')

-- Hair also goes into component 2
new, changes, total = look.buy(skin(), { hair = { style = 9, texture = 1, color = 5, highlight = 6 } }, barber, options)
check(total == 60 and new.hair.style == 9 and find(new.components, 'component_id', 2).drawable == 9, 'hair')

-- Overlays: a beard on, then an undrawn overlay with another style number is not a change
new, changes, total = look.buy(skin(), { overlays = { beard = { style = 10, opacity = 0.8, color = 2, secondColor = 2 } } }, barber, options)
check(total == 30 and new.headOverlays.beard.style == 10, 'beard')
new, changes, total = look.buy(skin(), { overlays = { beard = { style = 7, opacity = 0, color = 0, secondColor = 0 } } }, barber, options)
check(#changes == 0, 'an overlay that is off is the same whatever its style')

-- Sex-only categories: a female look can't buy a beard
local female = skin('mp_f_freemode_01')
new, changes = look.buy(female, { overlays = { beard = { style = 10, opacity = 1, color = 0, secondColor = 0 } } }, barber, options)
check(new and #changes == 0, 'beard only for men')

-- Bad values are refused whole
check(not look.buy(skin(), { components = { ['11'] = { drawable = 1.5, texture = 0 } } }, clothing, options), 'fraction')
check(not look.buy(skin(), { components = { ['11'] = { drawable = -1, texture = 0 } } }, clothing, options), 'negative component')
check(not look.buy(skin(), { components = { ['11'] = 'x' } }, clothing, options), 'not a table')
check(not look.buy(skin(), { props = { ['0'] = { drawable = 3, texture = -1 } } }, clothing, options), 'prop texture')
check(not look.buy(skin(), { overlays = { makeUp = { style = 75, opacity = 1 } } }, barber, options), 'overlay past max')
check(not look.buy(skin(), { overlays = { makeUp = { style = 3, opacity = 2 } } }, barber, options), 'opacity past 1')
check(not look.buy(skin('a_m_y_hipster_01'), {}, clothing, options), 'ped models can not shop')
check(not look.buy(skin(), 'x', clothing, options), 'wanted must be a table')

-- Blocked pieces
check(not look.buy(skin(), { components = { ['11'] = { drawable = 55, texture = 0 } } }, clothing, options), 'blocked single')
check(not look.buy(skin(), { components = { ['11'] = { drawable = 105, texture = 0 } } }, clothing, options), 'blocked range')
check(not look.buy(skin(), { props = { ['0'] = { drawable = 46, texture = 0 } } }, clothing, options), 'blocked prop')
check(look.buy(skin(), { props = { ['0'] = { drawable = -1, texture = -1 } } }, clothing, options), 'taking a hat off is fine')

-- Floats with whole values (JSON) are saved as integers
new = look.buy(skin(), { components = { ['11'] = { drawable = 20.0, texture = 0.0 } } }, clothing, options)
check(find(new.components, 'component_id', 11).drawable == 20, 'whole floats accepted')

-- Outfits: clothes without face and hair, and back on
local components, props = look.outfitOf(skin())
check(not find(components, 'component_id', 0) and not find(components, 'component_id', 2), 'outfit leaves face and hair out')
check(find(components, 'component_id', 11).drawable == 4 and #props == 1)

local worn = look.wear(skin(), {
    { component_id = 11, drawable = 30, texture = 1 },
    { component_id = 2, drawable = 99, texture = 0 },
}, { { prop_id = 0, drawable = 5, texture = 0 } })
check(worn and find(worn.components, 'component_id', 11).drawable == 30, 'outfit top on')
check(find(worn.components, 'component_id', 2).drawable == 4, 'outfit never changes hair')
check(find(worn.props, 'prop_id', 0).drawable == 5)
check(not look.wear(skin(), { { component_id = 11, drawable = 'x', texture = 0 } }, {}), 'bad outfit row refused')
check(not look.wear(skin('a_m_y_hipster_01'), {}, {}), 'ped models can not wear outfits')

print('city_clothing look: ok')
