return {
    -- Time (in ms) to wait before assigning the next task
    Timeout = 5000,

    -- Inventory item name for payment (e.g., 'cash', 'money')
    Account = 'cash',

    -- The work truck model to spawn
    Vehicle = `bison`,

    -- Precise coordinates where the truck spawns (x, y, z, heading)
    VehicleSpawn = vec4(892.6, -2339.76, 30.39, 262.64),

    -- Generic Locations (fallback for any task type)
    Locations = {
        vec3(1262.34, -1755.69, 49.35),
        vec3(1293.31, -1746.18, 53.88),
        vec3(546.91, -1958.31, 24.98),
        vec3(560.81, -1630.79, 27.69),
        vec3(566.69, -1579.15, 28.31),
        vec3(492.9, -1342.64, 29.27),
        vec3(251.54, -1357.55, 30.55),
        vec3(102.81, -1280.89, 29.25),
        vec3(-349.55, -1393.42, 37.31),
        vec3(-207.19, -1115.12, 22.86),
        vec3(-300.01, -932.19, 31.08),
        vec3(-7.61, -202.04, 52.61),
        vec3(210.06, -169.09, 56.32),
        vec3(398.24, 67.52, 97.98),
        vec3(966.5, -457.72, 62.4),
        vec3(1088.01, -488.41, 65.41),
        vec3(1294.55, -543.77, 70.29),
        vec3(1336.54, -612.45, 74.38),
        vec3(1092.65, -795.06, 58.27),
        vec3(756.45, -1099.05, 22.32),
    },

    -- Category-Specific Locations (more immersive spawns)
    CategoryLocations = {
        -- Maintenance tasks (pipes, hydrants, infrastructure)
        maintenance = {
            vec3(1262.34, -1755.69, 49.35),
            vec3(546.91, -1958.31, 24.98),
            vec3(492.9, -1342.64, 29.27),
            vec3(-349.55, -1393.42, 37.31),
            vec3(-300.01, -932.19, 31.08),
            vec3(398.24, 67.52, 97.98),
            vec3(1092.65, -795.06, 58.27),
        },

        -- Road tasks (potholes, signs, traffic control)
        road = {
            vec3(150.23, -1035.44, 29.34),  -- Legion Square
            vec3(-267.85, -960.15, 31.22),  -- Alta St
            vec3(378.16, -828.95, 29.30),   -- Mission Row
            vec3(815.35, -1290.47, 26.32),  -- La Mesa
            vec3(-1196.54, -1492.89, 4.38), -- Del Perro Pier
            vec3(1164.52, -1460.25, 34.81), -- Murrieta Heights
            vec3(-524.67, -677.98, 33.12),  -- Little Seoul
        },

        -- Electrical tasks (streetlights, boxes, transformers)
        electrical = {
            vec3(102.81, -1280.89, 29.25),
            vec3(-207.19, -1115.12, 22.86),
            vec3(210.06, -169.09, 56.32),
            vec3(966.5, -457.72, 62.4),
            vec3(1088.01, -488.41, 65.41),
            vec3(1294.55, -543.77, 70.29),
            vec3(1336.54, -612.45, 74.38),
        },

        -- Cleanup tasks (graffiti, trash, hazmat)
        cleanup = {
            vec3(89.53, -1952.24, 20.75),   -- Grove Street
            vec3(313.17, -2034.65, 20.89),  -- Ballas territory
            vec3(-1178.52, -1573.24, 4.36), -- Del Perro
            vec3(448.27, -1017.98, 28.54),  -- Pillbox Hill
            vec3(-135.64, -1697.02, 32.31), -- Davis
            vec3(1137.56, -1350.15, 34.59), -- El Burro Heights
            vec3(-1629.45, -1020.14, 13.02),-- Morningwood
        },

        -- Utility tasks (meters, cables, locating)
        utility = {
            vec3(-240.75, -901.54, 33.44),  -- Downtown
            vec3(301.95, -579.28, 43.26),   -- Rockford Hills
            vec3(-1093.42, -248.35, 37.76), -- West Vinewood
            vec3(1280.45, -1718.66, 54.77), -- Cypress Flats
            vec3(-524.67, -277.46, 35.40),  -- Little Seoul
            vec3(892.35, -2180.45, 32.28),  -- Rancho
            vec3(-1548.24, -453.91, 40.52), -- Morningwood
        },

        -- Sewer tasks (manholes, storm drains)
        sewer = {
            vec3(251.54, -1357.55, 30.55),
            vec3(560.81, -1630.79, 27.69),
            vec3(756.45, -1099.05, 22.32),
            vec3(-134.85, -1582.54, 35.04), -- Davis
            vec3(384.52, -1814.28, 28.97),  -- El Burro
            vec3(-1196.54, -1492.89, 4.38), -- Beach
            vec3(1127.74, -663.19, 56.97),  -- Mirror Park
        },

        -- Emergency tasks (use these for dramatic effect)
        emergency = {
            vec3(188.0, -923.0, 30.0),      -- Legion Square (central)
            vec3(1065.0, -716.0, 57.0),     -- Mirror Park (residential)
            vec3(1863.0, 3704.0, 33.0),     -- Sandy Shores
            vec3(-74.82, -818.47, 284.0),   -- Maze Bank (high profile)
            vec3(-1037.98, -2736.91, 20.17),-- Airport
            vec3(442.89, -981.74, 30.69),   -- Downtown
        },
    },

    -- Bridge Inspection Locations
    BridgeLocations = {
        { coords = vec3(-409.89, -2164.53, 10.03), label = 'La Puerta Bridge' },
        { coords = vec3(-268.31, -2572.43, 6.01), label = 'LSIA Overpass' },
        { coords = vec3(2645.88, 2927.75, 38.09), label = 'Route 68 Bridge' },
    },

    -- Traffic Control Zones (where players set up traffic control)
    TrafficControlZones = {
        { coords = vec3(150.23, -1035.44, 29.34), radius = 25.0, label = 'Legion Square' },
        { coords = vec3(-267.85, -960.15, 31.22), radius = 20.0, label = 'Alta Street' },
        { coords = vec3(815.35, -1290.47, 26.32), radius = 30.0, label = 'La Mesa' },
        { coords = vec3(-1196.54, -1492.89, 4.38), radius = 25.0, label = 'Del Perro' },
    },

    -- Meter Reading Routes (sequential stops)
    MeterRoutes = {
        residential = {
            vec3(1127.74, -663.19, 56.97),  -- Mirror Park 1
            vec3(1164.52, -583.15, 57.28),  -- Mirror Park 2
            vec3(1051.87, -481.32, 64.12),  -- Mirror Park 3
            vec3(971.64, -419.86, 64.85),   -- Mirror Park 4
        },
        commercial = {
            vec3(-240.75, -901.54, 33.44),  -- Downtown 1
            vec3(-168.73, -874.23, 29.34),  -- Downtown 2
            vec3(-89.52, -814.74, 36.27),   -- Downtown 3
            vec3(35.41, -768.52, 44.23),    -- Downtown 4
        },
        industrial = {
            vec3(892.35, -2180.45, 32.28),  -- Rancho 1
            vec3(986.47, -2152.32, 30.45),  -- Rancho 2
            vec3(1078.92, -2086.74, 30.87), -- Rancho 3
            vec3(1168.35, -1975.23, 34.52), -- Rancho 4
        },
    },
}
