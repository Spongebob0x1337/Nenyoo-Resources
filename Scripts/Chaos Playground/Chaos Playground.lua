-- @nenyoo-menu
-- Chaos Playground
-- Local-player fun effects for testing Nenyoo's native Lua API.

local nv = native_invoker

local super_jump = false
local explosive_melee = false
local rainbow_trail = true
local show_status = true
local trail_length = 28
local dash_power = 32
local trail = {}
local last_sample_ms = 0

local function call_player_frame_native(hash)
    nv.begin_call()
    nv.push_arg_int(player.id())
    nv.end_call(hash)
end

local function gameplay_camera_direction()
    nv.begin_call()
    nv.push_arg_int(2)
    nv.end_call("837765A25378F0BB") -- GET_GAMEPLAY_CAM_ROT
    return v3.new(nv.get_return_value_vector3()):toDir()
end

local function apply_force(handle, x, y, z)
    nv.begin_call()
    nv.push_arg_int(handle)
    nv.push_arg_int(1)
    nv.push_arg_float(x)
    nv.push_arg_float(y)
    nv.push_arg_float(z)
    nv.push_arg_float(0.0)
    nv.push_arg_float(0.0)
    nv.push_arg_float(0.0)
    nv.push_arg_int(0)
    nv.push_arg_bool(false)
    nv.push_arg_bool(true)
    nv.push_arg_bool(true)
    nv.push_arg_bool(false)
    nv.push_arg_bool(true)
    nv.end_call("C5F68BE9613E2D18") -- APPLY_FORCE_TO_ENTITY
end

local function hsv_rgb(h)
    local i = math.floor(h * 6.0)
    local f = h * 6.0 - i
    local q = 1.0 - f
    local n = i % 6
    local r, g, b
    if n == 0 then r, g, b = 1.0, f, 0.0
    elseif n == 1 then r, g, b = q, 1.0, 0.0
    elseif n == 2 then r, g, b = 0.0, 1.0, f
    elseif n == 3 then r, g, b = 0.0, q, 1.0
    elseif n == 4 then r, g, b = f, 0.0, 1.0
    else r, g, b = 1.0, 0.0, q end
    return math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)
end

local function clear_trail()
    trail = {}
end

local root = menu.my_root()
local movement = menu.list(root, "Movement Mayhem", {}, "Local movement powers that stop cleanly when disabled")

menu.toggle(movement, "Super Jump", {}, "Charge every jump with exaggerated force", function(on)
    super_jump = on
end, false)

menu.action(movement, "Magic Dash", {}, "Launch in the direction of the gameplay camera", function()
    local ped = player.ped()
    local target = player.in_vehicle(player.id()) and player.vehicle(player.id()) or ped
    local dir = gameplay_camera_direction()
    apply_force(target, dir.x * dash_power, dir.y * dash_power, dir.z * dash_power + dash_power * 0.28)
    audio.play_frontend("SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET")
end)

menu.slider(movement, "Dash Power", {}, "Strength of Magic Dash", 10, 80, dash_power, 2, function(value)
    dash_power = value
end)

menu.action(movement, "Vehicle Hop", {}, "Pop your current vehicle upward", function()
    if not player.in_vehicle(player.id()) then
        util.toast("Enter a vehicle first.")
        return
    end
    apply_force(player.vehicle(player.id()), 0.0, 0.0, 18.0)
end)

local combat = menu.list(root, "Combat Toys", {}, "One-frame local player powers")
menu.toggle(combat, "Explosive Melee", {}, "Make your melee hits explode while enabled", function(on)
    explosive_melee = on
end, false)

local visuals = menu.list(root, "Visuals", {}, "Lightweight script-drawn effects")
menu.toggle(visuals, "Rainbow Trail", {}, "Draw a colour-changing trail along your recent path", function(on)
    rainbow_trail = on
    if not on then clear_trail() end
end, true)

menu.slider(visuals, "Trail Length", {}, "Number of recent trail points to retain", 8, 80, trail_length, 2, function(value)
    trail_length = value
    while #trail > trail_length do table.remove(trail, 1) end
end)

menu.toggle(visuals, "Status Overlay", {}, "Show active Chaos Playground effects in the debug overlay", function(on)
    show_status = on
end, true)

menu.action(root, "Clear Trail", {}, "Erase all stored rainbow trail points", clear_trail)
menu.action(root, "Clear Wanted Level", {}, "Immediately clear your local wanted level", function()
    player.set_wanted_level(0)
end)

script.on_tick(function()
    if super_jump then
        call_player_frame_native("57FFF03E423A4C0B") -- SET_SUPER_JUMP_THIS_FRAME
    end
    if explosive_melee then
        call_player_frame_native("A66C71C98D5F2CFB") -- SET_EXPLOSIVE_MELEE_THIS_FRAME
    end

    if rainbow_trail then
        local now = util.time_ms()
        local pos = entity.coords(player.ped())
        local last = trail[#trail]
        if now - last_sample_ms >= 70 and (not last or pos:distance(last) >= 0.18) then
            trail[#trail + 1] = pos
            last_sample_ms = now
            while #trail > trail_length do table.remove(trail, 1) end
        end

        local phase = (now % 5000) / 5000.0
        for i = 1, #trail - 1 do
            local a, b = trail[i], trail[i + 1]
            local hue = (phase + i / math.max(#trail, 1)) % 1.0
            local r, g, blue = hsv_rgb(hue)
            world.draw_line(a.x, a.y, a.z + 0.12, b.x, b.y, b.z + 0.12, r, g, blue, 230)
        end
    end

end)

overlay.on_draw("chaos_playground_status", function()
    if not show_status then return end

    local lines = {
        "CHAOS PLAYGROUND",
        "Super Jump: " .. (super_jump and "ON" or "OFF"),
        "Explosive Melee: " .. (explosive_melee and "ON" or "OFF"),
        "Rainbow Trail: " .. (rainbow_trail and ("ON  [" .. #trail .. "]") or "OFF"),
    }
    local x, y, w = 20, 190, 245
    local pad = 10
    local line_h = text.height(font.small) + 5
    local h = pad * 2 + line_h * #lines
    local ar, ag, ab = theme.accent()

    draw.rect(x, y, x + w, y + h, 10, 10, 16, 205, 6)
    draw.rect(x, y, x + 3, y + h, ar, ag, ab, 255, 6)
    for i, line in ipairs(lines) do
        local r, g, b = 225, 225, 235
        if i == 1 then r, g, b = ar, ag, ab end
        text.draw(font.small, x + pad + 5, y + pad + (i - 1) * line_h,
            r, g, b, 255, line)
    end
end)

util.toast("Chaos Playground loaded.")
