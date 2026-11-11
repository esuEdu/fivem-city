dofile('harness.lua')

local look = require 'shared.look'

local entries = {
    TAT_A = { name = 'TAT_A', label = 'Skull', zone = 'ZONE_TORSO', collection = 'c1', hashMale = 'A_M', hashFemale = 'A_F' },
    TAT_B = { name = 'TAT_B', label = 'Rose', zone = 'ZONE_TORSO', collection = 'c1', hashMale = 'B_M', hashFemale = '' },
    TAT_C = { name = 'TAT_C', label = 'Anchor', zone = 'ZONE_LEFT_ARM', collection = 'c2', hashMale = 'C_M', hashFemale = 'C_F' },
    TAT_H = { name = 'TAT_H', label = 'Fade', zone = 'ZONE_HAIR', collection = 'c3', hashMale = 'H_M', hashFemale = 'H_F' },
}

local catalog = {
    get = function(name) return entries[name] end,
    hashFor = function(entry, sex)
        local hash = sex == 'f' and entry.hashFemale or entry.hashMale
        return hash ~= '' and hash or nil
    end,
}

local shop = {
    { id = 'torso', zone = 'ZONE_TORSO' },
    { id = 'leftArm', zone = 'ZONE_LEFT_ARM' },
}

local options = { prices = { tattoo = 200 }, maxPerZone = 3 }

local function skin(model, tattoos)
    return {
        model = model or 'mp_m_freemode_01',
        components = {},
        props = {},
        tattoos = tattoos or {
            ZONE_TORSO = { { name = 'TAT_A', label = 'Skull', zone = 'ZONE_TORSO', collection = 'c1', hashMale = 'A_M', hashFemale = 'A_F', opacity = 1.0 } },
            ZONE_HAIR = { { name = 'TAT_H', zone = 'ZONE_HAIR', collection = 'c3', hashMale = 'H_M', hashFemale = 'H_F', opacity = 1.0 } },
        },
    }
end

-- Nothing sent: nothing changes
local new, changes, total = look.buyTattoos(skin(), nil, shop, catalog, options)
check(new and #changes == 0 and total == 0, 'no tattoos sent')

-- Same list: nothing to pay
new, changes, total = look.buyTattoos(skin(), { ZONE_TORSO = { { name = 'TAT_A', opacity = 1 } } }, shop, catalog, options)
check(#changes == 0 and total == 0, 'same tattoos cost nothing')

-- A new tattoo is charged; the catalog fills in label, hashes and collection (never the client)
new, changes, total = look.buyTattoos(skin(), {
    ZONE_TORSO = { { name = 'TAT_A', opacity = 1 }, { name = 'TAT_B', opacity = 0.55 } },
    ZONE_LEFT_ARM = { { name = 'TAT_C', opacity = 1, collection = 'hacked' } },
}, shop, catalog, options)
check(total == 400 and #changes == 2, 'two new tattoos')
check(#new.tattoos.ZONE_TORSO == 2 and new.tattoos.ZONE_TORSO[2].label == 'Rose')
check(new.tattoos.ZONE_TORSO[2].opacity == 0.6, 'opacity rounded to a tenth')
check(new.tattoos.ZONE_LEFT_ARM[1].collection == 'c2', 'collection from the catalog')
check(#new.tattoos.ZONE_HAIR == 1, 'zones the shop does not sell are kept')

-- Removing and changing intensity are free
new, changes, total = look.buyTattoos(skin(), { ZONE_TORSO = {} }, shop, catalog, options)
check(total == 0 and #changes == 1 and changes[1].removed and #new.tattoos.ZONE_TORSO == 0, 'removal free')
new, changes, total = look.buyTattoos(skin(), { ZONE_TORSO = { { name = 'TAT_A', opacity = 0.3 } } }, shop, catalog, options)
check(total == 0 and #changes == 1 and new.tattoos.ZONE_TORSO[1].opacity == 0.3, 'intensity change free')

-- Refused: wrong zone, other sex only, unknown, duplicate, too many, bad opacity, zone not sold here
local function refused(wanted, model)
    return not look.buyTattoos(skin(model), wanted, shop, catalog, options)
end
check(refused({ ZONE_TORSO = { { name = 'TAT_C', opacity = 1 } } }), 'tattoo in the wrong zone')
check(refused({ ZONE_TORSO = { { name = 'TAT_B', opacity = 1 } } }, 'mp_f_freemode_01'), 'male-only tattoo on a woman')
check(refused({ ZONE_TORSO = { { name = 'NOPE', opacity = 1 } } }), 'unknown tattoo')
check(refused({ ZONE_TORSO = { { name = 'TAT_A', opacity = 1 }, { name = 'TAT_A', opacity = 1 } } }), 'duplicate')
check(refused({ ZONE_TORSO = { { name = 'TAT_A', opacity = 0 } } }), 'opacity under 0.1')
check(refused({ ZONE_TORSO = { { name = 'TAT_A', opacity = 2 } } }), 'opacity over 1')
check(refused({ ZONE_TORSO = { {}, {}, {}, {} } }), 'more than maxPerZone')
check(refused({ ZONE_TORSO = 'x' }), 'zone not a list')
new, changes = look.buyTattoos(skin(), { ZONE_HAIR = {} }, shop, catalog, options)
check(#new.tattoos.ZONE_HAIR == 1 and #changes == 0, 'a zone this shop does not sell is ignored')
check(refused({}, 'a_m_y_hipster_01'), 'ped models can not get tattoos')

-- An owned tattoo the catalog no longer has stays
local old = skin(nil, { ZONE_TORSO = { { name = 'GONE', zone = 'ZONE_TORSO', collection = 'x', hashMale = 'G', opacity = 1 } } })
new, changes, total = look.buyTattoos(old, { ZONE_TORSO = { { name = 'GONE', opacity = 1 } } }, shop, catalog, options)
check(new and total == 0 and new.tattoos.ZONE_TORSO[1].name == 'GONE', 'owned tattoo kept after a catalog change')

print('city_clothing tattoos: ok')
