-- Nenyoo "Linear" Theme — clean, minimal, flat
-- A refreshed take: flat near-black card, hairline dividers, a soft accent
-- fill + a thin rounded accent bar on the selected row. No gradient banners,
-- no decorative noise. Built entirely on THEME_API.md.

---------------------------------------------------------------------------
-- Fonts — tuned for a compact, crisp panel
---------------------------------------------------------------------------
text.set_size(font.title, 21);  text.set_weight(font.title, 700)
text.set_size(font.item, 13);   text.set_weight(font.item, 500)
text.set_size(font.value, 12);  text.set_weight(font.value, 600)

---------------------------------------------------------------------------
-- Settings (live-editable under Settings > Theme)
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

local function reload_colors()
    return {
        accent  = sc("Accent")      or {168, 85, 247, 255},
        accentL = sc("Accent Light")or {192, 132, 252, 255},
        bg      = sc("Background")   or {12, 12, 16, 255},
        surface = sc("Surface")      or {22, 22, 28, 255},
    }
end
local function reload_layout()
    return {
        menu_w  = sf("Menu Width", 380),
        item_h  = sf("Row Height", 46),
        header_h= 52,
        footer_h= 34,
        list_max= 460,
        pad_x   = 16,
    }
end

menu.clear_settings()
menu.add_setting_submenu("Colors", "Accent and surface colors")
menu.add_sub_color("Accent", 168, 85, 247, 255, "Active highlight")
menu.add_sub_color("Accent Light", 192, 132, 252, 255, "Highlight tint")
menu.add_sub_color("Background", 12, 12, 16, 255, "Panel background")
menu.add_sub_color("Surface", 22, 22, 28, 255, "Hover / control surface")
menu.add_setting_submenu("Layout", "Sizes and spacing")
menu.add_sub_slider("Menu Width", 380, 280, 640, 10, "Panel width (px)")
menu.add_sub_slider("Row Height", 46, 32, 72, 1, "Option row height (px)")

local c = reload_colors()
local l = reload_layout()

---------------------------------------------------------------------------
-- Helpers / state
---------------------------------------------------------------------------
local function lerp(a, b, t) return a + (b - a) * t end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function ease_out(t) t = clamp(t, 0, 1); return 1 - (1 - t)^3 end

local TOGGLE_W, TOGGLE_H = 34, 18
local SLIDER_W = 116
local GAP = 12

local scroll, scroll_target = 0, 0
local nav_time, last_page = 0, ""
local last_sel = -1
local sel_anim = 0            -- animated selection Y (for the accent bar)
local toggle_anim = {}
local dragging_slider = -1
local drag_x, drag_w = 0, 0
local frame = { menu_x = 0, list_y = 0, popup_item_y = 0 }

-- scrollbar
local sb_last = 0
local dragging_sb = false
local sb_grab = 0

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------
local function draw_toggle(rx, yc, item, idx)
    local anim = toggle_anim[idx] or (item.on and 1 or 0)
    anim = lerp(anim, item.on and 1 or 0, clamp(ctx.delta() * 14, 0, 1))
    toggle_anim[idx] = anim

    local tx, ty = rx - TOGGLE_W, yc - TOGGLE_H / 2
    local tr = lerp(255, c.accent[1],  anim)
    local tg = lerp(255, c.accent[2],  anim)
    local tb = lerp(255, c.accent[3],  anim)
    local ta = lerp(22, 255, anim)
    draw.rect(tx, ty, tx + TOGGLE_W, ty + TOGGLE_H,
        math.floor(tr), math.floor(tg), math.floor(tb), math.floor(ta), 9)

    local kr = TOGGLE_H / 2 - 3
    local kcx = tx + TOGGLE_H / 2 + (TOGGLE_W - TOGGLE_H) * anim
    local kc = math.floor(lerp(150, 255, anim))
    draw.circle(kcx, yc, kr, kc, kc, math.floor(lerp(160, 255, anim)), 255)
end

local function draw_slider(rx, yc, item, is_sel)
    local tw = SLIDER_W
    local sx = rx - tw
    local sy = yc - 2
    local frac = 0
    if item.f_max > item.f_min then
        frac = clamp((item.f_val - item.f_min) / (item.f_max - item.f_min), 0, 1)
    end
    -- track
    draw.rect(sx, sy, sx + tw, sy + 4, 255, 255, 255, is_sel and 26 or 12, 2)
    -- fill
    local fw = tw * frac
    if fw > 0 then
        draw.rect(sx, sy, sx + fw, sy + 4, c.accent[1], c.accent[2], c.accent[3], is_sel and 255 or 170, 2)
    end
    -- knob
    if is_sel then
        draw.circle(sx + fw, yc, 5, 255, 255, 255, 255)
    end
    -- value (left of track)
    local vs = string.format("%.1f", item.f_val)
    local vw = text.width(font.value, vs)
    text.draw(font.value, sx - 10 - vw, yc - text.height(font.value) / 2,
        255, 255, 255, is_sel and 255 or 140, vs)
    return sx, tw
end

local function draw_stepper(rx, yc, val_text, is_sel)
    local arrow_a = is_sel and 210 or 80
    local val_a   = is_sel and 255 or 140
    local af = font.item
    local lh = text.height(af)
    local ry = yc - lh / 2
    local raw = text.width(af, ">")
    local law = text.width(af, "<")
    local vw  = text.width(font.value, val_text)

    text.draw(af, rx - raw, ry, 255, 255, 255, arrow_a, ">")
    local vx = rx - raw - 10 - vw
    text.draw(font.value, vx, yc - text.height(font.value) / 2, 255, 255, 255, val_a, val_text)
    text.draw(af, vx - 10 - law, ry, 255, 255, 255, arrow_a, "<")
end

local function draw_widget(rx, yc, item, idx, is_sel)
    local t = item.type
    if t == item_type.sub_menu then
        local a = is_sel and 200 or 70
        local ch = ">"
        text.draw(font.item, rx - text.width(font.item, ch), yc - text.height(font.item) / 2,
            255, 255, 255, a, ch)
    elseif t == item_type.selected_tick then
        local a = is_sel and 200 or 70
        local ch = "✓"
        text.draw(font.item, rx - text.width(font.item, ch), yc - text.height(font.item) / 2,
            255, 255, 255, a, ch)
    elseif t == item_type.toggle then
        draw_toggle(rx, yc, item, idx)
    elseif t == item_type.float_toggle then
        draw_toggle(rx, yc, item, idx)
        draw_slider(rx - TOGGLE_W - GAP, yc, item, is_sel)
    elseif t == item_type.int_toggle then
        draw_toggle(rx, yc, item, idx)
        draw_stepper(rx - TOGGLE_W - GAP, yc, tostring(item.i_val), is_sel)
    elseif t == item_type.array_toggle or t == item_type.loop_toggle then
        draw_toggle(rx, yc, item, idx)
        draw_stepper(rx - TOGGLE_W - GAP, yc, item.current_value or "?", is_sel)
    elseif t == item_type.slider then
        draw_slider(rx, yc, item, is_sel)
    elseif t == item_type.int_option then
        draw_stepper(rx, yc, tostring(item.i_val), is_sel)
    elseif t == item_type.array_option or t == item_type.loop_option then
        draw_stepper(rx, yc, item.current_value or "?", is_sel)
    elseif t == item_type.color then
        local s = 22
        draw.rect(rx - s, yc - s / 2, rx, yc + s / 2, item.r, item.g, item.b, item.a or 255, 4)
        draw.rect_outline(rx - s, yc - s / 2, rx, yc + s / 2, 255, 255, 255, is_sel and 90 or 30, 4)
    elseif t == item_type.search then
        -- glyph on the far right, query text to its left
        local glyph = "[S]"
        local gw = text.width(font.value, glyph)
        local ga = is_sel and 220 or 80
        text.draw(font.value, rx - gw, yc - text.height(font.value) / 2, c.accent[1], c.accent[2], c.accent[3], ga, glyph)
        local q = (item.text and item.text ~= "") and item.text or "Search\226\128\166"
        local qa = is_sel and 190 or 70
        local qw = text.width(font.value, q)
        text.draw(font.value, rx - gw - 8 - qw, yc - text.height(font.value) / 2, 255, 255, 255, qa, q)
    elseif t == item_type.input_text then
        local vw = text.width(font.value, item.name)
        text.draw(font.value, rx - vw, yc - text.height(font.value) / 2, 255, 255, 255, is_sel and 190 or 90, item.name)
    elseif t == item_type.input_int then
        local vs = tostring(item.i_val)
        text.draw(font.value, rx - text.width(font.value, vs), yc - text.height(font.value) / 2, 255, 255, 255, is_sel and 190 or 90, vs)
    elseif t == item_type.input_float then
        local vs = string.format("%.2f", item.f_val)
        text.draw(font.value, rx - text.width(font.value, vs), yc - text.height(font.value) / 2, 255, 255, 255, is_sel and 190 or 90, vs)
    end
end

local function draw_hotkey_badge(x, y, vk, is_sel, lh)
    if vk == 0 then return end
    local kn = menu.vk_name(vk)
    local bw = text.width(font.tiny, kn)
    local bh = text.height(font.tiny)
    local by = y + (lh - bh) / 2 - 1
    draw.rect(x - 4, by - 1, x + bw + 4, by + bh + 2, c.accent[1], c.accent[2], c.accent[3], is_sel and 46 or 16, 3)
    text.draw(font.tiny, x, by, c.accentL[1], c.accentL[2], c.accentL[3], is_sel and 220 or 90, kn)
end

---------------------------------------------------------------------------
-- Header / footer
---------------------------------------------------------------------------
local function draw_header(x, y)
    local cyc = y + l.header_h / 2
    -- accent dot
    draw.circle(x + l.pad_x + 4, cyc, 4, c.accent[1], c.accent[2], c.accent[3], 255)
    -- title
    local title = menu.page_name()
    text.draw(font.title, x + l.pad_x + 16, cyc - text.height(font.title) / 2,
        255, 255, 255, 255, title)
    -- counter (right)
    local counter = string.format("%d / %d", menu.selected_index() + 1, menu.item_count())
    local cw = text.width(font.value, counter)
    text.draw(font.value, x + l.menu_w - l.pad_x - cw, cyc - text.height(font.value) / 2,
        255, 255, 255, 70, counter)
    -- hairline divider
    draw.rect(x + l.pad_x, y + l.header_h - 1, x + l.menu_w - l.pad_x, y + l.header_h, 255, 255, 255, 14)
end

local function draw_footer(x, y)
    draw.rect(x + l.pad_x, y, x + l.menu_w - l.pad_x, y + 1, 255, 255, 255, 14)
    -- compact key hints
    local hints = "UP/DN move    ENTER select    ESC back"
    text.draw(font.tiny, x + l.pad_x, y + (l.footer_h - text.height(font.tiny)) / 2 + 1,
        255, 255, 255, 60, hints)
    local brand = str.brand or "Nenyoo"
    local bw = text.width(font.tiny, brand)
    text.draw(font.tiny, x + l.menu_w - l.pad_x - bw, y + (l.footer_h - text.height(font.tiny)) / 2 + 1,
        c.accent[1], c.accent[2], c.accent[3], 120, brand)
end

---------------------------------------------------------------------------
-- Scrollbar (thin, fades)
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

    local sw = (near or dragging_sb) and 5 or 3
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
    local thumb_a = dragging_sb and 200 or (near and 150 or 110)
    draw.rect(sx, thumb_y, sx + sw, thumb_y + thumb_h,
        c.accent[1], c.accent[2], c.accent[3], math.floor(thumb_a * a), 2)
end

---------------------------------------------------------------------------
-- Side info panel (player / weapon / vehicle) — flat, clean
---------------------------------------------------------------------------
local function draw_side_panel(x, y, w, item)
    if not item or not item.info then return end
    local it = item.info_type
    local info = item.info
    local green, red, yellow, blue = {34,197,94}, {239,68,68}, {234,179,8}, {59,130,246}
    local valc = {255,255,255,150}
    local cy = y

    local function section(title)
        cy = cy + 6
        text.draw(font.label, x + 14, cy, c.accent[1], c.accent[2], c.accent[3], 150, string.upper(title))
        cy = cy + 16
        draw.rect(x + 14, cy, x + w - 14, cy + 1, 255, 255, 255, 12)
        cy = cy + 8
    end
    local function row2(k1, v1, v1c, k2, v2, v2c)
        local rh = 22
        local half = w * 0.5
        text.draw(font.breadcrumb, x + 14, cy + 4, 255, 255, 255, 70, k1)
        local vw1 = text.width(font.breadcrumb, v1)
        text.draw(font.breadcrumb, x + half - 8 - vw1, cy + 4, v1c[1], v1c[2], v1c[3], v1c[4] or 255, v1)
        if k2 and v2 then
            text.draw(font.breadcrumb, x + half + 10, cy + 4, 255, 255, 255, 70, k2)
            local vw2 = text.width(font.breadcrumb, v2)
            text.draw(font.breadcrumb, x + w - 14 - vw2, cy + 4, v2c[1], v2c[2], v2c[3], v2c[4] or 255, v2)
        end
        cy = cy + rh
    end
    local function mini_bar(bx, by, bw, frac, col)
        draw.rect(bx, by, bx + bw, by + 3, 255, 255, 255, 10, 1)
        draw.rect(bx, by, bx + bw * clamp(frac,0,1), by + 3, col[1], col[2], col[3], 255, 1)
    end
    local function stat_row(label, value, max_val)
        local rh = 22
        text.draw(font.small, x + 14, cy + 4, 255, 255, 255, 70, label)
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
        draw.rect(x + 14, cy, x + w - 14, cy + 76, 255, 255, 255, 4, 6)
        draw.rect_outline(x + 14, cy, x + w - 14, cy + 76, c.accent[1], c.accent[2], c.accent[3], 30, 6)
        local tw = text.width(font.small, label)
        text.draw(font.small, x + (w - tw) / 2, cy + 32, 255, 255, 255, 40, label)
        cy = cy + 84
    end

    -- estimate height
    local ph = 40
    if it == 1 then ph = 360
    elseif it == 2 then ph = 320
    elseif it == 3 then ph = 300 end

    draw.rect(x, y, x + w, y + ph, c.bg[1], c.bg[2], c.bg[3], 240, 10)
    draw.rect_outline(x, y, x + w, y + ph, 255, 255, 255, 12, 10)
    text.draw(font.item, x + 14, y + 14, 255, 255, 255, 255, item.name)
    cy = y + 36

    if it == 1 then
        section(str.general or "General")
        row2(str.rank or "Rank", tostring(info.rank), yellow, str.kd or "K/D", info.kd, valc)
        row2(str.cash or "Cash", info.cash, green, str.bank or "Bank", info.bank, green)
        section(str.status or "Status")
        local rh = 22
        text.draw(font.small, x + 14, cy + 4, 239, 68, 68, 150, str.health or "HP")
        mini_bar(x + 72, cy + 8, 56, info.health/100, info.health > 50 and green or red)
        text.draw(font.tiny, x + 134, cy + 4, 255, 255, 255, 180, tostring(info.health).."%")
        text.draw(font.small, x + w*0.5 + 6, cy + 4, 59, 130, 246, 150, str.armor or "AP")
        mini_bar(x + w*0.5 + 56, cy + 8, 56, info.armor/100, blue)
        text.draw(font.tiny, x + w*0.5 + 118, cy + 4, 255, 255, 255, 180, tostring(info.armor).."%")
        cy = cy + rh
        local wstr = info.wanted == 0 and (str.clear or "Clear") or tostring(info.wanted)
        row2(str.wanted or "Wanted", wstr, info.wanted == 0 and green or red, str.ping or "Ping", info.ping, valc)
        section(str.equipment or "Equipment")
        row2(str.weapon or "Weapon", info.weapon, valc, str.ammo or "Ammo", info.ammo, yellow)
        section(str.location or "Location")
        row2(str.zone or "Zone", info.zone, valc, str.coords or "Coords", info.coords, {c.accentL[1],c.accentL[2],c.accentL[3]})
        row2(str.vehicle or "Vehicle", info.vehicle, valc, str.speed or "Speed", info.speed, yellow)
    elseif it == 2 then
        local wname = string.lower(string.gsub(item.name, " ", "_"))
        image_box("weapon_" .. wname)
        section(item.name)
        row2(str.type or "Type", info.type, valc, str.fire_mode or "Mode", info.rof, valc)
        row2(str.clip_size or "Clip", tostring(info.clip), yellow, str.dps or "DPS", tostring(info.damage*info.firerate), red)
        section(str.stats or "Stats")
        stat_row(str.damage or "Damage", info.damage, 100)
        stat_row(str.fire_rate or "Fire Rate", info.firerate, 10)
        stat_row(str.range or "Range", info.range, 100)
        stat_row(str.accuracy or "Accuracy", info.accuracy, 100)
    elseif it == 3 then
        local vname = string.lower(string.gsub(item.name, " ", "_"))
        image_box("vehicle_" .. vname)
        section(item.name)
        row2(str.cls or "Class", info.cls, valc, str.price or "Price", info.price, green)
        row2(str.top_speed or "Top Speed", info.speed, yellow, str.drivetrain or "Drive", info.drivetrain, valc)
        row2(str.seats or "Seats", tostring(info.seats), valc, nil, nil, nil)
        section(str.performance or "Performance")
        stat_row(str.acceleration or "Accel", info.accel, 100)
        stat_row(str.braking or "Brake", info.brake, 100)
        stat_row(str.handling or "Handling", info.handling, 100)
    end
end

---------------------------------------------------------------------------
-- Main draw
---------------------------------------------------------------------------
function draw_menu()
    c = reload_colors()
    l = reload_layout()
    theme.set_body_bg(c.bg[1], c.bg[2], c.bg[3], c.bg[4])
    if not menu.is_visible() then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local time, dt = ctx.time(), ctx.delta()

    local page = menu.page_name()
    if page ~= last_page then last_page = page; nav_time = time; scroll = 0; scroll_target = 0 end
    local sel = menu.selected_index()
    local sel_changed = (sel ~= last_sel)

    local count = menu.item_count()
    local content_h = count * l.item_h
    local list_h = math.min(l.list_max, content_h + 4)
    local total_h = l.header_h + list_h + l.footer_h
    local max_h = l.header_h + l.list_max + l.footer_h
    local mx = (sw - l.menu_w) / 2
    local my = math.max(24, (sh - max_h) / 2)

    -- Header drag-to-move: pass natural origin, add returned offset
    local _dox, _doy = menu.drag_header(mx, my, l.menu_w, l.header_h)
    mx = mx + _dox
    my = my + _doy

    frame.menu_x = mx

    -- side panel
    local sel_item = menu.get_item(sel)
    local show_side = sel_item and sel_item.info_type and sel_item.info_type > 1
    if show_side then draw_side_panel(mx - 360 - 14, my, 360, sel_item) end

    -- panel
    draw.rect(mx - 4, my - 2, mx + l.menu_w + 4, my + total_h + 6, 0, 0, 0, 70, 14) -- soft shadow
    draw.rect(mx, my, mx + l.menu_w, my + total_h, c.bg[1], c.bg[2], c.bg[3], c.bg[4], 12)
    draw.rect_outline(mx, my, mx + l.menu_w, my + total_h, 255, 255, 255, 14, 12)

    local cy = my
    draw_header(mx, cy); cy = cy + l.header_h
    local list_y = cy
    frame.list_y = list_y

    -- scroll bookkeeping
    local scroll_max = math.max(0, content_h - list_h)
    if sel_changed then
        local st = sel * l.item_h
        local sb = st + l.item_h
        if sb > scroll_target + list_h then scroll_target = sb - list_h end
        if st < scroll_target then scroll_target = st end
        last_sel = sel
    end
    scroll_target = clamp(scroll_target, 0, scroll_max)
    scroll = lerp(scroll, scroll_target, clamp(dt * 16, 0, 1))

    local imx, imy = input.mouse_x(), input.mouse_y()
    local in_list = imx >= mx and imx <= mx + l.menu_w and imy >= list_y and imy <= list_y + list_h
    if in_list and menu.popup_mode() == 0 then
        local wh = input.mouse_wheel()
        if wh ~= 0 then scroll_target = clamp(scroll_target - wh * l.item_h * 3, 0, scroll_max) end
    end

    -- slider drag
    if dragging_slider >= 0 then
        local di = menu.get_item(dragging_slider)
        if di and input.mouse_down(0) then
            local pct = clamp((imx - drag_x) / drag_w, 0, 1)
            local raw = di.f_min + pct * (di.f_max - di.f_min)
            if di.f_step > 0 then
                raw = di.f_min + math.floor((raw - di.f_min) / di.f_step + 0.5) * di.f_step
            end
            menu.set_f_val(dragging_slider, clamp(raw, di.f_min, di.f_max))
        else dragging_slider = -1 end
    end

    -- animated selection bar target
    local sel_y_target = list_y + 2 + sel * l.item_h - scroll
    if sel_anim == 0 then sel_anim = sel_y_target end
    sel_anim = lerp(sel_anim, sel_y_target, clamp(dt * 18, 0, 1))

    draw.push_clip(mx, list_y, mx + l.menu_w, list_y + list_h)
    local ne = time - nav_time
    local lh = text.height(font.item)

    for i = 0, count - 1 do
        local item = menu.get_item(i)
        if not item then goto cont end
        local t = item.type
        local is_sel = (i == sel)
        local delay = i * 0.03
        local at = ne >= delay and clamp((ne - delay) / 0.35, 0, 1) or 0
        at = ease_out(at)
        local iy = list_y + 2 + i * l.item_h - scroll
        if iy + l.item_h < list_y or iy > list_y + list_h then goto cont end
        local ix = mx + (1 - at) * -10
        local ibx = mx + l.menu_w

        local hovered = in_list and imy >= iy and imy <= iy + l.item_h

        -- selected: soft fill + animated accent bar
        if is_sel then
            frame.popup_item_y = iy + l.item_h
            menu.set_popup_item_y(iy + l.item_h)
            draw.rect(mx + 2, iy, ibx - 2, iy + l.item_h, c.accent[1], c.accent[2], c.accent[3], math.floor(20 * at), 6)
            -- thin rounded accent bar on the left edge (uses smoothed sel_anim)
            draw.rect(mx + 4, sel_anim + 7, mx + 7, sel_anim + l.item_h - 7, c.accent[1], c.accent[2], c.accent[3], math.floor(255 * at), 2)
        elseif hovered then
            draw.rect(mx + 2, iy, ibx - 2, iy + l.item_h, 255, 255, 255, math.floor(10 * at), 6)
        end

        -- mouse interaction
        if hovered and input.mouse_clicked(0) and menu.popup_mode() == 0 and dragging_slider < 0 then
            local handled = false
            local has_toggle = t == item_type.toggle or t == item_type.float_toggle
                or t == item_type.int_toggle or t == item_type.array_toggle or t == item_type.loop_toggle
            if has_toggle then
                local tx0 = ibx - l.pad_x - TOGGLE_W
                if imx >= tx0 and imx <= ibx - l.pad_x and imy >= iy + l.item_h/2 - 12 and imy <= iy + l.item_h/2 + 12 then
                    menu.set_selected(i); menu.toggle_item(i)
                    notify.push(item.name, item.on and (str.disabled or "Disabled") or (str.enabled or "Enabled"), item.on and 2 or 1)
                    handled = true
                end
            end
            local has_slider = t == item_type.slider or t == item_type.float_toggle
            if not handled and has_slider then
                local sl_right = ibx - l.pad_x
                if t == item_type.float_toggle then sl_right = sl_right - TOGGLE_W - GAP end
                local sl_left = sl_right - SLIDER_W
                if imx >= sl_left and imx <= sl_right and imy >= iy + l.item_h/2 - 12 and imy <= iy + l.item_h/2 + 12 then
                    menu.set_selected(i); dragging_slider = i
                    drag_x = sl_left; drag_w = SLIDER_W; handled = true
                end
            end
            if not handled then
                if is_sel then menu.activate() else menu.set_selected(i) end
            end
        end

        -- name (+ optional description line)
        local has_desc = item.desc and #item.desc > 0
        local na = math.floor((is_sel and 255 or 165) * at)
        local tx = ix + l.pad_x + 4
        local ty = iy + (has_desc and 9 or (l.item_h - lh) / 2)
        text.draw(font.item, tx, ty, 255, 255, 255, na, item.name)

        if item.hotkey and item.hotkey ~= 0 then
            draw_hotkey_badge(tx + text.width(font.item, item.name) + 8, ty, item.hotkey, is_sel, lh)
        end
        if has_desc then
            text.draw(font.desc, tx, ty + lh + 1, 255, 255, 255, math.floor((is_sel and 120 or 55) * at), item.desc)
        end

        draw_widget(ibx - l.pad_x, iy + l.item_h / 2, item, i, is_sel)
        ::cont::
    end
    draw.pop_clip()

    draw_scrollbar(mx, list_y, list_h, content_h)

    cy = cy + list_h
    draw_footer(mx, cy)

    local pm = menu.popup_mode()
    if pm == 1 then draw_input_popup() end
    if pm == 2 then draw_color_picker() end
    if pm == 3 then draw_array_dropdown_popup() end
    if pm == 4 then draw_hotkey_popup() end
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------
function handle_input()
    if not menu.is_visible() then return end
    local pm = menu.popup_mode()
    if pm == 1 then handle_input_popup(); return end
    if pm == 2 then handle_color_picker(); return end
    if pm == 3 then handle_array_dropdown(); return end
    if pm == 4 then handle_hotkey_bind(); return end

    if input.key_pressed(VK.UP) then menu.move_selection(-1) end
    if input.key_pressed(VK.DOWN) then menu.move_selection(1) end
    if input.key_just_pressed(VK.RETURN) then menu.activate() end
    if input.key_just_pressed(VK.BACK) or input.key_just_pressed(VK.ESCAPE) then menu.go_back() end

    local sel = menu.selected_index()
    local item = menu.get_item(sel)
    if not item then return end
    local t = item.type

    if input.key_just_pressed(VK.SPACE) then
        if t == item_type.input_text or t == item_type.input_int or t == item_type.input_float
            or t == item_type.slider or t == item_type.int_option
            or t == item_type.float_toggle or t == item_type.int_toggle
            or t == item_type.search then
            if t == item_type.search then
                menu.set_input_buffer(item.text or "")
            end
            menu.open_input_popup()
        end
    end

    if input.key_just_pressed(0x48) and t ~= item_type.sub_menu then -- 'H' bind hotkey
        menu.set_popup_mode(4)
    end
    if input.key_just_pressed(VK.DELETE) and item.hotkey and item.hotkey ~= 0 then
        menu.set_hotkey(sel, 0)
        notify.push(item.name, str.cleared or "Cleared", 0)
        menu.save_hotkeys(); menu.rebuild_features()
    end

    if input.key_pressed(VK.LEFT) or input.key_pressed(VK.RIGHT) then
        local dir = input.key_pressed(VK.RIGHT) and 1 or -1
        if t == item_type.slider or t == item_type.float_toggle then
            menu.set_f_val(sel, clamp(item.f_val + item.f_step * dir, item.f_min, item.f_max))
        elseif t == item_type.int_option or t == item_type.int_toggle then
            menu.set_i_val(sel, clamp(item.i_val + item.i_step * dir, item.i_min, item.i_max))
        elseif t == item_type.loop_option or t == item_type.loop_toggle then
            local idx = item.value_index + dir
            if idx >= item.value_count then idx = 0 end
            if idx < 0 then idx = item.value_count - 1 end
            menu.set_value_index(sel, idx)
        elseif t == item_type.array_option or t == item_type.array_toggle then
            menu.open_array_popup()
        end
    end
end

---------------------------------------------------------------------------
-- POPUP: Input (mode 1)
---------------------------------------------------------------------------
local input_cursor, input_blink, input_open_time = 0, 0, 0

function draw_input_popup()
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    draw.rect(0, 0, sw, sh, 0, 0, 0, 140)
    local pw, ph = 340, 116
    local px, py = (sw - pw) / 2, (sh - ph) / 2
    draw.rect(px, py, px + pw, py + ph, c.bg[1], c.bg[2], c.bg[3], 255, 10)
    draw.rect_outline(px, py, px + pw, py + ph, c.accent[1], c.accent[2], c.accent[3], 40, 10)

    local item = menu.get_item(menu.input_target_item())
    local title = item and item.name or (str.edit_value or "Edit value")
    text.draw(font.label, px + 20, py + 18, c.accent[1], c.accent[2], c.accent[3], 160, string.upper(title))

    local buf = menu.get_input_buffer()
    local ix, iy, iw, ih = px + 18, py + 42, pw - 36, 34
    draw.rect(ix, iy, ix + iw, iy + ih, c.surface[1], c.surface[2], c.surface[3], 255, 6)
    draw.rect_outline(ix, iy, ix + iw, iy + ih, c.accent[1], c.accent[2], c.accent[3], 50, 6)
    local tx = ix + 10
    local ty = iy + (ih - text.height(font.item)) / 2
    text.draw(font.item, tx, ty, 255, 255, 255, 255, buf)
    if math.fmod(ctx.time() - input_blink, 1.0) < 0.55 then
        local cw = text.width(font.item, buf:sub(1, input_cursor))
        draw.rect(tx + cw, iy + 7, tx + cw + 2, iy + ih - 7, c.accentL[1], c.accentL[2], c.accentL[3], 255)
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

    local dw, dh_item = 210, 32
    local count = item.value_count
    local dh = math.min(count * dh_item, dh_item * 7) + 8
    local dx = frame.menu_x + l.menu_w - dw - l.pad_x
    local dy = frame.popup_item_y or 300
    if dy + dh > sh - 10 then dy = dy - dh - l.item_h end

    draw.rect(dx, dy, dx + dw, dy + dh, c.surface[1], c.surface[2], c.surface[3], 255, 8)
    draw.rect_outline(dx, dy, dx + dw, dy + dh, c.accent[1], c.accent[2], c.accent[3], 45, 8)

    local mx, my = input.mouse_x(), input.mouse_y()
    local vfh = text.height(font.value)
    for i = 1, count do
        local is_sel = ((i - 1) == array_picker_idx)
        local is_cur = ((i - 1) == item.value_index)
        local iy = dy + 4 + (i - 1) * dh_item
        local hovered = mx >= dx and mx <= dx + dw and my >= iy and my <= iy + dh_item
        if hovered then array_picker_idx = i - 1 end
        if is_sel or hovered then
            draw.rect(dx + 4, iy, dx + dw - 4, iy + dh_item, c.accent[1], c.accent[2], c.accent[3], 36, 6)
        end
        local tc = (is_sel or hovered) and 255 or 130
        text.draw(font.value, dx + 14, iy + (dh_item - vfh) / 2, 255, 255, 255, tc, values[i])
        if is_cur then
            draw.circle(dx + dw - 16, iy + dh_item / 2, 3, c.accent[1], c.accent[2], c.accent[3], 255)
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
        if input.key_just_pressed(VK.RETURN) then
            menu.set_value_index(sel, array_picker_idx); menu.set_popup_mode(0); return
        end
        local mx, my = input.mouse_x(), input.mouse_y()
        if input.mouse_clicked(0) and elapsed > 0.15 then
            local dw, dh_item = 210, 32
            local dx = frame.menu_x + l.menu_w - dw - l.pad_x
            local dy = (frame.popup_item_y or 300) + 4
            if mx >= dx and mx <= dx + dw and my >= dy and my <= dy + item.value_count * dh_item then
                local idx = math.floor((my - dy) / dh_item)
                if idx >= 0 and idx < item.value_count then
                    menu.set_value_index(sel, idx); menu.set_popup_mode(0); return
                end
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
    draw.rect(0, 0, sw, sh, 0, 0, 0, 140)
    local pw, ph = 280, 76
    local px, py = (sw - pw) / 2, (sh - ph) / 2
    draw.rect(px, py, px + pw, py + ph, c.bg[1], c.bg[2], c.bg[3], 255, 10)
    draw.rect_outline(px, py, px + pw, py + ph, c.accent[1], c.accent[2], c.accent[3], 60, 10)
    local title = str.press_key or "Press any key..."
    local tw = text.width(font.item, title)
    text.draw(font.item, px + (pw - tw) / 2, py + 18, 255, 255, 255, 235, title)
    local hint = str.esc_cancel or "ESC to cancel"
    local hw = text.width(font.desc, hint)
    text.draw(font.desc, px + (pw - hw) / 2, py + 18 + text.height(font.item) + 8, 255, 255, 255, 80, hint)
end

function handle_hotkey_bind()
    if input.key_just_pressed(VK.ESCAPE) then
        menu.set_popup_mode(0); notify.push("Hotkey", str.cancelled or "Cancelled", 0); return
    end
    local skip = {[27]=true,[1]=true,[2]=true,[4]=true,[16]=true,[17]=true,[18]=true,
                  [160]=true,[161]=true,[162]=true,[163]=true,[164]=true,[165]=true}
    for vk = 1, 255 do
        if not skip[vk] and input.key_just_pressed(vk) then
            local sel = menu.selected_index()
            menu.set_hotkey(sel, vk)
            notify.push(menu.get_item(sel).name, (str.bound_to or "Bound to") .. " " .. menu.vk_name(vk), 1)
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
    draw.rect(0, 0, sw, sh, 0, 0, 0, 140)
    local pw, ph = 400, 452
    local px, py = (sw - pw) / 2, (sh - ph) / 2
    draw.rect(px, py, px + pw, py + ph, c.bg[1], c.bg[2], c.bg[3], 255, 10)
    draw.rect_outline(px, py, px + pw, py + ph, c.accent[1], c.accent[2], c.accent[3], 45, 10)

    local tab_w, tab_h, tab_y = 80, 26, py + 18
    local tabs = {str.palette or "Palette", str.custom or "Custom"}
    local mx, my = input.mouse_x(), input.mouse_y()
    for i = 1, 2 do
        local tx = px + 18 + (i - 1) * (tab_w + 6)
        local active = (cp_tab == i - 1)
        draw.rect(tx, tab_y, tx + tab_w, tab_y + tab_h,
            active and c.accent[1] or 255, active and c.accent[2] or 255, active and c.accent[3] or 255,
            active and 36 or 12, 6)
        local tw = text.width(font.tagline, tabs[i])
        text.draw(font.tagline, tx + (tab_w - tw) / 2, tab_y + (tab_h - text.height(font.tagline)) / 2,
            255, 255, 255, active and 220 or 110, tabs[i])
        if mx >= tx and mx <= tx + tab_w and my >= tab_y and my <= tab_y + tab_h and input.mouse_clicked(0) then
            cp_tab = i - 1
        end
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
            draw.rect(cx, cyy, cx + cell, cyy + cell, pc[1], pc[2], pc[3], pc[4], 6)
            if cp_palette_idx == i - 1 then
                draw.rect_outline(cx - 2, cyy - 2, cx + cell + 2, cyy + cell + 2, 255, 255, 255, 220, 7)
            end
            if mx >= cx and mx <= cx + cell and my >= cyy and my <= cyy + cell and input.mouse_clicked(0) then
                cp_palette_idx = i - 1
            end
        end
        local pc = palette[cp_palette_idx + 1]
        if pc then
            local prev_y = gy + 4 * (cell + gap) + 14
            draw.rect(gx, prev_y, gx + 48, prev_y + 48, pc[1], pc[2], pc[3], pc[4], 6)
            text.draw(font.small, gx + 60, prev_y + 6, 255, 255, 255, 140, string.format("R %d  G %d  B %d", pc[1], pc[2], pc[3]))
            text.draw(font.small, gx + 60, prev_y + 24, 255, 255, 255, 90, string.format("#%02X%02X%02X", pc[1], pc[2], pc[3]))
        end
    else
        local sv_x, sv_y = px + 18, content_y
        local sv_w, sv_h = 200, 180
        local hue_x, hue_w = sv_x + sv_w + 14, 20
        local hr, hg, hb = util.hsv_to_rgb(cp_hue, 1, 1)
        draw.rect(sv_x, sv_y, sv_x + sv_w, sv_y + sv_h, hr, hg, hb, 255)
        draw.rect_gradient(sv_x, sv_y, sv_x + sv_w, sv_y + sv_h, 255,255,255,255, 255,255,255,0, 255,255,255,0, 255,255,255,255)
        draw.rect_gradient(sv_x, sv_y, sv_x + sv_w, sv_y + sv_h, 0,0,0,0, 0,0,0,0, 0,0,0,255, 0,0,0,255)
        draw.rect_outline(sv_x, sv_y, sv_x + sv_w, sv_y + sv_h, 255, 255, 255, 18)
        local scx = sv_x + cp_sat * sv_w
        local scy = sv_y + (1 - cp_val) * sv_h
        draw.circle_outline(scx, scy, 6, 255, 255, 255, 255, 2)
        draw.circle(scx, scy, 4, 0, 0, 0, 128)
        for i = 0, 11 do
            local y1 = sv_y + (i / 12) * sv_h
            local y2 = sv_y + ((i + 1) / 12) * sv_h
            local r1, g1, b1 = util.hsv_to_rgb((i / 12) * 360, 1, 1)
            local r2, g2, b2 = util.hsv_to_rgb(((i + 1) / 12) * 360, 1, 1)
            draw.rect_gradient(hue_x, y1, hue_x + hue_w, y2, r1,g1,b1,255, r1,g1,b1,255, r2,g2,b2,255, r2,g2,b2,255)
        end
        draw.rect_outline(hue_x, sv_y, hue_x + hue_w, sv_y + sv_h, 255, 255, 255, 18)
        local hcy = sv_y + (cp_hue / 360) * sv_h
        draw.rect_outline(hue_x - 2, hcy - 3, hue_x + hue_w + 2, hcy + 3, 255, 255, 255, 255, 0, 2)
        local pr, pg, pb = util.hsv_to_rgb(cp_hue, cp_sat, cp_val)
        local prev_y = sv_y + sv_h + 14
        draw.rect(sv_x, prev_y, sv_x + 48, prev_y + 48, pr, pg, pb, 255, 6)
        text.draw(font.small, sv_x + 60, prev_y + 4, 255, 255, 255, 140, string.format("R %d  G %d  B %d", pr, pg, pb))
        text.draw(font.small, sv_x + 60, prev_y + 20, 255, 255, 255, 90, string.format("H %.0f  S %.0f%%  V %.0f%%", cp_hue, cp_sat*100, cp_val*100))
        text.draw(font.small, sv_x + 60, prev_y + 36, 255, 255, 255, 90, string.format("#%02X%02X%02X", pr, pg, pb))
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
    if item and item.type == item_type.search then
        menu.set_input_buffer(item.text or "")
        menu.open_input_popup()
        return
    end
    orig_activate()
end
