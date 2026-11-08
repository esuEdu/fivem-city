export const FEATURES = {
    noseWidth: { label: 'Nose width', ends: ['Narrow', 'Wide'] },
    nosePeakHigh: { label: 'Tip height', ends: ['Up', 'Down'] },
    nosePeakSize: { label: 'Tip length', ends: ['Short', 'Long'] },
    noseBoneHigh: { label: 'Bridge height', ends: ['High', 'Low'] },
    nosePeakLowering: { label: 'Tip drop', ends: ['Up', 'Down'] },
    noseBoneTwist: { label: 'Bridge twist', ends: ['Left', 'Right'] },
    eyeBrownHigh: { label: 'Brow height', ends: ['High', 'Low'] },
    eyeBrownForward: { label: 'Brow depth', ends: ['Out', 'In'] },
    cheeksBoneHigh: { label: 'Cheekbone height', ends: ['High', 'Low'] },
    cheeksBoneWidth: { label: 'Cheekbone width', ends: ['Narrow', 'Wide'] },
    cheeksWidth: { label: 'Cheek fullness', ends: ['Full', 'Hollow'] },
    eyesOpening: { label: 'Eye opening', ends: ['Wide', 'Narrow'] },
    lipsThickness: { label: 'Lip fullness', ends: ['Full', 'Thin'] },
    jawBoneWidth: { label: 'Jaw width', ends: ['Narrow', 'Wide'] },
    jawBoneBackSize: { label: 'Jaw length', ends: ['Round', 'Square'] },
    chinBoneLowering: { label: 'Chin height', ends: ['Up', 'Down'] },
    chinBoneLenght: { label: 'Chin depth', ends: ['In', 'Out'] },
    chinBoneSize: { label: 'Chin width', ends: ['Narrow', 'Wide'] },
    chinHole: { label: 'Chin cleft', ends: ['None', 'Deep'] },
    neckThickness: { label: 'Neck thickness', ends: ['Thin', 'Thick'] },
};

// Face tab sections: a pad when a pair moves together, plain sliders for the rest
export const FACE_GROUPS = [
    { title: 'Nose', pads: [['noseWidth', 'nosePeakHigh'], ['noseBoneTwist', 'noseBoneHigh'], ['nosePeakSize', 'nosePeakLowering']] },
    { title: 'Brows & eyes', pads: [['eyeBrownForward', 'eyeBrownHigh']], sliders: ['eyesOpening'] },
    { title: 'Cheeks', pads: [['cheeksBoneWidth', 'cheeksBoneHigh']], sliders: ['cheeksWidth'] },
    { title: 'Lips', sliders: ['lipsThickness'] },
    { title: 'Jaw', pads: [['jawBoneWidth', 'jawBoneBackSize']] },
    { title: 'Chin', pads: [['chinBoneSize', 'chinBoneLowering'], ['chinHole', 'chinBoneLenght']] },
    { title: 'Neck', sliders: ['neckThickness'] },
];

export const OVERLAYS = {
    blemishes: 'Blemishes',
    beard: 'Facial hair',
    eyebrows: 'Eyebrows',
    ageing: 'Ageing',
    makeUp: 'Eye makeup',
    blush: 'Blush',
    complexion: 'Complexion',
    sunDamage: 'Sun damage',
    lipstick: 'Lipstick',
    moleAndFreckles: 'Moles & freckles',
    chestHair: 'Chest hair',
    bodyBlemishes: 'Body blemishes',
};

export const EYE_COLORS = [
    '#3d7a3a', '#2f8a66', '#7fb3d9', '#2b6ea6', '#9a6a3c', '#4e2f1c', '#7b6a2c',
    '#4d5257', '#a4abb3', '#d98aa8', '#d9c23c', '#7b4fb0', '#0b0b0b',
];

export const SHOTS = [
    { id: 'face', label: 'Face' },
    { id: 'torso', label: 'Upper body' },
    { id: 'body', label: 'Full body' },
    { id: 'feet', label: 'Shoes' },
];

export const LIGHTS = [
    { id: 'studio', label: 'Studio light', color: '#fff4e6' },
    { id: 'warm', label: 'Golden hour', color: '#ffb36b' },
    { id: 'night', label: 'Night', color: '#8c7bff' },
    { id: 'daylight', label: 'Daylight', color: '#ffffff' },
];

export const STEPS = {
    heritage: { title: 'Heritage', kicker: 'Step', hint: 'Pick the parents your character takes after, then blend their features and skin tone.', shot: 'face' },
    face: { title: 'Face', kicker: 'Sculpt', hint: 'Grab the points on the face and pull them, or drag the dots in the pads. Double-click anything to reset it.', shot: 'face' },
    skin: { title: 'Skin & eyes', kicker: 'Details', hint: 'Eye color and the marks that make a face look lived in.', shot: 'face' },
    hair: { title: 'Hair', kicker: 'Style', hint: 'Haircut, colors with highlights, brows and facial hair.', shot: 'face' },
    makeup: { title: 'Makeup', kicker: 'Style', hint: 'Eyes, cheeks and lips. Leave the opacity at zero for none.', shot: 'face' },
    clothes: { title: 'Clothes', kicker: 'Wardrobe', hint: 'Start from a look and change any piece. More clothes are sold in the city\'s shops.', shot: 'body' },
    identity: { title: 'Identity', kicker: 'Last step', hint: 'Who is this person? This goes on their ID card.', shot: 'torso' },
};

export const ERRORS = {
    firstname: 'Use 2 to 20 letters for the first name.',
    lastname: 'Use 2 to 20 letters for the last name.',
    birthdate: 'Pick a birth date in the allowed range.',
    nationality: 'Pick a nationality from the list.',
    create: 'The character could not be created. Try again.',
    look: 'The look could not be saved. Try again.',
    busy: 'Still working on it…',
    draft: 'Something went wrong with the look.',
};
