-- Nenyoo "Terminal" Theme — CRT / hacker aesthetic
-- Phosphor green on black, ASCII brackets, blinking block cursor, segmented
-- bars, scanline overlay and a soft CRT glow. Built on THEME_API.md.

---------------------------------------------------------------------------
-- Fonts
---------------------------------------------------------------------------
text.set_size(font.title, 18);  text.set_weight(font.title, 700)
text.set_size(font.item, 13);   text.set_weight(font.item, 500)
text.set_size(font.value, 12);  text.set_weight(font.value, 600)

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
local function sc(name)
    local s = menu.get_setting(name)
    if s then return {s.r, s.g, s.b, s.a} end
    return nil
end
local function sf(name, default)
    local s = menu.get_setting(name)
    if s then return s.f_val end
    return default
end
local function sb(name, default)
    local s = menu.get_setting(name)
    if s then return s.on end
    return default
end

local function reload_colors()
    return {
        accent  = sc("Phosphor")    or {88, 255, 136, 255},  -- bright green
        accentD = sc("Phosphor Dim")or {40, 120, 70, 255},   -- dim green
        bg      = sc("Background")   or {6, 10, 7, 255},      -- near-black green tint
        amber   = {255, 196, 90, 255},
        red     = {255, 90, 90, 255},
    }
end
local function reload_layout()
    return {
        menu_w  = sf("Menu Width", 400),
        item_h  = sf("Row Height", 32),
        header_h= 60,
        footer_h= 34,
        list_max= 440,
        pad_x   = 16,
        scan    = sb("Scanlines", true),
        glow    = sb("CRT Glow", true),
    }
end

menu.clear_settings()
menu.add_setting_submenu("Colors", "Phosphor and background")
menu.add_sub_color("Phosphor", 88, 255, 136, 255, "Bright text / accent")
menu.add_sub_color("Phosphor Dim", 40, 120, 70, 255, "Inactive text")
menu.add_sub_color("Background", 6, 10, 7, 255, "Panel background")
menu.add_setting_submenu("Display", "CRT effects and sizing")
menu.add_sub_toggle("Scanlines", true, "Horizontal scanline overlay")
menu.add_sub_toggle("CRT Glow", true, "Soft phosphor glow")
menu.add_sub_slider("Menu Width", 400, 300, 640, 10, "Panel width (px)")
menu.add_sub_slider("Row Height", 32, 24, 56, 1, "Row height (px)")

local c = reload_colors()
local l = reload_layout()

---------------------------------------------------------------------------
-- Helpers / state
---------------------------------------------------------------------------
local function lerp(a, b, t) return a + (b - a) * t end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function ease_out(t) t = clamp(t, 0, 1); return 1 - (1 - t)^3 end

local SEG_N, SEG_W, SEG_GAP = 12, 7, 2
local BAR_W = SEG_N * (SEG_W + SEG_GAP) - SEG_GAP

local scroll, scroll_target = 0, 0
local nav_time, last_page = 0, ""
local last_sel = -1
local dragging_slider = -1
local drag_x, drag_w = 0, 0
local frame = { menu_x = 0, list_y = 0, popup_item_y = 0 }
local sb_last, dragging_sb, sb_grab = 0, false, 0

-- terminal "boot" type-out of the title
local boot_time = ctx.time()

local function gtxt(font_id, x, y, a, s, spacing)
    -- green text helper
    if spacing then
        text.draw_spaced(font_id, x, y, c.accent[1], c.accent[2], c.accent[3], a, s, spacing)
    else
        text.draw(font_id, x, y, c.accent[1], c.accent[2], c.accent[3], a, s)
    end
end

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------
local function draw_checkbox(rx, yc, item, is_sel)
    local txt = item.on and "[x]" or "[ ]"
    local w = text.width(font.value, "[x]")
    local a = item.on and 255 or (is_sel and 150 or 90)
    text.draw(font.value, rx - w, yc - text.height(font.value) / 2, c.accent[1], c.accent[2], c.accent[3], a, txt)
    return w
end

local function draw_bar(rx, yc, item, is_sel)
    local frac = 0
    if item.f_max > item.f_min then
        frac = clamp((item.f_val - item.f_min) / (item.f_max - item.f_min), 0, 1)
    end
    local vs = string.format("%.1f", item.f_val)
    local vw = text.width(font.value, vs)
    -- value (right)
    text.draw(font.value, rx - vw, yc - text.height(font.value) / 2, c.accent[1], c.accent[2], c.accent[3], is_sel and 255 or 150, vs)
    -- segmented bar (left of value)
    local bar_right = rx - vw - 10
    local bx = bar_right - BAR_W
    local lit = math.floor(frac * SEG_N + 0.5)
    for i = 0, SEG_N - 1 do
        local sx = bx + i * (SEG_W + SEG_GAP)
        if i < lit then
            draw.rect(sx, yc - 5, sx + SEG_W, yc + 5, c.accent[1], c.accent[2], c.accent[3], is_sel and 255 or 170)
        else
            draw.rect(sx, yc - 5, sx + SEG_W, yc + 5, c.accentD[1], c.accentD[2], c.accentD[3], is_sel and 120 or 70)
        end
    end
    return bx, BAR_W
end

local function draw_stepper(rx, yc, val_text, is_sel)
    -- "< value >"
    local af = font.value
    local lh = text.height(af)
    local ry = yc - lh / 2
    local a_arrow = is_sel and 230 or 110
    local a_val   = is_sel and 255 or 150
    local rgt = text.width(af, ">")
    local lft = text.width(af, "<")
    local vw = text.width(af, val_text)
    text.draw(af, rx - rgt, ry, c.accent[1], c.accent[2], c.accent[3], a_arrow, ">")
    local vx = rx - rgt - 8 - vw
    text.draw(af, vx, ry, c.accent[1], c.accent[2], c.accent[3], a_val, val_text)
    text.draw(af, vx - 8 - lft, ry, c.accent[1], c.accent[2], c.accent[3], a_arrow, "<")
end

local function draw_widget(rx, yc, item, is_sel)
    local t = item.type
    if t == item_type.sub_menu then
        local ch = "->"
        text.draw(font.value, rx - text.width(font.value, ch), yc - text.height(font.value) / 2,
            c.accent[1], c.accent[2], c.accent[3], is_sel and 220 or 90, ch)
    elseif t == item_type.selected_tick then
        local ch = "[v]"
        text.draw(font.value, rx - text.width(font.value, ch), yc - text.height(font.value) / 2,
            c.accent[1], c.accent[2], c.accent[3], is_sel and 220 or 90, ch)
    elseif t == item_type.toggle then
        draw_checkbox(rx, yc, item, is_sel)
    elseif t == item_type.float_toggle then
        local w = draw_checkbox(rx, yc, item, is_sel)
        draw_bar(rx - w - 12, yc, item, is_sel)
    elseif t == item_type.int_toggle then
        local w = draw_checkbox(rx, yc, item, is_sel)
        draw_stepper(rx - w - 12, yc, tostring(item.i_val), is_sel)
    elseif t == item_type.array_toggle or t == item_type.loop_toggle then
        local w = draw_checkbox(rx, yc, item, is_sel)
        draw_stepper(rx - w - 12, yc, item.current_value or "?", is_sel)
    elseif t == item_type.slider then
        draw_bar(rx, yc, item, is_sel)
    elseif t == item_type.int_option then
        draw_stepper(rx, yc, tostring(item.i_val), is_sel)
    elseif t == item_type.array_option or t == item_type.loop_option then
        draw_stepper(rx, yc, item.current_value or "?", is_sel)
    elseif t == item_type.color then
        local s = 20
        local hexs = string.format("#%02X%02X%02X", item.r, item.g, item.b)
        local hw = text.width(font.value, hexs)
        text.draw(font.value, rx - s - 6 - hw, yc - text.height(font.value) / 2, c.accent[1], c.accent[2], c.accent[3], is_sel and 200 or 110, hexs)
        draw.rect(rx - s, yc - s / 2, rx, yc + s / 2, item.r, item.g, item.b, item.a or 255)
        draw.rect_outline(rx - s, yc - s / 2, rx, yc + s / 2, c.accent[1], c.accent[2], c.accent[3], is_sel and 200 or 90)
    elseif t == item_type.search then
        -- magnifier glyph on the right, query text (or dim placeholder) to its left
        local glyph = "[/]"
        local gw = text.width(font.value, glyph)
        text.draw(font.value, rx - gw, yc - text.height(font.value) / 2, c.accent[1], c.accent[2], c.accent[3], is_sel and 220 or 90, glyph)
        local q = (item.text and item.text ~= "") and item.text or "Search..."
        local qa = (item.text and item.text ~= "") and (is_sel and 200 or 110) or (is_sel and 100 or 60)
        local qw = text.width(font.value, q)
        text.draw(font.value, rx - gw - 8 - qw, yc - text.height(font.value) / 2, c.accent[1], c.accent[2], c.accent[3], qa, q)
    elseif t == item_type.input_text then
        local vw = text.width(font.value, item.name)
        text.draw(font.value, rx - vw, yc - text.height(font.value) / 2, c.accent[1], c.accent[2], c.accent[3], is_sel and 200 or 110, item.name)
    elseif t == item_type.input_int then
        local vs = "[" .. tostring(item.i_val) .. "]"
        text.draw(font.value, rx - text.width(font.value, vs), yc - text.height(font.value) / 2, c.accent[1], c.accent[2], c.accent[3], is_sel and 200 or 110, vs)
    elseif t == item_type.input_float then
        local vs = "[" .. string.format("%.2f", item.f_val) .. "]"
        text.draw(font.value, rx - text.width(font.value, vs), yc - text.height(font.value) / 2, c.accent[1], c.accent[2], c.accent[3], is_sel and 200 or 110, vs)
    end
end

local function draw_hotkey_badge(x, y, vk, is_sel, lh)
    if vk == 0 then return end
    local kn = "<" .. menu.vk_name(vk) .. ">"
    text.draw(font.tiny, x, y + (lh - text.height(font.tiny)) / 2 - 1,
        c.amber[1], c.amber[2], c.amber[3], is_sel and 220 or 110, kn)
end

---------------------------------------------------------------------------
-- Header / footer
---------------------------------------------------------------------------
local function draw_header(x, y)
    -- title bar "[ NENYOO ]"
    local title = "[ " .. (str.brand or "NENYOO") .. " ]"
    title = string.upper(title)
    -- boot type-out
    local bt = clamp((ctx.time() - boot_time) / 0.5, 0, 1)
    local shown = title:sub(1, math.floor(#title * bt + 0.5))
    gtxt(font.title, x + l.pad_x, y + 10, 255, shown, 2)

    -- counter [03/08]
    local counter = string.format("[%02d/%02d]", menu.selected_index() + 1, menu.item_count())
    local cw = text.width(font.value, counter)
    text.draw(font.value, x + l.menu_w - l.pad_x - cw, y + 12, c.accentD[1], c.accentD[2], c.accentD[3], 220, counter)

    -- prompt line: root/page $ _
    local path = "root/" .. string.lower(string.gsub(menu.page_name(), " ", "_"))
    local prompt = path .. " $"
    local py = y + 32
    text.draw(font.item, x + l.pad_x, py, c.accentD[1], c.accentD[2], c.accentD[3], 230, prompt)
    -- blinking block cursor
    if math.fmod(ctx.time(), 1.0) < 0.55 then
        local pw = text.width(font.item, prompt .. " ")
        local ch = text.height(font.item)
        draw.rect(x + l.pad_x + pw, py + 1, x + l.pad_x + pw + 7, py + ch, c.accent[1], c.accent[2], c.accent[3], 220)
    end

    -- divider
    draw.rect(x + l.pad_x, y + l.header_h - 1, x + l.menu_w - l.pad_x, y + l.header_h, c.accentD[1], c.accentD[2], c.accentD[3], 160)
end

local function draw_footer(x, y)
    draw.rect(x + l.pad_x, y, x + l.menu_w - l.pad_x, y + 1, c.accentD[1], c.accentD[2], c.accentD[3], 160)
    local hints = "[UP/DN] nav  [ENTER] exec  [ESC] back"
    text.draw(font.tiny, x + l.pad_x, y + (l.footer_h - text.height(font.tiny)) / 2 + 1,
        c.accentD[1], c.accentD[2], c.accentD[3], 200, hints)
    -- live clock-ish frame ticker for flavor
    local stat = string.format("%dfps", math.floor(1 / math.max(ctx.delta(), 0.0001)))
    local sw = text.width(font.tiny, stat)
    text.draw(font.tiny, x + l.menu_w - l.pad_x - sw, y + (l.footer_h - text.height(font.tiny)) / 2 + 1,
        c.accent[1], c.accent[2], c.accent[3], 150, stat)
end

---------------------------------------------------------------------------
-- CRT effects
---------------------------------------------------------------------------
local function draw_glow(x, y, w, h)
    if not l.glow then return end
    for i = 1, 4 do
        local e = i * 2
        local a = math.floor(26 / i)
        draw.rect_outline(x - e, y - e, x + w + e, y + h + e, c.accent[1], c.accent[2], c.accent[3], a, 4 + e)
    end
end

local function draw_scanlines(x, y, w, h)
    if not l.scan then return end
    local yy = y
    while yy < y + h do
        draw.rect(x, yy, x + w, yy + 1, 0, 0, 0, 46)
        yy = yy + 3
    end
    -- faint moving scan band
    local band = y + ((ctx.time() * 80) % h)
    draw.rect(x, band, x + w, band + 24, c.accent[1], c.accent[2], c.accent[3], 6)
end

---------------------------------------------------------------------------
-- Scrollbar
---------------------------------------------------------------------------
local function draw_scrollbar(x, list_y, list_h, content_h)
    if content_h <= list_h then dragging_sb = false; return end
    local scroll_max = content_h - list_h
    local mx, my = input.mouse_x(), input.mouse_y()
    local near = mx >= x + l.menu_w - 16 and mx <= x + l.menu_w and my >= list_y and my <= list_y + list_h
    local moving = (math.abs(scroll - scroll_target) > 0.5) or dragging_sb
    if near or moving then sb_last = ctx.time() end
    local fade = clamp(1.0 - (ctx.time() - sb_last - 0.6) / 0.3, 0, 1)
    if fade < 0.01 and not dragging_sb then return end

    local sw = 4
    local sx = x + l.menu_w - sw - 4
    local thumb_h = math.max((list_h / content_h) * list_h, 24)
    local fr = scroll_max > 0 and (scroll / scroll_max) or 0
    local thumb_y = list_y + fr * (list_h - thumb_h)

    if not dragging_sb and input.mouse_clicked(0) and near then
        if my >= thumb_y and my <= thumb_y + thumb_h then
            dragging_sb = true; sb_grab = my - thumb_y
        else
            scroll_target = clamp((my - list_y - thumb_h * 0.5) / (list_h - thumb_h), 0, 1) * scroll_max
            scroll = scroll_target; dragging_sb = true; sb_grab = thumb_h * 0.5
        end
    end
    if dragging_sb then
        if input.mouse_down(0) then
            scroll_target = clamp((my - sb_grab - list_y) / (list_h - thumb_h), 0, 1) * scroll_max
            scroll = scroll_target
        else dragging_sb = false end
    end

    local a = math.max(fade, dragging_sb and 1 or 0)
    draw.rect(sx, list_y, sx + sw, list_y + list_h, c.accentD[1], c.accentD[2], c.accentD[3], math.floor(60 * a))
    draw.rect(sx, thumb_y, sx + sw, thumb_y + thumb_h, c.accent[1], c.accent[2], c.accent[3], math.floor(200 * a))
end

---------------------------------------------------------------------------
-- Side info panel (terminal table style)
---------------------------------------------------------------------------
local function draw_side_panel(x, y, w, item)
    if not item or not item.info then return end
    local it = item.info_type
    local info = item.info
    local cy = y
    local green, red, yellow, blue = c.accent, c.red, c.amber, {120,180,255}
    local valc = {c.accent[1], c.accent[2], c.accent[3], 200}

    local function section(title)
        cy = cy + 6
        text.draw(font.label, x + 14, cy, c.accent[1], c.accent[2], c.accent[3], 200, "// " .. string.upper(title))
        cy = cy + 16
        draw.rect(x + 14, cy, x + w - 14, cy + 1, c.accentD[1], c.accentD[2], c.accentD[3], 120)
        cy = cy + 8
    end
    local function row2(k1, v1, v1c, k2, v2, v2c)
        local rh = 22
        local half = w * 0.5
        text.draw(font.breadcrumb, x + 14, cy + 4, c.accentD[1], c.accentD[2], c.accentD[3], 220, k1)
        local vw1 = text.width(font.breadcrumb, v1)
        text.draw(font.breadcrumb, x + half - 8 - vw1, cy + 4, v1c[1], v1c[2], v1c[3], v1c[4] or 255, v1)
        if k2 and v2 then
            text.draw(font.breadcrumb, x + half + 10, cy + 4, c.accentD[1], c.accentD[2], c.accentD[3], 220, k2)
            local vw2 = text.width(font.breadcrumb, v2)
            text.draw(font.breadcrumb, x + w - 14 - vw2, cy + 4, v2c[1], v2c[2], v2c[3], v2c[4] or 255, v2)
        end
        cy = cy + rh
    end
    local function mini_bar(bx, by, bw, frac, col)
        local seg = 10
        local sw = (bw - (seg - 1) * 2) / seg
        local lit = math.floor(clamp(frac,0,1) * seg + 0.5)
        for i = 0, seg - 1 do
            local sx = bx + i * (sw + 2)
            local on = i < lit
            draw.rect(sx, by, sx + sw, by + 4, col[1], col[2], col[3], on and 255 or 60)
        end
    end
    local function stat_row(label, value, max_val)
        local rh = 22
        text.draw(font.small, x + 14, cy + 4, c.accentD[1], c.accentD[2], c.accentD[3], 220, label)
        local frac = clamp(value / max_val, 0, 1)
        local col = value >= max_val*0.7 and green or (value >= max_val*0.4 and yellow or red)
        local bw = 80
        local bx = x + w - 14 - bw
        mini_bar(bx, cy + 8, bw, frac, col)
        local vs = tostring(value)
        text.draw(font.breadcrumb, bx - 8 - text.width(font.breadcrumb, vs), cy + 3, col[1], col[2], col[3], 255, vs)
        cy = cy + rh
    end
    local function image_box(label)
        draw.rect_outline(x + 14, cy, x + w - 14, cy + 76, c.accentD[1], c.accentD[2], c.accentD[3], 160)
        local tw = text.width(font.small, label)
        text.draw(font.small, x + (w - tw) / 2, cy + 32, c.accentD[1], c.accentD[2], c.accentD[3], 200, "[ " .. label .. " ]")
        cy = cy + 84
    end

    local ph = 40
    if it == 1 then ph = 360 elseif it == 2 then ph = 320 elseif it == 3 then ph = 300 end

    draw.rect(x, y, x + w, y + ph, c.bg[1], c.bg[2], c.bg[3], 245)
    draw.rect_outline(x, y, x + w, y + ph, c.accent[1], c.accent[2], c.accent[3], 120)
    text.draw(font.item, x + 14, y + 14, c.accent[1], c.accent[2], c.accent[3], 255, "> " .. item.name)
    cy = y + 36

    if it == 1 then
        section(str.general or "General")
        row2(str.rank or "rank", tostring(info.rank), yellow, str.kd or "k/d", info.kd, valc)
        row2(str.cash or "cash", info.cash, green, str.bank or "bank", info.bank, green)
        section(str.status or "Status")
        local rh = 22
        text.draw(font.small, x + 14, cy + 4, c.red[1], c.red[2], c.red[3], 220, str.health or "hp")
        mini_bar(x + 72, cy + 8, 56, info.health/100, info.health > 50 and green or red)
        text.draw(font.tiny, x + 134, cy + 4, c.accent[1], c.accent[2], c.accent[3], 200, tostring(info.health).."%")
        text.draw(font.small, x + w*0.5 + 6, cy + 4, blue[1], blue[2], blue[3], 220, str.armor or "ap")
        mini_bar(x + w*0.5 + 56, cy + 8, 56, info.armor/100, blue)
        text.draw(font.tiny, x + w*0.5 + 118, cy + 4, c.accent[1], c.accent[2], c.accent[3], 200, tostring(info.armor).."%")
        cy = cy + rh
        local wstr = info.wanted == 0 and (str.clear or "clear") or tostring(info.wanted)
        row2(str.wanted or "wanted", wstr, info.wanted == 0 and green or red, str.ping or "ping", info.ping, valc)
        section(str.equipment or "Equipment")
        row2(str.weapon or "weapon", info.weapon, valc, str.ammo or "ammo", info.ammo, yellow)
        section(str.location or "Location")
        row2(str.zone or "zone", info.zone, valc, str.coords or "coords", info.coords, valc)
        row2(str.vehicle or "vehicle", info.vehicle, valc, str.speed or "speed", info.speed, yellow)
    elseif it == 2 then
        local wname = string.lower(string.gsub(item.name, " ", "_"))
        image_box("weapon_" .. wname)
        section(item.name)
        row2(str.type or "type", info.type, valc, str.fire_mode or "mode", info.rof, valc)
        row2(str.clip_size or "clip", tostring(info.clip), yellow, str.dps or "dps", tostring(info.damage*info.firerate), red)
        section(str.stats or "Stats")
        stat_row(str.damage or "dmg", info.damage, 100)
        stat_row(str.fire_rate or "rof", info.firerate, 10)
        stat_row(str.range or "rng", info.range, 100)
        stat_row(str.accuracy or "acc", info.accuracy, 100)
    elseif it == 3 then
        local vname = string.lower(string.gsub(item.name, " ", "_"))
        image_box("vehicle_" .. vname)
        section(item.name)
        row2(str.cls or "class", info.cls, valc, str.price or "price", info.price, green)
        row2(str.top_speed or "top", info.speed, yellow, str.drivetrain or "drive", info.drivetrain, valc)
        row2(str.seats or "seats", tostring(info.seats), valc, nil, nil, nil)
        section(str.performance or "Performance")
        stat_row(str.acceleration or "accel", info.accel, 100)
        stat_row(str.braking or "brake", info.brake, 100)
        stat_row(str.handling or "hndl", info.handling, 100)
    end
end

---------------------------------------------------------------------------
-- Main draw
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- POPUP: Input (mode 1)
---------------------------------------------------------------------------
local input_cursor, input_blink, input_open_time = 0, 0, 0

function draw_input_popup()
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    draw.rect(0, 0, sw, sh, 0, 0, 0, 150)
    local pw, ph = 360, 110
    local px, py = (sw - pw) / 2, (sh - ph) / 2
    draw.rect(px, py, px + pw, py + ph, c.bg[1], c.bg[2], c.bg[3], 255)
    draw.rect_outline(px, py, px + pw, py + ph, c.accent[1], c.accent[2], c.accent[3], 160)
    local item = menu.get_item(menu.input_target_item())
    local title = item and item.name or (str.edit_value or "edit")
    gtxt(font.label, px + 18, py + 16, 220, "// " .. string.upper(title))
    local buf = menu.get_input_buffer()
    local ix, iy = px + 18, py + 44
    text.draw(font.item, ix, iy, c.accentD[1], c.accentD[2], c.accentD[3], 220, "$ ")
    local pre_w = text.width(font.item, "$ ")
    text.draw(font.item, ix + pre_w, iy, c.accent[1], c.accent[2], c.accent[3], 255, buf)
    if math.fmod(ctx.time() - input_blink, 1.0) < 0.55 then
        local cw = text.width(font.item, buf:sub(1, input_cursor))
        local ch = text.height(font.item)
        draw.rect(ix + pre_w + cw, iy + 1, ix + pre_w + cw + 7, iy + ch, c.accent[1], c.accent[2], c.accent[3], 220)
    end
end

function handle_input_popup()
    local elapsed = ctx.time() - input_open_time
    if input.key_just_pressed(VK.ESCAPE) then menu.set_popup_mode(0); return end
    if input.key_just_pressed(VK.RETURN) and elapsed > 0.15 then menu.confirm_input(); return end
    local buf = menu.get_input_buffer()
    local chars = input.get_chars()
    if #chars > 0 then
        buf = buf:sub(1, input_cursor) .. chars .. buf:sub(input_cursor + 1)
        input_cursor = input_cursor + #chars; input_blink = ctx.time(); menu.set_input_buffer(buf)
    end
    if input.key_pressed(VK.BACK) and input_cursor > 0 then
        buf = buf:sub(1, input_cursor - 1) .. buf:sub(input_cursor + 1)
        input_cursor = input_cursor - 1; input_blink = ctx.time(); menu.set_input_buffer(buf)
    end
    if input.key_pressed(VK.DELETE) and input_cursor < #buf then
        buf = buf:sub(1, input_cursor) .. buf:sub(input_cursor + 2); menu.set_input_buffer(buf)
    end
    if input.key_pressed(VK.LEFT) and input_cursor > 0 then input_cursor = input_cursor - 1; input_blink = ctx.time() end
    if input.key_pressed(VK.RIGHT) and input_cursor < #buf then input_cursor = input_cursor + 1; input_blink = ctx.time() end
    if input.key_just_pressed(VK.HOME) then input_cursor = 0; input_blink = ctx.time() end
    if input.key_just_pressed(VK.END) then input_cursor = #buf; input_blink = ctx.time() end
end

local orig_open_input = menu.open_input_popup
menu.open_input_popup = function()
    orig_open_input()
    input_cursor = #menu.get_input_buffer()
    input_blink = ctx.time(); input_open_time = ctx.time()
end

---------------------------------------------------------------------------
-- POPUP: Array Dropdown (mode 3)
---------------------------------------------------------------------------
local array_picker_idx, array_open_time = 0, 0

function draw_array_dropdown_popup()
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local sel = menu.selected_index()
    local item = menu.get_item(sel)
    if not item or item.value_count <= 0 then menu.set_popup_mode(0); return end
    local values = menu.get_item_values(sel)
    if not values then menu.set_popup_mode(0); return end
    local dw, dh_item = 210, 30
    local count = item.value_count
    local dh = math.min(count * dh_item, dh_item * 8) + 6
    local dx = frame.menu_x + l.menu_w - dw - l.pad_x
    local dy = frame.popup_item_y or 300
    if dy + dh > sh - 10 then dy = dy - dh - l.item_h end
    draw.rect(dx, dy, dx + dw, dy + dh, c.bg[1], c.bg[2], c.bg[3], 255)
    draw.rect_outline(dx, dy, dx + dw, dy + dh, c.accent[1], c.accent[2], c.accent[3], 160)
    local mx, my = input.mouse_x(), input.mouse_y()
    local vfh = text.height(font.value)
    for i = 1, count do
        local is_sel = ((i - 1) == array_picker_idx)
        local is_cur = ((i - 1) == item.value_index)
        local iy = dy + 3 + (i - 1) * dh_item
        local hovered = mx >= dx and mx <= dx + dw and my >= iy and my <= iy + dh_item
        if hovered then array_picker_idx = i - 1 end
        if is_sel or hovered then
            draw.rect(dx + 3, iy, dx + dw - 3, iy + dh_item, c.accent[1], c.accent[2], c.accent[3], 28)
        end
        local marker = (is_sel or hovered) and "> " or "  "
        local a = (is_sel or hovered) and 255 or 130
        text.draw(font.value, dx + 10, iy + (dh_item - vfh) / 2, c.accent[1], c.accent[2], c.accent[3], a, marker .. values[i])
        if is_cur then
            text.draw(font.value, dx + dw - 22, iy + (dh_item - vfh) / 2, c.accent[1], c.accent[2], c.accent[3], 220, "*")
        end
    end
end

function handle_array_dropdown()
    local elapsed = ctx.time() - array_open_time
    local sel = menu.selected_index()
    local item = menu.get_item(sel)
    if not item then menu.set_popup_mode(0); return end
    if input.key_just_pressed(VK.ESCAPE) or input.key_just_pressed(VK.BACK) then menu.set_popup_mode(0); return end
    if elapsed > 0.1 then
        if input.key_pressed(VK.DOWN) and array_picker_idx < item.value_count - 1 then array_picker_idx = array_picker_idx + 1 end
        if input.key_pressed(VK.UP) and array_picker_idx > 0 then array_picker_idx = array_picker_idx - 1 end
        if input.key_just_pressed(VK.RETURN) then menu.set_value_index(sel, array_picker_idx); menu.set_popup_mode(0); return end
        local mx, my = input.mouse_x(), input.mouse_y()
        if input.mouse_clicked(0) and elapsed > 0.15 then
            local dw, dh_item = 210, 30
            local dx = frame.menu_x + l.menu_w - dw - l.pad_x
            local dy = (frame.popup_item_y or 300) + 3
            if mx >= dx and mx <= dx + dw and my >= dy and my <= dy + item.value_count * dh_item then
                local idx = math.floor((my - dy) / dh_item)
                if idx >= 0 and idx < item.value_count then menu.set_value_index(sel, idx); menu.set_popup_mode(0); return end
            else menu.set_popup_mode(0); return end
        end
    end
end

local orig_open_array = menu.open_array_popup
menu.open_array_popup = function()
    orig_open_array()
    local item = menu.get_item(menu.selected_index())
    array_picker_idx = item and item.value_index or 0
    array_open_time = ctx.time()
end

---------------------------------------------------------------------------
-- POPUP: Hotkey Bind (mode 4)
---------------------------------------------------------------------------
function draw_hotkey_popup()
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    draw.rect(0, 0, sw, sh, 0, 0, 0, 150)
    local pw, ph = 300, 76
    local px, py = (sw - pw) / 2, (sh - ph) / 2
    draw.rect(px, py, px + pw, py + ph, c.bg[1], c.bg[2], c.bg[3], 255)
    draw.rect_outline(px, py, px + pw, py + ph, c.accent[1], c.accent[2], c.accent[3], 160)
    local title = "> " .. (str.press_key or "press any key")
    local tw = text.width(font.item, title)
    -- blink whole title for "waiting" feel
    local a = math.fmod(ctx.time(), 1.0) < 0.5 and 255 or 120
    text.draw(font.item, px + (pw - tw) / 2, py + 18, c.accent[1], c.accent[2], c.accent[3], a, title)
    local hint = str.esc_cancel or "[esc] cancel"
    local hw = text.width(font.desc, hint)
    text.draw(font.desc, px + (pw - hw) / 2, py + 18 + text.height(font.item) + 8, c.accentD[1], c.accentD[2], c.accentD[3], 220, hint)
end

function handle_hotkey_bind()
    if input.key_just_pressed(VK.ESCAPE) then
        menu.set_popup_mode(0); notify.push("hotkey", str.cancelled or "cancelled", 0); return
    end
    local skip = {[27]=true,[1]=true,[2]=true,[4]=true,[16]=true,[17]=true,[18]=true,
                  [160]=true,[161]=true,[162]=true,[163]=true,[164]=true,[165]=true}
    for vk = 1, 255 do
        if not skip[vk] and input.key_just_pressed(vk) then
            local sel = menu.selected_index()
            menu.set_hotkey(sel, vk)
            notify.push(menu.get_item(sel).name, (str.bound_to or "bound to") .. " " .. menu.vk_name(vk), 1)
            menu.save_hotkeys(); menu.rebuild_features(); menu.set_popup_mode(0)
            return
        end
    end
end

---------------------------------------------------------------------------
-- POPUP: Color Picker (mode 2)
---------------------------------------------------------------------------
local cp_tab, cp_palette_idx = 0, 0
local cp_hue, cp_sat, cp_val = 0, 1, 1
local cp_dragging_sv, cp_dragging_hue, cp_open_time = false, false, 0

local palette = {
    {239,68,68,255},{220,38,38,255},{185,28,28,255},{153,27,27,255},
    {249,115,22,255},{234,88,12,255},{194,65,12,255},{154,52,18,255},
    {234,179,8,255},{202,138,4,255},{161,98,7,255},{133,77,14,255},
    {34,197,94,255},{22,163,74,255},{21,128,61,255},{20,83,45,255},
    {59,130,246,255},{37,99,235,255},{29,78,216,255},{30,64,175,255},
    {168,85,247,255},{147,51,234,255},{126,34,206,255},{107,33,168,255},
    {236,72,153,255},{219,39,119,255},{190,24,93,255},{157,23,77,255},
    {255,255,255,255},{200,200,200,255},{100,100,100,255},{0,0,0,255},
}

function draw_color_picker()
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    draw.rect(0, 0, sw, sh, 0, 0, 0, 150)
    local pw, ph = 400, 452
    local px, py = (sw - pw) / 2, (sh - ph) / 2
    draw.rect(px, py, px + pw, py + ph, c.bg[1], c.bg[2], c.bg[3], 255)
    draw.rect_outline(px, py, px + pw, py + ph, c.accent[1], c.accent[2], c.accent[3], 160)

    local tab_w, tab_h, tab_y = 90, 26, py + 18
    local tabs = {"[ " .. (str.palette or "palette") .. " ]", "[ " .. (str.custom or "custom") .. " ]"}
    local mx, my = input.mouse_x(), input.mouse_y()
    for i = 1, 2 do
        local tx = px + 18 + (i - 1) * (tab_w + 6)
        local active = (cp_tab == i - 1)
        local tw = text.width(font.tagline, tabs[i])
        text.draw(font.tagline, tx, tab_y + (tab_h - text.height(font.tagline)) / 2,
            c.accent[1], c.accent[2], c.accent[3], active and 255 or 110, tabs[i])
        if mx >= tx and mx <= tx + tw and my >= tab_y and my <= tab_y + tab_h and input.mouse_clicked(0) then cp_tab = i - 1 end
    end

    local content_y = tab_y + tab_h + 16
    if cp_tab == 0 then
        local cell, gap = 36, 5
        local gx, gy = px + 18, content_y
        for i = 1, 32 do
            local col, row = (i - 1) % 8, math.floor((i - 1) / 8)
            local cx = gx + col * (cell + gap)
            local cyy = gy + row * (cell + gap)
            local pc = palette[i]
            draw.rect(cx, cyy, cx + cell, cyy + cell, pc[1], pc[2], pc[3], pc[4])
            if cp_palette_idx == i - 1 then
                draw.rect_outline(cx - 2, cyy - 2, cx + cell + 2, cyy + cell + 2, c.accent[1], c.accent[2], c.accent[3], 255)
            end
            if mx >= cx and mx <= cx + cell and my >= cyy and my <= cyy + cell and input.mouse_clicked(0) then cp_palette_idx = i - 1 end
        end
        local pc = palette[cp_palette_idx + 1]
        if pc then
            local prev_y = gy + 4 * (cell + gap) + 14
            draw.rect(gx, prev_y, gx + 48, prev_y + 48, pc[1], pc[2], pc[3], pc[4])
            draw.rect_outline(gx, prev_y, gx + 48, prev_y + 48, c.accent[1], c.accent[2], c.accent[3], 120)
            gtxt(font.small, gx + 60, prev_y + 6, 200, string.format("RGB(%d, %d, %d)", pc[1], pc[2], pc[3]))
            gtxt(font.small, gx + 60, prev_y + 24, 140, string.format("#%02X%02X%02X", pc[1], pc[2], pc[3]))
        end
    else
        local sv_x, sv_y = px + 18, content_y
        local sv_w, sv_h = 200, 180
        local hue_x, hue_w = sv_x + sv_w + 14, 20
        local hr, hg, hb = util.hsv_to_rgb(cp_hue, 1, 1)
        draw.rect(sv_x, sv_y, sv_x + sv_w, sv_y + sv_h, hr, hg, hb, 255)
        draw.rect_gradient(sv_x, sv_y, sv_x + sv_w, sv_y + sv_h, 255,255,255,255, 255,255,255,0, 255,255,255,0, 255,255,255,255)
        draw.rect_gradient(sv_x, sv_y, sv_x + sv_w, sv_y + sv_h, 0,0,0,0, 0,0,0,0, 0,0,0,255, 0,0,0,255)
        draw.rect_outline(sv_x, sv_y, sv_x + sv_w, sv_y + sv_h, c.accent[1], c.accent[2], c.accent[3], 80)
        local scx = sv_x + cp_sat * sv_w
        local scy = sv_y + (1 - cp_val) * sv_h
        draw.circle_outline(scx, scy, 6, 255, 255, 255, 255, 2)
        for i = 0, 11 do
            local y1 = sv_y + (i / 12) * sv_h
            local y2 = sv_y + ((i + 1) / 12) * sv_h
            local r1, g1, b1 = util.hsv_to_rgb((i / 12) * 360, 1, 1)
            local r2, g2, b2 = util.hsv_to_rgb(((i + 1) / 12) * 360, 1, 1)
            draw.rect_gradient(hue_x, y1, hue_x + hue_w, y2, r1,g1,b1,255, r1,g1,b1,255, r2,g2,b2,255, r2,g2,b2,255)
        end
        draw.rect_outline(hue_x, sv_y, hue_x + hue_w, sv_y + sv_h, c.accent[1], c.accent[2], c.accent[3], 80)
        local hcy = sv_y + (cp_hue / 360) * sv_h
        draw.rect_outline(hue_x - 2, hcy - 3, hue_x + hue_w + 2, hcy + 3, 255, 255, 255, 255, 0, 2)
        local pr, pg, pb = util.hsv_to_rgb(cp_hue, cp_sat, cp_val)
        local prev_y = sv_y + sv_h + 14
        draw.rect(sv_x, prev_y, sv_x + 48, prev_y + 48, pr, pg, pb, 255)
        draw.rect_outline(sv_x, prev_y, sv_x + 48, prev_y + 48, c.accent[1], c.accent[2], c.accent[3], 120)
        gtxt(font.small, sv_x + 60, prev_y + 4, 200, string.format("RGB(%d, %d, %d)", pr, pg, pb))
        gtxt(font.small, sv_x + 60, prev_y + 20, 140, string.format("HSV(%.0f, %.0f%%, %.0f%%)", cp_hue, cp_sat*100, cp_val*100))
        gtxt(font.small, sv_x + 60, prev_y + 36, 140, string.format("#%02X%02X%02X", pr, pg, pb))
        if input.mouse_down(0) then
            if cp_dragging_sv or (mx >= sv_x and mx <= sv_x + sv_w and my >= sv_y and my <= sv_y + sv_h) then
                cp_dragging_sv = true
                cp_sat = clamp((mx - sv_x) / sv_w, 0, 1)
                cp_val = 1 - clamp((my - sv_y) / sv_h, 0, 1)
            end
            if cp_dragging_hue or (mx >= hue_x and mx <= hue_x + hue_w and my >= sv_y and my <= sv_y + sv_h) then
                cp_dragging_hue = true
                cp_hue = clamp((my - sv_y) / sv_h, 0, 1) * 360
            end
        else cp_dragging_sv = false; cp_dragging_hue = false end
    end
end

function handle_color_picker()
    local elapsed = ctx.time() - cp_open_time
    if input.key_just_pressed(VK.ESCAPE) or input.key_just_pressed(VK.BACK) then menu.set_popup_mode(0); return end
    if input.key_just_pressed(VK.RETURN) and elapsed > 0.15 then
        local sel = menu.selected_index()
        if cp_tab == 0 then
            local pc = palette[cp_palette_idx + 1]
            if pc then menu.set_item_color(sel, pc[1], pc[2], pc[3], pc[4]) end
        else
            local r, g, b = util.hsv_to_rgb(cp_hue, cp_sat, cp_val)
            menu.set_item_color(sel, r, g, b, 255)
        end
        menu.set_popup_mode(0); return
    end
    if input.key_just_pressed(VK.TAB) then cp_tab = 1 - cp_tab end
    if cp_tab == 0 then
        if input.key_just_pressed(VK.RIGHT) then cp_palette_idx = math.min(cp_palette_idx + 1, 31) end
        if input.key_just_pressed(VK.LEFT) then cp_palette_idx = math.max(cp_palette_idx - 1, 0) end
        if input.key_just_pressed(VK.DOWN) then cp_palette_idx = math.min(cp_palette_idx + 8, 31) end
        if input.key_just_pressed(VK.UP) then cp_palette_idx = math.max(cp_palette_idx - 8, 0) end
    else
        if input.key_pressed(VK.LEFT) then cp_sat = clamp(cp_sat - 0.02, 0, 1) end
        if input.key_pressed(VK.RIGHT) then cp_sat = clamp(cp_sat + 0.02, 0, 1) end
        if input.key_pressed(VK.UP) then cp_val = clamp(cp_val + 0.02, 0, 1) end
        if input.key_pressed(VK.DOWN) then cp_val = clamp(cp_val - 0.02, 0, 1) end
        if input.key_down(VK.SHIFT) then
            if input.key_pressed(VK.LEFT) then cp_hue = (cp_hue - 5) % 360 end
            if input.key_pressed(VK.RIGHT) then cp_hue = (cp_hue + 5) % 360 end
        end
    end
end

local orig_activate = menu.activate
menu.activate = function()
    local sel = menu.selected_index()
    local item = menu.get_item(sel)
    if item and item.type == item_type.color then
        menu.set_popup_mode(2)
        cp_tab, cp_palette_idx, cp_open_time = 0, 0, ctx.time()
        cp_hue, cp_sat, cp_val = util.rgb_to_hsv(item.r, item.g, item.b)
        return
    end
    orig_activate()
end

-------------------------------------------------------------------------------
-- Hot Anime Theme Pack renderer. The style token is replaced per package.
-------------------------------------------------------------------------------
local HOT_STYLE = "oni"   -- load-time default; reassigned from NATIVE_STYLE below
local HOT_CONFIG = {
    oni = {folder="AKAI ONI", title="AKAI ONI", file="akai_oni_theme.ini",
        accent={198,36,46,255}, secondary={212,170,86,255}, bg={12,5,7,247}, layout="split"},
    vice = {folder="NEON VICE", title="NEON VICE", file="neon_vice_theme.ini",
        accent={224,42,244,255}, secondary={40,214,255,255}, bg={6,5,22,244}, layout="cards"},
    apex = {folder="MIDNIGHT APEX", title="MIDNIGHT APEX", file="midnight_apex_theme.ini",
        accent={255,116,24,255}, secondary={91,196,255,255}, bg={5,8,14,242}, layout="hud"},
}
local hot = HOT_CONFIG[HOT_STYLE] or HOT_CONFIG.oni

local HOT_DEFS = {
    {name="Animation",kind="tog",default=true,desc="Animate the character artwork and atmosphere"},
    {name="Animation Speed",kind="num",default=1.0,min=0.25,max=2.0,step=0.05,desc="Speed of theme particles and transitions"},
    {name="Art Opacity",kind="num",default=0.92,min=0.15,max=1.0,step=0.05,desc="Visibility of the character illustration"},
    {name="UI Scale",kind="num",default=1.0,min=0.75,max=1.20,step=0.05,desc="Scale the complete theme"},
    {name="Reduced Motion",kind="tog",default=false,desc="Use still artwork and disable rapid effects"},
}
local hot_last_signature=""
local hot_save_pending=false
local hot_save_at=0
local hot_home=nil
local hot_module_index=0
local hot_focus=1
local hot_scroll,hot_scroll_target=0,0
local hot_last_page=""
local hot_last_selected=-1
local hot_nav_at=-10
local hot_last_scale=-1
local hot_drag=-1
local hot_drag_x,hot_drag_w=0,1

local function hot_num(name,default)
    local s=menu.get_setting(name); return s and s.f_val or default
end
local function hot_toggle(name,default)
    local s=menu.get_setting(name); if s and s.on~=nil then return s.on end; return default
end
local function hot_accent()
    local s=menu.get_setting("Accent Color")
    return s and {s.r,s.g,s.b,s.a} or hot.accent
end
local function hot_register()
    menu.clear_settings()
    menu.add_setting_submenu("Artwork","Character artwork and animation")
    menu.add_sub_toggle("Animation",true,"Animate the character artwork and atmosphere")
    menu.add_sub_slider("Animation Speed",1.0,0.25,2.0,0.05,"Speed of particles and transitions")
    menu.add_sub_slider("Art Opacity",0.92,0.15,1.0,0.05,"Visibility of the character illustration")
    menu.add_setting_submenu("Interface","Scale, color and accessibility")
    menu.add_sub_slider("UI Scale",1.0,0.75,1.20,0.05,"Scale the complete theme")
    menu.add_sub_color("Accent Color",hot.accent[1],hot.accent[2],hot.accent[3],hot.accent[4],"Primary theme accent")
    menu.add_sub_toggle("Reduced Motion",false,"Use still artwork and disable rapid effects")
    menu.add_setting_action("Reset Theme","Restore this theme to its defaults")
end
local function hot_serialize()
    local a=hot_accent()
    return table.concat({"version=1","Animation="..(hot_toggle("Animation",true) and "1" or "0"),
        "Animation Speed="..hot_num("Animation Speed",1),"Art Opacity="..hot_num("Art Opacity",0.92),
        "UI Scale="..hot_num("UI Scale",1),"Reduced Motion="..(hot_toggle("Reduced Motion",false) and "1" or "0"),
        "Accent Color="..a[1]..","..a[2]..","..a[3]..","..a[4]},"\n")
end
local function hot_load()
    local data=file.read(hot.file); if not data or not data:match("^version=1") then return end
    for line in data:gmatch("[^\r\n]+") do
        local k,v=line:match("^(.-)=(.*)$")
        if k=="Animation" or k=="Reduced Motion" then menu.set_setting(k,v=="1")
        elseif k=="Animation Speed" or k=="Art Opacity" or k=="UI Scale" then local n=tonumber(v); if n then menu.set_setting(k,n) end
        elseif k=="Accent Color" then local r,g,b,a=v:match("(%d+),(%d+),(%d+),(%d+)"); if r then menu.set_setting(k,tonumber(r),tonumber(g),tonumber(b),tonumber(a)) end end
    end
end
local function hot_reset()
    menu.set_setting("Animation",true); menu.set_setting("Animation Speed",1.0)
    menu.set_setting("Art Opacity",0.92); menu.set_setting("UI Scale",1.0)
    menu.set_setting("Accent Color",hot.accent[1],hot.accent[2],hot.accent[3],hot.accent[4])
    menu.set_setting("Reduced Motion",false); file.remove(hot.file)
    hot_last_signature=hot_serialize(); hot_save_pending=false
end
local function hot_fonts(scale)
    if math.abs(scale-hot_last_scale)<0.001 then return end
    text.set_font_family("Bahnschrift")
    text.set_size(font.title,math.floor(24*scale+.5)); text.set_weight(font.title,800)
    text.set_size(font.item,math.floor(14*scale+.5)); text.set_weight(font.item,600)
    text.set_size(font.value,math.floor(12*scale+.5)); text.set_weight(font.value,600)
    text.set_size(font.breadcrumb,math.floor(12*scale+.5)); text.set_weight(font.breadcrumb,700)
    text.set_size(font.desc,math.floor(11*scale+.5)); text.set_weight(font.desc,400)
    text.set_size(font.label,math.floor(10*scale+.5)); text.set_weight(font.label,700)
    text.set_size(font.small,math.floor(10*scale+.5)); text.set_weight(font.small,500)
    text.set_size(font.tiny,math.floor(9*scale+.5)); text.set_weight(font.tiny,600)
    text.set_size(font.tagline,math.floor(11*scale+.5)); text.set_weight(font.tagline,600)
    hot_last_scale=scale
end
local function hot_hit(x1,y1,x2,y2)
    local mx,my=input.mouse_x(),input.mouse_y(); return mx>=x1 and mx<=x2 and my>=y1 and my<=y2
end
local function hot_handles()
    if not hot_home or #hot_home==0 then hot_home=items.page_items("Home") or {} end; return hot_home
end
local function hot_activate()
    local it=menu.get_item(menu.selected_index())
    if it and it.type==item_type.action and it.name=="Reset Theme" then hot_reset(); notify.push(hot.title,"Theme settings restored",1); return end
    menu.activate()
end
local function hot_open_module(index)
    local hs=hot_handles(); if #hs==0 then return end
    hot_module_index=math.max(0,math.min(index,#hs-1)); hot_focus=1; hot_nav_at=ctx.time(); items.activate(hs[hot_module_index+1])
end
local function hot_effects(x,y,w,h,t,a,secondary,reduced)
    if reduced then return end
    if HOT_STYLE=="oni" then
        for i=1,22 do
            local px=x+((i*83+t*(8+i%4))%w); local py=y+h-((i*47+t*(15+i%3))%(h+40))
            local r=1+i%3; draw.circle(px,py,r,255,75+i%3*28,30,80+i%5*25)
        end
    elseif HOT_STYLE=="vice" then
        local sx=x-120+((t*65)%(w+240))
        draw.rect_gradient(sx-70,y,sx,y+h,a[1],a[2],a[3],0,a[1],a[2],a[3],24,secondary[1],secondary[2],secondary[3],24,secondary[1],secondary[2],secondary[3],0)
        draw.rect_gradient(sx,y,sx+70,y+h,secondary[1],secondary[2],secondary[3],24,secondary[1],secondary[2],secondary[3],0,a[1],a[2],a[3],0,a[1],a[2],a[3],24)
        for i=1,14 do local px=x+((i*109+t*(4+i%3))%w); local py=y+((i*61)%h)+math.sin(t+i)*8; draw.rect_outline(px-2,py-2,px+2,py+2,i%2==0 and secondary[1] or a[1],i%2==0 and secondary[2] or a[2],i%2==0 and secondary[3] or a[3],90,1,1) end
    else
        for i=1,14 do local py=y+35+i*29; local px=x-180+((t*(120+i*4)+i*131)%(w+360)); draw.line(px,py,px+80+i%4*32,py,i%3==0 and secondary[1] or a[1],i%3==0 and secondary[2] or a[2],i%3==0 and secondary[3] or a[3],65+i%4*18,1+i%2) end
    end
end
local function hot_header(x,y,w,h,a,secondary,scale)
    draw.rect(x,y,x+w,y+h,hot.bg[1],hot.bg[2],hot.bg[3],245,4)
    draw.line(x,y+h-1,x+w,y+h-1,a[1],a[2],a[3],190,2)
    text.draw(font.title,x+18*scale,y+(h-text.height(font.title))*.5,255,255,255,250,hot.title)
    local sub=HOT_STYLE=="oni" and "CRIMSON COVENANT" or (HOT_STYLE=="vice" and "NIGHTLIFE SYSTEM" or "STREET PERFORMANCE")
    text.draw(font.tiny,x+w-18*scale-text.width(font.tiny,sub),y+(h-text.height(font.tiny))*.5,secondary[1],secondary[2],secondary[3],205,sub)
end
local function hot_tabs(x,y,w,h,a,secondary,scale,bottom)
    local hs=hot_handles(); local count=#hs; if count==0 then return end
    local cell=w/count; local current=menu.page_name() or ""
    for i,handle in ipairs(hs) do
        local name=items.name(handle) or "?"; local left=x+(i-1)*cell; local active=current==name or (menu.page_parent() or "")==name
        local focus=hot_focus==0 and hot_module_index==i-1; local hover=hot_hit(left,y,left+cell,y+h)
        if active or focus or hover then draw.rect(left,y,left+cell,y+h,a[1],a[2],a[3],active and 42 or 20,2) end
        if active then draw.rect(left,bottom and y or y+h-2,left+cell,bottom and y+2 or y+h,a[1],a[2],a[3],235) end
        text.draw_ellipsis(font.tiny,left+7*scale,y+(h-text.height(font.tiny))*.5,focus and secondary[1] or 220,focus and secondary[2] or 220,focus and secondary[3] or 220,active and 255 or 185,string.upper(name),cell-14*scale)
        if hover and input.mouse_clicked(0) and menu.popup_mode()==0 then hot_open_module(i-1) end
    end
end
local function hot_widget_click(item,index,x,y,w,h)
    if not input.mouse_clicked(0) or menu.popup_mode()~=0 then return end
    menu.set_selected(index); hot_focus=1
    if item.type==item_type.slider then
        local value_w=text.width(font.value,string.format("%.1f",item.f_val)); local right=x+w-12-value_w-10; local left=right-BAR_W
        if input.mouse_x()>=left and input.mouse_x()<=right then hot_drag=index; hot_drag_x=left; hot_drag_w=BAR_W; return end
    end
    if index==hot_last_selected then hot_activate() end
end
local function hot_rows(x,y,w,h,scale,cards)
    local count=menu.item_count(); local selected=menu.selected_index(); local row_h=(cards and 52 or 36)*scale
    if hot_drag>=0 then
        local dragged=menu.get_item(hot_drag)
        if dragged and input.mouse_down(0) then
            local pct=clamp((input.mouse_x()-hot_drag_x)/hot_drag_w,0,1)
            local raw=dragged.f_min+pct*(dragged.f_max-dragged.f_min)
            if dragged.f_step and dragged.f_step>0 then raw=dragged.f_min+math.floor((raw-dragged.f_min)/dragged.f_step+.5)*dragged.f_step end
            menu.set_f_val(hot_drag,clamp(raw,dragged.f_min,dragged.f_max))
        else hot_drag=-1 end
    end
    local cols=cards and 2 or 1; local gap=cards and 8*scale or 0; local col_w=(w-gap*(cols-1))/cols
    local selected_row=math.floor(selected/cols); local visible=math.max(1,math.floor(h/row_h)); local start=math.max(0,selected_row-visible+1)
    if selected_row<start then start=selected_row end
    draw.push_clip(x,y,x+w,y+h)
    for i=0,count-1 do
        local grid_row=math.floor(i/cols)-start; local col=i%cols; local iy=y+grid_row*row_h; local ix=x+col*(col_w+gap)
        if iy+row_h>=y and iy<=y+h then
            local it=menu.get_item(i)
            if it then
                local active=i==selected; local hover=hot_hit(ix,iy,ix+col_w,iy+row_h)
                if cards then draw.rect(ix+2,iy+3,ix+col_w-2,iy+row_h-3,hot.bg[1]+4,hot.bg[2]+4,hot.bg[3]+8,218,5); draw.rect_outline(ix+2,iy+3,ix+col_w-2,iy+row_h-3,c.accent[1],c.accent[2],c.accent[3],active and 210 or 45,5,1)
                elseif active then draw.rect_gradient(ix,iy,ix+col_w,iy+row_h,c.accent[1],c.accent[2],c.accent[3],55,c.accent[1],c.accent[2],c.accent[3],8,c.accent[1],c.accent[2],c.accent[3],8,c.accent[1],c.accent[2],c.accent[3],55); draw.rect(ix,iy,ix+4,iy+row_h,c.accent[1],c.accent[2],c.accent[3],255) end
                if it.is_header then text.draw(font.tiny,ix+12,iy+(row_h-text.height(font.tiny))*.5,c.ice[1],c.ice[2],c.ice[3],190,string.upper(it.name or "SECTION"))
                else
                    local tc=active and {255,255,255} or {205,200,207}; text.draw_ellipsis(font.item,ix+13,iy+(row_h-text.height(font.item))*.5,tc[1],tc[2],tc[3],active and 255 or 205,it.name or "",col_w-145*scale)
                    draw_widget(ix+col_w-13,iy+row_h*.5,it,active)
                    if hover then hot_widget_click(it,i,ix,iy,col_w,row_h) end
                    if active then frame.popup_item_y=iy+row_h; menu.set_popup_item_y(iy+row_h) end
                end
            end
        end
    end
    draw.pop_clip()
    hot_last_selected=selected
end
local function hot_description(x,y,w,h,scale,secondary)
    local it=menu.get_item(menu.selected_index()); local d=it and it.desc and it.desc~="" and it.desc or "Select an option to continue"
    draw.rect(x,y,x+w,y+h,hot.bg[1],hot.bg[2],hot.bg[3],238,3); draw.line(x,y,x+w,y,secondary[1],secondary[2],secondary[3],100,1)
    text.draw_ellipsis(font.desc,x+14*scale,y+(h-text.height(font.desc))*.5,210,210,216,210,d,w-28*scale)
end
local function hot_draw_tach(x,y,r,t,a,secondary)
    draw.circle_outline(x,y,r,secondary[1],secondary[2],secondary[3],90,2)
    for i=0,10 do local ang=math.pi*.75+i*math.pi*1.5/10; draw.line(x+math.cos(ang)*(r-7),y+math.sin(ang)*(r-7),x+math.cos(ang)*r,y+math.sin(ang)*r,a[1],a[2],a[3],150,1) end
    local needle=math.pi*.75+(math.sin(t*1.2)*.5+.5)*math.pi*1.5; draw.line(x,y,x+math.cos(needle)*(r-12),y+math.sin(needle)*(r-12),a[1],a[2],a[3],230,2)
end



hot_register(); hot_load(); hot_last_signature=hot_serialize()

-------------------------------------------------------------------------------
-- Rockstar/GTA-native animated pack renderer.
-------------------------------------------------------------------------------
local NATIVE_STYLE="heist"
local NATIVE_CONFIG={
    classic={folder="LS FREEMODE",title="LOS SANTOS",file="ls_freemode_theme.ini",accent={42,116,190,255},secondary={255,150,48,255},bg={5,8,12,245}},
    heist={folder="HEIST CONTROL",title="HEIST CONTROL",file="heist_control_theme.ini",accent={46,174,126,255},secondary={99,211,255,255},bg={5,14,13,245}},
    arena={folder="ARENA LIVE",title="ARENA LIVE",file="arena_live_theme.ini",accent={224,48,52,255},secondary={255,184,55,255},bg={12,6,7,245}},
}
local native=NATIVE_CONFIG[NATIVE_STYLE] or NATIVE_CONFIG.classic
hot=native
HOT_STYLE=NATIVE_STYLE
local native_last_sig,native_pending,native_save_at="",false,0
local native_focus=1
local native_module_index=0

local function native_register()
    menu.clear_settings()
    menu.add_setting_submenu("Animation","Native menu motion")
    menu.add_sub_toggle("Animation",true,"Animate banners, telemetry and selection effects")
    menu.add_sub_slider("Animation Speed",1.0,0.25,2.0,0.05,"Speed of native UI effects")
    menu.add_setting_submenu("Interface","Scale, opacity and color")
    menu.add_sub_slider("Panel Opacity",0.92,0.35,1.0,0.05,"Opacity of menu panels")
    menu.add_sub_slider("UI Scale",1.0,0.75,1.20,0.05,"Scale the complete interface")
    menu.add_sub_color("Accent Color",native.accent[1],native.accent[2],native.accent[3],255,"Primary native accent")
    menu.add_sub_toggle("Reduced Motion",false,"Disable sweeps, pulses and rapid telemetry")
    menu.add_setting_action("Reset Theme","Restore this native theme")
end
local function native_sig()
    local a=hot_accent()
    return table.concat({"version=1","Animation="..(hot_toggle("Animation",true) and "1" or "0"),"Animation Speed="..hot_num("Animation Speed",1),"Panel Opacity="..hot_num("Panel Opacity",.92),"UI Scale="..hot_num("UI Scale",1),"Reduced Motion="..(hot_toggle("Reduced Motion",false) and "1" or "0"),"Accent Color="..a[1]..","..a[2]..","..a[3]..","..a[4]},"\n")
end
local function native_load()
    local data=file.read(native.file); if not data or not data:match("^version=1") then return end
    for line in data:gmatch("[^\r\n]+") do local k,v=line:match("^(.-)=(.*)$"); if k=="Animation" or k=="Reduced Motion" then menu.set_setting(k,v=="1") elseif k=="Animation Speed" or k=="Panel Opacity" or k=="UI Scale" then local n=tonumber(v); if n then menu.set_setting(k,n) end elseif k=="Accent Color" then local r,g,b,a=v:match("(%d+),(%d+),(%d+),(%d+)"); if r then menu.set_setting(k,tonumber(r),tonumber(g),tonumber(b),tonumber(a)) end end end
end
local function native_reset()
    menu.set_setting("Animation",true); menu.set_setting("Animation Speed",1); menu.set_setting("Panel Opacity",.92); menu.set_setting("UI Scale",1); menu.set_setting("Accent Color",native.accent[1],native.accent[2],native.accent[3],255); menu.set_setting("Reduced Motion",false); file.remove(native.file); native_last_sig=native_sig(); native_pending=false
end
local function native_activate()
    local it=menu.get_item(menu.selected_index()); if it and it.type==item_type.action and it.name=="Reset Theme" then native_reset(); notify.push(native.title,"Theme settings restored",1) else menu.activate() end
end
local function native_gradient(x,y,w,h,a,s,t,reduced)
    local pulse=reduced and .5 or (math.sin(t*.8)*.5+.5)
    draw.rect_gradient(x,y,x+w,y+h,a[1],a[2],a[3],235,s[1],s[2],s[3],190,s[1],s[2],s[3],190,a[1],a[2],a[3],235)
    if not reduced then local sx=x-90+((t*70)%(w+180)); draw.rect_gradient(sx-55,y,sx,y+h,255,255,255,0,255,255,255,math.floor(34+20*pulse),255,255,255,math.floor(34+20*pulse),255,255,255,0); draw.rect_gradient(sx,y,sx+55,y+h,255,255,255,math.floor(34+20*pulse),255,255,255,0,255,255,255,0,255,255,255,math.floor(34+20*pulse)) end
end
local function native_route_grid(x,y,w,h,t,a,s,reduced)
    for gx=x,x+w,28 do draw.line(gx,y,gx,y+h,s[1],s[2],s[3],24,1) end; for gy=y,y+h,28 do draw.line(x,gy,x+w,gy,s[1],s[2],s[3],24,1) end
    local lastx,lasty=x+18,y+h*.72
    for i=1,10 do local px=x+18+i*(w-36)/10; local py=y+h*.5+math.sin(i*1.7+(reduced and 0 or t*.65))*h*.22; draw.line(lastx,lasty,px,py,a[1],a[2],a[3],120,2); draw.circle(px,py,3,s[1],s[2],s[3],180); lastx,lasty=px,py end
end
local function native_telemetry(x,y,w,h,t,a,s,reduced)
    for i=0,38 do local p=i/38; local px=x+p*w; local py=y+h*.5+math.sin(p*math.pi*8+(reduced and 0 or t*2.4))*h*.28; if i>0 then draw.line(lastx,lasty,px,py,s[1],s[2],s[3],170,1.2) end; lastx,lasty=px,py end
    for i=1,8 do local bh=(math.sin(i*1.2+(reduced and 0 or t*1.5))*.5+.5)*(h*.65); draw.rect(x+w-80+i*8,y+h-5-bh,x+w-76+i*8,y+h-5,a[1],a[2],a[3],120+i*10) end
end
local function native_module_rail(x,y,w,h,a,s,scale)
    local hs=hot_handles(); local rh=34*scale; local py=y+8*scale; local current=menu.page_name() or ""; local parent=menu.page_parent() or ""
    for i,handle in ipairs(hs) do local name=items.name(handle) or "?"; local active=current==name or parent==name; local focus=native_focus==0 and native_module_index==i-1; local hover=hot_hit(x,py,x+w,py+rh); if active or focus or hover then draw.rect(x,py,x+w,py+rh,a[1],a[2],a[3],active and 48 or 22) end; if active or focus then draw.rect(x,py,x+3,py+rh,focus and s[1] or a[1],focus and s[2] or a[2],focus and s[3] or a[3],240) end; text.draw_ellipsis(font.item,x+12*scale,py+(rh-text.height(font.item))*.5,active and 255 or 180,active and 255 or 190,active and 255 or 184,active and 255 or 210,string.upper(name),w-24*scale); if hover and input.mouse_clicked(0) and menu.popup_mode()==0 then native_module_index=i-1; native_focus=1; items.activate(handle) end; py=py+rh; if py+rh>y+h then break end end
end
local function native_footer(x,y,w,h,a,s,scale,label)
    draw.rect(x,y,x+w,y+h,0,0,0,218,2); draw.line(x,y,x+w,y,a[1],a[2],a[3],140,1); text.draw(font.tiny,x+12*scale,y+(h-text.height(font.tiny))*.5,205,205,205,170,label); local count=menu.item_count(); local counter=string.format("%d / %d",math.min(menu.selected_index()+1,count),count); text.draw(font.tiny,x+w-12*scale-text.width(font.tiny,counter),y+(h-text.height(font.tiny))*.5,s[1],s[2],s[3],190,counter)
end

function draw_menu()
    if not menu.is_visible() then return end
    local now=ctx.time(); local scale=hot_num("UI Scale",1); hot_fonts(scale); local reduced=hot_toggle("Reduced Motion",false) or not hot_toggle("Animation",true); local speed=hot_num("Animation Speed",1); local t=now*speed; local opacity=math.floor(hot_num("Panel Opacity",.92)*255); local a=hot_accent(); local s=native.secondary
    c={accent=a,accentD={math.floor(a[1]*.48),math.floor(a[2]*.48),math.floor(a[3]*.48),255},bg={native.bg[1],native.bg[2],native.bg[3],opacity},amber=a,red={235,70,70,255},ice=s}; hot.bg=c.bg
    theme.set_body_bg(5,7,10,230); theme.set_menu_bg(c.bg[1],c.bg[2],c.bg[3],opacity); theme.set_accent_palette(a[1],a[2],a[3],255)
    local page=menu.page_name() or "Home"; if page~=hot_last_page then hot_last_page=page; hot_last_selected=-1; if page=="Home" and NATIVE_STYLE~="classic" then native_focus=0 else native_focus=1 end end
    if NATIVE_STYLE=="classic" then
        local w,h=430*scale,650*scale; local x=(ctx.screen_w()-w)*.5; local y=math.max(16,(ctx.screen_h()-h)*.5); local banner=104*scale; local sub=34*scale; local foot=32*scale; local desc=48*scale; local dx,dy=menu.drag_header(x,y,w,banner); x=x+dx; y=y+dy
        draw.rect(x,y,x+w,y+h,c.bg[1],c.bg[2],c.bg[3],opacity,2); native_gradient(x,y,w,banner,a,s,t,reduced); text.draw_centered(font.title,x,y+(banner-text.height(font.title))*.42,x+w,255,255,255,255,"LOS SANTOS"); text.draw_centered(font.tiny,x,y+banner*.68,x+w,255,255,255,185,"FREEMODE INTERACTION")
        local sy=y+banner; draw.rect(x,sy,x+w,sy+sub,8,8,10,245); text.draw(font.breadcrumb,x+14*scale,sy+(sub-text.height(font.breadcrumb))*.5,235,235,235,240,string.upper(page)); local rows_y=sy+sub; local rows_h=h-banner-sub-foot-desc; frame.menu_x=x; l.menu_w=w; menu.set_content_rect(x,rows_y,w,rows_h); hot_rows(x,rows_y,w,rows_h,scale,false); hot_description(x,y+h-foot-desc,w,desc,scale,s); native_footer(x,y+h-foot,w,foot,a,s,scale,"ENTER SELECT   BACK RETURN   H HOTKEY")
    elseif NATIVE_STYLE=="heist" then
        local w,h=860*scale,560*scale; local x=(ctx.screen_w()-w)*.5; local y=math.max(16,(ctx.screen_h()-h)*.5); local head=58*scale; local rail=190*scale; local foot=32*scale; local dx,dy=menu.drag_header(x,y,w,head); x=x+dx; y=y+dy
        draw.rect(x,y,x+w,y+h,c.bg[1],c.bg[2],c.bg[3],opacity,3); native_gradient(x,y,w,head,a,s,t,reduced); text.draw(font.title,x+18*scale,y+(head-text.height(font.title))*.5,255,255,255,255,"HEIST CONTROL"); text.draw(font.tiny,x+w-155*scale,y+(head-text.height(font.tiny))*.5,230,255,245,200,"PLANNING NETWORK ONLINE")
        native_module_rail(x,y+head,rail,h-head-foot,a,s,scale); local px=x+rail; local pw=w-rail; local body_y=y+head; local body_h=h-head-foot; native_route_grid(px,body_y,pw,body_h,t,a,s,reduced); draw.rect(px,body_y,px+pw,body_y+body_h,c.bg[1],c.bg[2],c.bg[3],190)
        frame.menu_x=px; l.menu_w=pw; menu.set_content_rect(px,body_y,pw,body_h); if page=="Home" then text.draw_centered(font.title,px+30,body_y+body_h*.38,px+pw-30,255,255,255,230,"SELECT AN OPERATION"); text.draw_centered(font.small,px+30,body_y+body_h*.51,px+pw-30,s[1],s[2],s[3],190,"TAB SWITCHES BETWEEN NETWORK AND PLAN") else hot_rows(px+12*scale,body_y+12*scale,pw-24*scale,body_h-24*scale,scale,true) end; native_footer(x,y+h-foot,w,foot,a,s,scale,"TAB FOCUS   ENTER CONFIRM   ESC BACK")
    else
        local w,h=900*scale,540*scale; local x=(ctx.screen_w()-w)*.5; local y=math.max(16,(ctx.screen_h()-h)*.5); local head=62*scale; local tabs=38*scale; local foot=34*scale; local side=210*scale; local dx,dy=menu.drag_header(x,y,w,head); x=x+dx; y=y+dy
        draw.rect(x,y,x+w,y+h,c.bg[1],c.bg[2],c.bg[3],opacity,4); native_gradient(x,y,w,head,a,s,t,reduced); text.draw(font.title,x+18*scale,y+(head-text.height(font.title))*.5,255,255,255,255,"ARENA LIVE"); text.draw(font.tiny,x+w-145*scale,y+(head-text.height(font.tiny))*.5,255,235,190,200,"BROADCAST // LIVE")
        hot_tabs(x,y+head,w,tabs,a,s,scale,false); local body_y=y+head+tabs; local body_h=h-head-tabs-foot; draw.rect(x,body_y,x+side,body_y+body_h,5,5,7,220); native_telemetry(x+12*scale,body_y+18*scale,side-24*scale,80*scale,t,a,s,reduced); hot_draw_tach(x+side*.5,body_y+175*scale,62*scale,t,a,s); text.draw_centered(font.tiny,x+10,body_y+250*scale,x+side-10,s[1],s[2],s[3],180,"ARENA TELEMETRY")
        local px=x+side; local pw=w-side; frame.menu_x=px; l.menu_w=pw; menu.set_content_rect(px,body_y,pw,body_h); draw.rect(px,body_y,px+pw,body_y+body_h,c.bg[1],c.bg[2],c.bg[3],220); if page=="Home" then text.draw_centered(font.title,px+20,body_y+body_h*.4,px+pw-20,255,255,255,230,"CHOOSE A CATEGORY"); text.draw_centered(font.small,px+20,body_y+body_h*.54,px+pw-20,s[1],s[2],s[3],180,"LIVE EVENT SYSTEM READY") else hot_rows(px+8*scale,body_y+8*scale,pw-16*scale,body_h-16*scale,scale,false) end; native_footer(x,y+h-foot,w,foot,a,s,scale,"TAB MODULES   ENTER SELECT   H BIND")
    end
    local pm=menu.popup_mode(); if pm==1 then draw_input_popup() elseif pm==2 then draw_color_picker() elseif pm==3 then draw_array_dropdown_popup() elseif pm==4 then draw_hotkey_popup() end
    local sig=native_sig(); if sig~=native_last_sig then native_last_sig=sig; native_pending=true; native_save_at=now end; if native_pending and now-native_save_at>.4 then file.write(native.file,native_last_sig); native_pending=false end
end

function handle_input()
    if not menu.is_visible() then return end
    local pm=menu.popup_mode(); if pm==1 then handle_input_popup(); return elseif pm==2 then handle_color_picker(); return elseif pm==3 then handle_array_dropdown(); return elseif pm==4 then handle_hotkey_bind(); return end
    local hs=hot_handles(); if NATIVE_STYLE~="classic" and input.key_just_pressed(VK.TAB) then native_focus=1-native_focus; return end
    if NATIVE_STYLE~="classic" and native_focus==0 then local vertical=NATIVE_STYLE=="heist"; if input.key_pressed(vertical and VK.UP or VK.LEFT) and #hs>0 then native_module_index=(native_module_index-1)%#hs end; if input.key_pressed(vertical and VK.DOWN or VK.RIGHT) and #hs>0 then native_module_index=(native_module_index+1)%#hs end; if input.key_just_pressed(VK.RETURN) then local handle=hs[native_module_index+1]; if handle then native_focus=1; items.activate(handle) end end; if input.key_just_pressed(VK.BACK) or input.key_just_pressed(VK.ESCAPE) then menu.go_back() end; return end
    if input.key_pressed(VK.UP) then menu.move_selection(-1) end; if input.key_pressed(VK.DOWN) then menu.move_selection(1) end; if input.key_just_pressed(VK.RETURN) then native_activate() end; if input.key_just_pressed(VK.BACK) or input.key_just_pressed(VK.ESCAPE) then menu.go_back() end
    local idx=menu.selected_index(); local it=menu.get_item(idx); if not it then return end; local typ=it.type
    if input.key_just_pressed(VK.SPACE) and (typ==item_type.input_text or typ==item_type.search or typ==item_type.input_int or typ==item_type.input_float or typ==item_type.slider or typ==item_type.int_option or typ==item_type.float_toggle or typ==item_type.int_toggle) then menu.open_input_popup() end; if input.key_just_pressed(0x48) and typ~=item_type.sub_menu then menu.set_popup_mode(4) end; if input.key_just_pressed(VK.DELETE) and it.hotkey and it.hotkey~=0 then menu.set_hotkey(idx,0); notify.push(it.name,str.cleared or "cleared",0); menu.save_hotkeys(); menu.rebuild_features() end
    if input.key_pressed(VK.LEFT) or input.key_pressed(VK.RIGHT) then local dir=input.key_pressed(VK.RIGHT) and 1 or -1; if typ==item_type.slider or typ==item_type.float_toggle then local step=it.f_step~=0 and it.f_step or .1; menu.set_f_val(idx,clamp(it.f_val+step*dir,it.f_min,it.f_max)) elseif typ==item_type.int_option or typ==item_type.int_toggle then local step=it.i_step~=0 and it.i_step or 1; menu.set_i_val(idx,clamp(it.i_val+step*dir,it.i_min,it.i_max)) elseif typ==item_type.loop_option or typ==item_type.loop_toggle then local vi=it.value_index+dir; if vi>=it.value_count then vi=0 elseif vi<0 then vi=it.value_count-1 end; menu.set_value_index(idx,vi) elseif typ==item_type.array_option or typ==item_type.array_toggle then menu.open_array_popup() end end
end

native_register(); native_load(); native_last_sig=native_sig()
