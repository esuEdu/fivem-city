Config = {}

-- Where the character select and the creator happen: the police lineup room under Mission Row, always loaded and
-- out of everyone's way (players are also in a solo session until they spawn)
Config.Studio = {
    ped = vector4(402.87, -996.55, -99.0, 180.0),
    idle = {
        m = { dict = 'mp_character_creation@customise@male_a', anim = 'loop' },
        f = { dict = 'mp_character_creation@customise@female_a', anim = 'loop' },
    },
}

-- Camera shots, relative to the ped: distance in front, height above the ped's origin, field of view
Config.Cameras = {
    face = { distance = 0.75, height = 0.66, fov = 28.0 },
    torso = { distance = 1.5, height = 0.3, fov = 34.0 },
    body = { distance = 2.9, height = 0.0, fov = 40.0 },
    feet = { distance = 1.4, height = -0.65, fov = 34.0 },
}

-- Studio lights drawn while the screen is open. Each light: offset from the ped (right, forward, up), color, range, intensity
Config.Lights = {
    studio = {
        { offset = vector3(-1.2, 1.6, 1.4), color = { 255, 244, 230 }, range = 5.0, intensity = 6.0 },
        { offset = vector3(1.4, 1.2, 0.9), color = { 200, 215, 255 }, range = 5.0, intensity = 2.5 },
        { offset = vector3(0.0, -1.2, 1.8), color = { 255, 255, 255 }, range = 4.0, intensity = 4.0 },
    },
    warm = {
        { offset = vector3(-1.2, 1.6, 1.3), color = { 255, 190, 120 }, range = 5.0, intensity = 6.0 },
        { offset = vector3(1.4, 1.0, 0.8), color = { 255, 150, 90 }, range = 5.0, intensity = 2.0 },
        { offset = vector3(0.0, -1.2, 1.8), color = { 255, 210, 160 }, range = 4.0, intensity = 3.0 },
    },
    night = {
        { offset = vector3(-1.2, 1.6, 1.3), color = { 140, 170, 255 }, range = 5.0, intensity = 4.0 },
        { offset = vector3(1.4, 1.0, 0.8), color = { 190, 110, 255 }, range = 5.0, intensity = 2.5 },
        { offset = vector3(0.0, -1.2, 1.8), color = { 90, 200, 255 }, range = 4.0, intensity = 4.0 },
    },
    daylight = {
        { offset = vector3(-1.0, 1.8, 1.6), color = { 255, 255, 250 }, range = 6.0, intensity = 9.0 },
        { offset = vector3(1.2, 1.6, 1.0), color = { 255, 255, 255 }, range = 6.0, intensity = 5.0 },
        { offset = vector3(0.0, -1.2, 1.8), color = { 255, 255, 255 }, range = 4.0, intensity = 3.0 },
    },
}

-- Grabbable points drawn over the face. offset is from the head bone (right, forward, up) in metres; dragging moves
-- the feature named in x (left/right) and y (up/down, the same way as the pads). mirror flips x on the left half of the face
Config.FacePoints = {
    { id = 'brows', label = 'Brows', offset = vector3(0.035, 0.085, 0.075), x = 'eyeBrownForward', y = 'eyeBrownHigh' },
    { id = 'eyes', label = 'Eyes', offset = vector3(-0.032, 0.09, 0.045), x = 'eyesOpening' },
    { id = 'bridge', label = 'Nose bridge', offset = vector3(0.0, 0.1, 0.05), x = 'noseBoneTwist', y = 'noseBoneHigh' },
    { id = 'nose', label = 'Nose tip', offset = vector3(0.0, 0.12, 0.015), x = 'noseWidth', y = 'nosePeakHigh' },
    { id = 'nostril', label = 'Nose length', offset = vector3(0.0, 0.11, -0.005), x = 'nosePeakSize', y = 'nosePeakLowering' },
    { id = 'cheekbone', label = 'Cheekbones', offset = vector3(-0.055, 0.07, 0.02), x = 'cheeksBoneWidth', y = 'cheeksBoneHigh', mirror = true },
    { id = 'cheek', label = 'Cheeks', offset = vector3(0.06, 0.055, -0.015), x = 'cheeksWidth' },
    { id = 'lips', label = 'Lips', offset = vector3(0.0, 0.105, -0.035), y = 'lipsThickness' },
    { id = 'jaw', label = 'Jaw', offset = vector3(-0.06, 0.03, -0.055), x = 'jawBoneWidth', y = 'jawBoneBackSize', mirror = true },
    { id = 'chin', label = 'Chin', offset = vector3(0.0, 0.085, -0.085), x = 'chinBoneSize', y = 'chinBoneLowering' },
    { id = 'chinTip', label = 'Chin shape', offset = vector3(0.025, 0.09, -0.075), x = 'chinHole', y = 'chinBoneLenght' },
    { id = 'neck', label = 'Neck', offset = vector3(0.065, 0.0, -0.13), x = 'neckThickness' },
}

-- Starter looks shown as cards in the Clothes tab. Pieces: component id = { drawable, texture }, props = { [prop] = { drawable, texture } }.
-- Check them in game after adding addon clothing, which can shift the numbers.
Config.Outfits = {
    m = {
        {
            id = 'casual', label = 'Casual', icon = 'tee',
            components = { [11] = { 0, 0 }, [8] = { 15, 0 }, [3] = { 0, 0 }, [4] = { 0, 0 }, [6] = { 1, 0 } },
        },
        {
            id = 'street', label = 'Street', icon = 'hoodie',
            components = { [11] = { 7, 0 }, [8] = { 15, 0 }, [3] = { 0, 0 }, [4] = { 5, 0 }, [6] = { 7, 0 } },
        },
        {
            id = 'smart', label = 'Smart', icon = 'shirt',
            components = { [11] = { 13, 0 }, [8] = { 15, 0 }, [3] = { 11, 0 }, [4] = { 10, 0 }, [6] = { 10, 0 } },
        },
        {
            id = 'suit', label = 'Suit', icon = 'suit',
            components = { [11] = { 4, 0 }, [8] = { 4, 0 }, [3] = { 4, 0 }, [4] = { 10, 0 }, [6] = { 10, 0 }, [7] = { 10, 0 } },
        },
        {
            id = 'sport', label = 'Sport', icon = 'run',
            components = { [11] = { 5, 0 }, [8] = { 15, 0 }, [3] = { 5, 0 }, [4] = { 6, 0 }, [6] = { 1, 0 } },
        },
        {
            id = 'work', label = 'Workwear', icon = 'tool',
            components = { [11] = { 22, 0 }, [8] = { 15, 0 }, [3] = { 0, 0 }, [4] = { 9, 0 }, [6] = { 25, 0 } },
        },
    },
    f = {
        {
            id = 'casual', label = 'Casual', icon = 'tee',
            components = { [11] = { 0, 0 }, [8] = { 14, 0 }, [3] = { 0, 0 }, [4] = { 0, 0 }, [6] = { 1, 0 } },
        },
        {
            id = 'street', label = 'Street', icon = 'hoodie',
            components = { [11] = { 3, 0 }, [8] = { 14, 0 }, [3] = { 3, 0 }, [4] = { 4, 0 }, [6] = { 4, 0 } },
        },
        {
            id = 'smart', label = 'Smart', icon = 'shirt',
            components = { [11] = { 9, 0 }, [8] = { 14, 0 }, [3] = { 9, 0 }, [4] = { 6, 0 }, [6] = { 13, 0 } },
        },
        {
            id = 'dress', label = 'Dress', icon = 'dress',
            components = { [11] = { 21, 0 }, [8] = { 14, 0 }, [3] = { 15, 0 }, [4] = { 12, 0 }, [6] = { 6, 0 } },
        },
        {
            id = 'sport', label = 'Sport', icon = 'run',
            components = { [11] = { 10, 0 }, [8] = { 14, 0 }, [3] = { 10, 0 }, [4] = { 10, 0 }, [6] = { 1, 0 } },
        },
        {
            id = 'work', label = 'Workwear', icon = 'tool',
            components = { [11] = { 27, 0 }, [8] = { 14, 0 }, [3] = { 0, 0 }, [4] = { 3, 0 }, [6] = { 26, 0 } },
        },
    },
}

-- Clothes pieces the creator lets players change one by one, in order. kind = 'component' or 'prop'
Config.Pieces = {
    { kind = 'component', id = 11, label = 'Top' },
    { kind = 'component', id = 8, label = 'Undershirt' },
    { kind = 'component', id = 3, label = 'Arms' },
    { kind = 'component', id = 4, label = 'Pants' },
    { kind = 'component', id = 6, label = 'Shoes' },
    { kind = 'component', id = 7, label = 'Neck' },
    { kind = 'component', id = 5, label = 'Bag' },
    { kind = 'component', id = 1, label = 'Mask' },
    { kind = 'prop', id = 0, label = 'Hat' },
    { kind = 'prop', id = 1, label = 'Glasses' },
    { kind = 'prop', id = 2, label = 'Earrings' },
    { kind = 'prop', id = 6, label = 'Watch' },
    { kind = 'prop', id = 7, label = 'Bracelet' },
}

-- Drawables players can't pick here (uniforms, gear that belongs to a job). Per sex: [component or 'p'..prop] = { drawable, { from, to }, ... }
Config.Blocked = {
    m = {},
    f = {},
}

-- Eye colors offered (indices into the game's list); the rest are costume lenses
Config.EyeColors = 13
