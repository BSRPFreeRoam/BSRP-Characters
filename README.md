# 👤 BSRP Characters

A modern multi-character system built exclusively for the **BSRP Framework**.

BSRP Characters provides seamless character creation, selection, management, and persistence while integrating directly with the BSRP ecosystem. Designed for performance, flexibility, and future expansion, it serves as the foundation for player identity across all BSRP resources.

---

## Features

* 👤 Multi-character support
* ➕ Character creation
* ✏️ Character editing
* 🗑️ Character deletion
* 🎭 Character selection screen
* 💾 Persistent character data
* 📸 Character previews
* 🎨 Customizable appearance support
* ⚡ Fast loading and optimized performance
* 🔗 Full BSRP Framework integration

---

## Framework Requirements

This resource requires:

* BSRP Framework
* oxmysql
* ox_lib

Recommended:

* ox_inventory
* bsrp-housing
* bsrp-phone
* bsrp-jobs

---

## Installation

### 1. Place Resource

```text
resources/
└── bsrp-characters/
```

### 2. Ensure Dependencies

```cfg
ensure oxmysql
ensure ox_lib
ensure bsrp

ensure bsrp-characters
```

> BSRP Characters must start after the `bsrp` core resource.

---

## Database

Import the provided SQL file if included:

```sql
sql/bsrp-characters.sql
```

If automatic database initialization is enabled, required tables will be created automatically.

---

## Configuration

Configuration options can be found in:

```text
config.lua
```

Available settings may include:

* Maximum character slots
* Starting cash
* Spawn locations
* Character deletion permissions
* Default jobs
* Character appearance settings

---

## Character Management

### Create Character

Players can:

* Create new characters
* Select gender
* Set first and last name
* Configure date of birth
* Choose appearance options

### Select Character

* View available characters
* Preview character information
* Load saved progress
* Continue existing roleplay

### Delete Character

Players may remove characters based on server permissions and configuration settings.

---

## Character Data

Each character stores:

* Character ID
* First Name
* Last Name
* Date of Birth
* Gender
* Cash and Bank Accounts
* Job Information
* Housing Data
* Phone Information
* Inventory Data
* Position and Spawn Data

---

## Framework Integration

### Get Character

```lua
local player = exports.bsrp:GetPlayer(source)

if player then
    print(player.charinfo.firstname)
end
```

### Get Character Identifier

```lua
local citizenid = player.citizenid
```

### Check Character Loaded

```lua
if player and player.loaded then
    -- Character is active
end
```

---

## Character Events

Example usage:

```lua
RegisterNetEvent('bsrp:characterLoaded', function()
    print('Character loaded successfully.')
end)
```

```lua
RegisterNetEvent('bsrp:characterUnloaded', function()
    print('Character unloaded.')
end)
```

> Event names may vary depending on implementation.

---

## Permissions

Administrative actions can utilize the BSRP permission system:

```lua
if exports.bsrp:IsAdmin(source, 2) then
    -- Character administration actions
end
```

---

## Compatibility

| Resource       | Supported |
| -------------- | --------- |
| BSRP Framework | ✅         |
| oxmysql        | ✅         |
| ox_lib         | ✅         |
| ox_inventory   | ✅         |
| bsrp-phone     | ✅         |
| bsrp-housing   | ✅         |
| bsrp-jobs      | ✅         |

---

## Character Lifecycle

### Player Connects

1. Player joins server
2. Character selection opens
3. Existing characters are loaded
4. Player selects or creates a character

### Character Loads

1. Character data is retrieved
2. Inventory is loaded
3. Job information is loaded
4. Housing and phone data are synchronized
5. Player spawns into the world

### Character Saves

Character data is automatically saved during:

* Logout
* Server restart
* Character switch
* Manual save events

---

## Development

When creating resources that depend on character information:

```lua
local player = exports.bsrp:GetPlayer(source)

if not player then
    return
end

local citizenid = player.citizenid
```

Always verify character data server-side before processing sensitive actions.

---


