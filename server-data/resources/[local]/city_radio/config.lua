Config = {}

-- Names shown next to a channel number ("1 - LSPD"); others show only the number
Config.ChannelNames = {
    [1] = 'LSPD',
    [2] = 'LSPD 2',
    [3] = 'LSPD 3',
    [4] = 'EMS',
    [5] = 'LSPD + EMS',
}

-- /radiolist shows or hides the list, /radiolistmove lets the player drag and resize it (also bindable keys)
Config.Commands = { toggle = 'radiolist', move = 'radiolistmove' }

-- Width of the list in pixels: default and the range the player can resize it to
Config.Width = { default = 260, min = 200, max = 420 }
