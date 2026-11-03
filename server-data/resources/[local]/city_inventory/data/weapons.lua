-- Plain data only: qbx_core also loads this file (bridge/qb/shared/main.lua), which expects Weapons, Components and Ammo.
-- Weapons: label, weight (grams), ammoname (ammo item it uses), clip (rounds one reload loads)
return {
    Weapons = {
        weapon_pistol = {
            label = 'Pistol',
            weight = 1130,
            ammoname = 'ammo-9',
            clip = 12,
        },

        weapon_knife = {
            label = 'Knife',
            weight = 300,
        },
    },

    Components = {},

    Ammo = {
        ['ammo-9'] = {
            label = '9mm',
            weight = 7,
        },
    },
}
