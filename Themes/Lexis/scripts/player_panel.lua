-- Lexis theme — bundled player-info panel.
-- Overrides the global "player_panel" overlay by name while the Lexis theme is active.
-- Clean rounded-card look: dark cards with a centered header bar per section, rose/pink
-- accent, bright-white values, live ped composited into the top-left slot.

local ACCENT = { 160, 70, 90 }    -- rose accent
local PINK   = { 235, 96, 174 }   -- name highlight
local GREEN  = { 90, 210, 120 }
local RED    = { 225, 84, 84 }
local BLUE   = { 120, 160, 235 }
local DIM    = { 140, 140, 155 }

local CARD_BG = { 20, 18, 28, 240 }
local HEAD_BG = { 28, 32, 42, 250 }
local BORDER  = { 50, 50, 65, 90 }
local ROUND   = 8

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function vcol(v)
    if v == "Yes" then return GREEN[1], GREEN[2], GREEN[3] end
    if v == "No" then return RED[1], RED[2], RED[3] end
    if v == "Hidden" or v == "N/A" or v == "-" or v == "" then return DIM[1], DIM[2], DIM[3] end
    return BLUE[1], BLUE[2], BLUE[3]
end

overlay.on_draw("player_panel", function()
    if not menu.is_visible() then return end
    local it = menu.get_item(menu.selected_index())
    if not it or it.info_type ~= 1 or not it.info then return end
    local p = it.info

    -- LEFT column (under the ped): the player.
    local colL = {
        { "row", "Name",        it.name or "Player", PINK },
        { "row", "Model Name",  p.model_name },
        { "row", "Model Label", p.model_label },
        { "row", "Model Hash",  p.model_hash },
        { "bar", "Health",      p.health or 0, 200, GREEN },
        { "bar", "Armour",      p.armor or 0, 100, BLUE },
        { "row", "Position",    p.position },
        { "row", "Rotation",    p.rotation },
        { "row", "Heading",     p.heading },
        { "row", "Distance",    p.distance },
        { "row", "Bullet Proof",         p.bullet_proof },
        { "row", "Fire Proof",           p.fire_proof },
        { "row", "Melee Proof",          p.melee_proof },
        { "row", "Explosion Proof",      p.explosion_proof },
        { "row", "Global Invincibility", p.god_mode },
        { "row", "Invisibility",         p.invisible },
        { "row", "Wanted Level",         tostring(p.wanted or 0) .. " / 5" },
        { "row", "Off The Radar",        p.off_radar },
        { "row", "Cops Blind Eyes",      p.cops_blind },
        { "row", "Speed",                p.speed },
    }
    -- RIGHT column: vehicle + lobby + account + races + crew + geo.
    local colR = {
        { "sec", "Vehicle" },
        { "row", "Speed",                "N/A" },
        { "row", "Bullet Proof",         "N/A" },
        { "row", "Fire Proof",           "N/A" },
        { "row", "Melee Proof",          "N/A" },
        { "row", "Explosion Proof",      "N/A" },
        { "row", "Global Invincibility", "N/A" },
        { "row", "Current Vehicle",      p.vehicle },
        { "sec", "Lobby" },
        { "row", "Script Host",       p.script_host },
        { "row", "Session Host",      p.session_host },
        { "row", "Next Session Host", p.next_host },
        { "sec", "Account" },
        { "row", "Nenyoo User",       p.unreal_user },
        { "row", "Friend",            p.friend_status },
        { "row", "Pending Friend Request", p.pending_friend },
        { "row", "Wallet",            p.wallet },
        { "row", "Bank",              p.bank },
        { "row", "Rank",              "Level " .. tostring(p.rank or 0) },
        { "row", "RP",                p.rp },
        { "row", "K/D Ratio",         p.kd },
        { "row", "R* Id (Ped)",       p.rid_ped },
        { "row", "R* Id (Net)",       p.rid_net },
        { "row", "Spoofed R* Id",     p.spoofed_rid },
        { "sec", "Races" },
        { "row", "Won",               p.races_won },
        { "row", "Lost",              p.races_lost },
        { "sec", "Crew" },
        { "row", "Name",              p.crew_name },
        { "row", "Tag",               p.crew_tag },
        { "sec", "Geolocation" },
        { "row", "IP",                p.ip },
        { "row", "Port",              p.port },
        { "row", "Country",           p.country },
        { "row", "City",              p.city },
        { "row", "Latitude",          p.latitude },
        { "row", "Longitude",         p.longitude },
    }

    local sw, shh = ctx.screen_w(), ctx.screen_h()
    local rfont = font.small
    local header_h = 30
    local pad = 12
    local gap = 14
    local rh = math.floor(text.height(rfont) + 7)
    local LW = 240
    local RW = 256
    local ph_slot = 320
    local vpad = 10
    local W = pad + LW + gap + RW + pad

    local hL = ph_slot + 10 + #colL * rh
    local hR = #colR * rh
    local content_h = math.max(hL, hR)
    local H = math.min(header_h + pad + content_h + pad, shh - 16)

    -- Dock beside the menu.
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

    -- Ped slot geometry (top-left).
    local px0 = X0 + pad
    local py0 = Y0 + header_h + pad
    local px1 = px0 + LW
    local py1 = py0 + ph_slot

    -- Rounded card background; leave the ped slot UNFILLED (the renderer paints the backdrop
    -- behind the ped). Paint the card AROUND the slot in four rects so the slot stays transparent.
    local cr, cg, cb, ca = CARD_BG[1], CARD_BG[2], CARD_BG[3], CARD_BG[4]
    draw.rect(X0, Y0 + header_h, px1, py0, cr, cg, cb, ca)          -- above slot
    draw.rect(X0, py0, px0, py1, cr, cg, cb, ca)                    -- left strip
    draw.rect(X0, py1, px1, Y0 + H, cr, cg, cb, ca, ROUND)         -- below slot (rounded bottom-left)
    draw.rect(px1, Y0 + header_h, X0 + W, Y0 + H, cr, cg, cb, ca, ROUND) -- right column

    -- Header bar (rounded top, accent underline) with centered name feel: left-aligned title
    -- but accent strip for the Lexis card look.
    draw.rect(X0, Y0, X0 + W, Y0 + header_h, HEAD_BG[1], HEAD_BG[2], HEAD_BG[3], HEAD_BG[4], ROUND)
    draw.rect(X0 + pad, Y0 + header_h - 2, X0 + W - pad, Y0 + header_h, ACCENT[1], ACCENT[2], ACCENT[3], 200, 2)
    local hname = it.name or "Player"
    text.draw(font.item, X0 + pad, Y0 + (header_h - text.height(font.item)) / 2,
        235, 236, 242, 255, hname)

    -- Card outline.
    draw.rect_outline(X0, Y0, X0 + W, Y0 + H, BORDER[1], BORDER[2], BORDER[3], BORDER[4], ROUND)

    -- Ped slot outline + live ped.
    draw.rect_outline(px0, py0, px1, py1, BORDER[1], BORDER[2], BORDER[3], 120, 6)
    local ok = players.draw_ped(p.player_id or 0,
        px0 / sw, py0 / shh, (px1 - px0) / sw, (py1 - py0) / shh)
    if not ok then
        local s = "No preview"
        text.draw(rfont, px0 + (LW - text.width(rfont, s)) / 2,
            py0 + ph_slot / 2 - 6, DIM[1], DIM[2], DIM[3], 220, s)
    end

    -- Mini rounded bar (Lexis style).
    local function mini_bar(mbx, mby, mbw, frac, col)
        frac = clamp(frac, 0, 1)
        draw.rect(mbx, mby, mbx + mbw, mby + 5, 255, 255, 255, 18, 2)
        if frac > 0 then
            draw.rect(mbx, mby, mbx + mbw * frac, mby + 5, col[1], col[2], col[3], 220, 2)
        end
    end

    -- Render a column.
    --   {"sec", title} | {"row", label, value [, {r,g,b}]} | {"bar", label, value, max, {r,g,b}}
    local function render(cx, cw, yy, entries)
        for _, e in ipairs(entries) do
            if e[1] == "sec" then
                -- Centered card-style section header bar.
                draw.rect(cx, yy - 1, cx + cw - vpad, yy + rh - 4, HEAD_BG[1], HEAD_BG[2], HEAD_BG[3], 220, 5)
                local tw = text.width(rfont, e[2])
                text.draw(rfont, cx + (cw - vpad - tw) / 2, yy + 1, 200, 200, 210, 240, e[2])
            elseif e[1] == "bar" then
                text.draw(rfont, cx, yy, DIM[1], DIM[2], DIM[3], 220, e[2])
                local valstr = tostring(e[3])
                local cbw = 70
                local cbx = cx + cw - vpad - cbw
                text.draw(rfont, cbx - 8 - text.width(rfont, valstr), yy,
                    e[5][1], e[5][2], e[5][3], 255, valstr)
                mini_bar(cbx, yy + 4, cbw, e[3] / e[4], e[5])
            else
                text.draw(rfont, cx, yy, DIM[1], DIM[2], DIM[3], 220, e[2])
                local v = tostring(e[3] or "N/A")
                local r, g, b
                if e[4] then r, g, b = e[4][1], e[4][2], e[4][3] else r, g, b = vcol(v) end
                text.draw(rfont, cx + cw - vpad - text.width(rfont, v), yy, r, g, b, 255, v)
            end
            yy = yy + rh
        end
    end

    render(px0, LW, py1 + 10, colL)                   -- left column (under ped)
    render(px1 + gap, RW, Y0 + header_h + pad, colR)  -- right column
end)
