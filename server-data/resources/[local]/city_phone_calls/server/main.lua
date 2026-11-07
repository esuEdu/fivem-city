-- Loads the server modules in order and creates the tables
local store = require 'server.store'

require 'server.calls'

CreateThread(store.init)
