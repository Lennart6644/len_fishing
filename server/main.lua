local ESX = exports['es_extended']:getSharedObject()
local Fishers = {}

local function notify(src, key, ...)
    TriggerClientEvent('esx:showNotification', src, L(key, ...))
end

local function rodKeyFromItem(itemName)
    for key, rod in pairs(Config.Rods) do
        if rod.item == itemName then
            return key
        end
    end
    return nil
end

local function findRod(src, state)
    local item = exports.ox_inventory:GetSlot(src, state.slot)
    if item and item.name == state.item then
        return item
    end
    return exports.ox_inventory:GetSlotWithItem(src, state.item)
end

local function getDurability(item)
    if not Config.Durability.enabled then
        return Config.Durability.max
    end
    local value = item.metadata and item.metadata.durability
    if value == nil then
        return Config.Durability.max
    end
    return value
end

local function setDurability(src, item, value)
    local metadata = item.metadata or {}
    metadata.durability = value
    exports.ox_inventory:SetMetadata(src, item.slot, metadata)
end

local function stopFishing(src, key)
    Fishers[src] = nil
    TriggerClientEvent('len_fishing:client:stop', src, key)
end

local function getBaits(src)
    local list = {}
    for _, key in ipairs(Config.BaitOrder) do
        local bait = Config.Baits[key]
        local count = exports.ox_inventory:GetItemCount(src, bait.item)
        if count and count > 0 then
            list[#list + 1] = { key = key, item = bait.item, label = L('bait.' .. key), count = count }
        end
    end
    return list
end

local function consumeBait(src, key)
    local bait = key and Config.Baits[key]
    if not bait then
        return false
    end
    if exports.ox_inventory:GetItemCount(src, bait.item) < 1 then
        return false
    end
    return exports.ox_inventory:RemoveItem(src, bait.item, 1) and true or false
end

local function rollAmount(fish)
    local mc = Config.MultiCatch[fish.group]
    if mc and math.random(100) <= mc.chance then
        return math.random(mc.min, mc.max)
    end
    return 1
end

local function rollFish(methodName, rodKey, baitKey)
    local m = Config.Methods[methodName]
    if math.random(100) <= m.noBiteChance then
        return nil
    end
    local tier = Config.RodTiers[rodKey]
    local bait = baitKey and Config.Baits[baitKey] or nil
    local pool = {}
    local total = 0
    for _, fish in ipairs(Config.Fish) do
        if tier >= Config.RodTiers[fish.minRod] then
            local weight = fish.chance
            if fish.minRod ~= 'amateur' then
                weight = weight * m.rareMultiplier
            end
            if bait and bait.multipliers[fish.group] then
                weight = weight * bait.multipliers[fish.group]
            end
            total = total + weight
            pool[#pool + 1] = { fish = fish, weight = weight }
        end
    end
    if total <= 0 then
        return nil
    end
    local roll = math.random() * total
    local acc = 0
    for _, entry in ipairs(pool) do
        acc = acc + entry.weight
        if roll <= acc then
            return entry.fish
        end
    end
    return pool[#pool].fish
end

local LightestFish = nil
for _, fish in ipairs(Config.Fish) do
    if not LightestFish or fish.weight < LightestFish.weight then
        LightestFish = fish
    end
end

local function inventoryFull(src)
    return not exports.ox_inventory:CanCarryItem(src, LightestFish.name, 1)
end

exports('useRod', function(event, item, inventory, slot, data)
    if event ~= 'usingItem' then
        return
    end
    local src = inventory.id
    if Fishers[src] then
        stopFishing(src, 'notify.stopped')
        return false
    end
    local rod = exports.ox_inventory:GetSlot(src, slot)
    if not rod then
        return false
    end
    local key = rodKeyFromItem(rod.name)
    if not key then
        return false
    end
    local durability = getDurability(rod)
    if durability <= 0 then
        notify(src, 'notify.rod_broken')
        return false
    end
    if inventoryFull(src) then
        notify(src, 'notify.inventory_full')
        return false
    end
    Fishers[src] = { slot = slot, item = rod.name, rod = key }
    TriggerClientEvent('len_fishing:client:begin', src, {
        rod = key,
        baits = getBaits(src),
        durability = durability,
        durMax = Config.Durability.max
    })
    return false
end)

RegisterNetEvent('len_fishing:server:cast', function(methodName, baitKey)
    local src = source
    local state = Fishers[src]
    if not state or state.pending then
        return
    end
    if not Config.Methods[methodName] or not Config.Methods[methodName].enabled then
        return stopFishing(src, 'notify.need_position')
    end
    local rod = findRod(src, state)
    if not rod then
        return stopFishing(src, 'notify.rod_missing')
    end
    state.slot = rod.slot
    if getDurability(rod) <= 0 then
        return stopFishing(src, 'notify.rod_broken')
    end
    if inventoryFull(src) then
        return stopFishing(src, 'notify.inventory_full')
    end

    local bait = baitKey and Config.Baits[baitKey] or nil
    local candidate = nil
    if bait and exports.ox_inventory:GetItemCount(src, bait.item) > 0 then
        candidate = baitKey
    end
    local fish = rollFish(methodName, state.rod, candidate)
    local amount = fish and rollAmount(fish) or 1
    if fish and not exports.ox_inventory:CanCarryItem(src, fish.name, amount) then
        return stopFishing(src, 'notify.inventory_full')
    end

    local usedBait = nil
    if candidate and consumeBait(src, candidate) then
        usedBait = candidate
    end
    if Config.BaitRequired and not usedBait then
        return stopFishing(src, 'notify.no_bait')
    end

    state.pending = { fish = fish, amount = amount }
    if Config.Debug then
        print(('[len_fishing] %s cast by %s -> %s'):format(methodName, src, fish and fish.name or 'nothing'))
    end
    TriggerClientEvent('len_fishing:client:castResult', src, {
        fish = fish and fish.name or nil,
        group = fish and fish.group or nil,
        amount = amount,
        baits = getBaits(src)
    })
end)

RegisterNetEvent('len_fishing:server:finish', function(success)
    local src = source
    local state = Fishers[src]
    if not state or not state.pending then
        return
    end
    local fish = state.pending.fish
    local amount = state.pending.amount or 1
    state.pending = nil

    local caught = false
    local full = false
    if success == true and fish then
        caught = exports.ox_inventory:AddItem(src, fish.name, amount) and true or false
        full = not caught
    end

    local rod = findRod(src, state)
    if not rod then
        return stopFishing(src, 'notify.rod_missing')
    end

    local value = getDurability(rod)
    if Config.Durability.enabled then
        value = math.max(0, value - Config.Durability.loss)
        setDurability(src, rod, value)
    end

    local stopKey = nil
    if value <= 0 then
        stopKey = 'notify.rod_broken'
    elseif full or inventoryFull(src) then
        stopKey = 'notify.inventory_full'
    end

    TriggerClientEvent('len_fishing:client:result', src, {
        fish = fish and fish.name or nil,
        amount = amount,
        caught = caught,
        full = full,
        durability = value,
        durMax = Config.Durability.max,
        baits = getBaits(src)
    })

    if stopKey then
        stopFishing(src, stopKey)
    end
end)

RegisterNetEvent('len_fishing:server:stop', function()
    Fishers[source] = nil
end)

RegisterNetEvent('len_fishing:server:sell', function()
    local src = source
    if not Config.Selling.enabled then
        return notify(src, 'notify.sell_disabled')
    end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then
        return
    end
    local total = 0
    for _, fish in ipairs(Config.Fish) do
        local count = exports.ox_inventory:GetItemCount(src, fish.name)
        if count > 0 and exports.ox_inventory:RemoveItem(src, fish.name, count) then
            total = total + math.floor(count * fish.price * Config.Selling.multiplier)
        end
    end
    if total <= 0 then
        return notify(src, 'notify.nothing_to_sell')
    end
    xPlayer.addAccountMoney(Config.Selling.account, total)
    notify(src, 'notify.sold', total)
end)

AddEventHandler('playerDropped', function()
    Fishers[source] = nil
end)
