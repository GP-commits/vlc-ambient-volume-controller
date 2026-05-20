-- VLC Ambient Volume Controller - Interface Script
-- This runs as a background interface in VLC and supports continuous polling.
-- Place this file in: %APPDATA%\vlc\lua\intf\
--
-- To activate, either:
--   1. Launch VLC with: vlc --extraintf=luaintf --lua-intf=ambient_volume
--   2. Or set it in VLC Preferences:
--      Tools > Preferences > Show Settings: All >
--      Interface > Main interfaces > Extra interface modules > check "Lua interpreter"
--      Interface > Main interfaces > Lua > Lua interface > type "ambient_volume"

-- Shared State File Path
local SHARED_STATE_PATH = "C:/Users/gamer/.gemini/antigravity/scratch/vlc-ambient-volume-controller/vlc_volume_state.json"
local LOG_FILE_PATH = "C:/Users/gamer/.gemini/antigravity/scratch/vlc-ambient-volume-controller/lua_log.txt"

-- Polling interval in microseconds (500ms = 500000)
local POLL_INTERVAL = 500000

-- Simple logging helper
local function log_msg(message)
    vlc.msg.info("[AmbientVolume] " .. message)
    local f = io.open(LOG_FILE_PATH, "a")
    if f then
        f:write(os.date("%Y-%m-%d %H:%M:%S") .. " - " .. message .. "\n")
        f:close()
    end
end

-- Simple helper to parse values from raw JSON strings
local function get_json_value(json_str, key)
    -- Matches integer/float values
    local pattern = '"' .. key .. '"%s*:%s*([%d%-%.%+eE]+)'
    local val = string.match(json_str, pattern)
    if val then
        return tonumber(val)
    end

    -- Matches boolean true
    pattern = '"' .. key .. '"%s*:%s*(true)'
    if string.match(json_str, pattern) then
        return true
    end

    -- Matches boolean false
    pattern = '"' .. key .. '"%s*:%s*(false)'
    if string.match(json_str, pattern) then
        return false
    end

    return nil
end

-- Read shared state and apply volume
local function poll_and_adjust()
    local file = io.open(SHARED_STATE_PATH, "r")
    if not file then
        return false, "State file not found"
    end

    local content = file:read("*a")
    file:close()

    if not content or content == "" then
        return false, "State file is empty"
    end

    local active = get_json_value(content, "active")
    local noise = get_json_value(content, "noise")
    local smoothed = get_json_value(content, "smoothedNoise")
    local target_pct = get_json_value(content, "targetVolumePercentage")
    local vlc_volume = get_json_value(content, "vlcVolume")

    if active == false then
        return false, "Controller disabled"
    end

    if vlc_volume then
        vlc.volume.set(vlc_volume)
        return true, string.format("Noise: %d%% | Volume: %d%% (%d/256)", 
            smoothed or 0, target_pct or 0, vlc_volume)
    end

    return false, "No volume data"
end

-- Main interface loop
log_msg("Ambient Volume Controller interface started")
log_msg("Reading state from: " .. SHARED_STATE_PATH)
log_msg("Polling every " .. (POLL_INTERVAL / 1000000) .. " seconds")

local log_counter = 0

while true do
    local ok, msg = pcall(poll_and_adjust)
    
    if ok then
        -- poll_and_adjust returned successfully
        local success, status_msg = poll_and_adjust()
        -- Log status every 10 cycles (~5 seconds) to avoid flooding
        log_counter = log_counter + 1
        if log_counter >= 10 then
            log_msg(status_msg or "Unknown status")
            log_counter = 0
        end
    else
        -- pcall caught an error
        log_msg("ERROR: " .. tostring(msg))
    end

    -- Sleep for the polling interval (non-blocking VLC sleep)
    vlc.misc.mwait(vlc.misc.mdate() + POLL_INTERVAL)
end
