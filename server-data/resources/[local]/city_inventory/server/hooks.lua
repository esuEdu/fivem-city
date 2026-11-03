-- ox_inventory's registerHook, for scripts that decide who may open their inventories (qbx_properties' house stashes).
-- Only the openInventory event is fired for now.

local hooks = {}

---@class InventoryHook
---@field id integer
---@field resource string
---@field fn function
---@field filter? string[] Lua patterns matched against the inventory id

---@type table<string, InventoryHook[]>
local registered = {}
local nextId = 0

---@param event string
---@param fn function
---@param options? { inventoryFilter?: string[] }
---@param resource string the resource that registered it, so its hooks go when it stops
---@return integer? id
function hooks.register(event, fn, options, resource)
    if type(event) ~= 'string' or not fn then return end

    nextId = nextId + 1
    registered[event] = registered[event] or {}
    registered[event][#registered[event] + 1] = {
        id = nextId,
        resource = resource,
        fn = fn,
        filter = type(options) == 'table' and options.inventoryFilter or nil,
    }

    return nextId
end

---@param resource string
---@param id? integer one hook, or all of the resource's when nil
function hooks.remove(resource, id)
    for _, list in pairs(registered) do
        for i = #list, 1, -1 do
            if list[i].resource == resource and (id == nil or list[i].id == id) then
                table.remove(list, i)
            end
        end
    end
end

---@param hook InventoryHook
---@param inventoryId string
---@return boolean
local function applies(hook, inventoryId)
    if not hook.filter then return true end

    for _, pattern in ipairs(hook.filter) do
        if inventoryId:find(pattern) then return true end
    end

    return false
end

---@param event string
---@param payload { inventoryId: string }
---@return boolean allowed false when a hook returned false
function hooks.run(event, payload)
    for _, hook in ipairs(registered[event] or {}) do
        if applies(hook, payload.inventoryId) then
            local ok, result = pcall(hook.fn, payload)

            if not ok then
                lib.print.error(('%s hook from %s failed: %s'):format(event, hook.resource, result))
                return false
            elseif result == false then
                return false
            end
        end
    end

    return true
end

AddEventHandler('onResourceStop', function(resource)
    hooks.remove(resource)
end)

return hooks
