local Config = lib.require('config')
local isHired, activeJob = false, false
local cityBoss, startZone, currZone, currentCone
local JobBlip = nil
local CurrentTask = nil
local ControlRoomOpen = false

-- =====================================
-- BLIP SETUP
-- =====================================

local CITY_BLIP = AddBlipForCoord(Config.BossCoords.x, Config.BossCoords.y, Config.BossCoords.z)
SetBlipSprite(CITY_BLIP, 566)
SetBlipDisplay(CITY_BLIP, 4)
SetBlipScale(CITY_BLIP, 0.8)
SetBlipAsShortRange(CITY_BLIP, true)
SetBlipColour(CITY_BLIP, 5)
BeginTextCommandSetBlipName("STRING")
AddTextComponentSubstringPlayerName("City Worker Job")
EndTextCommandSetBlipName(CITY_BLIP)

-- =====================================
-- TARGET HELPERS
-- =====================================

local function AddTargetEntity(entity, options)
    if GetResourceState('ox_target') == 'started' then
        local oxOptions = {}
        for _, opt in ipairs(options) do
            table.insert(oxOptions, {
                icon = opt.icon,
                label = opt.label,
                onSelect = opt.action,
                canInteract = opt.canInteract,
                distance = opt.distance or 2.0
            })
        end
        exports.ox_target:addLocalEntity(entity, oxOptions)
    else
        exports['qb-target']:AddTargetEntity(entity, { options = options, distance = 2.0 })
    end
end

local function RemoveTargetEntity(entity, labels)
    if GetResourceState('ox_target') == 'started' then
        exports.ox_target:removeLocalEntity(entity, labels)
    else
        exports['qb-target']:RemoveTargetEntity(entity, labels)
    end
end

local function AddTargetZone(name, data, options)
    if GetResourceState('ox_target') == 'started' then
        local oxOptions = {}
        for _, opt in ipairs(options) do
            table.insert(oxOptions, {
                icon = opt.icon,
                label = opt.label,
                onSelect = opt.action,
                canInteract = opt.canInteract,
            })
        end
        return exports.ox_target:addSphereZone({
            name = name,
            coords = data.coords,
            radius = data.radius or 1.5,
            options = oxOptions,
        })
    else
        return exports['qb-target']:AddCircleZone(name, data.coords, data.radius or 1.5, {
            name = name,
            useZ = true,
        }, { options = options, distance = 2.0 })
    end
end

local function RemoveTargetZone(zone)
    if GetResourceState('ox_target') == 'started' then
        exports.ox_target:removeZone(zone)
    else
        exports['qb-target']:RemoveZone(zone)
    end
end

-- =====================================
-- FORWARD DECLARATIONS
-- =====================================

local StopAllParticles -- Forward declaration for particle cleanup

-- =====================================
-- CLEANUP
-- =====================================

local function cleanupJob()
    -- Stop any active particle effects
    if StopAllParticles then StopAllParticles() end

    if currZone then
        RemoveTargetZone(currZone)
        currZone = nil
    end
    if DoesEntityExist(currentCone) then
        DeleteEntity(currentCone)
        currentCone = nil
    end
    if JobBlip then
        RemoveBlip(JobBlip)
        JobBlip = nil
    end
    CurrentTask = nil
end

local function resetJob()
    cleanupJob()
    isHired = false
    activeJob = false

    if DoesEntityExist(cityBoss) then
        RemoveTargetEntity(cityBoss, {'Start Work', 'Finish Work'})
        DeleteEntity(cityBoss)
        cityBoss = nil
    end
    -- Note: Don't remove startZone here - it's created once at script load
    -- and should persist through character switches
end

-- =====================================
-- TASK PROPS & ANIMATIONS
-- =====================================

local function GetTaskProp(taskType)
    if Config.TaskProps and Config.TaskProps[taskType] then
        return Config.TaskProps[taskType]
    end
    return 'prop_roadcone02a' -- Default fallback
end

local function GetTaskAnimation(category)
    if Config.TaskAnimations and Config.TaskAnimations[category] then
        return Config.TaskAnimations[category]
    end
    return { dict = 'amb@world_human_welding@male@base', anim = 'base' }
end

local function SpawnTaskProp(taskType, coords)
    local propModel = GetTaskProp(taskType)
    lib.requestModel(propModel)

    local prop = CreateObject(propModel, coords.x, coords.y, coords.z - 1.0, false, false, false)
    PlaceObjectOnGroundProperly(prop)
    FreezeEntityPosition(prop, true)

    return prop
end

-- Task duration based on difficulty
local TaskDurations = {
    easy = 6000,
    medium = 8000,
    hard = 12000,
}

-- =====================================
-- PARTICLE EFFECTS SYSTEM
-- =====================================

local ActiveParticles = {}

-- Particle definitions for task types
local TaskParticles = {
    pipe = {
        dict = 'core',
        name = 'water_splash_plane',
        scale = 2.0,
        offset = vec3(0, 0, 0.5),
    },
    water_main = {
        dict = 'core',
        name = 'exp_grd_water',
        scale = 3.0,
        offset = vec3(0, 0, 0.3),
    },
    gas_leak = {
        dict = 'core',
        name = 'exp_grd_smoke',
        scale = 2.0,
        offset = vec3(0, 0, 0.5),
    },
    downed_lines = {
        dict = 'core',
        name = 'exp_grd_sparks',
        scale = 1.5,
        offset = vec3(0, 0, 1.0),
    },
    electrical = {
        dict = 'core',
        name = 'exp_grd_sparks',
        scale = 0.8,
        offset = vec3(0, 0, 0.5),
    },
    transformer = {
        dict = 'core',
        name = 'exp_grd_sparks',
        scale = 1.2,
        offset = vec3(0, 0, 1.5),
    },
    hydrant = {
        dict = 'core',
        name = 'water_splash_plane',
        scale = 1.0,
        offset = vec3(0, 0, 0.8),
    },
    storm_drain = {
        dict = 'core',
        name = 'water_splash_plane',
        scale = 0.8,
        offset = vec3(0, 0, -0.5),
    },
    hazmat = {
        dict = 'core',
        name = 'exp_grd_grenade_smoke',
        scale = 1.5,
        offset = vec3(0, 0, 0.3),
    },
}

local function StartTaskParticles(taskType, coords)
    local particleData = TaskParticles[taskType]
    if not particleData then return nil end

    -- Request particle asset
    RequestNamedPtfxAsset(particleData.dict)
    while not HasNamedPtfxAssetLoaded(particleData.dict) do
        Wait(10)
    end

    UseParticleFxAsset(particleData.dict)

    local particleCoords = coords + particleData.offset

    -- Start looped particle effect
    local particle = StartParticleFxLoopedAtCoord(
        particleData.name,
        particleCoords.x, particleCoords.y, particleCoords.z,
        0.0, 0.0, 0.0,
        particleData.scale,
        false, false, false, false
    )

    ActiveParticles[taskType] = particle
    return particle
end

local function StopTaskParticles(taskType)
    if ActiveParticles[taskType] then
        StopParticleFxLooped(ActiveParticles[taskType], false)
        ActiveParticles[taskType] = nil
    end
end

StopAllParticles = function()
    for taskType, particle in pairs(ActiveParticles) do
        if DoesParticleFxLoopedExist(particle) then
            StopParticleFxLooped(particle, false)
        end
    end
    ActiveParticles = {}
end

-- =====================================
-- SKILL CHECKS
-- =====================================

local function GetDifficultyForTask(taskType)
    local difficulties = {
        pipe = { 'easy', 'easy' },
        pothole = { 'easy' },
        streetlight = { 'easy', 'medium' },
        electrical = { 'medium', 'medium' },
        transformer = { 'medium', 'hard' },
        hazmat = { 'hard', 'hard' },
    }
    return difficulties[taskType] or Config.SkillCheck.Difficulty
end

local function DoTaskSkillCheck(taskType)
    local difficulty = GetDifficultyForTask(taskType)

    local success = lib.skillCheck(difficulty, Config.SkillCheck.Input)

    return success
end

-- =====================================
-- NEXT TASK
-- =====================================

function NextDelivery(data)
    if not data or not data.location then
        Bridge.Notify('No tasks available', 'error')
        return
    end

    activeJob = true
    CurrentTask = data

    -- Create blip for task location
    if JobBlip then RemoveBlip(JobBlip) end
    JobBlip = AddBlipForCoord(data.location.x, data.location.y, data.location.z)
    SetBlipSprite(JobBlip, 566)
    SetBlipColour(JobBlip, 5)
    SetBlipRoute(JobBlip, true)
    SetBlipRouteColour(JobBlip, 5)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(data.taskType and ('Task: ' .. (data.label or data.taskType)) or 'Work Site')
    EndTextCommandSetBlipName(JobBlip)

    -- Stop any existing particles
    StopAllParticles()

    -- Spawn task prop
    if currentCone then DeleteEntity(currentCone) end
    currentCone = SpawnTaskProp(data.taskType or 'pipe', data.location)

    -- Start particle effects for applicable tasks
    StartTaskParticles(data.taskType, data.location)

    -- Create target zone for task
    if currZone then RemoveTargetZone(currZone) end

    local taskType = data.taskType or 'pipe'
    local targetOptions = {}

    -- Special handling for traffic control task
    if taskType == 'traffic_control' then
        targetOptions = {
            {
                icon = 'fas fa-road',
                label = 'Setup Traffic Control',
                action = function()
                    OpenTrafficControlMenu()
                end,
                canInteract = function()
                    return activeJob and isHired
                end,
            }
        }
    else
        -- Standard repair task
        targetOptions = {
            {
                icon = 'fas fa-wrench',
                label = data.label or 'Repair',
                action = function()
                    DoRepairTask()
                end,
                canInteract = function()
                    return activeJob and isHired
                end,
            }
        }
    end

    currZone = AddTargetZone('cityworker_task_' .. math.random(1000, 9999), {
        coords = data.location,
        radius = 2.0,
    }, targetOptions)

    local taskLabel = data.label or 'Repair Task'
    Bridge.Notify('New task: ' .. taskLabel, 'inform')
end

function DoRepairTask()
    if not activeJob or not CurrentTask then return end

    local taskType = CurrentTask.taskType or 'pipe'
    local category = CurrentTask.category or 'maintenance'
    local difficulty = CurrentTask.difficulty or 'easy'

    -- Get category-specific animation
    local animData = GetTaskAnimation(category)
    lib.requestAnimDict(animData.dict)
    TaskPlayAnim(cache.ped, animData.dict, animData.anim, 8.0, -8.0, -1, 1, 0, false, false, false)

    -- Get duration based on difficulty
    local duration = TaskDurations[difficulty] or 8000

    -- Task-specific labels
    local taskLabels = {
        pipe = 'Repairing pipe...',
        pothole = 'Filling pothole...',
        meter_reading = 'Reading meter...',
        graffiti = 'Removing graffiti...',
        trash = 'Collecting trash...',
        streetlight = 'Fixing streetlight...',
        hydrant = 'Inspecting hydrant...',
        sign_repair = 'Repairing sign...',
        manhole = 'Inspecting manhole...',
        storm_drain = 'Clearing drain...',
        electrical = 'Repairing electrical box...',
        traffic_control = 'Setting up traffic control...',
        tree_trimming = 'Trimming tree...',
        cable_install = 'Installing cable...',
        transformer = 'Servicing transformer...',
        hazmat = 'Cleaning hazmat...',
        bridge_inspection = 'Inspecting bridge...',
        utility_locating = 'Locating utilities...',
        water_main = 'Fixing water main!',
        gas_leak = 'Sealing gas leak!',
        downed_lines = 'Securing power lines!',
        fallen_tree = 'Removing fallen tree!',
    }

    local progressLabel = taskLabels[taskType] or CurrentTask.label or 'Working...'

    local success = lib.progressBar({
        duration = duration,
        label = progressLabel,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = animData.dict, clip = animData.anim },
    })

    ClearPedTasks(cache.ped)

    if not success then
        Bridge.Notify('Task cancelled', 'error')
        return
    end

    -- Skill check
    local passed = DoTaskSkillCheck(taskType)

    if not passed then
        Bridge.Notify('Task failed - try again!', 'error')
        return
    end

    -- Get payment and next task
    local paymentSuccess, result = lib.callback.await('dps-cityworker:server:Payment', false)

    if paymentSuccess and result then
        -- Clean up current task
        if currZone then
            RemoveTargetZone(currZone)
            currZone = nil
        end
        if currentCone then
            DeleteEntity(currentCone)
            currentCone = nil
        end

        -- Show results
        Bridge.Notify(('Task complete! +$%d | +%d XP'):format(result.payment, result.xp), 'success')

        if result.sectorId then
            Bridge.Notify(('%s sector health: %.0f%%'):format(result.sectorId, result.sectorHealth), 'inform')
        end

        -- Get next task (wait before assigning new task)
        Wait(5000)

        if isHired and result.nextTask then
            NextDelivery({
                location = result.nextTask.location,
                taskType = result.nextTask.type,
                label = result.nextTask.label,
                category = result.nextTask.category,
                difficulty = result.nextTask.difficulty,
            })
        end
    else
        Bridge.Notify('Something went wrong', 'error')
    end
end

-- =====================================
-- WORK START/FINISH
-- =====================================

local function startWork(netid, data)
    local workVehicle = lib.waitFor(function()
        if NetworkDoesEntityExistWithNetworkId(netid) then
            return NetToVeh(netid)
        end
    end, 'Could not load entity in time.', 3000)

    if not workVehicle then
        Bridge.Notify('Failed to spawn work vehicle', 'error')
        return
    end

    SetVehicleNumberPlateText(workVehicle, 'CITY' .. tostring(math.random(1000, 9999)))
    SetVehicleColours(workVehicle, 111, 111)
    SetVehicleDirtLevel(workVehicle, 1)
    handleVehicleKeys(workVehicle)
    SetVehicleEngineOn(workVehicle, true, true)

    isHired = true

    -- Handle fuel
    if Config.FuelScript and Config.FuelScript.enable then
        exports[Config.FuelScript.script]:SetFuel(workVehicle, 100.0)
    else
        Entity(workVehicle).state.fuel = 100
    end

    Bridge.Notify('You started your shift!', 'success')

    -- Start first task
    NextDelivery({
        location = data.location,
        taskType = data.taskType,
        label = data.label or 'Repair Task',
        category = data.category,
        difficulty = data.difficulty,
    })
end

local function finishWork()
    local ped = cache.ped
    local pos = GetEntityCoords(ped)
    local finishspot = vec3(Config.BossCoords.x, Config.BossCoords.y, Config.BossCoords.z)

    if #(pos - finishspot) > 15.0 then
        Bridge.Notify('Return to HQ to clock out', 'error')
        return
    end

    if not isHired then return end

    local success = lib.callback.await('dps-cityworker:server:clockOut', false)
    if success then
        Bridge.Notify('You ended your shift', 'success')
        cleanupJob()
        isHired = false
        activeJob = false
    end
end

-- =====================================
-- BOSS PED
-- =====================================

local function yeetPed()
    if DoesEntityExist(cityBoss) then
        RemoveTargetEntity(cityBoss, {'Start Work', 'Finish Work'})
        DeleteEntity(cityBoss)
        cityBoss = nil
    end
end

local function spawnPed()
    if DoesEntityExist(cityBoss) then return end

    lib.requestModel(Config.BossModel)
    cityBoss = CreatePed(0, Config.BossModel, Config.BossCoords.x, Config.BossCoords.y, Config.BossCoords.z, Config.BossCoords.w, false, false)
    SetEntityAsMissionEntity(cityBoss, true, true)
    SetPedFleeAttributes(cityBoss, 0, 0)
    SetBlockingOfNonTemporaryEvents(cityBoss, true)
    SetEntityInvincible(cityBoss, true)
    FreezeEntityPosition(cityBoss, true)
    TaskStartScenarioInPlace(cityBoss, 'WORLD_HUMAN_CLIPBOARD', 0, true)

    AddTargetEntity(cityBoss, {
        {
            icon = 'fas fa-hard-hat',
            label = 'Start Work',
            action = function()
                local netid, data = lib.callback.await('dps-cityworker:server:spawnVehicle', false)
                if netid then
                    startWork(netid, data)
                else
                    Bridge.Notify('Could not start work', 'error')
                end
            end,
            canInteract = function()
                return not isHired
            end,
        },
        {
            icon = 'fas fa-sign-out-alt',
            label = 'Finish Work',
            action = function()
                finishWork()
            end,
            canInteract = function()
                return isHired
            end,
        },
    })
end

-- =====================================
-- SPAWN ZONE
-- =====================================

startZone = lib.points.new({
    coords = vec3(Config.BossCoords.x, Config.BossCoords.y, Config.BossCoords.z),
    distance = 50,
})

function startZone:onEnter()
    spawnPed()
end

function startZone:onExit()
    yeetPed()
end

-- =====================================
-- CONTROL ROOM NUI
-- =====================================

RegisterNetEvent('dps-cityworker:client:OpenControlRoom', function()
    local canOpen, sectorData = lib.callback.await('dps-cityworker:server:OpenControlRoom', false)

    if not canOpen then return end

    ControlRoomOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        sectors = sectorData
    })
end)

RegisterNetEvent('dps-cityworker:client:UpdateSectorHealth', function(sectorHealth)
    if ControlRoomOpen then
        local data = {}
        for id, health in pairs(sectorHealth) do
            data[id] = {
                health = health,
                label = Config.Sectors[id] and Config.Sectors[id].label or id,
            }
        end
        SendNUIMessage({
            action = 'update',
            sectors = data
        })
    end
end)

RegisterNUICallback('closeUI', function(_, cb)
    ControlRoomOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    cb('ok')
end)

RegisterNUICallback('dispatchCrew', function(data, cb)
    local success, msg = lib.callback.await('dps-cityworker:server:DispatchCrew', false, data.sector)
    if success then
        Bridge.Notify('Crew dispatched to ' .. data.sector, 'success')
    else
        Bridge.Notify(msg or 'Failed to dispatch', 'error')
    end
    cb('ok')
end)

-- =====================================
-- BLACKOUT EFFECTS
-- =====================================

local BlackoutActive = {}

RegisterNetEvent('dps-cityworker:client:TriggerBlackout', function(sectorId)
    if BlackoutActive[sectorId] then return end

    local sector = Config.Sectors[sectorId]
    if not sector then return end

    BlackoutActive[sectorId] = true

    Bridge.Notify(('ALERT: %s experiencing power outage!'):format(sector.label), 'error')

    -- Visual effect - flickering lights in area
    CreateThread(function()
        while BlackoutActive[sectorId] do
            local playerPos = GetEntityCoords(cache.ped)
            if #(playerPos - sector.coords) < sector.radius then
                -- Flicker effect
                SetArtificialLightsState(true)
                Wait(math.random(100, 500))
                SetArtificialLightsState(false)
                Wait(math.random(500, 2000))
            else
                Wait(1000)
            end
        end
        SetArtificialLightsState(false)
    end)
end)

-- Clear blackout when sector is repaired
RegisterNetEvent('dps-cityworker:client:ClearBlackout', function(sectorId)
    BlackoutActive[sectorId] = nil
    SetArtificialLightsState(false)
end)

-- =====================================
-- EMERGENCY EVENTS
-- =====================================

local ActiveEmergencyBlips = {}
local EmergencyProps = {}

RegisterNetEvent('dps-cityworker:client:EmergencyAlert', function(data)
    -- Create emergency blip
    if ActiveEmergencyBlips[data.sector] then
        RemoveBlip(ActiveEmergencyBlips[data.sector])
    end

    local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
    SetBlipSprite(blip, 126) -- Warning icon
    SetBlipColour(blip, 1) -- Red
    SetBlipScale(blip, 1.2)
    SetBlipFlashes(blip, true)
    SetBlipAsShortRange(blip, false) -- Always visible
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(('EMERGENCY: %s'):format(data.label))
    EndTextCommandSetBlipName(blip)

    ActiveEmergencyBlips[data.sector] = blip

    -- Alert notification with sound
    PlaySoundFrontend(-1, "TIMER_STOP", "HUD_MINI_GAME_SOUNDSET", true)

    -- Only show detailed alert to on-duty workers
    if isHired then
        lib.notify({
            title = 'EMERGENCY ALERT',
            description = ('%s at %s!\nBonus XP: +%d'):format(data.label, data.sectorLabel, data.xpBonus),
            type = 'error',
            duration = 15000,
            icon = 'fa-solid fa-triangle-exclamation',
        })

        -- Offer to respond
        local response = lib.alertDialog({
            header = 'Emergency Response',
            content = ('**%s** reported at **%s**!\n\nThis is a high-priority emergency. Respond for bonus pay and XP.\n\nSet GPS to emergency location?'):format(data.label, data.sectorLabel),
            centered = true,
            cancel = true,
            labels = { confirm = 'Respond', cancel = 'Ignore' }
        })

        if response == 'confirm' then
            SetNewWaypoint(data.coords.x, data.coords.y)
            Bridge.Notify('GPS set to emergency. Hurry!', 'warning')

            -- Create target zone for emergency
            CreateEmergencyZone(data)
        end
    else
        -- Non-workers just see the notification
        lib.notify({
            title = 'City Alert',
            description = ('%s reported at %s'):format(data.label, data.sectorLabel),
            type = 'warning',
            duration = 8000,
        })
    end
end)

function CreateEmergencyZone(data)
    -- Spawn emergency prop
    local propModel = GetTaskProp(data.type)
    lib.requestModel(propModel)
    local prop = CreateObject(propModel, data.coords.x, data.coords.y, data.coords.z - 1.0, false, false, false)
    PlaceObjectOnGroundProperly(prop)
    FreezeEntityPosition(prop, true)
    EmergencyProps[data.sector] = prop

    -- Start emergency particle effects (more intense)
    StartTaskParticles(data.type, data.coords)

    -- Create target zone
    local zoneName = 'emergency_' .. data.sector
    AddTargetZone(zoneName, {
        coords = data.coords,
        radius = 3.0,
    }, {
        {
            icon = 'fas fa-exclamation-triangle',
            label = ('Respond: %s'):format(data.label),
            action = function()
                RespondToEmergency(data.sector)
            end,
            canInteract = function()
                return isHired
            end,
        }
    })
end

function RespondToEmergency(sectorId)
    local canRespond, emergencyData = lib.callback.await('dps-cityworker:server:RespondToEmergency', false, sectorId)

    if not canRespond then
        Bridge.Notify(emergencyData or 'Cannot respond to emergency', 'error')
        return
    end

    -- Emergency repair with higher stakes
    local animData = GetTaskAnimation('emergency')
    lib.requestAnimDict(animData.dict)

    local success = lib.progressBar({
        duration = 15000, -- Emergencies take longer
        label = ('EMERGENCY: %s'):format(emergencyData.label),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = animData.dict, clip = animData.anim },
    })

    ClearPedTasks(cache.ped)

    if not success then
        Bridge.Notify('Emergency response cancelled!', 'error')
        return
    end

    -- Harder skill check for emergencies
    local passed = lib.skillCheck({'medium', 'hard', 'hard'}, Config.SkillCheck.Input)

    if not passed then
        Bridge.Notify('Emergency repair failed! Try again!', 'error')
        return
    end

    -- Complete the emergency
    local completed = lib.callback.await('dps-cityworker:server:CompleteEmergency', false, sectorId)

    if completed then
        Bridge.Notify('Emergency resolved! Great work!', 'success')

        -- Stop particle effects
        StopAllParticles()

        -- Clean up emergency prop
        if EmergencyProps[sectorId] then
            DeleteEntity(EmergencyProps[sectorId])
            EmergencyProps[sectorId] = nil
        end
    end
end

RegisterNetEvent('dps-cityworker:client:EmergencyResolved', function(sectorId)
    -- Remove emergency blip
    if ActiveEmergencyBlips[sectorId] then
        RemoveBlip(ActiveEmergencyBlips[sectorId])
        ActiveEmergencyBlips[sectorId] = nil
    end

    -- Stop particle effects
    if StopAllParticles then StopAllParticles() end

    -- Clean up prop
    if EmergencyProps[sectorId] then
        DeleteEntity(EmergencyProps[sectorId])
        EmergencyProps[sectorId] = nil
    end

    local sector = Config.Sectors[sectorId]
    if sector then
        lib.notify({
            title = 'Emergency Resolved',
            description = ('%s emergency has been handled'):format(sector.label),
            type = 'success',
            duration = 5000,
        })
    end
end)

-- =====================================
-- TRAFFIC CONTROL SYSTEM
-- =====================================

local PlacedTrafficProps = {}
local MAX_TRAFFIC_PROPS = 8

local function PlaceTrafficProp(propType)
    if #PlacedTrafficProps >= MAX_TRAFFIC_PROPS then
        Bridge.Notify('Maximum props placed (8)', 'error')
        return
    end

    local propModel = Config.TrafficProps[propType]
    if not propModel then return end

    lib.requestModel(propModel)

    local playerPos = GetEntityCoords(cache.ped)
    local playerHeading = GetEntityHeading(cache.ped)
    local forward = GetEntityForwardVector(cache.ped)

    -- Place prop 1.5m in front of player
    local placePos = playerPos + forward * 1.5

    -- Animation for placing
    lib.requestAnimDict('anim@heists@narcotics@trash')
    TaskPlayAnim(cache.ped, 'anim@heists@narcotics@trash', 'drop_front', 8.0, -8.0, 1000, 0, 0, false, false, false)

    Wait(500)

    local prop = CreateObject(propModel, placePos.x, placePos.y, placePos.z - 1.0, false, false, false)
    PlaceObjectOnGroundProperly(prop)
    FreezeEntityPosition(prop, true)
    SetEntityHeading(prop, playerHeading)

    table.insert(PlacedTrafficProps, prop)

    ClearPedTasks(cache.ped)
    Bridge.Notify(('Placed %s (%d/%d)'):format(propType, #PlacedTrafficProps, MAX_TRAFFIC_PROPS), 'success')
end

local function PickupTrafficProp()
    local playerPos = GetEntityCoords(cache.ped)
    local closestProp = nil
    local closestDist = 3.0

    for i, prop in ipairs(PlacedTrafficProps) do
        if DoesEntityExist(prop) then
            local propPos = GetEntityCoords(prop)
            local dist = #(playerPos - propPos)
            if dist < closestDist then
                closestDist = dist
                closestProp = i
            end
        end
    end

    if closestProp then
        lib.requestAnimDict('anim@heists@narcotics@trash')
        TaskPlayAnim(cache.ped, 'anim@heists@narcotics@trash', 'pickup', 8.0, -8.0, 1000, 0, 0, false, false, false)

        Wait(500)

        DeleteEntity(PlacedTrafficProps[closestProp])
        table.remove(PlacedTrafficProps, closestProp)

        ClearPedTasks(cache.ped)
        Bridge.Notify(('Picked up prop (%d remaining)'):format(#PlacedTrafficProps), 'inform')
    else
        Bridge.Notify('No props nearby', 'error')
    end
end

local function ClearAllTrafficProps()
    for _, prop in ipairs(PlacedTrafficProps) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end
    PlacedTrafficProps = {}
end

-- Traffic control radial menu (when doing traffic_control task)
local TrafficControlActive = false

local function OpenTrafficControlMenu()
    if TrafficControlActive then return end
    TrafficControlActive = true

    lib.registerContext({
        id = 'traffic_control_menu',
        title = 'Traffic Control Equipment',
        options = {
            {
                title = 'Place Cone',
                description = 'Place a traffic cone',
                icon = 'fa-solid fa-cone-striped',
                onSelect = function()
                    PlaceTrafficProp('Cone')
                end,
            },
            {
                title = 'Place Barrier',
                description = 'Place a road barrier',
                icon = 'fa-solid fa-road-barrier',
                onSelect = function()
                    PlaceTrafficProp('Barrier')
                end,
            },
            {
                title = 'Place Stop Sign',
                description = 'Place a stop sign',
                icon = 'fa-solid fa-octagon',
                onSelect = function()
                    PlaceTrafficProp('Sign_Stop')
                end,
            },
            {
                title = 'Place Slow Sign',
                description = 'Place a slow sign',
                icon = 'fa-solid fa-diamond',
                onSelect = function()
                    PlaceTrafficProp('Sign_Slow')
                end,
            },
            {
                title = 'Place Work Light',
                description = 'Place a work light',
                icon = 'fa-solid fa-lightbulb',
                onSelect = function()
                    PlaceTrafficProp('Light')
                end,
            },
            {
                title = 'Pickup Nearest',
                description = 'Pick up nearest prop',
                icon = 'fa-solid fa-hand',
                onSelect = function()
                    PickupTrafficProp()
                end,
            },
            {
                title = 'Complete Setup',
                description = ('Finish traffic control (%d props placed)'):format(#PlacedTrafficProps),
                icon = 'fa-solid fa-check',
                disabled = #PlacedTrafficProps < 4,
                onSelect = function()
                    CompleteTrafficControl()
                end,
            },
        }
    })

    lib.showContext('traffic_control_menu')
    TrafficControlActive = false
end

function CompleteTrafficControl()
    if #PlacedTrafficProps < 4 then
        Bridge.Notify('Place at least 4 props to complete', 'error')
        return
    end

    -- Complete the task
    local paymentSuccess, result = lib.callback.await('dps-cityworker:server:Payment', false)

    if paymentSuccess and result then
        -- Clean up placed props after a delay (simulating crew picks them up later)
        SetTimeout(60000, function()
            ClearAllTrafficProps()
        end)

        Bridge.Notify(('Traffic control complete! +$%d | +%d XP'):format(result.payment, result.xp), 'success')

        -- Clean up current task zone
        if currZone then
            RemoveTargetZone(currZone)
            currZone = nil
        end
        if currentCone then
            DeleteEntity(currentCone)
            currentCone = nil
        end

        Wait(5000)

        if isHired and result.nextTask then
            NextDelivery({
                location = result.nextTask.location,
                taskType = result.nextTask.type,
                label = result.nextTask.label,
                category = result.nextTask.category,
                difficulty = result.nextTask.difficulty,
            })
        end
    end
end

-- Cleanup traffic props on job reset
local OriginalCleanupJob = cleanupJob

cleanupJob = function()
    ClearAllTrafficProps()
    OriginalCleanupJob()
end

-- =====================================
-- WEATHER-TRIGGERED EVENTS
-- =====================================

local WeatherTypes = {
    RAIN = { 'RAIN', 'THUNDER', 'CLEARING' },
    STORM = { 'THUNDER' },
    CLEAR = { 'CLEAR', 'EXTRASUNNY', 'CLOUDS', 'OVERCAST', 'SMOG', 'FOGGY' },
}

local function IsWeatherType(weatherType, category)
    local hash = GetPrevWeatherTypeHashName()
    for _, weather in ipairs(WeatherTypes[category] or {}) do
        if hash == GetHashKey(weather) then
            return true
        end
    end
    return false
end

local LastWeatherCheck = 0
local WeatherEventCooldown = 600000 -- 10 minutes between weather events

-- Monitor weather and trigger appropriate events
CreateThread(function()
    while true do
        Wait(60000) -- Check every minute

        if not isHired then
            Wait(5000)
            goto continue
        end

        local currentTime = GetGameTimer()
        if currentTime - LastWeatherCheck < WeatherEventCooldown then
            goto continue
        end

        -- Check for rain - increased chance of storm drain tasks
        if IsWeatherType(nil, 'RAIN') then
            -- Notify server to potentially spawn storm drain clearing
            TriggerServerEvent('dps-cityworker:server:WeatherEvent', 'rain')
            LastWeatherCheck = currentTime

            lib.notify({
                title = 'Weather Alert',
                description = 'Heavy rain detected. Storm drains may need clearing.',
                type = 'warning',
                duration = 8000,
            })
        end

        -- Check for thunder - chance of fallen trees or downed power lines
        if IsWeatherType(nil, 'STORM') then
            TriggerServerEvent('dps-cityworker:server:WeatherEvent', 'storm')
            LastWeatherCheck = currentTime

            lib.notify({
                title = 'Storm Warning',
                description = 'Severe weather! Watch for fallen trees and downed lines.',
                type = 'error',
                duration = 10000,
            })
        end

        ::continue::
    end
end)

-- Weather task bonus notification
local WeatherBonusActive = {}

RegisterNetEvent('dps-cityworker:client:WeatherTaskBonus', function(data)
    WeatherBonusActive[data.type] = true

    lib.notify({
        title = 'Weather Bonus Active',
        description = data.message,
        type = 'success',
        duration = 15000,
        icon = 'fa-solid fa-cloud-rain',
    })

    -- Bonus expires after 10 minutes
    SetTimeout(600000, function()
        WeatherBonusActive[data.type] = nil
    end)
end)

-- =====================================
-- CREW/TEAM SYSTEM
-- =====================================

-- Task assigned by foreman
RegisterNetEvent('dps-cityworker:client:TaskAssigned', function(data)
    if not isHired then return end

    -- Play notification sound
    PlaySoundFrontend(-1, "CHALLENGE_UNLOCKED", "HUD_AWARDS", true)

    lib.notify({
        title = 'Task Assigned',
        description = ('Foreman %s assigned you: %s'):format(data.assignedBy, data.label),
        type = 'inform',
        duration = 10000,
        icon = 'fa-solid fa-clipboard-list',
    })

    -- Clean up current task
    cleanupJob()

    -- Start new assigned task
    NextDelivery({
        location = data.location,
        taskType = data.type,
        label = data.label,
    })
end)

-- Teamwork bonus indicator
local TeamworkCheckThread = nil

local function StartTeamworkCheck()
    if TeamworkCheckThread then return end

    TeamworkCheckThread = CreateThread(function()
        local lastBonus = 0

        while isHired do
            Wait(10000) -- Check every 10 seconds

            local nearby = lib.callback.await('dps-cityworker:server:GetNearbyWorkers', false, 30.0)
            local bonusPercent = math.min(#nearby * 10, 30)

            if bonusPercent > 0 and bonusPercent ~= lastBonus then
                lib.notify({
                    title = 'Teamwork Bonus',
                    description = ('%d%% bonus active! (%d workers nearby)'):format(bonusPercent, #nearby),
                    type = 'success',
                    duration = 5000,
                    icon = 'fa-solid fa-users',
                })
                lastBonus = bonusPercent
            elseif bonusPercent == 0 and lastBonus > 0 then
                lastBonus = 0
            end
        end

        TeamworkCheckThread = nil
    end)
end

-- Auto-start teamwork check when player becomes hired
CreateThread(function()
    while true do
        Wait(5000)
        if isHired and not TeamworkCheckThread then
            StartTeamworkCheck()
        end
    end
end)

-- =====================================
-- DISPATCH ALERTS
-- =====================================

RegisterNetEvent('dps-cityworker:client:DispatchAlert', function(data)
    if not isHired then return end

    lib.notify({
        title = 'Dispatch Alert',
        description = ('Crew needed at %s'):format(data.label),
        type = 'warning',
        duration = 10000,
    })

    -- Set GPS to dispatch location
    local alert = lib.alertDialog({
        header = 'Dispatch Alert',
        content = ('Crew requested at **%s**.\n\nSet GPS to location?'):format(data.label),
        centered = true,
        cancel = true,
        labels = { confirm = 'Set GPS', cancel = 'Ignore' }
    })

    if alert == 'confirm' then
        SetNewWaypoint(data.coords.x, data.coords.y)
        Bridge.Notify('GPS set to dispatch location', 'inform')
    end
end)

-- =====================================
-- PLAYER LOAD/UNLOAD
-- =====================================

function OnPlayerLoaded()
    -- Nothing needed on load
end

function OnPlayerUnload()
    resetJob()
end

-- =====================================
-- RESOURCE CLEANUP
-- =====================================

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        resetJob()
        SetArtificialLightsState(false)
        if ControlRoomOpen then
            SetNuiFocus(false, false)
        end
    end
end)

-- =====================================
-- EXPORTS
-- =====================================

exports('IsPlayerOnDuty', function()
    return isHired
end)

exports('GetNearestWorkZone', function()
    local playerPos = GetEntityCoords(cache.ped)
    local nearest = nil
    local nearestDist = math.huge

    for id, data in pairs(Config.Sectors) do
        local dist = #(playerPos - data.coords)
        if dist < nearestDist then
            nearest = id
            nearestDist = dist
        end
    end

    return nearest, nearestDist
end)
