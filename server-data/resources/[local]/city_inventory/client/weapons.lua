-- The weapon in the player's hands. The ped only ever holds the one weapon equipped from the inventory.

local AMMO_CHECK_MS = 250
local AMMO_REPORT_MS = 1000

local weapons = {}

---@class EquippedWeapon
---@field name string
---@field serial string
---@field hash integer
---@field ammoname? string
---@field reported integer last ammo count the server knows about

---@type EquippedWeapon?
local current

---@type fun()?
local onChange

---Called whenever the weapon in hand changes (ox_inventory's currentWeapon event is fired from it).
---@param fn fun()
function weapons.onChange(fn)
    onChange = fn
end

---@param weapon EquippedWeapon
---@param force? boolean report even if the last report was under a second ago
---@param lastReport? integer
---@return integer? reportedAt
local function reportAmmo(weapon, force, lastReport)
    if not weapon.ammoname then return end

    local ammo = GetAmmoInPedWeapon(cache.ped, weapon.hash)
    if ammo >= weapon.reported then return end

    local now = GetGameTimer()
    if not force and lastReport and now - lastReport < AMMO_REPORT_MS then return end

    weapon.reported = ammo
    TriggerServerEvent('city_inventory:server:updateAmmo', weapon.serial, ammo)

    return now
end

---Polls ammo only while a weapon that uses ammo is equipped.
---@param weapon EquippedWeapon
local function trackAmmo(weapon)
    local lastReport

    while current == weapon do
        lastReport = reportAmmo(weapon, false, lastReport) or lastReport
        Wait(AMMO_CHECK_MS)
    end
end

---@return string? serial
function weapons.getSerial()
    return current and current.serial
end

function weapons.disarm()
    local weapon = current
    if not weapon then return end

    reportAmmo(weapon, true)
    current = nil

    SetPedCanSwitchWeapon(cache.ped, true)
    RemoveAllPedWeapons(cache.ped, true)
    SendNUIMessage({ action = 'equipped', serial = false })

    if onChange then onChange() end
end

---Puts the weapon away because something on this client asked for it (e.g. qbx_medical when going down).
function weapons.holster()
    if not current then return end

    reportAmmo(current, true)
    TriggerServerEvent('city_inventory:server:holster')
    weapons.disarm()
end

---@param data { name: string, serial: string, ammo?: integer, ammoname?: string }
function weapons.arm(data)
    weapons.disarm()

    local weapon = {
        name = data.name,
        serial = data.serial,
        hash = joaat(data.name),
        ammoname = data.ammoname,
        reported = data.ammo or 0,
    }

    current = weapon

    GiveWeaponToPed(cache.ped, weapon.hash, 0, false, true)
    SetPedAmmo(cache.ped, weapon.hash, weapon.reported)
    SetCurrentPedWeapon(cache.ped, weapon.hash, true)
    SetPedCanSwitchWeapon(cache.ped, false)
    SendNUIMessage({ action = 'equipped', serial = weapon.serial })

    if onChange then onChange() end

    if weapon.ammoname then
        CreateThread(function()
            trackAmmo(weapon)
        end)
    end
end

---Equips the weapon in `slot`, or puts it away when it's already in hand.
---@param slot integer
---@return boolean success
---@return string? reason
function weapons.toggle(slot)
    -- Report the shots fired before the server decides, so it has the right ammo count
    if current then reportAmmo(current, true) end

    local success, result = lib.callback.await('city_inventory:equip', false, slot)
    if not success then return false, result end

    if result then
        weapons.arm(result)
    else
        weapons.disarm()
    end

    return true
end

function weapons.reload()
    local weapon = current
    if not weapon or not weapon.ammoname then return end

    local ammo = GetAmmoInPedWeapon(cache.ped, weapon.hash)
    local clip = GetMaxAmmoInClip(cache.ped, weapon.hash, true)
    if ammo >= clip then return end

    local success, result = lib.callback.await('city_inventory:reload', false, weapon.serial, ammo, clip)
    if current ~= weapon then return end

    if not success then
        if result == 'no_ammo' then
            lib.notify({ description = locale('error_no_ammo'), type = 'error' })
        end
        return
    end

    weapon.reported = result
    SetPedAmmo(cache.ped, weapon.hash, result)
    MakePedReload(cache.ped)
end

-- Ammo comes only from the inventory: don't let the game switch weapons when the clip runs dry
SetWeaponsNoAutoswap(true)

RegisterNetEvent('city_inventory:client:disarm', weapons.disarm)

lib.onCache('ped', function()
    local weapon = current
    if not weapon then return end

    -- A new ped (e.g. after a model change) has no weapons: give ours back once the cache points at it
    current = nil

    SetTimeout(0, function()
        weapons.arm({ name = weapon.name, serial = weapon.serial, ammo = weapon.reported, ammoname = weapon.ammoname })
    end)
end)

return weapons
