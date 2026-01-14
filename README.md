## Randolio: City Worker

**ESX/QB supported with bridge.**

Requirements: https://github.com/overextended/ox_lib/releases

**Changes** - Last updated: 10/03/2024

* Added support for both ESX and QB frameworks.
* Utilized ox lib throughout.
* Configs are now split into client and server configs. (config.lua and sv_config.lua)
* The whole script was rewritten to secure any exploits.

**You have permission to use this in your server and edit for your personal needs but are not allowed to redistribute.**

## 🚀 Future Feature Improvements (Roadmap)

We are planning to expand `randol_cityworker` from a simple task script into a comprehensive career simulation. Below are the planned features:

### 🧠 Strategic Grid Management
- **Control Room UI:** A new management interface at City Works HQ dividing the city into sectors (Legion, Mirror Park, Sandy Shores, Roxwood, Paleto).
- **Sector Health:** Each sector has a "Health" percentage that drops over time or due to neglect.
- **Consequences:** Reaching 0% health triggers massive **Blackouts** (lights off, store alarms triggering) in that specific zone, forcing players to prioritize emergency repairs strategically.

### ⏳ Persistent Infrastructure Decay
- **Database Persistence:** Damage to the city (potholes, broken streetlights) is saved to the database and persists through server restarts.
- **Worsening Conditions:** Unfixed issues degrade further over time. Ignored potholes get deeper, eventually causing tire damage to player vehicles.
- **Government Incentive:** Creates a gameplay loop where the City Government must properly fund the City Works department to prevent the city from falling into disrepair.

### 🏗️ Contractor Economy
- **Player-Owned Companies:** Allows players to register their own "Utility Sub-Contractor" companies instead of just working for an NPC boss.
- **Bidding System:** The Mayor or City Government sets a maintenance budget, and player companies must bid on city maintenance contracts.
- **Competition:** Creates a competitive labor market where companies like "Deamon Electric" or "Randol Roads" compete for the most lucrative city contracts.
