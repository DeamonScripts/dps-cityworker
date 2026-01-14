return {
    -- Core Settings
    Debug = false, -- Set to true for print debugging and dev commands
    Framework = 'qb', -- 'qb' or 'esx'
    Target = 'ox_target', -- 'ox_target' or 'qb-target'
    Notify = 'ox_lib', -- 'ox_lib' or 'qb' or 'esx'

    -- Interaction Settings
    FuelScript = {
        enable = false,
        script = 'LegacyFuel', -- Name of your fuel script export
    },

    -- Boss / HQ Settings
    BossModel = `s_m_y_construct_02`,
    BossCoords = vec4(884.47, -2337.14, 29.34, 359.1),
    
    -- Economy & Contractor Settings
    Economy = {
        BasePay = 250, -- Base payment for a simple repair
        WeeklyBudget = 50000, -- Government budget allocation (Roadmap feature)
        CompanyRegistrationFee = 5000, -- Cost to register a sub-contractor company
        MaterialCost = 50, -- Cost deducted if player buys their own supplies
    },

    -- Seniority / Progression System
    -- Higher ranks = harder skill checks but more pay and access to better tools
    Ranks = {
        [1] = { label = 'Probationary Laborer', payMultiplier = 1.0, canAssign = false },
        [2] = { label = 'Junior Technician', payMultiplier = 1.2, canAssign = false },
        [3] = { label = 'Senior Technician', payMultiplier = 1.5, canAssign = false },
        [4] = { label = 'Specialist', payMultiplier = 1.8, canAssign = false },
        [5] = { label = 'Foreman', payMultiplier = 2.5, canAssign = true }, -- Can access Control Room
    },

    -- Strategic Grid Management (Sectors)
    -- Defines the zones for the "Control Room" UI
    Sectors = {
        ['legion'] = {
            label = "Legion Square",
            coords = vec3(188.0, -923.0, 30.0),
            radius = 300.0,
            decayRate = 0.5, -- % health lost per hour
            blackoutThreshold = 0 -- If health hits 0, lights go out
        },
        ['mirror_park'] = {
            label = "Mirror Park",
            coords = vec3(1065.0, -716.0, 57.0),
            radius = 400.0,
            decayRate = 0.3,
            blackoutThreshold = 0
        },
        ['sandy_shores'] = {
            label = "Sandy Shores",
            coords = vec3(1863.0, 3704.0, 33.0),
            radius = 600.0,
            decayRate = 0.8, -- Decays faster (old infrastructure)
            blackoutThreshold = 10 -- Lights flicker/fail at 10%
        },
    },

    -- Minigame / Skill Check Settings
    SkillCheck = {
        Difficulty = { 'easy', 'easy', 'medium' }, -- default difficulty sequence
        HardDifficulty = { 'medium', 'medium', 'hard' }, -- for Specialists/High Voltage
        Input = {'e'}
    },

    -- Task Props (visual markers for each task type)
    -- All props verified to exist in GTA V
    TaskProps = {
        -- Basic Tasks
        pipe = 'prop_waterpump_01',
        pothole = 'prop_roadcone02a',
        meter_reading = 'prop_toolchest_05',      -- Toolbox for meter reading
        graffiti = 'prop_cs_spray_can',
        trash = 'prop_rub_binbag_01',

        -- Intermediate Tasks
        streetlight = 'prop_worklight_03b',       -- Work light
        hydrant = 'prop_fire_hydrant_2',          -- Fire hydrant (verified)
        sign_repair = 'prop_sign_road_01a',
        manhole = 'prop_roadcone02a',             -- Cone marking manhole
        storm_drain = 'prop_barrier_work06a',     -- Work barrier for drain

        -- Advanced Tasks
        electrical = 'prop_elecbox_01a',
        traffic_control = 'prop_roadcone02a',
        tree_trimming = 'prop_tree_stump_01',
        cable_install = 'prop_rail_boxpile',      -- Cable box

        -- Expert Tasks
        transformer = 'prop_sub_trans_01',
        hazmat = 'prop_barrel_01a',
        bridge_inspection = 'prop_roadcone02a',
        utility_locating = 'prop_roadcone02a',

        -- Emergency Tasks
        water_main = 'prop_waterpump_01',
        gas_leak = 'prop_barrel_02a',             -- Different barrel
        downed_lines = 'prop_worklight_03a',      -- Work light marking danger
        fallen_tree = 'prop_tree_fallen_02',      -- Fallen tree (verified)
    },

    -- Traffic Control Props (for setup tasks)
    TrafficProps = {
        Cone = 'prop_roadcone02a',
        Barrier = 'prop_barrier_work05',
        Sign_Stop = 'prop_sign_road_04b',
        Sign_Slow = 'prop_sign_road_04a',
        Light = 'prop_worklight_02a',
    },

    -- Animation dictionaries per task category
    TaskAnimations = {
        maintenance = { dict = 'amb@world_human_welding@male@base', anim = 'base' },
        road = { dict = 'amb@world_human_const_drill@male@drill@base', anim = 'base' },
        electrical = { dict = 'anim@heists@prison_heiststation@cop_reactions', anim = 'yourface' },
        cleanup = { dict = 'timetable@floyd@clean_kitchen@base', anim = 'base' },
        utility = { dict = 'amb@world_human_clipboard@male@base', anim = 'base' },
        sewer = { dict = 'mini@repair', anim = 'fixing_a_ped' },
        emergency = { dict = 'amb@world_human_welding@male@base', anim = 'base' },
    },

    -- Emergency Settings
    Emergency = {
        RandomChance = 15, -- % chance per check (every 10 min)
        BonusMultiplier = 1.5, -- XP bonus for emergency response
        PaymentMultiplier = 2.0, -- Payment bonus for emergency
        MaxActivePerSector = 1, -- Only one emergency per sector
    },
}
