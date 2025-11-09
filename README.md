## Install
1. Clone or Download the repository.
2. Copy the `connector_discord` to your resources.
3. Follow the `Setup Bot` Installation below.
4. Add `ensure connector_discord` to your server.cfg
5. Configure the needed requirments in the "config.lua"
6. MAKE SURE THE BOT IS ABOVE ALL ROLES !

## Setup Bot
1. If you dont know how to setup the bot watch the `setupbot.mp4`
2. If you know how to set up a discord bot & then u are all good
3. MAKE SURE THE BOT IS ABOVE ALL ROLES !

## Usage / Documentation

### Available Exports

#### GetPlayerRoles
Gets all Discord roles for a player.

```lua
-- Returns: table of role IDs or nil
local roles = exports['connector_discord']:GetPlayerRoles(source)
if roles then
    print('Player has ' .. #roles .. ' roles')
end
```

#### PlayerHasRole
Check if a player has a specific role or any role from a list of roles.

```lua
-- Check single role
local roleID = 123456789012345678
if exports['connector_discord']:PlayerHasRole(source, roleID) then
    print('Player has the role!')
end

-- Check multiple roles (returns true if player has ANY of the roles)
local roleIDs = {123456789012345678, 987654321098765432}
if exports['connector_discord']:PlayerHasRole(source, roleIDs) then
    print('Player has at least one of the roles!')
end
```

#### GetPlayerUsername
Gets the player's Discord username (format: Username#0000).

```lua
-- Returns: string or nil
local username = exports['connector_discord']:GetPlayerUsername(source)
if username then
    print('Discord username: ' .. username)
end
```

#### GetPlayerAvatar
Gets the player's Discord avatar URL.

```lua
-- Returns: string (URL) or nil
local avatar = exports['connector_discord']:GetPlayerAvatar(source)
if avatar then
    print('Avatar URL: ' .. avatar)
end
```

#### GetPlayerDUID
Gets the player's Discord User ID.

```lua
-- Returns: string or nil
local discordID = exports['connector_discord']:GetPlayerDUID(source)
if discordID then
    print('Discord ID: ' .. discordID)
end
```

#### GetPlayerData
Gets all cached Discord data for a player.

```lua
-- Returns: table with roles, name, avatar, discordID or nil
local data = exports['connector_discord']:GetPlayerData(source)
if data then
    print('Discord ID: ' .. data.discordID)
    print('Username: ' .. data.name)
    print('Avatar: ' .. data.avatar)
    print('Roles: ' .. #data.roles)
end
```

### Example Usage

```lua
-- Check if player has admin role before allowing command
RegisterCommand('banexample', function(source, args, rawCommand)
    local adminRoleID = 123456789012345678
    
    if exports['connector_discord']:PlayerHasRole(source, adminRoleID) then
        -- Player has admin role
        print('Admin command executed by ' .. GetPlayerName(source))
    else
        -- Player doesn't have admin role
        TriggerClientEvent('chat:addMessage', source, {
            args = {'System', 'You do not have permission to use this command'}
        })
    end
end, false)

-- Get all player Discord info
RegisterCommand('myinfo', function(source, args, rawCommand)
    local data = exports['connector_discord']:GetPlayerData(source)
    
    if data then
        TriggerClientEvent('chat:addMessage', source, {
            args = {'Discord Info', 'Username: ' .. (data.name or 'N/A')}
        })
        TriggerClientEvent('chat:addMessage', source, {
            args = {'Discord Info', 'Discord ID: ' .. data.discordID}
        })
        TriggerClientEvent('chat:addMessage', source, {
            args = {'Discord Info', 'Roles: ' .. #data.roles}
        })
    else
        TriggerClientEvent('chat:addMessage', source, {
            args = {'System', 'Could not fetch your Discord data'}
        })
    end
end, false)
```
