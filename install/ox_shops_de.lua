return {
    ['fishing_shop'] = {
        name = 'Angelladen',
        blip = { id = 68, colour = 3, scale = 0.7 },
        ped = {
            model = 's_m_m_fisherman_01',
            scenario = 'WORLD_HUMAN_CLIPBOARD',
            coords = vec4(-1792.0, -1198.5, 13.3, 40.0),
        },
        locations = {
            vec3(-1792.0, -1198.5, 13.3),
        },
        inventory = {
            { name = 'fishing_rod_amateur', price = 500 },
            { name = 'fishing_rod_normal', price = 1000 },
            { name = 'fishing_rod_pro', price = 3500 },
            { name = 'fishing_bait_worm', price = 10 },
            { name = 'fishing_bait_shrimp', price = 25 },
            { name = 'fishing_bait_lure', price = 50 },
            { name = 'fishing_bait_premium', price = 200 },
        },
    },
}
