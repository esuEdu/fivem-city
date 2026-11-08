-- Finds the props other resources stream (.ydr drawables, .yft fragments) so the editor lists them under "Custom".
-- Runs once at start with the system's file listing; vehicles (a .yft with a _hi sibling) and LODs are left out.
local streams = { models = {} }

local function listCommand(root)
    if package.config:sub(1, 1) == '\\' then
        return ('dir /s /b "%s\\*.ydr" "%s\\*.yft" 2>nul'):format(root, root)
    end

    return ("find '%s' -type f \\( -iname '*.ydr' -o -iname '*.yft' \\) 2>/dev/null"):format(root:gsub("'", "'\\''"))
end

function streams.scan()
    local own = GetResourcePath(cache.resource)
    local root = own and own:gsub('[/\\][^/\\]+[/\\][^/\\]+$', '')

    if not root or not io or not io.popen then
        lib.print.warn('city_builder: cannot list stream files here, the Custom list stays empty')
        return
    end

    local ok, output = pcall(function()
        local handle = io.popen(listCommand(root))
        if not handle then return end

        local text = handle:read('a')
        handle:close()

        return text
    end)

    if not ok or not output then
        lib.print.warn(('city_builder: listing stream files failed (%s)'):format(tostring(output)))
        return
    end

    local drawables, fragments = {}, {}

    for path in output:gmatch('[^\r\n]+') do
        local name, ext = path:match('([^/\\]+)%.(%a+)$')
        name, ext = name and name:lower(), ext and ext:lower()

        if name and name:match('^[%w_%-]+$') and #name <= 64 and not name:match('_s?lod%d*$') then
            if ext == 'ydr' then
                drawables[name] = true
            elseif ext == 'yft' then
                fragments[name] = true
            end
        end
    end

    local seen, models = {}, {}

    local function add(name)
        if seen[name] then return end
        seen[name] = true
        models[#models + 1] = name
    end

    for name in pairs(drawables) do add(name) end

    for name in pairs(fragments) do
        local base = name:match('^(.+)_hi$')
        if not base and not fragments[name .. '_hi'] then add(name) end
    end

    table.sort(models)
    streams.models = models

    lib.print.info(('city_builder: %d streamed props found'):format(#models))
end

return streams
