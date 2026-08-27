-- @nenyoo-menu
-- Human Cannonball -- fire yourself down the street and score the landing.
--
-- Aim with power and angle, watch the predicted arc, launch, then get marked on distance, how close
-- you landed to the target ring, hang time and bounces.
--
-- The arc is real projectile maths (v*t and v*t - g*t^2/2) sampled forward, so what it draws is what
-- the launch velocity will actually do -- gravity is the only thing it cannot know about in advance
-- (walls, roofs and other people's cars are your problem).
--
-- Threading (see CLAUDE.md): flight tracking runs on the SCRIPT thread. The card is drawn on the
-- RENDER thread from a published snapshot.

local NAME = "Human Cannonball"
local CFG  = "human_cannonball"

----------------------------------------------------------------------------------------------------
-- natives (hashes verified against src/invoker/natives.hpp)
----------------------------------------------------------------------------------------------------

local call = native.call
local nv   = native_invoker

local N = {
    SET_PED_TO_RAGDOLL      = 0xAE99FB955581844A,
    RESET_RAGDOLL_TIMER     = 0x9FA4664CF62E47E8,
    SET_PED_CAN_RAGDOLL     = 0xB128377056A54E2A,
    IS_PED_RAGDOLL          = 0x47E4E977581C5B55,
    IS_ENTITY_IN_AIR        = 0x886E37EC497200B6,
    SET_ENTITY_VELOCITY     = 0x1C99BB7B6E96D16F,
    SET_ENTITY_INVINCIBLE   = 0x3882114BDE571AD4,
    CLEAR_PED_TASKS_IMMED   = 0xAAA34F8A7CB32098,
    DRAW_MARKER             = 0x28477EC23D892089,
    IS_PED_IN_ANY_VEHICLE   = 0x997ABD671D25CA0B,
}

local function nbool(h, ...) return call(h, ...) ~= 0 end

local function speed_of(ent)
    nv.begin_call(); nv.push_arg_int(ent); nv.end_call("D5037BA82E12416F")   -- GET_ENTITY_SPEED
    return nv.get_return_value_float()
end

local GRAVITY = 9.81

----------------------------------------------------------------------------------------------------
-- config
----------------------------------------------------------------------------------------------------

local cfg = {
    power = 25,             -- launch speed, m/s (about 60 m at 40 degrees, matching the ring)
    angle = 40,             -- degrees above horizontal
    target = 60,            -- how far out the target ring sits
    ring = 8,               -- target ring radius
    invincible = true,
    show_arc = true,
    auto_return = false,    -- teleport back to the firing line after each shot
    show_panel = true,
    panel_x = 2, panel_y = 60,
}

do
    local saved = settings.load(CFG)
    for k, v in pairs(saved) do if cfg[k] ~= nil then cfg[k] = v end end
end

local dirty_at = 0
local function mark_dirty() dirty_at = util.time_ms() + 1200 end

----------------------------------------------------------------------------------------------------
-- state
----------------------------------------------------------------------------------------------------

local S = {
    armed = false,          -- firing line set, ready to launch
    flying = false,
    origin = nil,           -- v3 of the firing line
    heading = 0.0,
    target_pos = nil,
    launched_at = 0,
    peak = 0.0,
    bounces = 0,
    was_air = false,
    settle_at = 0,
    last = nil,             -- scorecard of the previous shot
    best = 0,
    best_dist = 0,
}

local HUD = { snap = nil }
local ui = {}

local function refresh_rows()
    if ui.best then menu.set_value(ui.best, string.format("%d pts", math.floor(S.best))) end
    if ui.bestd then menu.set_value(ui.bestd, string.format("%.1f m", S.best_dist)) end
    if ui.last then
        menu.set_value(ui.last, S.last and string.format("%d pts, %.1f m", S.last.score, S.last.dist) or "--")
    end
    if ui.state then
        menu.set_value(ui.state, S.flying and "in flight" or (S.armed and "ready" or "not set up"))
    end
end

----------------------------------------------------------------------------------------------------
-- firing line
----------------------------------------------------------------------------------------------------

local function forward_of(heading)
    local r = math.rad(heading)
    return -math.sin(r), math.cos(r)
end

local function set_line()
    local me = player.ped()
    S.origin = entity.coords(me)
    S.heading = entity.rotation(me).z
    local fx, fy = forward_of(S.heading)
    local tx, ty = S.origin.x + fx * cfg.target, S.origin.y + fy * cfg.target
    local ok, gz = world.ground_z(tx, ty, S.origin.z + 5.0)
    S.target_pos = v3.new(tx, ty, ok and gz or S.origin.z)
    S.armed = true
    refresh_rows()
end

-- Sample the launch arc forward in time. Purely ballistic: the same numbers the launch will use.
local function arc_points(steps)
    if not S.origin then return {} end
    local fx, fy = forward_of(S.heading)
    local rad = math.rad(cfg.angle)
    local vh = cfg.power * math.cos(rad)
    local vv = cfg.power * math.sin(rad)
    -- Sample across the whole flight rather than a fixed number of fixed steps: time back to launch
    -- height is 2*vv/g, so a fixed 4.8 s window used to cut the arc off in mid-air on a long shot.
    local flight = math.max(0.3, (2.0 * vv) / GRAVITY)
    local n = steps or 48
    local pts = {}
    for i = 1, n do
        local t = (flight * 1.08) * (i / n)
        pts[#pts + 1] = v3.new(S.origin.x + fx * vh * t,
                               S.origin.y + fy * vh * t,
                               S.origin.z + vv * t - 0.5 * GRAVITY * t * t)
    end
    return pts
end

----------------------------------------------------------------------------------------------------
-- the shot
----------------------------------------------------------------------------------------------------

local function score_landing()
    local me = player.ped()
    local pos = entity.coords(me)
    local dist = pos:distance(S.origin)
    local flat = math.sqrt((pos.x - S.target_pos.x) ^ 2 + (pos.y - S.target_pos.y) ^ 2)
    local air = (util.time_ms() - S.launched_at) / 1000.0

    -- inside the ring scores on a linear falloff to the rim; outside scores nothing for accuracy
    local acc = 0
    if flat <= cfg.ring then acc = math.floor(500 * (1.0 - flat / cfg.ring)) end

    local score = math.floor(dist * 10 + acc + air * 25 + S.bounces * 40 + S.peak * 5)

    S.last = { score = score, dist = dist, flat = flat, air = air,
               peak = S.peak, bounces = S.bounces, bullseye = (flat <= cfg.ring * 0.2) }

    if score > S.best then S.best = score; cfg.best = score; mark_dirty() end
    if dist > S.best_dist then S.best_dist = dist; cfg.best_dist = dist; mark_dirty() end

    local msg
    if S.last.bullseye then msg = string.format("Bullseye. %d points.", score)
    elseif flat <= cfg.ring then msg = string.format("On target. %d points, %.0f m out.", score, dist)
    else msg = string.format("%d points, %.0f m out, %.0f m wide.", score, dist, flat) end
    notify.push(NAME, msg, 0, 6.0)

    audio.play_frontend(S.last.bullseye and "RACE_PLACED" or "CHECKPOINT_NORMAL", "HUD_AWARDS")
    refresh_rows()
end

local function launch()
    local me = player.ped()
    if nbool(N.IS_PED_IN_ANY_VEHICLE, me, false) then
        notify.push(NAME, "Get out of the vehicle first.", 1, 3.0)
        return
    end
    if not S.armed then set_line() end

    local fx, fy = forward_of(S.heading)
    local rad = math.rad(cfg.angle)
    local vh = cfg.power * math.cos(rad)
    local vv = cfg.power * math.sin(rad)

    call(N.SET_ENTITY_INVINCIBLE, me, cfg.invincible)
    call(N.SET_PED_CAN_RAGDOLL, me, true)
    call(N.CLEAR_PED_TASKS_IMMED, me)
    -- ragdoll FIRST: velocity applied to a standing ped is fought by the movement system, but a
    -- ragdolled ped is a physics body and simply goes where it is thrown
    call(N.SET_PED_TO_RAGDOLL, me, 20000, 20000, 0, false, false, false)
    call(N.SET_ENTITY_VELOCITY, me, fx * vh, fy * vh, vv)

    S.flying, S.launched_at = true, util.time_ms()
    S.peak, S.bounces, S.was_air = 0.0, 0, true
    S.settle_at = 0
    refresh_rows()
    audio.play_frontend("TIMER_STOP", "HUD_MINI_GAME_SOUNDSET")
end

local function return_to_line()
    if not S.origin then notify.push(NAME, "Set the firing line first.", 1, 3.0); return end
    local me = player.ped()
    entity.set_coords(me, S.origin.x, S.origin.y, S.origin.z)
    call(N.CLEAR_PED_TASKS_IMMED, me)
    S.flying = false
    refresh_rows()
end

----------------------------------------------------------------------------------------------------
-- ticks
----------------------------------------------------------------------------------------------------

util.create_thread(function()
    S.best = tonumber(cfg.best) or 0
    S.best_dist = tonumber(cfg.best_dist) or 0
    while true do
        local me = player.ped()

        if S.armed and S.target_pos and not S.flying then
            -- target ring on the ground
            local ar, ag, ab = theme.accent()
            call(N.DRAW_MARKER, 1, S.target_pos.x + 0.0, S.target_pos.y + 0.0, S.target_pos.z - 1.0,
                 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                 cfg.ring * 2.0, cfg.ring * 2.0, 0.4,
                 math.floor(ar), math.floor(ag), math.floor(ab), 70,
                 false, false, 2, false, 0, 0, false)

            if cfg.show_arc then
                local pts = arc_points(40)
                for i = 2, #pts do
                    world.draw_line(pts[i - 1].x, pts[i - 1].y, pts[i - 1].z,
                                    pts[i].x, pts[i].y, pts[i].z,
                                    math.floor(ar), math.floor(ag), math.floor(ab), 160)
                end
            end
        end

        if S.flying then
            local pos = entity.coords(me)
            local h = pos.z - S.origin.z
            if h > S.peak then S.peak = h end

            local in_air = nbool(N.IS_ENTITY_IN_AIR, me)
            if in_air and not S.was_air then S.bounces = S.bounces + 1 end
            S.was_air = in_air

            call(N.RESET_RAGDOLL_TIMER, me)   -- keep them limp for the whole flight

            -- the shot is over once they have stopped moving on the ground
            local sp = speed_of(me)
            if not in_air and sp < 0.6 then
                if S.settle_at == 0 then S.settle_at = util.time_ms()
                elseif util.time_ms() - S.settle_at > 1200 then
                    S.flying = false
                    score_landing()
                    if cfg.auto_return then util.yield(1500); return_to_line() end
                end
            else
                S.settle_at = 0
            end

            -- a shot that somehow never settles still ends
            if util.time_ms() - S.launched_at > 30000 then
                S.flying = false
                score_landing()
            end
        end

        if dirty_at ~= 0 and util.time_ms() >= dirty_at then
            dirty_at = 0
            settings.save(CFG, cfg)
        end
        util.yield()
    end
end)

util.create_thread(function()
    while true do
        if not cfg.show_panel or not (S.armed or S.flying) then
            HUD.snap = nil
        else
            local me = player.ped()
            local snap = {
                flying = S.flying,
                power = cfg.power, angle = cfg.angle,
                best = math.floor(S.best), best_dist = S.best_dist,
                px = cfg.panel_x, py = cfg.panel_y,
            }
            if S.flying and S.origin then
                local pos = entity.coords(me)
                snap.dist = pos:distance(S.origin)
                snap.height = pos.z - S.origin.z
                snap.speed = speed_of(me)
                snap.air = (util.time_ms() - S.launched_at) / 1000.0
                snap.bounces = S.bounces
            elseif S.last then
                snap.card = S.last
            end
            HUD.snap = snap
        end
        util.yield(80)
    end
end)

----------------------------------------------------------------------------------------------------
-- panel (render thread -- no natives)
----------------------------------------------------------------------------------------------------

overlay.on_draw(NAME, function()
    local s = HUD.snap
    if not s then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local ar, ag, ab = theme.accent()
    local pad, w = 14, 232
    local h = s.flying and 104 or (s.card and 118 or 74)
    local x = math.max(4, math.min(sw - w - 4, sw * (s.px / 100.0)))
    local y = math.max(4, math.min(sh - h - 4, sh * (s.py / 100.0)))
    local left, right = x + pad, x + w - pad

    local function rt(f, rx, ty, r, g, b, a, str)
        text.draw(f, rx - text.width(f, str), ty, r, g, b, a, str)
    end
    local function row(ty, label, value, vr, vg, vb)
        text.draw(font.small, left, ty, 150, 150, 162, 255, label)
        rt(font.small, right, ty, vr or 226, vg or 226, vb or 236, 255, value)
    end

    draw.rect(x, y, x + w, y + h, 10, 10, 16, 218, 7)
    draw.rect(x, y, x + 3, y + h, ar, ag, ab, 245, 3)

    if s.flying then
        text.draw(font.item, left, y + 9, ar, ag, ab, 255, "IN FLIGHT")
        row(y + 32, "distance", string.format("%.1f m", s.dist or 0))
        row(y + 48, "height",   string.format("%.1f m", s.height or 0))
        row(y + 64, "speed",    string.format("%.0f m/s", s.speed or 0))
        row(y + 80, "air time", string.format("%.1f s", s.air or 0))
    elseif s.card then
        local c = s.card
        text.draw(font.item, left, y + 9, ar, ag, ab, 255, c.bullseye and "BULLSEYE" or "LANDED")
        rt(font.item, right, y + 9, 240, 240, 248, 255, tostring(c.score))
        row(y + 34, "distance", string.format("%.1f m", c.dist))
        row(y + 50, "off target", string.format("%.1f m", c.flat))
        row(y + 66, "hang time", string.format("%.1f s", c.air))
        row(y + 82, "peak / bounces", string.format("%.0f m / %d", c.peak, c.bounces))
        row(y + 98, "best", string.format("%d pts", s.best), ar, ag, ab)
    else
        text.draw(font.item, left, y + 9, 232, 232, 240, 255, "READY")
        row(y + 32, "power / angle", string.format("%d  /  %d deg", s.power, s.angle))
        row(y + 50, "best", string.format("%d pts, %.0f m", s.best, s.best_dist), ar, ag, ab)
    end
end)

----------------------------------------------------------------------------------------------------
-- menu
----------------------------------------------------------------------------------------------------

local root = menu.my_root()

menu.action(root, "Set Firing Line", {}, "Mark where you stand as the launch point, facing your way.", function()
    set_line()
    notify.push(NAME, string.format("Firing line set. Target %d m out.", math.floor(cfg.target)), 0, 4.0)
end)
menu.action(root, "Fire", {}, "Launch yourself.", function() launch() end)
menu.action(root, "Back To The Line", {}, "Teleport back to the launch point.", function() return_to_line() end)

menu.divider(root, "The Shot")
ui.state = menu.readonly(root, "Status", "not set up")
menu.slider(root, "Power", {}, "Launch speed in metres per second.", 10, 120, cfg.power, 1, function(v)
    cfg.power = v; mark_dirty()
end)
menu.slider(root, "Angle", {}, "Degrees above horizontal. 45 carries furthest.", 0, 85, cfg.angle, 1, function(v)
    cfg.angle = v; mark_dirty()
end)
menu.toggle(root, "Show Arc", {}, "Draw the predicted flight path.", function(on)
    cfg.show_arc = on; mark_dirty()
end, cfg.show_arc)

menu.divider(root, "Target")
menu.slider(root, "Target Distance", {}, "How far out the scoring ring sits.", 10, 250, cfg.target, 5, function(v)
    cfg.target = v
    if S.armed then set_line() end
    mark_dirty()
end)
menu.slider(root, "Ring Size", {}, "Radius of the scoring ring. Smaller is worth more.", 2, 30, cfg.ring, 1, function(v)
    cfg.ring = v; mark_dirty()
end)

menu.divider(root, "Rules")
menu.toggle(root, "Survive The Landing", {}, "Invincible while you fly. Turn off at your own risk.", function(on)
    cfg.invincible = on
    call(N.SET_ENTITY_INVINCIBLE, player.ped(), on)
    mark_dirty()
end, cfg.invincible)
menu.toggle(root, "Return Automatically", {}, "Teleport back to the line after each landing.", function(on)
    cfg.auto_return = on; mark_dirty()
end, cfg.auto_return)

menu.divider(root, "Records")
ui.last  = menu.readonly(root, "Last Shot", "--")
ui.best  = menu.readonly(root, "Best Score", "0 pts")
ui.bestd = menu.readonly(root, "Longest Flight", "0.0 m")

menu.divider(root, "Panel")
menu.toggle(root, "Show Panel", {}, "The flight card.", function(on) cfg.show_panel = on; mark_dirty() end, cfg.show_panel)
menu.slider(root, "Panel X", {}, "Horizontal position, percent of screen.", 0, 92, cfg.panel_x, 1, function(v) cfg.panel_x = v; mark_dirty() end)
menu.slider(root, "Panel Y", {}, "Vertical position, percent of screen.", 0, 88, cfg.panel_y, 1, function(v) cfg.panel_y = v; mark_dirty() end)

menu.divider(root, "")
menu.action(root, "Reset Records", {}, "Forget your best score and longest flight.", function()
    S.best, S.best_dist = 0, 0
    cfg.best, cfg.best_dist = 0, 0
    mark_dirty(); refresh_rows()
    notify.push(NAME, "Records cleared.", 0, 3.0)
end)

refresh_rows()

if util.on_stop then util.on_stop(function()
    call(N.SET_ENTITY_INVINCIBLE, player.ped(), false)
end) end
