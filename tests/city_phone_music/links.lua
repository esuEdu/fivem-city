dofile('harness.lua')

local common = require 'server.common'

-- YouTube: every usual link gives the 11-character video id
local ID = 'dQw4w9WgXcQ'
check(common.youtubeId('https://www.youtube.com/watch?v=' .. ID) == ID, 'watch link')
check(common.youtubeId('https://youtu.be/' .. ID .. '?si=abc') == ID, 'short link')
check(common.youtubeId('https://www.youtube.com/watch?list=x&v=' .. ID .. '&t=3') == ID, 'v= after other parameters')
check(common.youtubeId('https://music.youtube.com/watch?v=' .. ID) == ID, 'YouTube Music link')
check(common.youtubeId('https://www.youtube.com/shorts/' .. ID) == ID, 'shorts link')
check(common.youtubeId(ID) == ID, 'a bare id')
check(common.youtubeId('https://example.com/watch?v=x') == nil, 'another site is refused')
check(common.youtubeId('short') == nil, 'not an id')
check(common.youtubeId(42) == nil, 'not a string')

-- Direct audio: https and a known extension only, nothing that could break out of an attribute
check(common.audioUrl('https://files.example.com/a/song.mp3') ~= nil, 'https mp3')
check(common.audioUrl('https://files.example.com/a/song.OGG?x=1') ~= nil, 'extension in any case, with a query')
check(common.audioUrl('http://files.example.com/song.mp3') == nil, 'plain http is refused')
check(common.audioUrl('https://files.example.com/song.exe') == nil, 'unknown extension is refused')
check(common.audioUrl('https://files.example.com/so"ng.mp3') == nil, 'quotes are refused')
check(common.audioUrl('https://files.example.com/' .. ('a'):rep(500) .. '.mp3') == nil, 'too long is refused')

finish()
