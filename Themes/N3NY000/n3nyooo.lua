-- N3NYOOO Theme — Custom assets version

-- Load assets (runs once)
local header_img = draw.load_image("themes/N3NY000/header/Header.gif")
local selected_img = draw.load_image("themes/N3NY000/scroller/Selected.png")
-- footer/options images not used (rect drawn instead)
-- local footer_img = draw.load_image("themes/N3NY000/scroller/Footer.png")
-- local options_img = draw.load_image("themes/N3NY000/scroller/Options.png")
local toggle_on_img = draw.load_image("themes/N3NY000/icons/ToggleOn.png")
local toggle_off_img = draw.load_image("themes/N3NY000/icons/ToggleOff.png")
local arrow_img = draw.load_image("themes/N3NY000/icons/RightArrow.png")
local locked_img = draw.load_image("themes/N3NY000/icons/Locked.png")
local info_img = draw.load_image("themes/N3NY000/icons/Info.png")
local arrows_img = draw.load_image("themes/N3NY000/icons/Arrows.png")
local tick_img = draw.load_image("textures/tick.png")
local search_img = draw.load_image("textures/search.png")

-- Load custom font (auto-detects family name and sets it active)
text.load_font("themes/N3NY000/fonts/Chalet London.ttf")

-- Font sizes (all same base size, adjust as needed)
local fs = 14
text.set_size(font.title, 36)
text.set_size(font.item, fs)
text.set_size(font.breadcrumb, fs)
text.set_size(font.desc, fs)
text.set_size(font.label, fs)
text.set_size(font.tagline, fs)
text.set_size(font.value, fs)
text.set_size(font.small, fs)
text.set_size(font.tiny, fs - 2)

-- Font weights (100=thin, 300=light, 400=regular, 500=medium, 600=semibold, 700=bold)
local fw = 0
text.set_weight(font.title, 700)
text.set_weight(font.item, fw)
text.set_weight(font.breadcrumb, fw)
text.set_weight(font.desc, fw)
text.set_weight(font.label, fw)
text.set_weight(font.tagline, fw)
text.set_weight(font.value, fw)
text.set_weight(font.small, fw)
text.set_weight(font.tiny, fw)

-- Colors (from ui.json)
local c = {
    bg           = {0, 0, 0, 235},         -- option.background
    selected     = {80, 125, 255, 246},     -- option.selected_option
    borders      = {80, 145, 255, 170},     -- gradient lines
    separator    = {80, 145, 255, 0},     -- line between options (set alpha 0 to hide)
    text         = {255, 255, 255, 255},    -- item text
    text_sel     = {255, 255, 255, 255},    -- item text when selected
    text_sub     = {255, 255, 255, 255},    -- breadcrumb / submenu text
    text_counter = {255, 255, 255, 255},    -- counter text (5/6)
    text_value   = {255, 255, 255, 255},    -- widget values (slider, int, array)
    text_footer  = {255, 255, 255, 255},    -- footer text
    text_desc    = {220, 220, 230, 255},    -- description bar text
    footer_bg    = {0, 0, 0, 255},          -- Footer.footer_rgba
    footer_arrows= {255, 255, 255, 255},   -- footer center arrows icon
    desc_bg      = {0, 0, 0, 255},         -- description bar tint
    icon_arrow   = {255, 255, 255, 255},   -- submenu arrow icon
    icon_toggle  = {255, 255, 255, 255},   -- toggle on/off icons
    icon_info    = {255, 255, 255, 255},   -- info icon in desc bar
    green        = {40, 175, 80, 255},
}

-- Layout
local l = {
    -- Panel sizes
    menu_w       = 430,       -- menu width
    banner_h     = 90,        -- header/banner height
    subtitle_h   = 35,        -- breadcrumb/submenu bar height
    item_h       = 35,        -- option item height
    footer_h     = 35,        -- footer bar height
    desc_h       = 30,        -- description bar height
    list_max_h   = 500,       -- max height of options list

    -- Spacing / padding
    pad_x        = 14,        -- horizontal padding
    desc_gap     = 20,        -- gap between footer and description
    line_h       = 2,         -- gradient line thickness
    scrollbar_w  = 3,         -- scrollbar width
    text_off_y   = 0,         -- text vertical offset (+ moves down, - moves up)

    -- Icon sizes
    arrow_w      = 20,        -- submenu arrow width
    arrow_h      = 20,        -- submenu arrow height
    toggle_w     = 30,        -- toggle icon width
    toggle_h     = 30,        -- toggle icon height
    info_size    = 14,        -- info icon in desc bar
    footer_arrows = 14,       -- arrows icon in footer center
}

-- Register settings
menu.clear_settings()
menu.add_setting_submenu("Colors", "Theme colors")
menu.add_sub_color("Selected", c.selected[1], c.selected[2], c.selected[3], c.selected[4], "Selection highlight")
menu.add_sub_color("Borders", c.borders[1], c.borders[2], c.borders[3], c.borders[4], "Separator lines")
menu.add_sub_color("Background", c.bg[1], c.bg[2], c.bg[3], c.bg[4], "Menu background")

-- State
local scroll = 0
local scroll_target = 0
local nav_time = 0
local last_page = ""
local last_sel = -1
local desc_anim_start = 0
local toggle_anim = {}

-- Helpers
local function lerp(a, b, t) return a + (b - a) * t end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function ease_out(t) t = clamp(t, 0, 1); return 1 - (1 - t)^2 end

-- Draw widget on right side
local function draw_widget(rx, yc, item, idx, is_sel)
    local t = item.type

    if t == item_type.sub_menu then
        if arrow_img > 0 then
            draw.image_colored(arrow_img, rx - l.arrow_w, yc - l.arrow_h/2, rx, yc + l.arrow_h/2, c.icon_arrow[1], c.icon_arrow[2], c.icon_arrow[3], c.icon_arrow[4])
        else
            text.draw(font.value, rx - text.width(font.value, ">"), yc - text.height(font.value)/2, 255,255,255, is_sel and 220 or 120, ">")
        end

    elseif t == item_type.selected_tick then
        -- selected button: draw tick on right (same color logic as arrow icon)
        local tw = l.arrow_h
        if tick_img and tick_img > 0 then
            draw.image_colored(tick_img, rx - tw, yc - tw/2, rx, yc + tw/2, c.icon_arrow[1], c.icon_arrow[2], c.icon_arrow[3], c.icon_arrow[4])
        else
            text.draw(font.value, rx - text.width(font.value, "\xe2\x9c\x93"), yc - text.height(font.value)/2, c.icon_arrow[1], c.icon_arrow[2], c.icon_arrow[3], c.icon_arrow[4], "\xe2\x9c\x93")
        end

    elseif t == item_type.toggle or t == item_type.float_toggle or t == item_type.int_toggle
        or t == item_type.array_toggle or t == item_type.loop_toggle then
        local img = item.on and toggle_on_img or toggle_off_img
        if img > 0 then
            draw.image_colored(img, rx - l.toggle_w, yc - l.toggle_h/2, rx, yc + l.toggle_h/2, c.icon_toggle[1], c.icon_toggle[2], c.icon_toggle[3], c.icon_toggle[4])
        else
            local txt = item.on and "Enable" or "Off"
            local col = item.on and c.text or {120, 125, 135, 190}
            local tw = text.width(font.value, txt)
            text.draw(font.value, rx - tw, yc - text.height(font.value)/2, col[1], col[2], col[3], col[4] or 255, txt)
        end

    elseif t == item_type.slider then
        local sw = 140
        local th = 4
        local sx = rx - sw
        local sy = yc - 2
        local frac = 0
        if item.f_max > item.f_min then frac = clamp((item.f_val - item.f_min) / (item.f_max - item.f_min), 0, 1) end
        draw.rect(sx, sy, sx + sw - 46, sy + th, 255,255,255, is_sel and 38 or 10)
        if frac > 0 then
            draw.rect(sx, sy, sx + (sw-46)*frac, sy + th, c.selected[1], c.selected[2], c.selected[3], 255)
        end
        local vs = string.format("%.1f", item.f_val)
        local vw = text.width(font.breadcrumb, vs)
        text.draw(font.breadcrumb, rx - vw, yc - text.height(font.breadcrumb)/2, c.text_value[1], c.text_value[2], c.text_value[3], is_sel and 255 or 153, vs)

    elseif t == item_type.int_option then
        local vs = tostring(item.i_val)
        local vw = text.width(font.value, vs)
        text.draw(font.value, rx - vw, yc - text.height(font.value)/2, c.text_value[1], c.text_value[2], c.text_value[3], is_sel and 204 or 77, vs)

    elseif t == item_type.array_option or t == item_type.loop_option then
        local vt = item.current_value or "?"
        local vw = text.width(font.value, vt)
        text.draw(font.value, rx - vw, yc - text.height(font.value)/2, c.text_value[1], c.text_value[2], c.text_value[3], is_sel and 204 or 77, vt)

    elseif t == item_type.color then
        local s = 20
        draw.rect(rx - s, yc - s/2, rx, yc + s/2, item.r, item.g, item.b, item.a or 255)
        draw.rect_outline(rx - s - 1, yc - s/2 - 1, rx + 1, yc + s/2 + 1, 255,255,255, is_sel and 77 or 20)

    elseif t == item_type.search then
        -- search icon on the right, query text (or dim placeholder) to its left
        local iw = l.arrow_w
        if search_img and search_img > 0 then
            draw.image_colored(search_img, rx - iw, yc - iw/2, rx, yc + iw/2,
                c.icon_arrow[1], c.icon_arrow[2], c.icon_arrow[3], c.icon_arrow[4])
        end
        local q = (item.text and item.text ~= "") and item.text or "Search\xe2\x80\xa6"
        local has_q = item.text and item.text ~= ""
        local qa = has_q and (is_sel and c.text_sel[4] or c.text_value[4]) or 77
        local qr = has_q and c.text_value[1] or 180
        local qg = has_q and c.text_value[2] or 180
        local qb = has_q and c.text_value[3] or 180
        local qw = text.width(font.value, q)
        text.draw(font.value, rx - iw - 6 - qw, yc - text.height(font.value)/2, qr, qg, qb, qa, q)
    end
end

-- Stored frame data
local frame = { popup_item_y = 300, menu_x = 0, list_y = 0 }

---------------------------------------------------------------------------
-- Popups & Notifications (must be defined before draw_menu/handle_input)
---------------------------------------------------------------------------

local input_cursor = 0
local input_blink = 0
local input_open_time = 0

local function draw_input_popup()
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    draw.rect(0, 0, sw, sh, 0, 0, 0, 128)
    local pw, ph = 360, 120
    local px, py = (sw-pw)/2, (sh-ph)/2
    draw.rect(px, py, px+pw, py+ph, c.bg[1], c.bg[2], c.bg[3], 255, 6)
    draw.rect_outline(px, py, px+pw, py+ph, c.selected[1], c.selected[2], c.selected[3], 80, 6)
    local item = menu.get_item(menu.input_target_item())
    text.draw(font.label, px+22, py+20, c.selected[1], c.selected[2], c.selected[3], 128, item and item.name or str.edit_value)
    local buf = menu.get_input_buffer()
    draw.rect(px+16, py+44, px+pw-16, py+76, 255,255,255, 8, 4)
    text.draw(font.item, px+24, py+50, 255,255,255,255, buf)
    if math.fmod(ctx.time() - input_blink, 1.0) < 0.55 then
        local cw = text.width(font.item, buf:sub(1, input_cursor))
        draw.rect(px+24+cw, py+48, px+24+cw+1.5, py+72, c.selected[1], c.selected[2], c.selected[3], 255)
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

-- Array dropdown
local array_idx = 0
local array_open_time = 0

local function draw_array_dropdown()
    local sel = menu.selected_index()
    local item = menu.get_item(sel)
    if not item or item.value_count <= 0 then menu.set_popup_mode(0); return end
    local values = menu.get_item_values(sel)
    if not values then menu.set_popup_mode(0); return end
    local dw, dih = 220, 34
    local dh = math.min(#values * dih, dih * 7)
    local dx = frame.menu_x + l.menu_w - dw
    local dy = frame.popup_item_y or 300
    if dy + dh > ctx.screen_h() - 10 then dy = dy - dh - l.item_h end
    draw.rect(dx, dy, dx+dw, dy+dh, c.bg[1], c.bg[2], c.bg[3], 255, 6)
    draw.rect_outline(dx, dy, dx+dw, dy+dh, c.selected[1], c.selected[2], c.selected[3], 80, 6)
    local mx, my = input.mouse_x(), input.mouse_y()
    for i = 1, #values do
        local iy = dy + (i-1)*dih
        local hov = mx >= dx and mx <= dx+dw and my >= iy and my <= iy+dih
        if hov then array_idx = i-1 end
        if (i-1) == array_idx then
            draw.rect(dx, iy, dx+dw, iy+dih, c.selected[1], c.selected[2], c.selected[3], 255, 0)
        end
        local tc = ((i-1)==array_idx) and 255 or 115
        text.draw(font.value, dx+14, iy+(dih-text.height(font.value))/2, 255,255,255, tc, values[i])
        if (i-1) == item.value_index then
            text.draw(font.value, dx+dw-24, iy+(dih-text.height(font.value))/2, c.selected[1], c.selected[2], c.selected[3], 180, "v")
        end
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
        if input.mouse_clicked(0) and elapsed > 0.15 then
            local dx = frame.menu_x + l.menu_w - 220
            local dy = frame.popup_item_y or 300
            local mx, my = input.mouse_x(), input.mouse_y()
            if mx >= dx and mx <= dx+220 then
                local idx = math.floor((my - dy) / 34)
                if idx >= 0 and idx < item.value_count then menu.set_value_index(menu.selected_index(), idx); menu.set_popup_mode(0) end
            else menu.set_popup_mode(0) end
        end
    end
end

local orig_open_array = menu.open_array_popup
menu.open_array_popup = function()
    orig_open_array()
    local item = menu.get_item(menu.selected_index())
    array_idx = item and item.value_index or 0
    array_open_time = ctx.time()
end

-- Hotkey bind
local function draw_hotkey_popup()
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    draw.rect(0, 0, sw, sh, 0, 0, 0, 128)
    local pw, ph = 280, 70
    local px, py = (sw-pw)/2, (sh-ph)/2
    draw.rect(px, py, px+pw, py+ph, c.bg[1], c.bg[2], c.bg[3], 255, 6)
    draw.rect_outline(px, py, px+pw, py+ph, c.selected[1], c.selected[2], c.selected[3], 80, 6)
    local tw = text.width(font.item, str.press_key)
    text.draw(font.item, px+(pw-tw)/2, py+16, 255,255,255,230, str.press_key)
    local hw = text.width(font.desc, str.esc_cancel)
    text.draw(font.desc, px+(pw-hw)/2, py+40, 255,255,255,77, str.esc_cancel)
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

-- Color picker
local cp_tab = 0
local cp_idx = 0
local cp_hue, cp_sat, cp_val = 0, 1, 1
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
    local pw, ph = 380, 300
    local px, py = (sw-pw)/2, (sh-ph)/2
    draw.rect(px, py, px+pw, py+ph, c.bg[1], c.bg[2], c.bg[3], 255, 6)
    draw.rect_outline(px, py, px+pw, py+ph, c.selected[1], c.selected[2], c.selected[3], 80, 6)
    local cell, gap = 36, 4
    local gx, gy = px + 18, py + 18
    local mx, my = input.mouse_x(), input.mouse_y()
    for i = 1, 32 do
        local col = ((i-1)%8)
        local row = math.floor((i-1)/8)
        local cx = gx + col*(cell+gap)
        local cy = gy + row*(cell+gap)
        draw.rect(cx, cy, cx+cell, cy+cell, palette[i][1], palette[i][2], palette[i][3], 255, 4)
        if cp_idx == i-1 then draw.rect_outline(cx-2, cy-2, cx+cell+2, cy+cell+2, 255,255,255, 200, 4) end
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
    theme.set_body_bg(0, 0, 0, 255)
    if not menu.is_visible() then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local time = ctx.time()
    local dt = ctx.delta()

    local page = menu.page_name()
    if page ~= last_page then last_page = page; nav_time = time; scroll = 0; scroll_target = 0 end
    local sel = menu.selected_index()
    local sel_changed = (sel ~= last_sel)
    if sel_changed then desc_anim_start = time end

    local count = menu.item_count()
    local content_h = count * l.item_h
    local list_h = math.min(l.list_max_h, content_h)
    local card_h = l.banner_h + l.subtitle_h + list_h + l.footer_h
    local max_h = l.banner_h + l.subtitle_h + l.list_max_h + l.footer_h + 6 + l.desc_h
    local mx = (sw - l.menu_w) / 2
    local my = math.max(20, (sh - max_h) / 2)

    -- Header drag-to-move: pass natural origin, add returned offset
    local _dox, _doy = menu.drag_header(mx, my, l.menu_w, l.banner_h)
    mx = mx + _dox
    my = my + _doy

    frame.menu_x = mx

    -- Semi-transparent background behind entire menu (no border, no rounding)
    draw.rect(mx, my, mx + l.menu_w, my + card_h, c.bg[1], c.bg[2], c.bg[3], c.bg[4])

    local cy = my

    -- Banner (animated header image)
    draw.push_clip(mx, cy, mx + l.menu_w, cy + l.banner_h)
    if header_img > 0 then
        draw.image(header_img, mx, cy, mx + l.menu_w, cy + l.banner_h)
    else
        draw.rect(mx, cy, mx + l.menu_w, cy + l.banner_h, 15, 20, 35, 250)
        local tw = text.width_spaced(font.title, "N3NYOOO", 4)
        text.draw_spaced(font.title, mx + (l.menu_w - tw)/2, cy + 28, 255,255,255,255, "N3NYOOO", 4)
    end
    draw.pop_clip()
    cy = cy + l.banner_h

    -- Breadcrumb bar
    draw.rect(mx, cy, mx + l.menu_w, cy + l.subtitle_h, c.bg[1], c.bg[2], c.bg[3], c.bg[4])
    text.draw(font.breadcrumb, mx + l.pad_x, cy + (l.subtitle_h - text.height(font.breadcrumb))/2 + l.text_off_y, c.text_sub[1], c.text_sub[2], c.text_sub[3], c.text_sub[4], page)
    local counter = string.format("%d / %d", sel + 1, count)
    local cw = text.width(font.tagline, counter)
    text.draw(font.tagline, mx + l.menu_w - l.pad_x - cw, cy + (l.subtitle_h - text.height(font.tagline))/2 + l.text_off_y, c.text_counter[1], c.text_counter[2], c.text_counter[3], c.text_counter[4], counter)
    -- Gradient line below breadcrumb
    draw.rect_gradient(mx, cy + l.subtitle_h - l.line_h, mx + l.menu_w, cy + l.subtitle_h,
        c.borders[1], c.borders[2], c.borders[3], 0,
        c.borders[1], c.borders[2], c.borders[3], 255,
        c.borders[1], c.borders[2], c.borders[3], 255,
        c.borders[1], c.borders[2], c.borders[3], 0)
    cy = cy + l.subtitle_h

    local list_y = cy
    frame.list_y = list_y

    -- Scroll
    local scroll_max = math.max(0, content_h - list_h)
    if sel_changed then
        local st = sel * l.item_h
        local sb = st + l.item_h
        if sb > scroll_target + list_h then scroll_target = sb - list_h end
        if st < scroll_target then scroll_target = st end
        last_sel = sel
    end
    scroll_target = clamp(scroll_target, 0, scroll_max)
    scroll = lerp(scroll, scroll_target, clamp(dt * 14, 0, 1))

    -- Mouse wheel
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
        local is_sel = (i == sel)
        local iy = list_y + i * l.item_h - scroll
        if iy + l.item_h < list_y or iy > list_y + list_h then goto cont end

        if is_sel then
            frame.popup_item_y = iy + l.item_h
            menu.set_popup_item_y(iy + l.item_h)
            if c.selected[4] > 0 then
                draw.rect(mx, iy, mx + l.menu_w, iy + l.item_h, c.selected[1], c.selected[2], c.selected[3], c.selected[4])
            end
        end

        -- Hover
        local hovered = in_list and imy >= iy and imy <= iy + l.item_h
        if hovered and not is_sel then
            draw.rect(mx, iy, mx + l.menu_w, iy + l.item_h, 255,255,255, 8)
        end

        -- Click
        if hovered and input.mouse_clicked(0) and menu.popup_mode() == 0 then
            if is_sel then
                if item.type == item_type.search then
                    menu.set_input_buffer(item.text or "")
                end
                menu.activate()
            else menu.set_selected(i) end
        end

        -- Name
        local tc = is_sel and c.text_sel or c.text
        text.draw(font.item, mx + l.pad_x, iy + (l.item_h - text.height(font.item))/2 + l.text_off_y, tc[1], tc[2], tc[3], tc[4], item.name)

        -- Hotkey badge
        if item.hotkey and item.hotkey ~= 0 then
            local kn = menu.vk_name(item.hotkey)
            local nw = text.width(font.item, item.name)
            local bw = text.width(font.tiny, kn)
            local bx = mx + l.pad_x + nw + 6
            local by = iy + (l.item_h - text.height(font.tiny))/2
            draw.rect(bx - 2, by - 1, bx + bw + 2, by + text.height(font.tiny) + 1, c.selected[1], c.selected[2], c.selected[3], is_sel and 50 or 15)
            text.draw(font.tiny, bx, by, c.selected[1], c.selected[2], c.selected[3], is_sel and 200 or 60, kn)
        end

        -- Widget
        draw_widget(mx + l.menu_w - l.pad_x, iy + l.item_h/2, item, i, is_sel)

        -- Separator line between items
        if i < count - 1 then
            draw.line(mx, iy + l.item_h, mx + l.menu_w, iy + l.item_h, c.separator[1], c.separator[2], c.separator[3], c.separator[4])
        end

        ::cont::
    end
    draw.pop_clip()

    -- Scrollbar indicator (right side)
    if scroll_max > 0 then
        local sb_w = l.scrollbar_w
        local sb_track_h = list_h
        local sb_thumb_h = math.max(20, sb_track_h * (list_h / content_h))
        local sb_frac = scroll / scroll_max
        local sb_y = list_y + sb_frac * (sb_track_h - sb_thumb_h)
        draw.rect(mx + l.menu_w - sb_w, sb_y, mx + l.menu_w, sb_y + sb_thumb_h,
            c.selected[1], c.selected[2], c.selected[3], 180)
    end

    cy = list_y + list_h

    -- Footer bar (solid black per ui.json)
    draw.rect(mx, cy, mx + l.menu_w, cy + l.footer_h, c.footer_bg[1], c.footer_bg[2], c.footer_bg[3], c.footer_bg[4])
    -- Gradient line on top edge of footer
    draw.rect_gradient(mx, cy, mx + l.menu_w, cy + l.line_h,
        c.borders[1], c.borders[2], c.borders[3], 0,
        c.borders[1], c.borders[2], c.borders[3], 255,
        c.borders[1], c.borders[2], c.borders[3], 255,
        c.borders[1], c.borders[2], c.borders[3], 0)
    local fy = cy + (l.footer_h - text.height(font.small)) / 2 + l.text_off_y
    text.draw(font.small, mx + l.pad_x, fy, c.text_footer[1], c.text_footer[2], c.text_footer[3], c.text_footer[4], "Build V13a")
    -- Center: Arrows.png rotated 90 degrees
    local aw = l.footer_arrows
    local fcx = mx + l.menu_w / 2
    local fcy = cy + l.footer_h / 2 + 2
    if arrows_img > 0 then
        draw.image_rotated(arrows_img, fcx - aw/2, fcy - aw/2, fcx + aw/2, fcy + aw/2, 90,
            c.footer_arrows[1], c.footer_arrows[2], c.footer_arrows[3], c.footer_arrows[4])
    end
    local rtext = "Release"
    local rw = text.width(font.small, rtext)
    text.draw(font.small, mx + l.menu_w - l.pad_x - rw, fy, c.text_footer[1], c.text_footer[2], c.text_footer[3], c.text_footer[4], rtext)
    cy = cy + l.footer_h

    -- Gap between footer and description
    cy = cy + l.desc_gap

    -- Description bar (separate box, gray transparent with blue gradient top line)
    draw.rect(mx, cy, mx + l.menu_w, cy + l.desc_h, c.desc_bg[1], c.desc_bg[2], c.desc_bg[3], c.desc_bg[4])
    draw.rect_gradient(mx, cy, mx + l.menu_w, cy + l.line_h,
        c.borders[1], c.borders[2], c.borders[3], 0,
        c.borders[1], c.borders[2], c.borders[3], 255,
        c.borders[1], c.borders[2], c.borders[3], 255,
        c.borders[1], c.borders[2], c.borders[3], 0)
    local desc_item = menu.get_item(sel)
    if desc_item then
        local dty = cy + (l.desc_h - text.height(font.desc)) / 2 + l.text_off_y
        if info_img > 0 then
            draw.image_colored(info_img, mx + l.pad_x, cy + (l.desc_h - l.info_size)/2, mx + l.pad_x + l.info_size, cy + (l.desc_h + l.info_size)/2, c.icon_info[1], c.icon_info[2], c.icon_info[3], c.icon_info[4])
        else
            draw.rect(mx + l.pad_x, dty + 1, mx + l.pad_x + l.info_size, dty + 1 + l.info_size, c.green[1], c.green[2], c.green[3], 255)
        end
        local dtx = mx + l.pad_x + l.info_size + 6
        local desc_str = desc_item.desc and #desc_item.desc > 0
            and (desc_item.name .. " \xe2\x80\x94 " .. desc_item.desc)
            or desc_item.name
        text.draw(font.desc, dtx, dty, c.text_desc[1], c.text_desc[2], c.text_desc[3], c.text_desc[4], desc_str)
    end

    -- Popups
    local pm = menu.popup_mode()
    if pm == 1 then draw_input_popup() end
    if pm == 2 then draw_color_picker() end
    if pm == 3 then draw_array_dropdown() end
    if pm == 4 then draw_hotkey_popup() end
end

---------------------------------------------------------------------------
-- Input handler
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

    if input.key_just_pressed(0x48) and t ~= item_type.sub_menu then -- H
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
