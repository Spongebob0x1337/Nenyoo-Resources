-- Lexis cursor — clean rounded rose pointer matching the Lexis card style.
-- Bundled with the theme: loads after the global cursor and overrides it by name
-- ("cursor") while Lexis is active; reverts automatically on theme switch.

local rose = { 196, 88, 112 }   -- Lexis rose accent, brightened slightly for cursor visibility
local pulse_t = -1.0

overlay.on_draw("cursor", function()
    if not menu.is_visible() then return end
    local mx, my = input.mouse_x(), input.mouse_y()
    local t = ctx.time()
    if input.mouse_clicked(0) then pulse_t = t end

    -- soft breathing outer glow (Lexis is gentle/rounded)
    local breathe = 0.5 + 0.5 * math.sin(t * 3.0)
    draw.circle(mx, my, 12, rose[1], rose[2], rose[3], math.floor(20 + 14 * breathe))

    -- dark halo for contrast on bright scenes
    draw.circle_outline(mx, my, 8, 0, 0, 0, 120, 3.0)
    -- crisp rose ring
    draw.circle_outline(mx, my, 8, rose[1], rose[2], rose[3], 240, 2.0)

    -- filled rose dot + white core
    draw.circle(mx, my, 3.2, rose[1], rose[2], rose[3], 255)
    draw.circle(mx, my, 1.5, 255, 255, 255, 255)

    -- expanding click pulse (~0.4s)
    if pulse_t >= 0 then
        local e = t - pulse_t
        if e < 0.4 then
            local k = e / 0.4
            draw.circle_outline(mx, my, 8 + k * 18, rose[1], rose[2], rose[3], math.floor(200 * (1 - k)), 2.0)
        else
            pulse_t = -1.0
        end
    end
end)
