# DPS City Worker

**Turn utility work into a full career simulation.**

This isn't a basic delivery script. Players build careers as city infrastructure specialists - starting as laborers, working their way up to Foremen managing entire grid sectors. The city's infrastructure decays over time, creating real consequences when maintenance is neglected.

---

## What Players Experience

### Start as a Probationary Laborer
New workers start at **City Works HQ** where they clock in and receive a utility truck:
- Get assigned repair tasks across the city
- Complete skill checks to finish repairs
- Earn XP and money for each completed job

### Build Your Career
Every repair matters. The system tracks:
- **Total Repairs Completed** - Your work history
- **XP & Rank Progress** - Unlock harder (higher-paying) tasks
- **Sector Health Contributions** - Your impact on the city

### The Progression System

| Rank | Title | Unlocks |
|------|-------|---------|
| 1 | Probationary Laborer | Pothole Repair, Pipe Repair |
| 2 | Junior Technician | Streetlight Repair |
| 3 | Senior Technician | Electrical Box Repair |
| 4 | Specialist | Transformer Maintenance, Hazmat Cleanup |
| 5 | Foreman | **Control Room Access**, Crew Dispatch |

### Real Consequences
This isn't busy work. Infrastructure neglect has server-wide effects:
- **Sector Health Decay** - Each area decays over time without maintenance
- **Rolling Blackouts** - Sectors hitting 0% health trigger power outages
- **Persistent Damage** - Damage reports saved to database, persist through restarts

---

## The Control Room (Foreman Only)

Rank 5 Foremen get access to the **Grid Control Dashboard**:
- Monitor real-time health of all city sectors
- Dispatch crews to critical areas
- View which sectors need priority attention

The NUI dashboard shows Legion Square, Mirror Park, and Sandy Shores with live health bars.

---

## Task Types

| Task | Rank Required | Difficulty | XP |
|------|---------------|------------|-----|
| Pothole Repair | 1 | Easy | 15 |
| Water Pipe Repair | 1 | Easy | 20 |
| Streetlight Repair | 2 | Medium | 25 |
| Electrical Box | 3 | Medium | 35 |
| Transformer Maintenance | 4 | Hard | 50 |
| Hazmat Cleanup | 4 | Hard | 60 |

Higher rank = access to harder tasks with better pay.

---

## For Server Owners

### Why Add This?

**Player Engagement** - The career progression keeps workers coming back. They want to hit Foreman rank, see their impact on sector health.

**Server Consequences** - Blackouts when sectors fail creates organic RP moments. Government must fund city maintenance or face consequences.

**Low Maintenance** - Once configured, decay happens automatically. Workers self-organize to prevent blackouts.

### Framework Support

Works with your existing setup - no migrations needed:
- **QBCore** / **QBX** / **ESX** (auto-detected)
- **ox_target** / **qb-target**
- **ox_lib** notifications and skill checks

### Performance

Built for busy servers:
- Database persistence for sector health
- Efficient decay loops (10-minute intervals)
- Proper entity cleanup on clock-out

---

## Quick Start

1. Drop in `resources/[jobs]/dps-cityworker`
2. Run `sql/cityworker.sql`
3. `ensure dps-cityworker`

Full configuration in `config.lua`.

---

## Configuration

### Main Settings (`config.lua`)
```lua
Config.Framework = 'qb' -- Auto-detected, but can force
Config.Target = 'ox_target' -- or 'qb-target'
Config.Notify = 'ox_lib' -- or 'qb' or 'esx'

Config.Economy = {
    BasePay = 250, -- Base payment per task
    WeeklyBudget = 50000, -- Government budget (roadmap)
    MaterialCost = 50,
}

Config.Sectors = {
    ['legion'] = {
        label = "Legion Square",
        decayRate = 0.5, -- % health lost per hour
        blackoutThreshold = 0 -- Health % that triggers blackout
    },
}
```

### Adding More Sectors
Add entries to `Config.Sectors` in config.lua and matching cards in `web/index.html`.

---

## Commands

| Command | Permission | Description |
|---------|------------|-------------|
| `/workstatus` | All | Check your rank and stats |
| `/controlroom` | Rank 5+ | Open the Control Room dashboard |
| `/reportdamage [type]` | All | Report infrastructure damage |
| `/setsectorhealth [id] [%]` | Admin | Force set sector health |

---

## Exports

### Server
```lua
exports['dps-cityworker']:GetSectorHealth(sectorId)
exports['dps-cityworker']:GetAllSectorHealth()
exports['dps-cityworker']:TriggerBlackout(sectorId)
exports['dps-cityworker']:GetPlayerSeniority(source)
exports['dps-cityworker']:RepairSector(coords, amount)
```

### Client
```lua
exports['dps-cityworker']:IsPlayerOnDuty()
exports['dps-cityworker']:GetNearestWorkZone()
```

---

## Future Roadmap

### Strategic Grid Management
- **Control Room UI**: Management interface at City Works HQ dividing the city into sectors
- **Sector Health**: Each sector has a "Health" percentage that drops over time
- **Consequences**: 0% health triggers Blackouts in that zone

### Persistent Infrastructure Decay
- **Database Persistence**: Damage saved through server restarts
- **Worsening Conditions**: Unfixed issues degrade further (deeper potholes cause tire damage)
- **Government Incentive**: City Government must fund City Works to prevent disrepair

### Contractor Economy (Planned)
- **Player-Owned Companies**: Register utility sub-contractor companies
- **Bidding System**: Mayor/City Government sets maintenance budget, companies bid on contracts
- **Competition**: Companies like "Deamon Electric" or "Randol Roads" compete for city contracts

---

## Dependencies

**Required:**
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target) or qb-target
- [oxmysql](https://github.com/overextended/oxmysql)

**Framework (one of):**
- qb-core / qbx_core / es_extended

---

## Version History

**v2.5.0** - Multi-framework support, bridge architecture, infrastructure persistence, task variety
**v2.0.0** - Control Room UI, sector health system, rank progression
**v1.0.0** - Initial release (basic pipe repair)

---

## Credits

- **Randol** - Original concept and script
- **DaemonAlex / DPSRP Development** - Career expansion and bridge architecture
- Overextended (ox_lib, ox_target, oxmysql)

---

## License

You have permission to use this in your server and edit for your personal needs but are not allowed to redistribute.

---

*DPS City Worker - Keep the lights on.*
