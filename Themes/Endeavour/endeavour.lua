-- Endeavour Theme — Cyan bordered, centered text

-- Fonts
text.load_font("themes/Endeavour/fonts/Chalet London.ttf")
text.set_font_for(font.title, "themes/Endeavour/fonts/SignPainterHouseScript.ttf")
-- Credit uses title font too (script)

-- Font sizes
local fs = 14
text.set_size(font.title, 28)
text.set_size(font.item, fs)
text.set_size(font.breadcrumb, fs)
text.set_size(font.desc, fs - 2)
text.set_size(font.label, fs)
text.set_size(font.tagline, fs)
text.set_size(font.value, fs)
text.set_size(font.small, 12)
text.set_size(font.tiny, 10)

-- Font weights
local fw = 400
text.set_weight(font.title, fw)
text.set_weight(font.item, fw)
text.set_weight(font.breadcrumb, fw)
text.set_weight(font.desc, fw)
text.set_weight(font.label, fw)
text.set_weight(font.tagline, fw)
text.set_weight(font.value, fw)
text.set_weight(font.small, fw)
text.set_weight(font.tiny, fw)

-- Colors
local c = {
    bg           = {10, 10, 15, 200},       -- dark transparent
    accent       = {0, 220, 240, 255},       -- bright cyan
    bar_dark     = {0, 0, 0, 255},            -- black bar
    bar_alt      = {0, 0, 0, 255},           -- same black bar
    text         = {255, 255, 255, 240},     -- white text
    text_sel     = {0, 220, 240, 255},       -- cyan selected text
    text_credit  = {0, 220, 240, 255},       -- cyan credit
    border_w     = 3,                         -- border thickness
}

-- Layout
local l = {
    menu_w       = 320,
    header_h     = 50,
    item_h       = 28,
    credit_h     = 35,
    list_max_h   = 16 * 28,
    pad_x        = 10,
    text_off_y   = 0,
    toggle_r     = 5,
    sidebar_w    = 5,         -- cyan side border width
    inline_size  = 1,         -- inline text stroke thickness
    inline_color = {30, 30, 30, 200},  -- inline stroke color
}

-- Settings
menu.clear_settings()
menu.add_setting_submenu("Colors", "Theme colors")
menu.add_sub_color("Accent", c.accent[1], c.accent[2], c.accent[3], 255, "Cyan border/accent")
menu.add_sub_color("Inline Color", l.inline_color[1], l.inline_color[2], l.inline_color[3], l.inline_color[4], "Inline text stroke color")
menu.add_setting_submenu("Layout", "Theme layout")
menu.add_sub_slider("Sidebar Width", l.sidebar_w, 1, 30, 1, "Cyan side border width")
menu.add_sub_slider("Inline Size", l.inline_size, 0, 5, 0.5, "Inline text stroke thickness")

-- State
local scroll = 0
local scroll_target = 0
local last_page = ""
local last_sel = -1

-- Helpers
local function lerp(a, b, t) return a + (b - a) * t end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function ease_out(t) t = clamp(t, 0, 1); return 1 - (1 - t)^2 end

-- Draw centered text helper
local function draw_centered(fnt, x1, x2, y, r, g, b, a, str)
    local tw = text.width(fnt, str)
    text.draw(fnt, x1 + (x2 - x1 - tw) / 2, y, r, g, b, a, str)
end

-- Draw centered outlined text
local function draw_centered_outlined(fnt, x1, x2, y, r, g, b, a, or_, og, ob, oa, thickness, str)
    local tw = text.width(fnt, str)
    text.draw_outlined(fnt, x1 + (x2 - x1 - tw) / 2, y, r, g, b, a, or_, og, ob, oa, thickness, str)
end

-- Draw centered inlined text
local function draw_centered_inlined(fnt, x1, x2, y, r, g, b, a, ir, ig, ib, ia, thickness, str)
    local tw = text.width(fnt, str)
    text.draw_inlined(fnt, x1 + (x2 - x1 - tw) / 2, y, r, g, b, a, ir, ig, ib, ia, thickness, str)
end

-- Icons
local IMG = {}
do
    local h = draw.load_image("textures/tick.png")
    if h and h > 0 then IMG.tick = h end
    local hs = draw.load_image("textures/search.png")
    if hs and hs > 0 then IMG.search = hs end
end

-- Draw widget (minimal — just values on right for non-submenus)
local function draw_widget(rx, yc, item, is_sel)
    local t = item.type
    if t == item_type.selected_tick then
        -- draw tick on the right: cyan when selected, white otherwise
        local h = IMG.tick
        if h then
            local iw, ih = draw.image_size(h)
            local sz = 14
            local w = iw and ih and ih > 0 and (iw * (sz / ih)) or sz
            local tc = is_sel and c.text_sel or c.text
            draw.image_colored(h, rx - w, yc - sz * 0.5, rx, yc + sz * 0.5, tc[1], tc[2], tc[3], tc[4])
        end
    elseif t == item_type.toggle or t == item_type.float_toggle or t == item_type.int_toggle
        or t == item_type.array_toggle or t == item_type.loop_toggle then
        local col = item.on and {0,200,60,255} or {200,50,50,255}
        draw.circle(rx - l.toggle_r - 2, yc, l.toggle_r, col[1], col[2], col[3], col[4])
    elseif t == item_type.slider then
        local vs = string.format("%.1f", item.f_val)
        local vw = text.width(font.value, vs)
        local tc = is_sel and c.text_sel or c.text
        text.draw(font.value, rx - vw, yc - text.height(font.value)/2, tc[1], tc[2], tc[3], 200, vs)
    elseif t == item_type.int_option then
        local vs = tostring(item.i_val)
        local vw = text.width(font.value, vs)
        local tc = is_sel and c.text_sel or c.text
        text.draw(font.value, rx - vw, yc - text.height(font.value)/2, tc[1], tc[2], tc[3], 200, vs)
    elseif t == item_type.array_option or t == item_type.loop_option then
        local vt = item.current_value or "?"
        local vw = text.width(font.value, vt)
        local tc = is_sel and c.text_sel or c.text
        text.draw(font.value, rx - vw, yc - text.height(font.value)/2, tc[1], tc[2], tc[3], 200, vt)
    elseif t == item_type.color then
        draw.rect(rx - 14, yc - 7, rx, yc + 7, item.r, item.g, item.b, item.a or 255)
    elseif t == item_type.search then
        -- search icon on the right
        local h = IMG.search
        local icon_w = 0
        if h then
            local iw, ih = draw.image_size(h)
            local sz = 14
            local w = iw and ih and ih > 0 and (iw * (sz / ih)) or sz
            local tc = is_sel and c.text_sel or c.text
            draw.image_colored(h, rx - w, yc - sz * 0.5, rx, yc + sz * 0.5, tc[1], tc[2], tc[3], tc[4])
            icon_w = w
        end
        -- query text to the left of the icon
        local pm = menu.popup_mode()
        local editing = (pm == 1 and menu.input_target_item and menu.input_target_item() == item._idx)
        local q
        if editing then
            local buf = menu.get_input_buffer()
            q = buf .. (math.fmod(ctx.time(), 1.0) < 0.55 and "|" or "")
        else
            q = (item.text and item.text ~= "") and item.text or "Search\226\128\166"
        end
        local tc = is_sel and c.text_sel or c.text
        local qw = text.width(font.value, q)
        text.draw(font.value, rx - icon_w - 4 - qw, yc - text.height(font.value) / 2, tc[1], tc[2], tc[3], 200, q)
    end
end

local frame = { popup_item_y = 300, menu_x = 0, list_y = 0 }

---------------------------------------------------------------------------
-- Popups & Notifications
---------------------------------------------------------------------------
local input_cursor, input_blink, input_open_time = 0, 0, 0

local function draw_input_popup()
    local sw, sh = ctx.screen_w(), ctx.screen_h(); draw.rect(0, 0, sw, sh, 0, 0, 0, 128)
    local pw, ph = 300, 95; local px, py = (sw-pw)/2, (sh-ph)/2
    draw.rect(px, py, px+pw, py+ph, c.bg[1], c.bg[2], c.bg[3], 250)
    draw.rect_outline(px, py, px+pw, py+ph, c.accent[1], c.accent[2], c.accent[3], 255, 0, c.border_w)
    local item = menu.get_item(menu.input_target_item())
    text.draw(font.label, px+14, py+12, c.accent[1], c.accent[2], c.accent[3], 200, item and item.name or str.edit_value)
    local buf = menu.get_input_buffer()
    draw.rect(px+10, py+34, px+pw-10, py+56, 0,0,0, 60)
    text.draw(font.item, px+16, py+39, 255,255,255,255, buf)
    if math.fmod(ctx.time() - input_blink, 1.0) < 0.55 then
        local cw = text.width(font.item, buf:sub(1, input_cursor))
        draw.rect(px+16+cw, py+37, px+16+cw+1.5, py+54, c.accent[1], c.accent[2], c.accent[3], 255)
    end
end
local function handle_input_popup()
    if input.key_just_pressed(VK.ESCAPE) then menu.set_popup_mode(0); return end
    if input.key_just_pressed(VK.RETURN) and (ctx.time() - input_open_time) > 0.15 then menu.confirm_input(); return end
    local buf = menu.get_input_buffer(); local chars = input.get_chars()
    if #chars > 0 then buf = buf:sub(1, input_cursor) .. chars .. buf:sub(input_cursor + 1); input_cursor = input_cursor + #chars; input_blink = ctx.time(); menu.set_input_buffer(buf) end
    if input.key_pressed(VK.BACK) and input_cursor > 0 then buf = buf:sub(1, input_cursor-1) .. buf:sub(input_cursor+1); input_cursor = input_cursor - 1; input_blink = ctx.time(); menu.set_input_buffer(buf) end
    if input.key_pressed(VK.LEFT) and input_cursor > 0 then input_cursor = input_cursor - 1 end
    if input.key_pressed(VK.RIGHT) and input_cursor < #buf then input_cursor = input_cursor + 1 end
end
local orig_open_input = menu.open_input_popup
menu.open_input_popup = function() orig_open_input(); input_cursor = #menu.get_input_buffer(); input_blink = ctx.time(); input_open_time = ctx.time() end

local array_idx, array_open_time = 0, 0
local function draw_array_dropdown()
    local sel = menu.selected_index(); local item = menu.get_item(sel)
    if not item or item.value_count <= 0 then menu.set_popup_mode(0); return end
    local values = menu.get_item_values(sel); if not values then menu.set_popup_mode(0); return end
    local dw, dih = 200, l.item_h; local dh = math.min(#values * dih, dih * 8)
    local dx = frame.menu_x + (l.menu_w - dw)/2; local dy = frame.popup_item_y or 300
    if dy + dh > ctx.screen_h() - 10 then dy = dy - dh - l.item_h end
    draw.rect(dx, dy, dx+dw, dy+dh, c.bg[1], c.bg[2], c.bg[3], 250)
    draw.rect_outline(dx, dy, dx+dw, dy+dh, c.accent[1], c.accent[2], c.accent[3], 200, 0, 2)
    local mx, my = input.mouse_x(), input.mouse_y()
    for i = 1, #values do local iy = dy + (i-1)*dih
        local hov = mx >= dx and mx <= dx+dw and my >= iy and my <= iy+dih; if hov then array_idx = i-1 end
        local tc = ((i-1)==array_idx) and c.text_sel or c.text
        draw_centered(font.value, dx, dx+dw, iy+(dih-text.height(font.value))/2, tc[1], tc[2], tc[3], tc[4], values[i])
    end
end
local function handle_array_dropdown()
    local elapsed = ctx.time() - array_open_time
    if input.key_just_pressed(VK.ESCAPE) or input.key_just_pressed(VK.BACK) then menu.set_popup_mode(0); return end
    local item = menu.get_item(menu.selected_index()); if not item then menu.set_popup_mode(0); return end
    if elapsed > 0.1 then
        if input.key_pressed(VK.DOWN) and array_idx < item.value_count-1 then array_idx = array_idx + 1 end
        if input.key_pressed(VK.UP) and array_idx > 0 then array_idx = array_idx - 1 end
        if input.key_just_pressed(VK.RETURN) then menu.set_value_index(menu.selected_index(), array_idx); menu.set_popup_mode(0) end
    end
end
local orig_open_array = menu.open_array_popup
menu.open_array_popup = function() orig_open_array(); local item = menu.get_item(menu.selected_index()); array_idx = item and item.value_index or 0; array_open_time = ctx.time() end

local function draw_hotkey_popup()
    local sw, sh = ctx.screen_w(), ctx.screen_h(); draw.rect(0, 0, sw, sh, 0, 0, 0, 128)
    local pw, ph = 220, 50; local px, py = (sw-pw)/2, (sh-ph)/2
    draw.rect(px, py, px+pw, py+ph, c.bg[1], c.bg[2], c.bg[3], 250)
    draw.rect_outline(px, py, px+pw, py+ph, c.accent[1], c.accent[2], c.accent[3], 255, 0, 2)
    draw_centered(font.item, px, px+pw, py+8, 255,255,255,230, str.press_key)
    draw_centered(font.desc, px, px+pw, py+28, 255,255,255,80, str.esc_cancel)
end
local function handle_hotkey_bind()
    if input.key_just_pressed(VK.ESCAPE) then menu.set_popup_mode(0); notify.push("Hotkey", str.cancelled, 0); return end
    local skip = {[27]=true,[1]=true,[2]=true,[4]=true,[16]=true,[17]=true,[18]=true,[160]=true,[161]=true,[162]=true,[163]=true,[164]=true,[165]=true}
    for vk = 1, 255 do if not skip[vk] and input.key_just_pressed(vk) then
        menu.set_hotkey(menu.selected_index(), vk); notify.push(menu.get_item(menu.selected_index()).name, str.bound_to .. " " .. menu.vk_name(vk), 1)
        menu.save_hotkeys(); menu.rebuild_features(); menu.set_popup_mode(0); return
    end end
end

local cp_idx, cp_open_time = 0, 0
local palette = {{239,68,68,255},{220,38,38,255},{185,28,28,255},{153,27,27,255},{249,115,22,255},{234,88,12,255},{194,65,12,255},{154,52,18,255},{234,179,8,255},{202,138,4,255},{161,98,7,255},{133,77,14,255},{34,197,94,255},{22,163,74,255},{21,128,61,255},{20,83,45,255},{59,130,246,255},{37,99,235,255},{29,78,216,255},{30,64,175,255},{168,85,247,255},{147,51,234,255},{126,34,206,255},{107,33,168,255},{236,72,153,255},{219,39,119,255},{190,24,93,255},{157,23,77,255},{255,255,255,255},{200,200,200,255},{100,100,100,255},{0,0,0,255}}
local function draw_color_picker()
    local sw, sh = ctx.screen_w(), ctx.screen_h(); draw.rect(0, 0, sw, sh, 0, 0, 0, 128)
    local pw, ph = 300, 230; local px, py = (sw-pw)/2, (sh-ph)/2
    draw.rect(px, py, px+pw, py+ph, c.bg[1], c.bg[2], c.bg[3], 250)
    draw.rect_outline(px, py, px+pw, py+ph, c.accent[1], c.accent[2], c.accent[3], 255, 0, 2)
    local cell, gap = 28, 4; local gx, gy = px + 12, py + 12; local mx, my = input.mouse_x(), input.mouse_y()
    for i = 1, 32 do local col = ((i-1)%8); local row = math.floor((i-1)/8)
        local cx = gx + col*(cell+gap); local cy = gy + row*(cell+gap)
        draw.rect(cx, cy, cx+cell, cy+cell, palette[i][1], palette[i][2], palette[i][3], 255)
        if cp_idx == i-1 then draw.rect_outline(cx-2, cy-2, cx+cell+2, cy+cell+2, c.accent[1], c.accent[2], c.accent[3], 255) end
        if mx >= cx and mx <= cx+cell and my >= cy and my <= cy+cell and input.mouse_clicked(0) then cp_idx = i-1 end
    end
end
local function handle_color_picker()
    if input.key_just_pressed(VK.ESCAPE) then menu.set_popup_mode(0); return end
    if input.key_just_pressed(VK.RETURN) and (ctx.time() - cp_open_time) > 0.15 then local pc = palette[cp_idx+1]; if pc then menu.set_item_color(menu.selected_index(), pc[1], pc[2], pc[3], pc[4]) end; menu.set_popup_mode(0) end
    if input.key_just_pressed(VK.RIGHT) then cp_idx = math.min(cp_idx+1, 31) end; if input.key_just_pressed(VK.LEFT) then cp_idx = math.max(cp_idx-1, 0) end
    if input.key_just_pressed(VK.DOWN) then cp_idx = math.min(cp_idx+8, 31) end; if input.key_just_pressed(VK.UP) then cp_idx = math.max(cp_idx-8, 0) end
end
local orig_activate = menu.activate
menu.activate = function() local item = menu.get_item(menu.selected_index()); if item and item.type == item_type.color then menu.set_popup_mode(2); cp_idx = 0; cp_open_time = ctx.time(); return end; if item and item.type == item_type.search then menu.set_input_buffer(item.text or ""); menu.open_input_popup(); return end; orig_activate() end

---------------------------------------------------------------------------
-- Main draw
---------------------------------------------------------------------------
function draw_menu()
    theme.set_body_bg(5, 5, 8, 255)
    if not menu.is_visible() then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local dt = ctx.delta()

    local page = menu.page_name()
    if page ~= last_page then last_page = page; scroll = 0; scroll_target = 0 end
    local sel = menu.selected_index()
    local sel_changed = (sel ~= last_sel); last_sel = sel

    -- Read live settings
    local sw_item = menu.get_setting("Sidebar Width")
    if sw_item then l.sidebar_w = sw_item.f_val end
    local is_item = menu.get_setting("Inline Size")
    if is_item then l.inline_size = is_item.f_val end
    local ic_item = menu.get_setting("Inline Color")
    if ic_item then l.inline_color = {ic_item.r, ic_item.g, ic_item.b, ic_item.a or 200} end

    local count = menu.item_count()
    local content_h = count * l.item_h
    local list_h = math.min(l.list_max_h, content_h)
    local bar_h = 6  -- thick cyan bar height
    local total_h = l.header_h + bar_h + list_h + bar_h + l.credit_h
    local max_h = l.header_h + bar_h + l.list_max_h + bar_h + l.credit_h
    local mx = (sw - l.menu_w) / 2
    local my = math.max(20, (sh - max_h) / 2)

    -- Header drag-to-move: pass natural origin, add returned offset
    local _dox, _doy = menu.drag_header(mx, my, l.menu_w, l.header_h)
    mx = mx + _dox
    my = my + _doy

    frame.menu_x = mx

    local cy = my

    -- Cyan header bar with white outlined title ON it
    draw.rect(mx, cy, mx + l.menu_w, cy + l.header_h, c.accent[1], c.accent[2], c.accent[3], c.accent[4])
    draw_centered_outlined(font.title, mx, mx + l.menu_w, cy + (l.header_h - text.height(font.title))/2 + l.text_off_y,
        255, 255, 255, 255, 0, 0, 0, 200, 1, page)
    cy = cy + l.header_h

    -- Items area background with left/right cyan borders
    draw.rect(mx, cy, mx + l.menu_w, cy + list_h, 0, 0, 0, 255)
    draw.rect(mx, cy, mx + l.sidebar_w, cy + list_h, c.accent[1], c.accent[2], c.accent[3], c.accent[4])
    draw.rect(mx + l.menu_w - l.sidebar_w, cy, mx + l.menu_w, cy + list_h, c.accent[1], c.accent[2], c.accent[3], c.accent[4])

    local list_y = cy
    frame.list_y = list_y

    -- Scroll
    local scroll_max = math.max(0, content_h - list_h)
    if sel_changed then
        local st = sel * l.item_h; local sb = st + l.item_h
        if sb > scroll_target + list_h then scroll_target = sb - list_h end
        if st < scroll_target then scroll_target = st end
    end
    scroll_target = clamp(scroll_target, 0, scroll_max)
    scroll = lerp(scroll, scroll_target, clamp(dt * 14, 0, 1))

    local imx, imy = input.mouse_x(), input.mouse_y()
    local in_list = imx >= mx and imx <= mx + l.menu_w and imy >= list_y and imy <= list_y + list_h
    if in_list and menu.popup_mode() == 0 then
        local wh = input.mouse_wheel()
        if wh ~= 0 then scroll_target = clamp(scroll_target - wh * l.item_h * 3, 0, scroll_max) end
    end

    -- Items
    draw.push_clip(mx, list_y, mx + l.menu_w, list_y + list_h)
    for i = 0, count - 1 do
        local item = menu.get_item(i)
        if not item then goto cont end
        item._idx = i
        local is_sel = (i == sel)
        local iy = list_y + i * l.item_h - scroll
        if iy + l.item_h < list_y or iy > list_y + list_h then goto cont end

        -- Alternating dark bars
        local bar = (i % 2 == 0) and c.bar_dark or c.bar_alt
        draw.rect(mx + l.sidebar_w, iy, mx + l.menu_w - l.sidebar_w, iy + l.item_h, bar[1], bar[2], bar[3], bar[4])

        if is_sel then
            frame.popup_item_y = iy + l.item_h
            menu.set_popup_item_y(iy + l.item_h)
        end

        -- Hover
        local hovered = in_list and imy >= iy and imy <= iy + l.item_h
        if hovered and not is_sel then draw.rect(mx + c.border_w, iy, mx + l.menu_w - c.border_w, iy + l.item_h, 255,255,255, 6) end
        if hovered and input.mouse_clicked(0) and menu.popup_mode() == 0 then
            if is_sel then menu.activate() else menu.set_selected(i) end
        end

        -- Item name (CENTERED, outlined, cyan if selected, underlined)
        local tc = is_sel and c.text_sel or c.text
        local tw = text.width(font.item, item.name)
        local tx = mx + (l.menu_w - tw) / 2
        local ty = iy + (l.item_h - text.height(font.item))/2 + l.text_off_y
        text.draw_outlined(font.item, tx, ty, tc[1], tc[2], tc[3], tc[4], 0, 0, 0, 180, 1, item.name)

        -- Widget (right side for non-submenus)
        draw_widget(mx + l.menu_w - l.pad_x - 2, iy + l.item_h/2, item, is_sel)

        ::cont::
    end
    draw.pop_clip()
    cy = list_y + list_h

    -- Cyan footer bar with white outlined credit ON it
    draw.rect(mx, cy, mx + l.menu_w, cy + l.credit_h, c.accent[1], c.accent[2], c.accent[3], c.accent[4])
    draw_centered_outlined(font.title, mx, mx + l.menu_w, cy + (l.credit_h - text.height(font.title))/2,
        255, 255, 255, 255, 0, 0, 0, 200, 1, "Made By Welsh & Sabotage")

    -- Popups
    local pm = menu.popup_mode()
    if pm == 1 then draw_input_popup() end
    if pm == 2 then draw_color_picker() end
    if pm == 3 then draw_array_dropdown() end
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

    local sel = menu.selected_index(); local item = menu.get_item(sel); if not item then return end; local t = item.type
    if input.key_just_pressed(VK.SPACE) then
        if t == item_type.input_text or t == item_type.input_int or t == item_type.input_float or t == item_type.slider or t == item_type.int_option or t == item_type.float_toggle or t == item_type.int_toggle or t == item_type.search then
            if t == item_type.search then menu.set_input_buffer(item.text or "") end
            menu.open_input_popup()
        end
    end
    if input.key_just_pressed(0x48) and t ~= item_type.sub_menu then menu.set_popup_mode(4) end
    if input.key_just_pressed(VK.DELETE) and item.hotkey and item.hotkey ~= 0 then menu.set_hotkey(sel, 0); notify.push(item.name, str.cleared, 0); menu.save_hotkeys(); menu.rebuild_features() end
    if input.key_pressed(VK.LEFT) or input.key_pressed(VK.RIGHT) then
        local dir = input.key_pressed(VK.RIGHT) and 1 or -1
        if t == item_type.slider or t == item_type.float_toggle then menu.set_f_val(sel, clamp(item.f_val + item.f_step * dir, item.f_min, item.f_max))
        elseif t == item_type.int_option or t == item_type.int_toggle then menu.set_i_val(sel, clamp(item.i_val + item.i_step * dir, item.i_min, item.i_max))
        elseif t == item_type.loop_option or t == item_type.loop_toggle then local idx = item.value_index + dir; if idx >= item.value_count then idx = 0 end; if idx < 0 then idx = item.value_count - 1 end; menu.set_value_index(sel, idx)
        elseif t == item_type.array_option or t == item_type.array_toggle then menu.open_array_popup() end
    end
end
