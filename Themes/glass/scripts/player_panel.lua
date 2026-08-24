-- Glass-styled player-info panel. Overrides the global "player_panel" overlay when
-- the Glass theme is active (theme scripts load after globals, override by name).
-- Translucent frosted body, big rounded corners, glowing violet/cyan rims, white
-- text. Shows full info + the live ped.

local BG     = { 10, 9, 18 }
local ACCENT = { 139, 92, 246 }    -- violet
local CYAN   = { 56, 189, 248 }    -- cyan glow
local GREEN  = { 52, 211, 153 }
local RED    = { 248, 113, 113 }
local DIM    = { 150, 150, 160 }
local ROUND  = 16

local function vcol(v)
    if v == "Yes" then return GREEN[1], GREEN[2], GREEN[3] end
    if v == "No" then return RED[1], RED[2], RED[3] end
    if v == "Hidden" or v == "N/A" or v == "-" or v == "" then return DIM[1], DIM[2], DIM[3] end
    return CYAN[1], CYAN[2], CYAN[3]
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function frost(x1, y1, x2, y2, round)
    draw.rect(x1, y1, x2, y2, 255, 255, 255, 14, round)        -- glass tint
    draw.rect(x1, y1, x2, y2, BG[1], BG[2], BG[3], 150, round) -- darken
    draw.rect_outline(x1, y1, x2, y2, 255, 255, 255, 36, round) -- rim light
end

overlay.on_draw("player_panel", function()
    if not menu.is_visible() then return end
    local it = menu.get_item(menu.selected_index())
    if not it or it.info_type ~= 1 or not it.info then return end
    local p = it.info

    local function S(v) return tostring(v ~= nil and v or "N/A") end

    local colL = {
        { "row", "Name",        it.name or "Player", ACCENT },
        { "row", "Model Name",  S(p.model_name) },
        { "row", "Model Label", S(p.model_label) },
        { "row", "Model Hash",  S(p.model_hash) },
        { "bar", "Health",      p.health or 0, 200, GREEN },
        { "bar", "Armour",      p.armor or 0, 100, CYAN },
        { "row", "Position",    S(p.position) },
        { "row", "Rotation",    S(p.rotation) },
        { "row", "Heading",     S(p.heading) },
        { "row", "Distance",    S(p.distance) },
        { "row", "Bullet Proof",         S(p.bullet_proof) },
        { "row", "Fire Proof",           S(p.fire_proof) },
        { "row", "Melee Proof",          S(p.melee_proof) },
        { "row", "Explosion Proof",      S(p.explosion_proof) },
        { "row", "Global Invincibility", S(p.god_mode) },
        { "row", "Invisibility",         S(p.invisible) },
        { "row", "Wanted Level",         tostring(p.wanted or 0) .. " / 5" },
        { "row", "Off The Radar",        S(p.off_radar) },
        { "row", "Cops Blind Eyes",      S(p.cops_blind) },
        { "row", "Speed",                S(p.speed) },
    }
    local colR = {
        { "sec", "Vehicle" },
        { "row", "Speed",                "N/A" },
        { "row", "Bullet Proof",         "N/A" },
        { "row", "Fire Proof",           "N/A" },
        { "row", "Melee Proof",          "N/A" },
        { "row", "Explosion Proof",      "N/A" },
        { "row", "Global Invincibility", "N/A" },
        { "row", "Current Vehicle",      S(p.vehicle) },
        { "sec", "Lobby" },
        { "row", "Script Host",       S(p.script_host) },
        { "row", "Session Host",      S(p.session_host) },
        { "row", "Next Session Host", S(p.next_host) },
        { "sec", "Account" },
        { "row", "Nenyoo User",       S(p.unreal_user) },
        { "row", "Friend",            S(p.friend_status) },
        { "row", "Pending Friend Request", S(p.pending_friend) },
        { "row", "Wallet",            S(p.wallet) },
        { "row", "Bank",              S(p.bank) },
        { "row", "Rank",              "Level " .. tostring(p.rank or 0) },
        { "row", "RP",                S(p.rp) },
        { "row", "K/D Ratio",         S(p.kd) },
        { "row", "R* Id (Ped)",       S(p.rid_ped) },
        { "row", "R* Id (Net)",       S(p.rid_net) },
        { "row", "Spoofed R* Id",     S(p.spoofed_rid) },
        { "sec", "Races" },
        { "row", "Won",               S(p.races_won) },
        { "row", "Lost",              S(p.races_lost) },
        { "sec", "Crew" },
        { "row", "Name",              S(p.crew_name) },
        { "row", "Tag",               S(p.crew_tag) },
        { "sec", "Geolocation" },
        { "row", "IP",                S(p.ip) },
        { "row", "Port",              S(p.port) },
        { "row", "Country",           S(p.country) },
        { "row", "City",              S(p.city) },
        { "row", "Latitude",          S(p.latitude) },
        { "row", "Longitude",         S(p.longitude) },
    }

    local sw, shh = ctx.screen_w(), ctx.screen_h()
    local rfont = font.small
    local header_h = 30
    local pad = 14
    local gap = 16
    local rh = math.floor(text.height(rfont) + 6)
    local LW = 244
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
        if (bx + bw * 0.5) < sw * 0.5 then X0 = bx + bw + 16 else X0 = bx - 16 - W end
        Y0 = by
    else
        X0 = 30; Y0 = 80
    end
    if X0 < 8 then X0 = 8 elseif X0 + W > sw - 8 then X0 = sw - 8 - W end
    if Y0 < 8 then Y0 = 8 elseif Y0 + H > shh - 8 then Y0 = shh - 8 - H end

    local px0 = X0 + pad
    local py0 = Y0 + header_h + pad
    local px1 = px0 + LW
    local py1 = py0 + ph_slot

    -- panel glow then frosted body. Frost the regions around the ped slot only so the
    -- slot stays transparent (the game paints a backdrop + ped behind the overlay).
    for k = 1, 3 do
        draw.rect_outline(X0 - k * 2, Y0 - k * 2, X0 + W + k * 2, Y0 + H + k * 2, ACCENT[1], ACCENT[2], ACCENT[3], math.floor(18 / k), ROUND + k * 2)
    end
    frost(X0, Y0 + header_h, px1, py0, 0)             -- above slot
    frost(X0, py0, px0, py1, 0)                        -- left strip
    frost(X0, py1, px1, Y0 + H, 0)                     -- below slot
    frost(px1, Y0 + header_h, X0 + W, Y0 + H, 0)       -- right column

    -- Header: frosted with accent glow + cyan underline
    draw.rect(X0, Y0, X0 + W, Y0 + header_h, 255, 255, 255, 16, ROUND)
    draw.rect(X0, Y0, X0 + W, Y0 + header_h, ACCENT[1], ACCENT[2], ACCENT[3], 90, ROUND)
    draw.rect(X0 + pad, Y0 + header_h - 1, X0 + W - pad, Y0 + header_h, CYAN[1], CYAN[2], CYAN[3], 180)
    text.draw(font.item, X0 + pad, Y0 + (header_h - text.height(font.item)) / 2, 255, 255, 255, 255, it.name or "Player")

    -- ped slot rim
    draw.rect_outline(px0, py0, px1, py1, CYAN[1], CYAN[2], CYAN[3], 60, 8)

    local ok = players.draw_ped(p.player_id or 0,
        px0 / sw, py0 / shh, (px1 - px0) / sw, (py1 - py0) / shh)
    if not ok then
        local s = "No preview"
        text.draw(rfont, px0 + (LW - text.width(rfont, s)) / 2, py0 + ph_slot / 2 - 6, 255, 255, 255, 80, s)
    end

    local function mini_bar(mbx, mby, mbw, frac, r, g, b)
        frac = clamp(frac, 0, 1)
        draw.rect(mbx, mby, mbx + mbw, mby + 5, 255, 255, 255, 16, 2)
        draw.rect(mbx, mby, mbx + mbw * frac, mby + 5, r, g, b, 255, 2)
    end

    local function render(cx, cw, yy, entries)
        for _, e in ipairs(entries) do
            if e[1] == "sec" then
                text.draw(font.label, cx, yy, CYAN[1], CYAN[2], CYAN[3], 200, string.upper(e[2]))
                draw.rect(cx, yy + 15, cx + cw, yy + 16, 255, 255, 255, 16)
            elseif e[1] == "bar" then
                text.draw(rfont, cx, yy, 255, 255, 255, 100, e[2])
                local valstr = tostring(e[3])
                local cbw = 70
                local cbx = cx + cw - vpad - cbw
                text.draw(rfont, cbx - 8 - text.width(rfont, valstr), yy, e[5][1], e[5][2], e[5][3], 255, valstr)
                mini_bar(cbx, yy + 4, cbw, e[3] / e[4], e[5][1], e[5][2], e[5][3])
            else
                text.draw(rfont, cx, yy, 255, 255, 255, 100, e[2])
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
