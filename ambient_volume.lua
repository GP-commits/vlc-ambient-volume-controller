-- VLC Extension Descriptor
function descriptor()
    return {
        title = "Ambient Volume Controller",
        version = "1.0.0",
        author = "Antigravity",
        shortdesc = "Controls volume based on room noise",
        description = "Works with a background Python script to dynamically scale VLC playback volume in response to microphone noise.",
        capabilities = { "menu", "input-listener" }
    }
end

-- UI Controls Globals
local dlg = nil
local lbl_status = nil
local lbl_noise = nil
local lbl_volume = nil

-- Shared State File Path (Forward slashes work on Windows in Lua)
local SHARED_STATE_PATH = "C:/Users/gamer/.gemini/antigravity/scratch/vlc-ambient-volume-controller/vlc_volume_state.json"
local LOG_FILE_PATH = "C:/Users/gamer/.gemini/antigravity/scratch/vlc-ambient-volume-controller/lua_log.txt"

-- Simple logging helper
local function log_debug(message)
    local f = io.open(LOG_FILE_PATH, "a")
    if f then
        f:write(os.date("%Y-%m-%d %H:%M:%S") .. " - " .. message .. "\n")
        f:close()
    end
end

-- Simple helper to parse values from raw JSON strings via regex
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

-- Extension activation hook
function activate()
    log_debug("Extension activated")
    create_dialog()
end

-- Extension deactivation hook
function deactivate()
    log_debug("Extension deactivated")
    destroy_dialog()
end

-- Dialog close hook
function close()
    log_debug("Extension closed")
    vlc.deactivate()
end

-- Draw VLC native UI Dialog window
function create_dialog()
    dlg = vlc.dialog("Ambient Volume Controller")
    
    dlg:add_label("<b>Ambient Volume Controller for VLC</b>", 1, 1, 3, 1)
    dlg:add_label("Make sure the python helper <i>vlc_noise_listener.py</i> is running.", 1, 2, 3, 1)
    
    lbl_status = dlg:add_label("<b>Status:</b> Initializing...", 1, 4, 3, 1)
    lbl_noise = dlg:add_label("Ambient Noise: --", 1, 5, 3, 1)
    lbl_volume = dlg:add_label("VLC Volume: --", 1, 6, 3, 1)
    
    dlg:add_label("--------------------------------------------------------------------------------", 1, 7, 3, 1)
    dlg:add_label("Configure settings in <b>config.json</b> located in the installation folder.", 1, 8, 3, 1)
    
    dlg:show()
    log_debug("Dialog created and shown")
end

function destroy_dialog()
    if dlg then
        dlg:delete()
        dlg = nil
    end
    lbl_status = nil
    lbl_noise = nil
    lbl_volume = nil
    log_debug("Dialog destroyed")
end

-- Inner loop implementation wrapped in pcall
local function inner_loop()
    -- Attempt to open the shared state file
    local file = io.open(SHARED_STATE_PATH, "r")
    if not file then
        if lbl_status then
            lbl_status:set_text("<b>Status:</b> Python listener script is not running.")
        end
        return
    end
    
    local content = file:read("*a")
    file:close()
    
    if not content or content == "" then
        return
    end
    
    -- Extract values from JSON content
    local active = get_json_value(content, "active")
    local noise = get_json_value(content, "noise")
    local smoothed = get_json_value(content, "smoothedNoise")
    local target_pct = get_json_value(content, "targetVolumePercentage")
    local vlc_volume = get_json_value(content, "vlcVolume")
    
    if active == false then
        if lbl_status then
            lbl_status:set_text("<b>Status:</b> Controller Disabled in settings.")
        end
        return
    end
    
    -- Set VLC internal playback volume
    if vlc_volume then
        -- Safe volume setting check
        if vlc.volume then
            vlc.volume.set(vlc_volume)
        else
            log_debug("vlc.volume is nil! Trying fallback vlc.audio.volume...")
            -- Fallback if vlc.volume is not exposed directly in this version
            vlc.audio.volume(vlc_volume)
        end
        
        -- Update Dialog Text elements
        if lbl_status then
            lbl_status:set_text("<b>Status:</b> Listening and adjusting playback volume.")
        end
        if lbl_noise and smoothed and noise then
            lbl_noise:set_text("Ambient Noise: <b>" .. tostring(smoothed) .. "%</b> (Raw peaks: " .. tostring(noise) .. "%)")
        end
        if lbl_volume and target_pct then
            lbl_volume:set_text("VLC Volume: <b>" .. tostring(target_pct) .. "%</b> (Value: " .. tostring(vlc_volume) .. "/256)")
        end
    end
end

-- Periodic execution loop (called by VLC Extension Manager every ~100-300ms)
function loop()
    local status, err = pcall(inner_loop)
    if not status then
        log_debug("ERROR in loop: " .. tostring(err))
    end
    return 1
end
