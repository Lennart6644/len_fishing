local ESX = exports['es_extended']:getSharedObject()

local fishing = false
local phase = 'ready'
local method = nil
local rodKey = nil
local baits = {}
local baitIndex = 1
local durability = 0
local durMax = 100
local castResult = nil
local minigameResult = nil
local rodProp = nil
local biteAt = 0
local biteEnd = 0
local attemptFish = nil
local attemptGroup = nil
local lastPosCheck = 0

local function notify(msg)
    ESX.ShowNotification(msg)
end

local function clampBait()
    if #baits == 0 then
        baitIndex = 1
        return
    end
    if baitIndex > #baits then
        baitIndex = #baits
    end
    if baitIndex < 1 then
        baitIndex = 1
    end
end

local function findNearbyBoat()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        return nil
    end
    local pos = GetEntityCoords(ped)
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if Config.Methods.boat.vehicleClasses[GetVehicleClass(vehicle)] and #(pos - GetEntityCoords(vehicle)) <= Config.Methods.boat.boatRadius then
            return vehicle
        end
    end
    return nil
end

local function hasWater(x, y, z)
    local above = GetWaterHeight(x, y, z + 50.0)
    if above then
        return true
    end
    return GetWaterHeight(x, y, z - 50.0) == true
end

local function isFarFromShore(pos)
    local boat = Config.Methods.boat
    local n = boat.shoreProbes
    local land = {}
    local landCount = 0
    for i = 0, n - 1 do
        local angle = (2.0 * math.pi * i) / n
        local x = pos.x + math.cos(angle) * boat.minDistanceToShore
        local y = pos.y + math.sin(angle) * boat.minDistanceToShore
        land[i] = not hasWater(x, y, pos.z)
        if land[i] then
            landCount = landCount + 1
        end
    end
    local best = 0
    local run = 0
    for i = 0, 2 * n - 1 do
        if land[i % n] then
            run = run + 1
            if run > best then
                best = run
            end
        else
            run = 0
        end
    end
    local ownWater = hasWater(pos.x, pos.y, pos.z)
    if Config.Debug then
        print(('[len_fishing] shore check: landProbes=%d longestLandSector=%d ownWater=%s'):format(landCount, best, tostring(ownWater)))
    end
    if best >= boat.shoreSectorMin then
        return false
    end
    return ownWater
end

local function getNearbyDock()
    local pos = GetEntityCoords(PlayerPedId())
    for _, dock in ipairs(Config.Docks) do
        if #(pos - dock) <= Config.Methods.dock.interactDistance then
            return true
        end
    end
    return false
end

local function detectMethod()
    if Config.Methods.boat.enabled and findNearbyBoat() then
        return 'boat'
    end
    if Config.Methods.dock.enabled and not IsPedInAnyVehicle(PlayerPedId(), false) and getNearbyDock() then
        return 'dock'
    end
    return nil
end

local function getPositionError(methodName)
    local ped = PlayerPedId()
    if IsEntityDead(ped) then
        return 'notify.died'
    end
    if methodName == 'boat' then
        if not findNearbyBoat() then
            return 'notify.left_boat'
        end
        if not isFarFromShore(GetEntityCoords(ped)) then
            return 'notify.too_close_shore'
        end
        return nil
    end
    if methodName == 'dock' then
        if IsPedInAnyVehicle(ped, false) or not getNearbyDock() then
            return 'notify.moved_away'
        end
        return nil
    end
    return 'notify.need_position'
end

local function loadModel(model)
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) then
        return nil
    end
    RequestModel(hash)
    local ends = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < ends do
        Wait(10)
    end
    if HasModelLoaded(hash) then
        return hash
    end
    return nil
end

local function loadAnimDict(dict)
    if HasAnimDictLoaded(dict) then
        return true
    end
    RequestAnimDict(dict)
    local ends = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < ends do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

local function clearProp()
    if rodProp and DoesEntityExist(rodProp) then
        DeleteEntity(rodProp)
    end
    rodProp = nil
end

local function attachRodProp(groupKey)
    clearProp()
    local group = Config.Groups[groupKey or Config.DefaultGroup]
    local hash = loadModel(group.prop) or loadModel(Config.DefaultRodProp)
    if not hash then
        return
    end
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    rodProp = CreateObject(hash, pos.x, pos.y, pos.z, false, true, false)
    local o = group.propOffset
    AttachEntityToEntity(rodProp, ped, GetPedBoneIndex(ped, 28422), o[1], o[2], o[3], o[4], o[5], o[6], true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(hash)
end

local function playAnimation(anim)
    if not loadAnimDict(anim[1]) then
        return
    end
    TaskPlayAnim(PlayerPedId(), anim[1], anim[2], 8.0, -8.0, -1, 49, 0.0, false, false, false)
end

local function getImagePath()
    if Config.UI.useOxImages and GetResourceState('ox_inventory') == 'started' then
        return Config.UI.imagePath
    end
    return nil
end

local function buildLabels()
    return {
        status = {
            ready = L('ui.status.ready'),
            waiting = L('ui.status.waiting'),
            bite = L('ui.status.bite'),
            fighting = L('ui.status.fighting')
        },
        keyCast = L('ui.key_cast'),
        keyReel = L('ui.key_reel'),
        keyBait = L('ui.key_bait'),
        durability = L('ui.durability'),
        noBait = L('ui.no_bait'),
        bait = L('ui.bait'),
        bite = L('ui.bite'),
        biteHint = L('ui.bite_hint'),
        progress = L('ui.progress'),
        time = L('ui.time'),
        miniHint = L('minigame.hint'),
        caught = L('ui.caught'),
        escaped = L('ui.escaped')
    }
end

local function sendHud(status)
    SendNUIMessage({
        action = 'hud',
        visible = fishing,
        rod = rodKey and L('rod.' .. rodKey) or '',
        baits = baits,
        index = baitIndex - 1,
        durability = durability,
        durMax = durMax,
        status = status
    })
end

local function hideUi()
    SendNUIMessage({ action = 'hud', visible = false })
    SendNUIMessage({ action = 'bite', visible = false })
end

local function cycleBait(dir)
    if #baits == 0 then
        return
    end
    baitIndex = ((baitIndex - 1 + dir) % #baits) + 1
    sendHud(phase)
end

local frozenVehicle = nil

local function disableFishingControls()
    DisableAllControlActions(0)
    EnableControlAction(0, 1, true)
    EnableControlAction(0, 2, true)
    EnableControlAction(0, 199, true)
    EnableControlAction(0, 200, true)
    EnableControlAction(0, 245, true)
    EnableControlAction(0, 289, true)
    EnableControlAction(0, 322, true)
end

local function lockVehicle(vehicle)
    if vehicle and DoesEntityExist(vehicle) then
        frozenVehicle = vehicle
        FreezeEntityPosition(frozenVehicle, true)
    end
end

local function unlockVehicle()
    if frozenVehicle and DoesEntityExist(frozenVehicle) then
        FreezeEntityPosition(frozenVehicle, false)
    end
    frozenVehicle = nil
end

local function controlLockLoop()
    SetCurrentPedWeapon(PlayerPedId(), GetHashKey('WEAPON_UNARMED'), true)
    while fishing do
        Wait(0)
        disableFishingControls()
    end
    EnableAllControlActions(0)
end

local function stopFishing(notifyServer, msgKey)
    fishing = false
    phase = 'ready'
    method = nil
    rodKey = nil
    attemptFish = nil
    attemptGroup = nil
    clearProp()
    ClearPedTasks(PlayerPedId())
    unlockVehicle()
    hideUi()
    if notifyServer then
        TriggerServerEvent('len_fishing:server:stop')
    end
    if msgKey then
        notify(L(msgKey, Config.Methods.boat.minDistanceToShore))
    end
end

local function runMinigame(groupKey, fishName)
    local group = Config.Groups[groupKey]
    local m = group.minigame
    local d = Config.Rods[rodKey].difficulty
    minigameResult = nil
    SendNUIMessage({
        action = 'mini',
        visible = true,
        title = L('minigame.title'),
        group = L('group.' .. groupKey),
        fish = { item = fishName, label = L('fish.' .. fishName) },
        config = {
            speed = m.speed * d,
            zone = math.max(0.08, m.zone / d),
            noise = m.noise * d,
            gain = m.gain,
            loss = m.loss * d,
            duration = m.duration
        }
    })
    phase = 'fighting'
    sendHud('fighting')

    local holding = false
    local deadline = GetGameTimer() + (m.duration + 4) * 1000
    while minigameResult == nil and fishing and GetGameTimer() < deadline do
        local hold = false
        for _, key in ipairs(Config.Keys.hold) do
            if IsDisabledControlPressed(0, key) then
                hold = true
            end
        end
        if hold ~= holding then
            holding = hold
            SendNUIMessage({ action = 'hold', value = hold })
        end
        if IsDisabledControlJustPressed(0, Config.Keys.cancel) then
            minigameResult = false
        end
        Wait(0)
    end

    local outcome = minigameResult
    if outcome ~= nil then
        Wait(900)
    end
    SendNUIMessage({ action = 'mini', visible = false })
    minigameResult = nil
    return outcome == true
end

local function attemptEnd(success)
    TriggerServerEvent('len_fishing:server:finish', success == true)
    attemptFish = nil
    attemptGroup = nil
    biteAt = 0
    biteEnd = 0
    clearProp()
    ClearPedTasks(PlayerPedId())
    phase = 'ready'
    SendNUIMessage({ action = 'bite', visible = false })
    sendHud('ready')
end

local function startCast()
    local bait = baits[baitIndex]
    if Config.BaitRequired and not bait then
        notify(L('notify.no_bait'))
        return
    end
    castResult = nil
    phase = 'waiting'
    playAnimation(Config.Animations.cast)
    TriggerServerEvent('len_fishing:server:cast', method, bait and bait.key or nil)

    local deadline = GetGameTimer() + 5000
    while castResult == nil and fishing and GetGameTimer() < deadline do
        Wait(10)
    end
    if not fishing then
        return
    end
    local result = castResult
    castResult = nil
    if not result then
        stopFishing(true, 'notify.stopped')
        return
    end

    Wait(Config.Animations.castDuration)
    if not fishing then
        return
    end

    baits = result.baits or {}
    clampBait()
    attemptFish = result.fish
    attemptGroup = result.group
    local m = Config.Methods[method]
    biteAt = GetGameTimer() + math.random(m.biteTime.min, m.biteTime.max)
    attachRodProp(nil)
    playAnimation(Config.Groups[Config.DefaultGroup].anim)
    sendHud('waiting')
end

local function fishingLoop()
    while fishing do
        Wait(0)
        local now = GetGameTimer()

        if now - lastPosCheck >= 500 then
            lastPosCheck = now
            local err = getPositionError(method)
            if err then
                stopFishing(true, err)
                return
            end
        end

        if phase == 'ready' then
            if IsDisabledControlJustPressed(0, Config.Controls.castUp) then
                startCast()
            end
        elseif phase == 'waiting' then
            if IsDisabledControlJustPressed(0, Config.Controls.reelDown) then
                attemptEnd(false)
            elseif now >= biteAt then
                if attemptFish then
                    phase = 'bite'
                    biteEnd = now + Config.Rods[rodKey].biteWindow
                    attachRodProp(attemptGroup)
                    playAnimation(Config.Groups[attemptGroup].anim)
                    SendNUIMessage({ action = 'bite', visible = true, duration = Config.Rods[rodKey].biteWindow })
                    sendHud('bite')
                else
                    notify(L('notify.nothing_bit'))
                    attemptEnd(false)
                end
            end
        elseif phase == 'bite' then
            if IsDisabledControlJustPressed(0, Config.Controls.reelDown) then
                SendNUIMessage({ action = 'bite', visible = false })
                local success = runMinigame(attemptGroup, attemptFish)
                if not fishing then
                    return
                end
                attemptEnd(success)
            elseif now >= biteEnd then
                attemptEnd(false)
            end
        end

        if fishing and phase ~= 'fighting' then
            if IsDisabledControlJustPressed(0, Config.Controls.baitLeft) then
                cycleBait(-1)
            elseif IsDisabledControlJustPressed(0, Config.Controls.baitRight) then
                cycleBait(1)
            end
        end
    end
end

RegisterNetEvent('len_fishing:client:begin', function(data)
    if fishing then
        return
    end
    local m = detectMethod()
    if not m then
        notify(L('notify.need_position'))
        TriggerServerEvent('len_fishing:server:stop')
        return
    end
    local err = getPositionError(m)
    if err then
        notify(L(err, Config.Methods.boat.minDistanceToShore))
        TriggerServerEvent('len_fishing:server:stop')
        return
    end
    fishing = true
    method = m
    if m == 'boat' then
        lockVehicle(findNearbyBoat())
    end
    CreateThread(controlLockLoop)
    rodKey = data.rod
    baits = data.baits or {}
    baitIndex = 1
    clampBait()
    durability = data.durability
    durMax = data.durMax
    phase = 'ready'
    lastPosCheck = GetGameTimer()
    SendNUIMessage({ action = 'setup', imagePath = getImagePath(), labels = buildLabels() })
    sendHud('ready')
    CreateThread(fishingLoop)
end)

RegisterNetEvent('len_fishing:client:castResult', function(data)
    castResult = data
end)

RegisterNetEvent('len_fishing:client:result', function(data)
    durability = data.durability or durability
    durMax = data.durMax or durMax
    baits = data.baits or {}
    clampBait()
    if data.fish then
        SendNUIMessage({
            action = 'toast',
            kind = data.caught and 'success' or 'fail',
            item = data.fish,
            label = L('fish.' .. data.fish) .. ((data.amount or 1) > 1 and (' x' .. data.amount) or '')
        })
    end
    if fishing then
        sendHud(phase)
    end
end)

RegisterNetEvent('len_fishing:client:stop', function(msgKey)
    stopFishing(false, msgKey)
end)

RegisterNUICallback('minigameResult', function(data, cb)
    cb('ok')
    minigameResult = data and data.success == true
end)

local function createBlip(pos, options, label)
    local blip = AddBlipForCoord(pos.x, pos.y, pos.z)
    SetBlipSprite(blip, options.sprite)
    SetBlipColour(blip, options.color)
    SetBlipScale(blip, options.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
end

local function drawMarker(pos)
    DrawMarker(1, pos.x, pos.y, pos.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.2, 1.2, 0.6, 60, 170, 255, 110, false, true, 2, false, nil, nil, false)
end

CreateThread(function()
    if Config.Methods.dock.enabled and Config.Blips.dock.enabled then
        for _, pos in ipairs(Config.Docks) do
            createBlip(pos, Config.Blips.dock, L('blip.dock'))
        end
    end
    if Config.Selling.enabled and Config.Blips.sell.enabled then
        for _, pos in ipairs(Config.Selling.locations) do
            createBlip(pos, Config.Blips.sell, L('blip.sell'))
        end
    end

    while true do
        local sleep = 1000
        local pos = GetEntityCoords(PlayerPedId())

        if Config.Methods.dock.enabled then
            for _, dock in ipairs(Config.Docks) do
                if #(pos - dock) < Config.Markers.distance then
                    sleep = 0
                    drawMarker(dock)
                end
            end
        end

        if Config.Selling.enabled then
            for _, loc in ipairs(Config.Selling.locations) do
                local dist = #(pos - loc)
                if dist < Config.Markers.distance then
                    sleep = 0
                    drawMarker(loc)
                    if dist < Config.Selling.interactDistance then
                        ESX.ShowHelpNotification(L('hud.sell_help'))
                        if IsDisabledControlJustPressed(0, Config.Keys.interact) then
                            TriggerServerEvent('len_fishing:server:sell')
                            Wait(1000)
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end
    clearProp()
    ClearPedTasks(PlayerPedId())
    unlockVehicle()
    EnableAllControlActions(0)
    SendNUIMessage({ action = 'hud', visible = false })
    SendNUIMessage({ action = 'bite', visible = false })
    SendNUIMessage({ action = 'mini', visible = false })
end)
