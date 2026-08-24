-- ArabicGuy Theme — Teal gradient with star icons

-- Fonts
text.load_font("themes/ArabicGuy/fonts/Chalet London.ttf")
text.set_font_for(font.title, "themes/ArabicGuy/fonts/SignPainterHouseScript.ttf")

-- Font sizes
local fs = 16
text.set_size(font.title, 36)
text.set_size(font.item, fs)
text.set_size(font.breadcrumb, fs + 3)  -- used for selected item (bigger)
text.set_size(font.desc, fs - 1)
text.set_size(font.label, fs)
text.set_size(font.tagline, fs)
text.set_size(font.value, fs)
text.set_size(font.small, 14)
text.set_size(font.tiny, 12)

-- Font weights
text.set_weight(font.title, 400)
text.set_weight(font.item, 400)
text.set_weight(font.breadcrumb, 400)
text.set_weight(font.desc, 400)
text.set_weight(font.label, 400)
text.set_weight(font.tagline, 400)
text.set_weight(font.value, 400)
text.set_weight(font.small, 400)
text.set_weight(font.tiny, 400)

-- Colors
local c = {
    -- Gradient background (vibrant bright teal/cyan)
    bg_top       = {15, 60, 90, 200},
    bg_bot       = {55, 140, 175, 180},
    -- Dark bar (near-black, rows 0,2,4...)
    bar_dark_l   = {5, 12, 20, 240},
    bar_dark_r   = {10, 25, 40, 220},
    -- Teal bar (dark teal-blue, rows 1,3,5...)
    bar_teal_l   = {15, 45, 65, 220},
    bar_teal_r   = {25, 65, 90, 200},
    -- Selected: brighter teal, stands out
    selected_l   = {20, 70, 100, 240},
    selected_r   = {40, 100, 135, 220},
    text         = {255, 255, 255, 250},
    text_sel     = {255, 255, 0, 255},
    text_footer  = {255, 255, 255, 210},
    star         = {255, 255, 255, 240},
    star_sel     = {255, 255, 0, 255},
    toggle_on    = {0, 220, 60, 255},
    toggle_off   = {240, 40, 40, 255},
}

-- Layout
local l = {
    menu_w       = 480,
    header_h     = 80,
    item_h       = 38,
    item_gap     = 2,
    footer_h     = 32,
    list_max_h   = 11 * (36 + 2),
    pad_x        = 18,
    toggle_r     = 10,        -- bigger toggle circles
    star_pad     = 28,        -- more space for star
    text_off_y   = 0,
    scrollbar_w  = 3,
}

-- Register settings
menu.clear_settings()
menu.add_setting_submenu("Colors", "Theme colors")
menu.add_sub_color("Selected Text", c.text_sel[1], c.text_sel[2], c.text_sel[3], 255, "Selected item text color")
menu.add_sub_color("Toggle On", c.toggle_on[1], c.toggle_on[2], c.toggle_on[3], 255, "Toggle on color")
menu.add_sub_color("Toggle Off", c.toggle_off[1], c.toggle_off[2], c.toggle_off[3], 255, "Toggle off color")

-- State
local scroll = 0
local scroll_target = 0
local last_page = ""
local last_sel = -1

-- Helpers
local function lerp(a, b, t) return a + (b - a) * t end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function ease_out(t) t = clamp(t, 0, 1); return 1 - (1 - t)^2 end

-- Star character
local star = "\xe2\x98\x85"

-- Draw widget
local function draw_widget(rx, yc, item, is_sel)
    local t = item.type

    if t == item_type.sub_menu then
        -- no icon, just submenu text is enough
    elseif t == item_type.selected_tick then
        local tc = is_sel and c.star_sel or c.star
        local ck = "\xe2\x9c\x93"
        local cw = text.width(font.small, ck)
        text.draw(font.small, rx - cw, yc - text.height(font.small)/2, tc[1], tc[2], tc[3], tc[4], ck)
    elseif t == item_type.toggle or t == item_type.float_toggle or t == item_type.int_toggle
        or t == item_type.array_toggle or t == item_type.loop_toggle then
        local col = item.on and c.toggle_on or c.toggle_off
        draw.circle(rx - l.toggle_r - 2, yc, l.toggle_r, col[1], col[2], col[3], col[4])

    elseif t == item_type.slider then
        local vs = string.format("%.1f", item.f_val)
        local vw = text.width(font.value, vs)
        text.draw(font.value, rx - vw, yc - text.height(font.value)/2, 255,255,255, is_sel and 255 or 160, vs)

    elseif t == item_type.int_option then
        local vs = tostring(item.i_val)
        local vw = text.width(font.value, vs)
        text.draw(font.value, rx - vw, yc - text.height(font.value)/2, 255,255,255, is_sel and 255 or 160, vs)

    elseif t == item_type.array_option or t == item_type.loop_option then
        local vt = item.current_value or "?"
        local vw = text.width(font.value, vt)
        text.draw(font.value, rx - vw, yc - text.height(font.value)/2, 255,255,255, is_sel and 255 or 160, vt)

    elseif t == item_type.color then
        local s = 16
        draw.rect(rx - s, yc - s/2, rx, yc + s/2, item.r, item.g, item.b, item.a or 255)

    elseif t == item_type.search then
        local sc2 = is_sel and c.star_sel or c.star
        local mag = "\xe2\x8c\x95"
        local mw = text.width(font.small, mag)
        text.draw(font.small, rx - mw, yc - text.height(font.small)/2, sc2[1], sc2[2], sc2[3], sc2[4], mag)
        local q = (item.text and item.text ~= "") and item.text or "Search\xe2\x80\xa6"
        local qa = (item.text and item.text ~= "") and (is_sel and 255 or 200) or 100
        local qw = text.width(font.value, q)
        text.draw(font.value, rx - mw - 6 - qw, yc - text.height(font.value)/2, 255, 255, 255, qa, q)
    end
end

local frame = { popup_item_y = 300, menu_x = 0, list_y = 0 }

---------------------------------------------------------------------------
-- Popups & Notifications
---------------------------------------------------------------------------

local input_cursor = 0
local input_blink = 0
local input_open_time = 0

local function draw_input_popup()
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    draw.rect(0, 0, sw, sh, 0, 0, 0, 128)
    local pw, ph = 320, 100
    local px, py = (sw-pw)/2, (sh-ph)/2
    draw.rect(px, py, px+pw, py+ph, 20, 50, 70, 250)
    local item = menu.get_item(menu.input_target_item())
    text.draw(font.label, px+16, py+14, 255,255,0, 200, item and item.name or str.edit_value)
    local buf = menu.get_input_buffer()
    draw.rect(px+12, py+36, px+pw-12, py+60, 0,0,0, 60)
    text.draw(font.item, px+18, py+41, 255,255,255,255, buf)
    if math.fmod(ctx.time() - input_blink, 1.0) < 0.55 then
        local cw = text.width(font.item, buf:sub(1, input_cursor))
        draw.rect(px+18+cw, py+39, px+18+cw+1.5, py+58, 255,255,0, 255)
    end
end

local function handle_input_popup()
    if input.key_just_pressed(VK.ESCAPE) then menu.set_popup_mode(0); return end
    if input.key_just_pressed(VK.RETURN) and (ctx.time() - input_open_time) > 0.15 then menu.confirm_input(); return end
    local buf = menu.get_input_buffer()
    local chars = input.get_chars()
    if #chars > 0 then
        buf = buf:sub(1, input_cursor) .. chars .. buf:sub(input_cursor + 1)
        input_cursor = input_cursor + #chars
        input_blink = ctx.time()
        menu.set_input_buffer(buf)
    end
    if input.key_pressed(VK.BACK) and input_cursor > 0 then
        buf = buf:sub(1, input_cursor-1) .. buf:sub(input_cursor+1)
        input_cursor = input_cursor - 1
        input_blink = ctx.time()
        menu.set_input_buffer(buf)
    end
    if input.key_pressed(VK.LEFT) and input_cursor > 0 then input_cursor = input_cursor - 1 end
    if input.key_pressed(VK.RIGHT) and input_cursor < #buf then input_cursor = input_cursor + 1 end
end

local orig_open_input = menu.open_input_popup
menu.open_input_popup = function()
    orig_open_input()
    input_cursor = #menu.get_input_buffer()
    input_blink = ctx.time()
    input_open_time = ctx.time()
end

local array_idx = 0
local array_open_time = 0

local function draw_array_dropdown()
    local sel = menu.selected_index()
    local item = menu.get_item(sel)
    if not item or item.value_count <= 0 then menu.set_popup_mode(0); return end
    local values = menu.get_item_values(sel)
    if not values then menu.set_popup_mode(0); return end
    local dw, dih = 200, l.item_h
    local dh = math.min(#values * dih, dih * 8)
    local dx = frame.menu_x + l.menu_w - dw
    local dy = frame.popup_item_y or 300
    if dy + dh > ctx.screen_h() - 10 then dy = dy - dh - l.item_h end
    draw.rect(dx, dy, dx+dw, dy+dh, 20, 50, 70, 250)
    local mx, my = input.mouse_x(), input.mouse_y()
    for i = 1, #values do
        local iy = dy + (i-1)*dih
        local hov = mx >= dx and mx <= dx+dw and my >= iy and my <= iy+dih
        if hov then array_idx = i-1 end
        if (i-1) == array_idx then
            draw.rect(dx, iy, dx+dw, iy+dih, 30, 65, 85, 220)
        end
        local tc = ((i-1)==array_idx) and 255 or 160
        text.draw(font.value, dx+10, iy+(dih-text.height(font.value))/2, 255,255,255, tc, values[i])
    end
end

local function handle_array_dropdown()
    local elapsed = ctx.time() - array_open_time
    if input.key_just_pressed(VK.ESCAPE) or input.key_just_pressed(VK.BACK) then menu.set_popup_mode(0); return end
    local item = menu.get_item(menu.selected_index())
    if not item then menu.set_popup_mode(0); return end
    if elapsed > 0.1 then
        if input.key_pressed(VK.DOWN) and array_idx < item.value_count-1 then array_idx = array_idx + 1 end
        if input.key_pressed(VK.UP) and array_idx > 0 then array_idx = array_idx - 1 end
        if input.key_just_pressed(VK.RETURN) then menu.set_value_index(menu.selected_index(), array_idx); menu.set_popup_mode(0) end
    end
end

local orig_open_array = menu.open_array_popup
menu.open_array_popup = function()
    orig_open_array()
    local item = menu.get_item(menu.selected_index())
    array_idx = item and item.value_index or 0
    array_open_time = ctx.time()
end

local function draw_hotkey_popup()
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    draw.rect(0, 0, sw, sh, 0, 0, 0, 128)
    local pw, ph = 240, 56
    local px, py = (sw-pw)/2, (sh-ph)/2
    draw.rect(px, py, px+pw, py+ph, 20, 50, 70, 250)
    local tw = text.width(font.item, str.press_key)
    text.draw(font.item, px+(pw-tw)/2, py+10, 255,255,255,230, str.press_key)
    local hw = text.width(font.desc, str.esc_cancel)
    text.draw(font.desc, px+(pw-hw)/2, py+32, 255,255,255,80, str.esc_cancel)
end

local function handle_hotkey_bind()
    if input.key_just_pressed(VK.ESCAPE) then menu.set_popup_mode(0); notify.push("Hotkey", str.cancelled, 0); return end
    local skip = {[27]=true,[1]=true,[2]=true,[4]=true,[16]=true,[17]=true,[18]=true,[160]=true,[161]=true,[162]=true,[163]=true,[164]=true,[165]=true}
    for vk = 1, 255 do
        if not skip[vk] and input.key_just_pressed(vk) then
            menu.set_hotkey(menu.selected_index(), vk)
            notify.push(menu.get_item(menu.selected_index()).name, str.bound_to .. " " .. menu.vk_name(vk), 1)
            menu.save_hotkeys(); menu.rebuild_features(); menu.set_popup_mode(0); return
        end
    end
end

local cp_idx = 0
local cp_open_time = 0
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

local function draw_color_picker()
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    draw.rect(0, 0, sw, sh, 0, 0, 0, 128)
    local pw, ph = 340, 260
    local px, py = (sw-pw)/2, (sh-ph)/2
    draw.rect(px, py, px+pw, py+ph, 20, 50, 70, 250)
    local cell, gap = 32, 4
    local gx, gy = px + 14, py + 14
    local mx, my = input.mouse_x(), input.mouse_y()
    for i = 1, 32 do
        local col = ((i-1)%8)
        local row = math.floor((i-1)/8)
        local cx = gx + col*(cell+gap)
        local cy = gy + row*(cell+gap)
        draw.rect(cx, cy, cx+cell, cy+cell, palette[i][1], palette[i][2], palette[i][3], 255)
        if cp_idx == i-1 then draw.rect_outline(cx-2, cy-2, cx+cell+2, cy+cell+2, 255,255,0, 200) end
        if mx >= cx and mx <= cx+cell and my >= cy and my <= cy+cell and input.mouse_clicked(0) then cp_idx = i-1 end
    end
end

local function handle_color_picker()
    if input.key_just_pressed(VK.ESCAPE) then menu.set_popup_mode(0); return end
    if input.key_just_pressed(VK.RETURN) and (ctx.time() - cp_open_time) > 0.15 then
        local pc = palette[cp_idx+1]
        if pc then menu.set_item_color(menu.selected_index(), pc[1], pc[2], pc[3], pc[4]) end
        menu.set_popup_mode(0)
    end
    if input.key_just_pressed(VK.RIGHT) then cp_idx = math.min(cp_idx+1, 31) end
    if input.key_just_pressed(VK.LEFT) then cp_idx = math.max(cp_idx-1, 0) end
    if input.key_just_pressed(VK.DOWN) then cp_idx = math.min(cp_idx+8, 31) end
    if input.key_just_pressed(VK.UP) then cp_idx = math.max(cp_idx-8, 0) end
end

local orig_activate = menu.activate
menu.activate = function()
    local item = menu.get_item(menu.selected_index())
    if item and item.type == item_type.color then
        menu.set_popup_mode(2)
        cp_idx = 0
        cp_open_time = ctx.time()
        return
    end
    orig_activate()
end

---------------------------------------------------------------------------
-- Main draw
---------------------------------------------------------------------------
function draw_menu()
    theme.set_body_bg(5, 15, 25, 255)
    if not menu.is_visible() then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local dt = ctx.delta()

    local page = menu.page_name()
    if page ~= last_page then last_page = page; scroll = 0; scroll_target = 0 end
    local sel = menu.selected_index()
    local sel_changed = (sel ~= last_sel)
    last_sel = sel

    local count = menu.item_count()
    local slot_h_calc = l.item_h + l.item_gap
    local content_h = count * slot_h_calc
    local list_h = math.min(l.list_max_h, content_h)
    local card_h = l.header_h + list_h + l.footer_h
    local max_h = l.header_h + l.list_max_h + l.footer_h
    local mx = (sw - l.menu_w) / 2
    local my = math.max(20, (sh - max_h) / 2)

    -- Header drag-to-move: pass natural origin, add returned offset
    local _dox, _doy = menu.drag_header(mx, my, l.menu_w, l.header_h)
    mx = mx + _dox
    my = my + _doy

    frame.menu_x = mx

    -- Background gradient (top teal to bottom lighter teal)
    draw.rect_gradient(mx, my, mx + l.menu_w, my + card_h,
        c.bg_top[1], c.bg_top[2], c.bg_top[3], c.bg_top[4],
        c.bg_top[1], c.bg_top[2], c.bg_top[3], c.bg_top[4],
        c.bg_bot[1], c.bg_bot[2], c.bg_bot[3], c.bg_bot[4],
        c.bg_bot[1], c.bg_bot[2], c.bg_bot[3], c.bg_bot[4])

    local cy = my

    -- Header: page title (on gradient, no dark bar)
    text.draw(font.title, mx + l.pad_x, cy + (l.header_h - text.height(font.title))/2 + l.text_off_y,
        255, 255, 255, 255, page)
    cy = cy + l.header_h
    -- Thin line between header and items
    draw.line(mx, cy, mx + l.menu_w, cy, 0, 0, 0, 80)

    local list_y = cy
    frame.list_y = list_y

    -- Scroll
    local scroll_max = math.max(0, content_h - list_h)
    if sel_changed then
        local st = sel * slot_h_calc
        local sb = st + slot_h_calc
        if sb > scroll_target + list_h then scroll_target = sb - list_h end
        if st < scroll_target then scroll_target = st end
    end
    scroll_target = clamp(scroll_target, 0, scroll_max)
    scroll = lerp(scroll, scroll_target, clamp(dt * 14, 0, 1))

    -- Mouse wheel
    local imx, imy = input.mouse_x(), input.mouse_y()
    local in_list = imx >= mx and imx <= mx + l.menu_w and imy >= list_y and imy <= list_y + list_h
    if in_list and menu.popup_mode() == 0 then
        local wh = input.mouse_wheel()
        if wh ~= 0 then scroll_target = clamp(scroll_target - wh * slot_h_calc * 3, 0, scroll_max) end
    end

    -- Items
    draw.push_clip(mx, list_y, mx + l.menu_w, list_y + list_h)

    local slot_h = l.item_h + l.item_gap  -- total height per item slot (bar + gap)

    for i = 0, count - 1 do
        local item = menu.get_item(i)
        if not item then goto cont end
        local is_sel = (i == sel)
        local iy = list_y + i * slot_h - scroll
        if iy + l.item_h < list_y or iy > list_y + slot_h * count then goto cont end

        -- Item bar (horizontal gradient, alternating dark/teal — no special bg for selected)
        local bl, br
        if i % 2 == 0 then bl = c.bar_dark_l; br = c.bar_dark_r
        else bl = c.bar_teal_l; br = c.bar_teal_r end

        draw.rect_gradient(mx, iy, mx + l.menu_w, iy + l.item_h,
            bl[1], bl[2], bl[3], bl[4],
            br[1], br[2], br[3], br[4],
            br[1], br[2], br[3], br[4],
            bl[1], bl[2], bl[3], bl[4])

        if is_sel then
            frame.popup_item_y = iy + l.item_h
            menu.set_popup_item_y(iy + l.item_h)
        end

        -- Hover
        local hovered = in_list and imy >= iy and imy <= iy + l.item_h
        if hovered and not is_sel then
            draw.rect(mx, iy, mx + l.menu_w, iy + l.item_h, 255,255,255, 8)
        end
        if hovered and input.mouse_clicked(0) and menu.popup_mode() == 0 then
            if is_sel then menu.activate() else menu.set_selected(i) end
        end

        -- Star icon
        local sc = is_sel and c.star_sel or c.star
        text.draw(font.small, mx + l.pad_x, iy + (l.item_h - text.height(font.small))/2, sc[1], sc[2], sc[3], sc[4], star)

        -- Item name (selected uses bigger font)
        local tc = is_sel and c.text_sel or c.text
        local fn = is_sel and font.breadcrumb or font.item
        text.draw(fn, mx + l.pad_x + l.star_pad, iy + (l.item_h - text.height(fn))/2 + l.text_off_y,
            tc[1], tc[2], tc[3], tc[4], item.name)

        -- Hotkey badge
        if item.hotkey and item.hotkey ~= 0 then
            local kn = menu.vk_name(item.hotkey)
            local nw = text.width(font.item, item.name)
            local bw = text.width(font.tiny, kn)
            local bx = mx + l.pad_x + l.star_pad + nw + 5
            local by = iy + (l.item_h - text.height(font.tiny))/2
            draw.rect(bx - 2, by - 1, bx + bw + 2, by + text.height(font.tiny) + 1, 0,0,0, 40)
            text.draw(font.tiny, bx, by, 255,255,0, is_sel and 200 or 80, kn)
        end

        -- Widget
        draw_widget(mx + l.menu_w - l.pad_x, iy + l.item_h/2, item, is_sel)

        ::cont::
    end
    draw.pop_clip()
    cy = list_y + list_h

    -- Footer
    local fy = cy + (l.footer_h - text.height(font.small))/2
    text.draw(font.small, mx + l.pad_x, fy + l.text_off_y, c.text_footer[1], c.text_footer[2], c.text_footer[3], c.text_footer[4], "Ver: 1.0")
    local counter = string.format("%d / %d", sel + 1, count)
    local cntw = text.width(font.small, counter)
    text.draw(font.small, mx + l.menu_w - l.pad_x - cntw, fy + l.text_off_y, c.text_footer[1], c.text_footer[2], c.text_footer[3], c.text_footer[4], counter)

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

    local sel = menu.selected_index()
    local item = menu.get_item(sel)
    if not item then return end
    local t = item.type

    if input.key_just_pressed(VK.SPACE) then
        if t == item_type.input_text or t == item_type.input_int or t == item_type.input_float
            or t == item_type.search
            or t == item_type.slider or t == item_type.int_option
            or t == item_type.float_toggle or t == item_type.int_toggle then
            menu.open_input_popup()
        end
    end

    if input.key_just_pressed(0x48) and t ~= item_type.sub_menu then
        menu.set_popup_mode(4)
    end
    if input.key_just_pressed(VK.DELETE) and item.hotkey and item.hotkey ~= 0 then
        menu.set_hotkey(sel, 0)
        notify.push(item.name, str.cleared, 0)
        menu.save_hotkeys()
        menu.rebuild_features()
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
