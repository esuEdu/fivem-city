-- The player's library (saved songs) and playlists. Every query is limited to the caller's own rows.
local common = require 'server.common'

local TRACK_COLUMNS = 't.`id`, t.`kind`, t.`ref`, t.`title`, t.`artist`'

lib.callback.register('city_phone_music:library', function(source)
    local citizenid = common.citizenid(source)
    if not citizenid then return end

    local tracks = MySQL.query.await(('SELECT %s FROM `phone_music_tracks` t WHERE t.`citizenid` = ? ORDER BY t.`id` DESC'):format(TRACK_COLUMNS), { citizenid }) or {}
    local playlists = MySQL.query.await([[
        SELECT p.`id`, p.`name`, (SELECT COUNT(*) FROM `phone_music_playlist_tracks` x WHERE x.`playlist_id` = p.`id`) AS `count`
        FROM `phone_music_playlists` p WHERE p.`citizenid` = ? ORDER BY p.`name`
    ]], { citizenid }) or {}

    return { tracks = tracks, playlists = playlists }
end)

-- kind 'youtube' (ref: a video id or link) or 'url' (a direct https audio link); saving the same song twice keeps one
lib.callback.register('city_phone_music:addTrack', function(source, kind, ref, title, artist)
    local src = source
    local citizenid = common.citizenid(src)
    if not citizenid or common.throttled(src, 'add', 500) then return false, 'invalid' end

    if kind == 'youtube' then ref = common.youtubeId(ref) elseif kind == 'url' then ref = common.audioUrl(ref) else ref = nil end
    title = common.text(title, Config.TitleLength)
    artist = common.text(artist or '', Config.TitleLength) or ''
    if not ref then return false, 'link' end
    if not title or title == '' then return false, 'title' end

    local existing = MySQL.scalar.await('SELECT `id` FROM `phone_music_tracks` WHERE `citizenid` = ? AND `kind` = ? AND `ref` = ?', { citizenid, kind, ref })
    if existing then return existing end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM `phone_music_tracks` WHERE `citizenid` = ?', { citizenid }) or 0
    if count >= Config.MaxTracks then return false, 'full' end

    return MySQL.insert.await('INSERT INTO `phone_music_tracks` (`citizenid`, `kind`, `ref`, `title`, `artist`, `created_at`) VALUES (?, ?, ?, ?, ?, ?)', {
        citizenid, kind, ref, title, artist, os.time(),
    })
end)

lib.callback.register('city_phone_music:removeTrack', function(source, id)
    local citizenid = common.citizenid(source)
    id = common.int(id)
    if not citizenid or not id then return false end

    local removed = MySQL.update.await('DELETE FROM `phone_music_tracks` WHERE `id` = ? AND `citizenid` = ?', { id, citizenid })
    if removed < 1 then return false end

    MySQL.update('DELETE FROM `phone_music_playlist_tracks` WHERE `track_id` = ?', { id })
    return true
end)

---The playlist if it belongs to the caller
local function ownPlaylist(citizenid, id)
    id = common.int(id)
    if not id then return end
    return MySQL.scalar.await('SELECT `id` FROM `phone_music_playlists` WHERE `id` = ? AND `citizenid` = ?', { id, citizenid })
end

lib.callback.register('city_phone_music:createPlaylist', function(source, name)
    local src = source
    local citizenid = common.citizenid(src)
    name = common.text(name, Config.PlaylistNameLength)
    if not citizenid or not name or name == '' or common.throttled(src, 'playlist', 1000) then return false, 'invalid' end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM `phone_music_playlists` WHERE `citizenid` = ?', { citizenid }) or 0
    if count >= Config.MaxPlaylists then return false, 'full' end

    return MySQL.insert.await('INSERT INTO `phone_music_playlists` (`citizenid`, `name`, `created_at`) VALUES (?, ?, ?)', { citizenid, name, os.time() })
end)

lib.callback.register('city_phone_music:renamePlaylist', function(source, id, name)
    local citizenid = common.citizenid(source)
    name = common.text(name, Config.PlaylistNameLength)
    if not citizenid or not name or name == '' then return false end

    id = ownPlaylist(citizenid, id)
    if not id then return false end

    return MySQL.update.await('UPDATE `phone_music_playlists` SET `name` = ? WHERE `id` = ?', { name, id }) >= 0
end)

lib.callback.register('city_phone_music:deletePlaylist', function(source, id)
    local citizenid = common.citizenid(source)
    if not citizenid then return false end

    id = ownPlaylist(citizenid, id)
    if not id then return false end

    MySQL.update.await('DELETE FROM `phone_music_playlist_tracks` WHERE `playlist_id` = ?', { id })
    MySQL.update.await('DELETE FROM `phone_music_playlists` WHERE `id` = ?', { id })
    return true
end)

lib.callback.register('city_phone_music:playlist', function(source, id)
    local citizenid = common.citizenid(source)
    if not citizenid then return end

    id = ownPlaylist(citizenid, id)
    if not id then return end

    return MySQL.query.await(([[
        SELECT %s FROM `phone_music_playlist_tracks` x JOIN `phone_music_tracks` t ON t.`id` = x.`track_id`
        WHERE x.`playlist_id` = ? ORDER BY x.`position`
    ]]):format(TRACK_COLUMNS), { id }) or {}
end)

lib.callback.register('city_phone_music:addToPlaylist', function(source, playlistId, trackId)
    local citizenid = common.citizenid(source)
    trackId = common.int(trackId)
    if not citizenid or not trackId then return false end

    playlistId = ownPlaylist(citizenid, playlistId)
    if not playlistId then return false end
    if not MySQL.scalar.await('SELECT 1 FROM `phone_music_tracks` WHERE `id` = ? AND `citizenid` = ?', { trackId, citizenid }) then return false end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM `phone_music_playlist_tracks` WHERE `playlist_id` = ?', { playlistId }) or 0
    if count >= Config.MaxPlaylistTracks then return false, 'full' end

    MySQL.insert.await('INSERT IGNORE INTO `phone_music_playlist_tracks` (`playlist_id`, `track_id`, `position`) VALUES (?, ?, ?)', {
        playlistId, trackId, count + 1,
    })

    return true
end)

lib.callback.register('city_phone_music:removeFromPlaylist', function(source, playlistId, trackId)
    local citizenid = common.citizenid(source)
    trackId = common.int(trackId)
    if not citizenid or not trackId then return false end

    playlistId = ownPlaylist(citizenid, playlistId)
    if not playlistId then return false end

    return MySQL.update.await('DELETE FROM `phone_music_playlist_tracks` WHERE `playlist_id` = ? AND `track_id` = ?', { playlistId, trackId }) > 0
end)
