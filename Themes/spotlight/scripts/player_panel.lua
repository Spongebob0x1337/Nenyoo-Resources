-- Spotlight theme — bundled player-info panel. Overrides the global "player_panel"
-- by name when Spotlight is active. Indigo command-palette styling (soft accent,
-- airy two-column list, rounded surfaces) matching spotlight.lua.

local ACCENT  = { 110, 120, 255 }
local ACCENTL = { 150, 160, 255 }
local BG      = { 20, 21, 27 }
local BAR     = { 16, 17, 22 }
local ROUND   = 16

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function vcol(v)
    if v == "Yes" then return 90, 210, 130 end
    if v == "No" then return 235, 96, 96 end
    if v == "Hidden" or v == "N/A" or v == "-" or v == "" then return 110, 116, 134 end
    return ACCENTL[1], ACCENTL[2], ACCENTL[3]
end

overlay.on_draw("player_panel", function()
    if not menu.is_visible() then return end
    local it = menu.get_item(menu.selected_index())
    if not it or it.info_type ~= 1 or not it.info then return end
    local p = it.info

    local function s(x) return tostring(x or "N/A") end

    local colL = {
        { "row", "Name",        s(it.name), ACCENTL },
        { "row", "Model Name",  s(p.model_name) },
        { "row", "Model Label", s(p.model_label) },
        { "row", "Model Hash",  s(p.model_hash) },
        { "bar", "Health",      p.health or 0, 200, { 90, 210, 130 } },
        { "bar", "Armour",      p.armor or 0, 100, { 110, 120, 255 } },
        { "row", "Position",    s(p.position) },
        { "row", "Rotation",    s(p.rotation) },
        { "row", "Heading",     s(p.heading) },
        { "row", "Distance",    s(p.distance) },
        { "row", "Bullet Proof",         s(p.bullet_proof) },
        { "row", "Fire Proof",           s(p.fire_proof) },
        { "row", "Melee Proof",          s(p.melee_proof) },
        { "row", "Explosion Proof",      s(p.explosion_proof) },
        { "row", "Global Invincibility", s(p.god_mode) },
        { "row", "Invisibility",         s(p.invisible) },
        { "row", "Wanted Level",         tostring(p.wanted or 0) .. " / 5" },
        { "row", "Off The Radar",        s(p.off_radar) },
        { "row", "Cops Blind Eyes",      s(p.cops_blind) },
        { "row", "Speed",                s(p.speed) },
    }
    local colR = {
        { "sec", "Vehicle" },
        { "row", "Speed",                "N/A" },
        { "row", "Bullet Proof",         "N/A" },
        { "row", "Fire Proof",           "N/A" },
        { "row", "Melee Proof",          "N/A" },
        { "row", "Explosion Proof",      "N/A" },
        { "row", "Global Invincibility", "N/A" },
        { "row", "Current Vehicle",      s(p.vehicle) },
        { "sec", "Lobby" },
        { "row", "Script Host",       s(p.script_host) },
        { "row", "Session Host",      s(p.session_host) },
        { "row", "Next Session Host", s(p.next_host) },
        { "sec", "Account" },
        { "row", "Nenyoo User",       s(p.unreal_user) },
        { "row", "Friend",            s(p.friend_status) },
        { "row", "Pending Friend Request", s(p.pending_friend) },
        { "row", "Wallet",            s(p.wallet) },
        { "row", "Bank",              s(p.bank) },
        { "row", "Rank",              "Level " .. tostring(p.rank or 0) },
        { "row", "RP",                s(p.rp) },
        { "row", "K/D Ratio",         s(p.kd) },
        { "row", "R* Id (Ped)",       s(p.rid_ped) },
        { "row", "R* Id (Net)",       s(p.rid_net) },
        { "row", "Spoofed R* Id",     s(p.spoofed_rid) },
        { "sec", "Races" },
        { "row", "Won",               s(p.races_won) },
        { "row", "Lost",              s(p.races_lost) },
        { "sec", "Crew" },
        { "row", "Name",              s(p.crew_name) },
        { "row", "Tag",               s(p.crew_tag) },
        { "sec", "Geolocation" },
        { "row", "IP",                s(p.ip) },
        { "row", "Port",              s(p.port) },
        { "row", "Country",           s(p.country) },
        { "row", "City",              s(p.city) },
        { "row", "Latitude",          s(p.latitude) },
        { "row", "Longitude",         s(p.longitude) },
    }

    local sw, shh = ctx.screen_w(), ctx.screen_h()
    local rfont = font.small
    local header_h = 28
    local pad = 12
    local gap = 16
    local rh = math.floor(text.height(rfont) + 5)
    local LW = 240
    local RW = 250
    local ph_slot = 320
    local vpad = 8
    local W = pad + LW + gap + RW + pad

    local hL = ph_slot + 8 + #colL * rh
    local hR = #colR * rh
    local content_h = math.max(hL, hR)
    local H = math.min(header_h + pad + content_h + pad, shh - 16)

    local bx, by, bw = menu.bounds()
    local X0, Y0
    if bw and bw > 0 then
        if (bx + bw * 0.5) < sw * 0.5 then X0 = bx + bw + 14 else X0 = bx - 14 - W end
        Y0 = by
    else
        X0 = 30; Y0 = 80
    end
    if X0 < 8 then X0 = 8 elseif X0 + W > sw - 8 then X0 = sw - 8 - W end
    if Y0 < 8 then Y0 = 8 elseif Y0 + H > shh - 8 then Y0 = shh - 8 - H end

    local ar, ag, ab = ACCENT[1], ACCENT[2], ACCENT[3]

    local px0 = X0 + pad
    local py0 = Y0 + header_h + pad
    local px1 = px0 + LW
    local py1 = py0 + ph_slot

    -- panel background, leaving the ped slot transparent (game paints behind the ped).
    local br, bgc, bb, ba = BG[1], BG[2], BG[3], 250
    draw.rect(X0, Y0 + header_h, px1, py0, br, bgc, bb, ba)
    draw.rect(X0, py0, px0, py1, br, bgc, bb, ba)
    draw.rect(X0, py1, px1, Y0 + H, br, bgc, bb, ba)
    draw.rect(px1, Y0 + header_h, X0 + W, Y0 + H, br, bgc, bb, ba)

    -- header bar (palette-style)
    draw.rect(X0, Y0, X0 + W, Y0 + header_h, BAR[1], BAR[2], BAR[3], 255, ROUND)
    draw.rect(X0, Y0 + header_h - 8, X0 + W, Y0 + header_h, BAR[1], BAR[2], BAR[3], 255)
    draw.rect(X0, Y0 + header_h - 2, X0 + W, Y0 + header_h, ar, ag, ab, 255)
    draw.circle(X0 + pad + 4, Y0 + header_h / 2, 3, ACCENTL[1], ACCENTL[2], ACCENTL[3], 255)
    text.draw(font.item, X0 + pad + 14, Y0 + 6, 235, 236, 242, 255, s(it.name))

    draw.rect_outline(X0, Y0, X0 + W, Y0 + H, 255, 255, 255, 16, ROUND)
    draw.rect_outline(px0, py0, px1, py1, ar, ag, ab, 50, 8)

    local ok = players.draw_ped(p.player_id or 0,
        px0 / sw, py0 / shh, (px1 - px0) / sw, (py1 - py0) / shh)
    if not ok then
        local ns = "No preview"
        text.draw(rfont, px0 + (LW - text.width(rfont, ns)) / 2,
            py0 + ph_slot / 2 - 6, 130, 134, 148, 255, ns)
    end

    local function mini_bar(mbx, mby, mbw, frac, r, g, b)
        frac = clamp(frac, 0, 1)
        draw.rect(mbx, mby, mbx + mbw, mby + 5, 255, 255, 255, 16, 2)
        draw.rect(mbx, mby, mbx + mbw * frac, mby + 5, r, g, b, 255, 2)
    end

    local function render(cx, cw, yy, entries)
        for _, e in ipairs(entries) do
            if e[1] == "sec" then
                text.draw(rfont, cx + (cw - text.width(rfont, e[2])) / 2, yy + 1,
                    ACCENTL[1], ACCENTL[2], ACCENTL[3], 210, e[2])
            elseif e[1] == "bar" then
                text.draw(rfont, cx, yy, 150, 152, 166, 255, e[2])
                local valstr = tostring(e[3])
                local cbw = 70
                local cbx = cx + cw - vpad - cbw
                text.draw(rfont, cbx - 8 - text.width(rfont, valstr), yy,
                    e[5][1], e[5][2], e[5][3], 255, valstr)
                mini_bar(cbx, yy + 4, cbw, e[3] / e[4], e[5][1], e[5][2], e[5][3])
            else
                text.draw(rfont, cx, yy, 150, 152, 166, 255, e[2])
                local v = tostring(e[3])
                local r, g, b
                if e[4] then r, g, b = e[4][1], e[4][2], e[4][3] else r, g, b = vcol(v) end
                text.draw(rfont, cx + cw - vpad - text.width(rfont, v), yy, r, g, b, 255, v)
            end
            yy = yy + rh
        end
    end

    render(px0, LW, py1 + 8, colL)
    render(px1 + gap, RW, Y0 + header_h + pad, colR)
end)
