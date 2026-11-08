Config = {}

Config.Item = 'phone'

-- Songs one character keeps, playlists and songs per playlist
Config.MaxTracks = 300
Config.MaxPlaylists = 30
Config.MaxPlaylistTracks = 100

Config.TitleLength = 100
Config.PlaylistNameLength = 40

-- Direct audio links must be https and end in one of these
Config.AudioExtensions = { 'mp3', 'ogg', 'wav', 'm4a', 'aac', 'webm' }
Config.UrlLength = 500

-- Searching YouTube by title (needs the server convar youtube_api_key): results per search, minutes a search is
-- remembered, and seconds between two searches from one player
Config.SearchResults = 15
Config.SearchCacheMinutes = 60
Config.SearchCooldown = 3
