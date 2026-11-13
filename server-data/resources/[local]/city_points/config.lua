Config = {}

-- Default key to use the point the player is at (players can rebind it in GTA's key settings, FiveM section)
Config.Key = 'E'

-- Meters: the icon fades in within ShowDistance; the key works within UseDistance
Config.ShowDistance = 3.0
Config.UseDistance = 1.5

-- Where the icon floats for a vec4 point (where the player stands, facing the thing): Ahead meters towards the
-- heading and Height meters up. A vec3 point only gets the Height. Keep Ahead small: a player standing against a wall
-- is only ~0.3 m from it, and an icon pushed past the wall shows in the next room.
Config.Ahead = 0.12
Config.Height = 0.5

-- Badge height as a share of the screen height, close up (it shrinks to 70% at ShowDistance)
Config.Size = 0.04

-- How often (ms) a nearby point checks access and whether a wall is in the way
Config.CheckMs = 250

-- Icons in icons/<name>.png (white on transparent, 128x128; scripts/point-icons.mjs draws them)
Config.Icons = { 'weapon', 'locker', 'shirt', 'clock', 'car', 'basket' }

-- Height of the icon for a point added with ped = true (garage keepers, shop clerks), over the ped's coords
Config.PedHeight = 1.15

-- Ped points: players stand a little away from a ped (and the icon is higher), so both distances are longer
Config.PedShowDistance = 4.5
Config.PedUseDistance = 2.5
