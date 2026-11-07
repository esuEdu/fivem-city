dofile('harness.lua')

local apps = require 'server.apps'

local GLYPH = 'M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z'

local function app(fields)
    local data = { id = 'police_mdt', label = 'Police', page = 'web/index.html', icon = { glyph = GLYPH, colors = { '#7aa8ff', '#3f74f0', '#2149b8' } } }
    for key, value in pairs(fields or {}) do data[key] = value end
    return data
end

-- A good registration, with defaults filled in
local valid = assert(apps.validate('city_police', app()))
assert(valid.icon.glyphColor == '#ffffff' and valid.icon.tint == '#7aa8ff' and valid.order == 100 and valid.access == nil)

-- Bad ones say why
local bad = {
    app({ id = 'has space' }),
    app({ id = 'settings' }),
    app({ label = '' }),
    app({ label = ('x'):rep(25) }),
    app({ page = '../city_inventory/web/index.html' }),
    app({ page = '/web/index.html' }),
    app({ page = 'web/index.php' }),
    app({ page = 'web/x.html"><script>' }),
    app({ icon = { glyph = GLYPH, colors = { '#fff', '#000', '#123456' } } }),
    app({ icon = { glyph = 'M0 0"/><script>', colors = { '#7aa8ff', '#3f74f0', '#2149b8' } } }),
    app({ icon = { glyph = GLYPH, colors = { 'red; background:url(x)', '#3f74f0', '#2149b8' } } }),
    app({ access = 'police' }),
}

for i, data in ipairs(bad) do
    local result, reason = apps.validate('city_police', data)
    assert(result == nil and type(reason) == 'string', 'bad registration ' .. i)
end

-- Access rules are cleaned; an empty access table means everyone
local ruled = assert(apps.validate('x', app({ access = { jobs = { police = '2', bad = -1 }, staff = 'mod', unlock = 'burner' } })))
assert(ruled.access.jobs.police == 2 and ruled.access.jobs.bad == nil and ruled.access.staff == 'mod' and ruled.access.unlock == 'burner')
assert(apps.validate('x', app({ access = { jobs = {} } })).access == nil)

-- Registering: an id belongs to one resource
assert(apps.register('city_police', app({ access = { jobs = { police = 0 } }, order = 10 })))
assert(not apps.register('city_other', app()))
assert(apps.register('city_police', app({ access = { jobs = { police = 0 } }, order = 10 })))
assert(apps.register('city_burner', app({ id = 'burner', label = 'Burner', access = { unlock = 'burner' } })))
assert(apps.register('city_staff', app({ id = 'staff', label = 'Staff', access = { staff = 'mod' }, order = 5 })))
assert(apps.register('city_bank', app({ id = 'bank', label = 'Bank', order = 50 })))

local function viewer(job, grade, staff, unlocks)
    return {
        job = job and { name = job, grade = { level = grade or 0 } },
        gang = { name = 'none', grade = { level = 0 } },
        isStaff = function(ace) return staff == ace end,
        unlocks = unlocks or {},
    }
end

local function ids(list)
    local result = {}
    for i, entry in ipairs(list) do result[i] = entry.id end
    return table.concat(result, ',')
end

-- Who sees what (and in order)
assert(ids(apps.visible(viewer('unemployed'))) == 'bank')
assert(ids(apps.visible(viewer('police', 0))) == 'police_mdt,bank')
assert(ids(apps.visible(viewer('police', 0, 'mod'))) == 'staff,police_mdt,bank')
assert(ids(apps.visible(viewer('unemployed', 0, nil, { burner = true }))) == 'bank,burner')

-- The page gets the frame address and the hidden flag
local list = apps.visible(viewer('unemployed', 0, nil, { burner = true }))
assert(list[1].url == 'https://cfx-nui-city_bank/web/index.html' and list[1].hidden == false)
assert(list[2].hidden == true)

-- Grade limits
assert(apps.register('city_police', app({ access = { jobs = { police = 3 } } })))
assert(ids(apps.visible(viewer('police', 2))) == 'bank')
assert(ids(apps.visible(viewer('police', 3))) == 'bank,police_mdt')

-- A stopped resource takes its apps with it
assert(apps.removeResource('city_police'))
assert(not apps.removeResource('city_police'))
assert(apps.get('police_mdt') == nil)
