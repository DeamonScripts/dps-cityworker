
# dps-cityworker - City Worker Career Simulation

A comprehensive career simulation resource for FiveM that transforms simple utility tasks into a fully managed city infrastructure system. Features strategic grid management, persistent world damage, and a player-run contractor economy.

## Features

- **Strategic Grid Management**: City is divided into managed sectors (Legion, Mirror Park, Sandy Shores) with dynamic health tracking.
- **Persistent Decay**: Infrastructure damage (potholes, broken lights) is saved to the database and worsens over time if neglected.
- **Contractor Economy**: Players can register utility companies and bid on government maintenance contracts.
- **Union Progression**: A 5-tier seniority system unlocking specialized equipment and pay grades.
- **Control Room UI**: Advanced dashboard for monitoring grid health and dispatching crews.
- **Traffic Control**: Functional props (cones, barriers) that actively reroute NPC traffic around work zones.

## Dependencies

- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)
- [oxmysql](https://github.com/overextended/oxmysql)
- [qb-core](https://github.com/qbcore-framework/qb-core) or ESX Legacy

## Installation

1. Copy `dps-cityworker` to your resources folder.
2. Import `sql/cityworker.sql` into your database.
3. Add `ensure dps-cityworker` to your `server.cfg`.
4. Configure `config.lua` to set your framework and pricing.

## Progression System (Roadmap)

| Level | Rank | Unlocks |
| :--- | :--- | :--- |
| 1 | Probationary Laborer | Basic Pothole Repair, Cone Placement |
| 2 | Junior Technician | Streetlight Repair, Utility Truck (Tier 1) |
| 3 | Senior Technician | Electrical Box Repair, Transformer Minigames |
| 4 | Specialist | Hazmat Cleanup, High-Voltage Equipment |
| 5 | Foreman | Control Room Access, Contract Bidding, Crew Management |

## Configuration

### Main Settings (`config.lua`)
```lua
Config = {}
Config.Debug = false
Config.Framework = 'qb' -- 'qb' or 'esx'
Config.Target = 'ox_target'

-- Economic Settings
Config.Economy = {
    WeeklyBudget = 50000, -- Gov budget for maintenance
    CompanyRegistrationFee = 5000,
    BasePayPerTask = 250
}

Config.Sectors = {
    ['legion_square'] = {
        label = "Legion Square",
        decayRate = 0.5, -- % health lost per hour
        blackoutThreshold = 0 -- % health where lights go out
    },
    ['sandy_shores'] = {
        label = "Sandy Shores",
        decayRate = 0.8,
        blackoutThreshold = 10
    }
}
```
### Exports
## Server
```Lua
exports['dps-cityworker']:GetSectorHealth(sectorId)
exports['dps-cityworker']:TriggerBlackout(sectorId)
exports['dps-cityworker']:GetPlayerSeniority(source)
```
## Client 
```lua
exports['dps-cityworker']:IsPlayerOnDuty()
exports['dps-cityworker']:GetNearestWorkZone()
```
## Command,Permission,Description
/workstatusEveryoneCheck your current rank and job stats
/controlroomForeman+Open the HQ grid management dashboard
/setsectorhealth [id] [amount]AdminForce set a sector's health percentage
/reportdamageEveryoneReport infrastructure damage to dispatch

## Credits
DPS Development Team (Maintainer & Expansion)

Randol (Original Script Creator)

License
You have permission to use this in your server and edit for your personal needs but are not allowed to redistribute.
