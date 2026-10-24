Config = {}

Config.Locale = 'en'
Config.Debug = false

Config.Keys = {
    interact = 38,
    cancel = 73,
    hold = { 24, 22 }
}

Config.Controls = {
    castUp = 172,
    reelDown = 173,
    baitLeft = 174,
    baitRight = 175
}

Config.UI = {
    useOxImages = true,
    imagePath = 'nui://ox_inventory/web/images/%s.png'
}

Config.Markers = {
    distance = 30.0
}

Config.Blips = {
    dock = { enabled = true, sprite = 68, color = 3, scale = 0.6 },
    sell = { enabled = true, sprite = 356, color = 2, scale = 0.6 }
}

Config.RodTiers = {
    amateur = 1,
    normal = 2,
    pro = 3
}

Config.Rods = {
    amateur = { item = 'fishing_rod_amateur', difficulty = 0.75, biteWindow = 5000 },
    normal = { item = 'fishing_rod_normal', difficulty = 1.0, biteWindow = 4000 },
    pro = { item = 'fishing_rod_pro', difficulty = 1.5, biteWindow = 3000 }
}

Config.Durability = {
    enabled = true,
    max = 100,
    loss = 5
}

Config.BaitRequired = true
Config.BaitOrder = { 'worm', 'shrimp', 'lure', 'premium' }

Config.Baits = {
    worm = { item = 'fishing_bait_worm', multipliers = { coastal = 1.4, reef = 1.2 } },
    shrimp = { item = 'fishing_bait_shrimp', multipliers = { reef = 1.5, deepsea = 1.2 } },
    lure = { item = 'fishing_bait_lure', multipliers = { predator = 1.8, coastal = 1.1 } },
    premium = { item = 'fishing_bait_premium', multipliers = { deepsea = 1.5, predator = 1.3, legendary = 2.5 } }
}

Config.MultiCatch = {
    coastal = { chance = 35, min = 2, max = 5 }
}

Config.Methods = {
    boat = {
        enabled = true,
        rareMultiplier = 1.8,
        noBiteChance = 8,
        biteTime = { min = 10000, max = 45000 },
        minDistanceToShore = 100,
        shoreProbes = 24,
        shoreSectorMin = 4,
        boatRadius = 5.0,
        vehicleClasses = { [14] = true }
    },
    dock = {
        enabled = true,
        rareMultiplier = 1.0,
        noBiteChance = 15,
        biteTime = { min = 20000, max = 90000 },
        interactDistance = 3.0
    }
}

Config.Docks = {
    vector3(-1850.4948, -1250.2250, 8.6153),
	vector3(-1612.3469, 5262.7075, 3.9741)
}

Config.DefaultGroup = 'coastal'
Config.DefaultRodProp = 'prop_fishing_rod_01'

Config.Animations = {
    cast = { 'amb@world_human_stand_fishing@base', 'base' },
    castDuration = 1200
}

Config.Groups = {
    coastal = {
        prop = 'prop_fishing_rod_01',
        propOffset = { 0.1, 0.02, 0.0, 0.0, 0.0, 0.0 },
        anim = { 'amb@world_human_stand_fishing@idle_a', 'idle_a' },
        minigame = { speed = 0.7, zone = 0.36, noise = 0.10, gain = 30, loss = 14, duration = 24 }
    },
    predator = {
        prop = 'prop_fishing_rod_02',
        propOffset = { 0.1, 0.02, 0.0, 0.0, 0.0, 0.0 },
        anim = { 'amb@world_human_stand_fishing@idle_a', 'idle_b' },
        minigame = { speed = 1.0, zone = 0.30, noise = 0.20, gain = 30, loss = 16, duration = 22 }
    },
    deepsea = {
        prop = 'prop_fishing_rod_03',
        propOffset = { 0.1, 0.02, 0.0, 0.0, 0.0, 0.0 },
        anim = { 'amb@world_human_stand_fishing@idle_a', 'idle_c' },
        minigame = { speed = 0.9, zone = 0.28, noise = 0.16, gain = 30, loss = 16, duration = 24 }
    },
    reef = {
        prop = 'prop_fishing_rod_04',
        propOffset = { 0.1, 0.02, 0.0, 0.0, 0.0, 0.0 },
        anim = { 'amb@world_human_stand_fishing@idle_a', 'idle_a' },
        minigame = { speed = 0.8, zone = 0.32, noise = 0.12, gain = 30, loss = 15, duration = 22 }
    },
    legendary = {
        prop = 'prop_fishing_rod_05',
        propOffset = { 0.1, 0.02, 0.0, 0.0, 0.0, 0.0 },
        anim = { 'amb@world_human_stand_fishing@idle_a', 'idle_b' },
        minigame = { speed = 1.2, zone = 0.24, noise = 0.26, gain = 28, loss = 18, duration = 26 }
    }
}

Config.Selling = {
    enabled = false,
    account = 'money',
    multiplier = 1.0,
    interactDistance = 2.0,
    locations = {
        vector3(-1790.0, -1200.0, 13.0)
    }
}

Config.Fish = {
    { name = 'fish_sardine', group = 'coastal', chance = 40, minRod = 'amateur', price = 100, weight = 150 },
    { name = 'fish_mackerel', group = 'coastal', chance = 30, minRod = 'amateur', price = 140, weight = 400 },
    { name = 'fish_herring', group = 'coastal', chance = 25, minRod = 'amateur', price = 150, weight = 300 },
    { name = 'fish_anchovy', group = 'coastal', chance = 35, minRod = 'amateur', price = 95, weight = 80 },
    { name = 'fish_sea_bream', group = 'coastal', chance = 20, minRod = 'normal', price = 280, weight = 900 },
    { name = 'fish_barracuda', group = 'predator', chance = 15, minRod = 'normal', price = 300, weight = 2500 },
    { name = 'fish_tuna', group = 'predator', chance = 12, minRod = 'normal', price = 440, weight = 5000 },
    { name = 'fish_mahi_mahi', group = 'predator', chance = 10, minRod = 'normal', price = 510, weight = 4000 },
    { name = 'fish_blacktip_shark', group = 'predator', chance = 6, minRod = 'pro', price = 745, weight = 6000 },
    { name = 'fish_marlin', group = 'predator', chance = 4, minRod = 'pro', price = 1180, weight = 8000 },
    { name = 'fish_lanternfish', group = 'deepsea', chance = 18, minRod = 'normal', price = 225, weight = 200 },
    { name = 'fish_viperfish', group = 'deepsea', chance = 15, minRod = 'normal', price = 265, weight = 350 },
    { name = 'fish_gulper_eel', group = 'deepsea', chance = 12, minRod = 'pro', price = 590, weight = 3000 },
    { name = 'fish_anglerfish', group = 'deepsea', chance = 10, minRod = 'pro', price = 635, weight = 3500 },
    { name = 'fish_oarfish', group = 'deepsea', chance = 8, minRod = 'pro', price = 830, weight = 7500 },
    { name = 'fish_parrotfish', group = 'reef', chance = 22, minRod = 'amateur', price = 190, weight = 600 },
    { name = 'fish_clownfish', group = 'reef', chance = 26, minRod = 'amateur', price = 170, weight = 150 },
    { name = 'fish_triggerfish', group = 'reef', chance = 18, minRod = 'normal', price = 280, weight = 700 },
    { name = 'fish_lionfish', group = 'reef', chance = 14, minRod = 'normal', price = 320, weight = 500 },
    { name = 'fish_moray_eel', group = 'reef', chance = 12, minRod = 'normal', price = 370, weight = 1800 },
    { name = 'fish_golden_tuna', group = 'legendary', chance = 1.5, minRod = 'pro', price = 4220, weight = 8000 },
    { name = 'fish_crystal_sturgeon', group = 'legendary', chance = 1, minRod = 'pro', price = 5065, weight = 8000 },
    { name = 'fish_ancient_coelacanth', group = 'legendary', chance = 1, minRod = 'pro', price = 5910, weight = 6500 },
    { name = 'fish_phantom_ray', group = 'legendary', chance = 0.8, minRod = 'pro', price = 6750, weight = 8000 },
    { name = 'fish_sea_king_carp', group = 'legendary', chance = 1, minRod = 'pro', price = 8440, weight = 8000 },
}
