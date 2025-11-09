local function GetIdentifiers(target)
    if not target or not GetPlayerName(target) then return nil end
    
    local identifiers = {}
    for _, v in ipairs(GetPlayerIdentifiers(target)) do
        local prefix, identifier = string.strsplit(':', v)
        identifiers[prefix] = identifier
    end
    return identifiers
end

local function ValidString(str)
    return type(str) == 'string' and string.match(str, "%S") ~= nil
end

local function CreateRateLimiter(maxRequests, interval)
    local requests = {}
    return function()
        if not Config.RateLimit.Enabled then return true end
        
        local now = os.time()
        local count = 0
        
        for i = #requests, 1, -1 do
            if requests[i] >= now - interval then
                count = count + 1
            else
                table.remove(requests, i)
            end
        end
        
        if count < maxRequests then
            table.insert(requests, now)
            return true
        end
        return false
    end
end

local function RemoveEmojis(str)
    if not str then return '' end
    return string.gsub(str, "[%z\1-\127\194-\244][\128-\191]*", function(char)
        return char:byte() > 127 and char:byte() <= 244 and '' or char
    end)
end

local function HasValue(tbl, value)
    if not tbl then return false end
    value = tonumber(value) or value
    
    for _, v in pairs(tbl) do
        if tonumber(v) == value or v == value then
            return true
        end
    end
    return false
end

local RateLimiter = CreateRateLimiter(Config.RateLimit.Requests, Config.RateLimit.Interval)
local PlayerCache = {}
local Ready = false

local function RequestDiscordData(target, onlyRoles)
    if not RateLimiter() then
        print(('[CONNECTOR DISCORD] Rate limit reached for player %s'):format(target))
        return nil
    end

    local identifiers = GetIdentifiers(target)
    if not identifiers or not identifiers.discord then return nil end

    local discordID = identifiers.discord
    local url = ('https://discordapp.com/api/guilds/%s/members/%s'):format(Config.Guild, discordID)
    local headers = {
        ['Content-Type'] = 'application/json',
        ['Authorization'] = ('Bot %s'):format(Config.Token)
    }

    local promise = promise.new()

    PerformHttpRequest(url, function(errorCode, resultData, _)
        if errorCode ~= 200 or not resultData then
            promise:resolve(nil)
            return
        end

        local data = json.decode(resultData)
        if not data then
            promise:resolve(nil)
            return
        end

        local response = {}
        
        if onlyRoles then
            response.roles = {}
            for _, roleId in ipairs(data.roles or {}) do
                table.insert(response.roles, tonumber(roleId))
            end
        else
            response.roles = {}
            for _, roleId in ipairs(data.roles or {}) do
                table.insert(response.roles, tonumber(roleId))
            end

            if data.user then
                response.name = data.user.username and data.user.discriminator and 
                    ('%s#%s'):format(data.user.username, data.user.discriminator) or nil
                
                response.avatar = data.user.avatar and 
                    ('https://cdn.discordapp.com/avatars/%s/%s.%s'):format(
                        discordID, 
                        data.user.avatar, 
                        data.user.avatar:sub(1, 2) == 'a_' and 'gif' or 'png'
                    ) or nil
            end
        end
        response.discordID = discordID
        promise:resolve(response)
    end, 'GET', '', headers)

    return Citizen.Await(promise)
end

local function UpdatePlayerCache(target, data)
    if not Config.Cache.Enabled then return end
    PlayerCache[target] = {
        data = data,
        timestamp = os.time()
    }
end

local function GetCachedPlayerData(target)
    if not Config.Cache.Enabled then return nil end
    local cached = PlayerCache[target]
    if not cached then return nil end
    if os.time() - cached.timestamp > Config.Cache.Duration then
        PlayerCache[target] = nil
        return nil
    end
    return cached.data
end

local function CompareRoles(roles1, roles2)
    if not roles1 or not roles2 then return false end
    if #roles1 ~= #roles2 then return false end
    
    local roleSet = {}
    for _, role in ipairs(roles1) do
        roleSet[role] = true
    end
    
    for _, role in ipairs(roles2) do
        if not roleSet[role] then
            return false
        end
    end
    
    return true
end

local function GetPlayerRoles(target)
    local freshData = RequestDiscordData(target, true)
    
    if not freshData then
        local cached = GetCachedPlayerData(target)
        return cached and cached.roles or nil
    end
    
    local cached = GetCachedPlayerData(target)
    
    if cached and not CompareRoles(cached.roles, freshData.roles) then
        local fullData = RequestDiscordData(target)
        if fullData then
            UpdatePlayerCache(target, fullData)
            print(('[CONNECTOR DISCORD] Player %s (ID:%s) roles updated in cache'):format(
                GetPlayerName(target), target
            ))
            return fullData.roles
        end
    elseif not cached then
        local fullData = RequestDiscordData(target)
        if fullData then
            UpdatePlayerCache(target, fullData)
            return fullData.roles
        end
    end
    
    return freshData.roles
end

RegisterNetEvent('connector_discord:server:playerConnected', function()
    if not Ready then return end

    local src = source
    local cachedData = GetCachedPlayerData(src)
    local discordData = cachedData or RequestDiscordData(src)

    if not discordData then
        print(('[CONNECTOR DISCORD] Player %s (ID:%s) not in Discord'):format(GetPlayerName(src), src))
        return
    end

    UpdatePlayerCache(src, discordData)
    print(('[CONNECTOR DISCORD] Player %s (ID:%s) has %d roles'):format(
        GetPlayerName(src), src, #discordData.roles
    ))
end)

local function PlayerHasRole(target, role)
    local roles = GetPlayerRoles(target)
    if not roles then return false end
    
    if type(role) == 'table' then
        for _, r in ipairs(role) do
            if HasValue(roles, r) then
                return true
            end
        end
        return false
    end
    return HasValue(roles, role)
end

local function GetPlayerUsername(target)
    local cached = GetCachedPlayerData(target)
    return cached and cached.name or nil
end

local function GetPlayerAvatar(target)
    local cached = GetCachedPlayerData(target)
    return cached and cached.avatar or nil
end

local function GetPlayerDUID(target)
    local cached = GetCachedPlayerData(target)
    return cached and cached.discordID or nil
end

local function GetPlayerData(target)
    return GetCachedPlayerData(target)
end

CreateThread(function()
    if not ValidString(Config.Token) or not ValidString(Config.Guild) then
        print('[CONNECTOR DISCORD] ERROR: Invalid config')
        return
    end

    local url = ('https://discordapp.com/api/guilds/%s'):format(Config.Guild)
    local headers = {
        ['Content-Type'] = 'application/json',
        ['Authorization'] = ('Bot %s'):format(Config.Token)
    }

    PerformHttpRequest(url, function(errorCode, data, _)
        if errorCode ~= 200 then
            print('[CONNECTOR DISCORD] ERROR: Discord API failed')
            return
        end

        local guildData = json.decode(data)
        if not guildData then
            print('[CONNECTOR DISCORD] ERROR: Invalid response')
            return
        end

        Ready = true
        print(('[CONNECTOR DISCORD] Connected to Discord server: %s'):format(
            RemoveEmojis(guildData.name)
        ))
    end, 'GET', '', headers)
end)

exports('GetPlayerRoles', GetPlayerRoles)
exports('PlayerHasRole', PlayerHasRole)
exports('GetPlayerUsername', GetPlayerUsername)
exports('GetPlayerAvatar', GetPlayerAvatar)
exports('GetPlayerDUID', GetPlayerDUID)
exports('GetPlayerData', GetPlayerData)