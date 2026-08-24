-- Brutalist-styled player-info panel. Overrides the global "player_panel" overlay
-- when the Brutalist theme is active (theme scripts load after globals, override by name).
-- Off-white paper, THICK black borders, hard offset drop-shadow, zero rounding,
-- UPPERCASE labels, hot-red accent. Shows full info + the live ped.

local INK    = { 17, 17, 17 }
local PAPER  = { 238, 236, 225 }
local ACCENT = { 255, 61, 87 }     -- hot red
local CYAN   = { 45, 226, 230 }    -- secondary
local GREEN  = { 22, 163, 74 }
local RED    = { 220, 38, 38 }
local DIM    = { 90, 90, 90 }
local BLUE   = { 37, 99, 235 }

local function vcol(v)
    if v == "Yes" then return GREEN[1], GREEN[2], GREEN[3] end
    if v == "No" then return RED[1], RED[2], RED[3] end
    if v == "Hidden" or v == "N/A" or v == "-" or v == "" then return DIM[1], DIM[2], DIM[3] end
    return INK[1], INK[2], INK[3]
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

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
        { "bar", "Armour",      p.armor or 0, 100, BLUE },
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
    local pad = 12
    local gap = 16
    local shadow = 7
    local border = 3
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
        if (bx + bw * 0.5) < sw * 0.5 then X0 = bx + bw + 14 else X0 = bx - 14 - W end
        Y0 = by
    else
        X0 = 30; Y0 = 80
    end
    if X0 < 8 then X0 = 8 elseif X0 + W > sw - 8 then X0 = sw - 8 - W end
    if Y0 < 8 then Y0 = 8 elseif Y0 + H > shh - 8 then Y0 = shh - 8 - H end

    -- Ped slot (top-left)
    local px0 = X0 + pad
    local py0 = Y0 + header_h + pad
    local px1 = px0 + LW
    local py1 = py0 + ph_slot

    -- Hard offset shadow + paper body (ped slot left transparent for the game to paint into)
    draw.rect(X0 + shadow, Y0 + shadow, X0 + W + shadow, Y0 + H + shadow, INK[1], INK[2], INK[3], 255)
    draw.rect(X0, Y0 + header_h, px1, py0, PAPER[1], PAPER[2], PAPER[3], 255)         -- above slot
    draw.rect(X0, py0, px0, py1, PAPER[1], PAPER[2], PAPER[3], 255)                   -- left strip
    draw.rect(X0, py1, px1, Y0 + H, PAPER[1], PAPER[2], PAPER[3], 255)                -- below slot
    draw.rect(px1, Y0 + header_h, X0 + W, Y0 + H, PAPER[1], PAPER[2], PAPER[3], 255)  -- right column

    -- Header bar: solid red, thick black underline
    draw.rect(X0, Y0, X0 + W, Y0 + header_h, ACCENT[1], ACCENT[2], ACCENT[3], 255)
    draw.rect(X0, Y0 + header_h - border, X0 + W, Y0 + header_h, INK[1], INK[2], INK[3], 255)
    text.draw(font.item, X0 + pad, Y0 + (header_h - text.height(font.item)) / 2, 255, 255, 255, 255, string.upper(it.name or "PLAYER"))

    -- Thick outer border + ped slot border
    draw.rect_outline(X0, Y0, X0 + W, Y0 + H, INK[1], INK[2], INK[3], 255, 0, border)
    draw.rect_outline(px0, py0, px1, py1, INK[1], INK[2], INK[3], 255, 0, 2)

    local ok = players.draw_ped(p.player_id or 0,
        px0 / sw, py0 / shh, (px1 - px0) / sw, (py1 - py0) / shh)
    if not ok then
        local s = "NO PREVIEW"
        text.draw(rfont, px0 + (LW - text.width(rfont, s)) / 2, py0 + ph_slot / 2 - 6, INK[1], INK[2], INK[3], 150, s)
    end

    local function mini_bar(mbx, mby, mbw, frac, r, g, b)
        frac = clamp(frac, 0, 1)
        draw.rect(mbx, mby, mbx + mbw, mby + 6, 0, 0, 0, 30)
        draw.rect(mbx, mby, mbx + mbw * frac, mby + 6, r, g, b, 255)
        draw.rect_outline(mbx, mby, mbx + mbw, mby + 6, INK[1], INK[2], INK[3], 255, 0, 1)
    end

    local function render(cx, cw, yy, entries)
        for _, e in ipairs(entries) do
            if e[1] == "sec" then
                local up = string.upper(e[2])
                local lw = text.width(font.label, up)
                draw.rect(cx, yy, cx + lw + 8, yy + 14, ACCENT[1], ACCENT[2], ACCENT[3], 255)
                text.draw(font.label, cx + 4, yy + 2, 255, 255, 255, 255, up)
                draw.rect(cx, yy + 16, cx + cw, yy + 18, INK[1], INK[2], INK[3], 255)
            elseif e[1] == "bar" then
                text.draw(rfont, cx, yy, INK[1], INK[2], INK[3], 200, string.upper(e[2]))
                local valstr = tostring(e[3])
                local cbw = 70
                local cbx = cx + cw - vpad - cbw
                text.draw(rfont, cbx - 8 - text.width(rfont, valstr), yy, e[5][1], e[5][2], e[5][3], 255, valstr)
                mini_bar(cbx, yy + 4, cbw, e[3] / e[4], e[5][1], e[5][2], e[5][3])
            else
                text.draw(rfont, cx, yy, INK[1], INK[2], INK[3], 200, string.upper(e[2]))
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
