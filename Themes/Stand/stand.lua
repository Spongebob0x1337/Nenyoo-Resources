-- Stand Theme — Sidebar layout

-- Load assets
local arrow_img = draw.load_image("themes/Stand/icons/RightArrow.png")
local toggle_on_img = draw.load_image("themes/Stand/icons/ToggleOn.png")
local toggle_off_img = draw.load_image("themes/Stand/icons/ToggleOff.png")
local tick_img = draw.load_image("textures/tick.png")
local search_img = draw.load_image("textures/search.png")

-- Load font
text.load_font("themes/Stand/fonts/Chalet London.ttf")

-- Font sizes
local fs = 16
text.set_size(font.title, 16)
text.set_size(font.item, fs)
text.set_size(font.breadcrumb, fs)
text.set_size(font.desc, fs - 1)
text.set_size(font.label, fs)
text.set_size(font.tagline, fs)
text.set_size(font.value, fs)
text.set_size(font.small, fs)
text.set_size(font.tiny, fs - 2)

-- Font weights
local fw = 0
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
    bg           = {0, 0, 0, 100},
    accent       = {255, 0, 180, 255},      -- magenta/pink
    sidebar_bg   = {0, 0, 0, 230},
    sidebar_sel  = {255, 0, 180, 255},
    sidebar_text = {255, 255, 255, 180},
    sidebar_text_sel = {255, 255, 255, 255},
    title_bg     = {30, 30, 40, 240},
    title_text   = {255, 255, 255, 200},
    text         = {255, 255, 255, 220},
    text_sel     = {255, 255, 255, 255},
    text_value   = {255, 255, 255, 180},
    text_desc    = {255, 255, 255, 140},
    separator    = {255, 255, 255, 8},
    desc_bg      = {0, 0, 0, 100},
    scrollbar    = {255, 0, 180, 150},
    icon_arrow   = {255, 255, 255, 200},
    icon_toggle  = {255, 255, 255, 255},
}

-- Layout
local l = {
    sidebar_w    = 120,       -- sidebar width
    content_w    = 380,       -- content area width
    title_h      = 32,        -- title bar height
    item_h       = 32,        -- option item height
    tab_h        = 32,        -- sidebar tab height
    desc_h       = 28,        -- description bar height
    list_max_h   = 11 * 32,   -- exactly 11 items visible (11 * item_h)
    pad_x        = 12,        -- horizontal padding
    title_gap    = 4,         -- gap between title bar and sidebar/content
    sidebar_gap  = 4,         -- gap between sidebar and content
    desc_gap     = 2,         -- gap before desc
    scrollbar_w  = 3,
    arrow_w      = 22,
    arrow_h      = 22,
    toggle_w     = 22,
    toggle_h     = 22,
    text_off_y   = 0,
}

-- Sidebar tabs — map to top-level page names
local tabs = {
    {label = "Online",  page = "Network"},
    {label = "Weapons", page = "Weapon"},
    {label = "Settings",page = "Settings"},
}

-- Register settings
menu.clear_settings()
menu.add_setting_submenu("Colors", "Theme colors")
menu.add_sub_color("Accent", c.accent[1], c.accent[2], c.accent[3], 255, "Accent color")
menu.add_sub_color("Background", c.bg[1], c.bg[2], c.bg[3], c.bg[4], "Menu background")

-- State
local scroll = 0
local scroll_target = 0
local last_page = ""
local last_sel = -1

-- Helpers
local function lerp(a, b, t) return a + (b - a) * t end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function ease_out(t) t = clamp(t, 0, 1); return 1 - (1 - t)^2 end

-- Find which tab the current page belongs to
local function active_tab_index()
    local page = menu.page_name()
    local parent = menu.page_parent()
    -- Direct match
    for i, t in ipairs(tabs) do
        if page == t.page then return i end
    end
    -- Parent match
    for i, t in ipairs(tabs) do
        if parent == t.page or parent == "Home" then
            -- Check if this page is a child of the tab's page
            if page == t.page then return i end
        end
    end
    -- Walk: if parent matches a tab
    for i, t in ipairs(tabs) do
        if parent == t.page then return i end
    end
    -- Home page — no tab active
    return 0
end

-- Draw widget on right side
local function draw_widget(rx, yc, item, idx, is_sel)
    local t = item.type

    if t == item_type.sub_menu then
        if arrow_img > 0 then
            draw.image_colored(arrow_img, rx - l.arrow_w, yc - l.arrow_h/2, rx, yc + l.arrow_h/2,
                c.icon_arrow[1], c.icon_arrow[2], c.icon_arrow[3], c.icon_arrow[4])
        else
            text.draw(font.value, rx - text.width(font.value, ">"), yc - text.height(font.value)/2, 255,255,255, is_sel and 255 or 120, ">")
        end

    elseif t == item_type.selected_tick then
        if tick_img and tick_img > 0 then
            draw.image_colored(tick_img, rx - l.arrow_w, yc - l.arrow_h/2, rx, yc + l.arrow_h/2,
                c.icon_arrow[1], c.icon_arrow[2], c.icon_arrow[3], c.icon_arrow[4])
        else
            text.draw(font.value, rx - text.width(font.value, "✓"), yc - text.height(font.value)/2, 255,255,255, is_sel and 255 or 120, "✓")
        end

    elseif t == item_type.toggle or t == item_type.float_toggle or t == item_type.int_toggle
        or t == item_type.array_toggle or t == item_type.loop_toggle then
        if toggle_on_img > 0 and toggle_off_img > 0 then
            local img = item.on and toggle_on_img or toggle_off_img
            draw.image_colored(img, rx - l.toggle_w, yc - l.toggle_h/2, rx, yc + l.toggle_h/2,
                c.icon_toggle[1], c.icon_toggle[2], c.icon_toggle[3], c.icon_toggle[4])
        else
            local txt = item.on and "On" or "Off"
            local col = item.on and c.accent or c.text_value
            text.draw(font.value, rx - text.width(font.value, txt), yc - text.height(font.value)/2, col[1], col[2], col[3], col[4], txt)
        end

    elseif t == item_type.slider then
        local sw = 100
        local th = 3
        local sx = rx - sw
        local sy = yc - th/2
        local frac = 0
        if item.f_max > item.f_min then frac = clamp((item.f_val - item.f_min) / (item.f_max - item.f_min), 0, 1) end
        draw.rect(sx, sy, sx + sw - 36, sy + th, 255,255,255, 20)
        if frac > 0 then
            draw.rect(sx, sy, sx + (sw-36)*frac, sy + th, c.accent[1], c.accent[2], c.accent[3], 255)
        end
        local vs = string.format("%.1f", item.f_val)
        local vw = text.width(font.value, vs)
        text.draw(font.value, rx - vw, yc - text.height(font.value)/2, c.text_value[1], c.text_value[2], c.text_value[3], is_sel and 255 or 140, vs)

    elseif t == item_type.int_option then
        local vs = tostring(item.i_val)
        local vw = text.width(font.value, vs)
        text.draw(font.value, rx - vw, yc - text.height(font.value)/2, c.text_value[1], c.text_value[2], c.text_value[3], is_sel and 255 or 140, vs)

    elseif t == item_type.array_option or t == item_type.loop_option then
        local vt = item.current_value or "?"
        local vw = text.width(font.value, vt)
        text.draw(font.value, rx - vw, yc - text.height(font.value)/2, c.text_value[1], c.text_value[2], c.text_value[3], is_sel and 255 or 140, vt)

    elseif t == item_type.color then
        local s = 14
        draw.rect(rx - s, yc - s/2, rx, yc + s/2, item.r, item.g, item.b, item.a or 255)

    elseif t == item_type.search then
        -- search icon on right
        local iw = l.arrow_w
        if search_img and search_img > 0 then
            draw.image_colored(search_img, rx - iw, yc - l.arrow_h/2, rx, yc + l.arrow_h/2,
                c.icon_arrow[1], c.icon_arrow[2], c.icon_arrow[3], c.icon_arrow[4])
        else
            text.draw(font.value, rx - text.width(font.value, "[S]"), yc - text.height(font.value)/2,
                c.accent[1], c.accent[2], c.accent[3], 200, "[S]")
            iw = text.width(font.value, "[S]")
        end
        -- query text or placeholder to the left of the icon
        local q = (item.text and item.text ~= "") and item.text or "Search…"
        local qcol = (item.text and item.text ~= "") and c.text_value or {c.text_value[1], c.text_value[2], c.text_value[3], 80}
        local qw = text.width(font.value, q)
        text.draw(font.value, rx - iw - 6 - qw, yc - text.height(font.value)/2,
            qcol[1], qcol[2], qcol[3], qcol[4], q)
    end
end

-- Stored frame data
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
    local pw, ph = 340, 110
    local px, py = (sw-pw)/2, (sh-ph)/2
    draw.rect(px, py, px+pw, py+ph, c.bg[1], c.bg[2], c.bg[3], 255)
    local item = menu.get_item(menu.input_target_item())
    text.draw(font.label, px+16, py+14, c.accent[1], c.accent[2], c.accent[3], 200, item and item.name or str.edit_value)
    local buf = menu.get_input_buffer()
    draw.rect(px+12, py+38, px+pw-12, py+64, 255,255,255, 8)
    text.draw(font.item, px+18, py+43, 255,255,255,255, buf)
    if math.fmod(ctx.time() - input_blink, 1.0) < 0.55 then
        local cw = text.width(font.item, buf:sub(1, input_cursor))
        draw.rect(px+18+cw, py+41, px+18+cw+1.5, py+62, c.accent[1], c.accent[2], c.accent[3], 255)
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
    local dx = frame.menu_x + l.sidebar_w + l.content_w - dw
    local dy = frame.popup_item_y or 300
    if dy + dh > ctx.screen_h() - 10 then dy = dy - dh - l.item_h end
    draw.rect(dx, dy, dx+dw, dy+dh, c.bg[1], c.bg[2], c.bg[3], 255)
    local mx, my = input.mouse_x(), input.mouse_y()
    for i = 1, #values do
        local iy = dy + (i-1)*dih
        local hov = mx >= dx and mx <= dx+dw and my >= iy and my <= iy+dih
        if hov then array_idx = i-1 end
        if (i-1) == array_idx then
            draw.rect(dx, iy, dx+dw, iy+dih, c.accent[1], c.accent[2], c.accent[3], 255)
        end
        text.draw(font.value, dx+8, iy+(dih-text.height(font.value))/2, 255,255,255, ((i-1)==array_idx) and 255 or 140, values[i])
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
    draw.rect(px, py, px+pw, py+ph, c.bg[1], c.bg[2], c.bg[3], 255)
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
    draw.rect(px, py, px+pw, py+ph, c.bg[1], c.bg[2], c.bg[3], 255)
    local cell, gap = 32, 4
    local gx, gy = px + 14, py + 14
    local mx, my = input.mouse_x(), input.mouse_y()
    for i = 1, 32 do
        local col = ((i-1)%8)
        local row = math.floor((i-1)/8)
        local cx = gx + col*(cell+gap)
        local cy = gy + row*(cell+gap)
        draw.rect(cx, cy, cx+cell, cy+cell, palette[i][1], palette[i][2], palette[i][3], 255)
        if cp_idx == i-1 then draw.rect_outline(cx-2, cy-2, cx+cell+2, cy+cell+2, 255,255,255, 200) end
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
    if item and item.type == item_type.search then
        menu.set_input_buffer(item.text or "")
        menu.open_input_popup()
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
    local dt = ctx.delta()

    local page = menu.page_name()
    -- Auto-redirect Home to first tab (sidebar IS the main nav)
    if page == "Home" then menu.navigate(tabs[1].page); return end
    if page ~= last_page then last_page = page; scroll = 0; scroll_target = 0 end
    local sel = menu.selected_index()
    local sel_changed = (sel ~= last_sel)
    last_sel = sel

    local count = menu.item_count()
    local content_h = count * l.item_h
    local list_h = math.min(l.list_max_h, content_h)
    local total_w = l.sidebar_w + l.content_w
    local sidebar_h = math.max(#tabs * l.tab_h, l.title_h + list_h)
    local panel_h = l.title_h + list_h + l.desc_gap + l.desc_h
    local max_panel_h = l.title_h + l.list_max_h + l.desc_gap + l.desc_h
    local full_w = l.sidebar_w + l.sidebar_gap + l.content_w
    local mx = (sw - full_w) / 2
    local total_h = l.title_h + l.title_gap + math.max(#tabs * l.tab_h + l.desc_h, l.list_max_h)
    local my = math.max(20 + l.title_h + l.title_gap, (sh - total_h) / 2 + l.title_h + l.title_gap)

    -- Header drag-to-move: pass natural origin, add returned offset
    local _dox, _doy = menu.drag_header(mx, my, full_w, l.title_h)
    mx = mx + _dox
    my = my + _doy

    frame.menu_x = mx

    -- Sidebar
    local sb_x = mx
    local sb_h = #tabs * l.tab_h
    draw.rect(sb_x, my, sb_x + l.sidebar_w, my + sb_h, c.sidebar_bg[1], c.sidebar_bg[2], c.sidebar_bg[3], c.sidebar_bg[4])

    local active_ti = active_tab_index()
    local imx, imy = input.mouse_x(), input.mouse_y()

    for i, t in ipairs(tabs) do
        local ty = my + (i-1) * l.tab_h
        local is_active = (i == active_ti)

        if is_active then
            draw.rect(sb_x, ty, sb_x + l.sidebar_w, ty + l.tab_h, c.sidebar_sel[1], c.sidebar_sel[2], c.sidebar_sel[3], c.sidebar_sel[4])
        end

        -- Hover
        local hov = imx >= sb_x and imx <= sb_x + l.sidebar_w and imy >= ty and imy <= ty + l.tab_h
        if hov and not is_active then
            draw.rect(sb_x, ty, sb_x + l.sidebar_w, ty + l.tab_h, 255,255,255, 8)
        end

        -- Click sidebar tab
        if hov and input.mouse_clicked(0) and menu.popup_mode() == 0 then
            menu.navigate(t.page)
        end

        local tc = is_active and c.sidebar_text_sel or c.sidebar_text
        text.draw(font.small, sb_x + l.pad_x, ty + (l.tab_h - text.height(font.small))/2 + l.text_off_y,
            tc[1], tc[2], tc[3], tc[4], t.label)
    end

    -- Title bar (full width, accent colored)
    local tw_full = l.sidebar_w + l.sidebar_gap + l.content_w
    draw.rect(mx, my - l.title_h - l.title_gap, mx + tw_full, my - l.title_gap, c.accent[1], c.accent[2], c.accent[3], c.accent[4])
    local parent = menu.page_parent()
    local title_str = "Nenyoo > " .. page
    if parent and #parent > 0 and parent ~= "Home" then
        title_str = "Nenyoo > " .. parent .. " > " .. page
    end
    text.draw(font.title, mx + l.pad_x, my - l.title_h - l.title_gap + (l.title_h - text.height(font.title))/2 + l.text_off_y,
        c.title_text[1], c.title_text[2], c.title_text[3], c.title_text[4], title_str)

    -- Content area (offset by sidebar + gap)
    local cx = mx + l.sidebar_w + l.sidebar_gap
    local cy = my

    -- Items background
    draw.rect(cx, cy, cx + l.content_w, cy + list_h, c.bg[1], c.bg[2], c.bg[3], c.bg[4])

    local list_y = cy
    frame.list_y = list_y

    -- Scroll
    local scroll_max = math.max(0, content_h - list_h)
    if sel_changed then
        local st = sel * l.item_h
        local sb = st + l.item_h
        if sb > scroll_target + list_h then scroll_target = sb - list_h end
        if st < scroll_target then scroll_target = st end
    end
    scroll_target = clamp(scroll_target, 0, scroll_max)
    scroll = lerp(scroll, scroll_target, clamp(dt * 14, 0, 1))

    -- Mouse wheel
    local in_list = imx >= cx and imx <= cx + l.content_w and imy >= list_y and imy <= list_y + list_h
    if in_list and menu.popup_mode() == 0 then
        local wh = input.mouse_wheel()
        if wh ~= 0 then scroll_target = clamp(scroll_target - wh * l.item_h * 3, 0, scroll_max) end
    end

    -- Items
    draw.push_clip(cx, list_y, cx + l.content_w, list_y + list_h)

    for i = 0, count - 1 do
        local item = menu.get_item(i)
        if not item then goto cont end
        local is_sel = (i == sel)
        local iy = list_y + i * l.item_h - scroll
        if iy + l.item_h < list_y or iy > list_y + list_h then goto cont end

        if is_sel then
            frame.popup_item_y = iy + l.item_h
            menu.set_popup_item_y(iy + l.item_h)
            draw.rect(cx, iy, cx + l.content_w, iy + l.item_h, c.accent[1], c.accent[2], c.accent[3], c.accent[4])
        end

        local hovered = in_list and imy >= iy and imy <= iy + l.item_h
        if hovered and not is_sel then
            draw.rect(cx, iy, cx + l.content_w, iy + l.item_h, 255,255,255, 6)
        end
        if hovered and input.mouse_clicked(0) and menu.popup_mode() == 0 then
            if item.type == item_type.selected_tick then
                menu.set_selected(i); menu.activate()
            elseif is_sel then menu.activate() else menu.set_selected(i) end
        end

        local tc = is_sel and c.text_sel or c.text
        text.draw(font.item, cx + l.pad_x, iy + (l.item_h - text.height(font.item))/2 + l.text_off_y,
            tc[1], tc[2], tc[3], tc[4], item.name)

        -- Hotkey badge
        if item.hotkey and item.hotkey ~= 0 then
            local kn = menu.vk_name(item.hotkey)
            local nw = text.width(font.item, item.name)
            local bw = text.width(font.tiny, kn)
            local bx = cx + l.pad_x + nw + 5
            local by = iy + (l.item_h - text.height(font.tiny))/2
            draw.rect(bx - 2, by - 1, bx + bw + 2, by + text.height(font.tiny) + 1, c.accent[1], c.accent[2], c.accent[3], is_sel and 60 or 20)
            text.draw(font.tiny, bx, by, c.accent[1], c.accent[2], c.accent[3], is_sel and 200 or 80, kn)
        end

        draw_widget(cx + l.content_w - l.pad_x, iy + l.item_h/2, item, i, is_sel)

        if i < count - 1 then
            draw.line(cx, iy + l.item_h, cx + l.content_w, iy + l.item_h, c.separator[1], c.separator[2], c.separator[3], c.separator[4])
        end

        ::cont::
    end
    draw.pop_clip()

    -- Scrollbar
    if scroll_max > 0 then
        local sb_thumb_h = math.max(16, list_h * (list_h / content_h))
        local sb_frac = scroll / scroll_max
        local sb_y = list_y + sb_frac * (list_h - sb_thumb_h)
        draw.rect(cx + l.content_w, sb_y, cx + l.content_w + l.scrollbar_w, sb_y + sb_thumb_h,
            c.scrollbar[1], c.scrollbar[2], c.scrollbar[3], c.scrollbar[4])
    end

    -- Description bar (only if there's text, expands left to fit)
    local desc_item = menu.get_item(sel)
    local desc_str = desc_item and desc_item.desc and #desc_item.desc > 0 and desc_item.desc or ""
    if #desc_str > 0 then
        local desc_y = my + sb_h + l.desc_gap
        local desc_tw = text.width(font.desc, desc_str) + l.pad_x * 2
        local desc_w = math.max(l.sidebar_w, desc_tw)
        local desc_rx = mx + l.sidebar_w
        draw.rect(desc_rx - desc_w, desc_y, desc_rx, desc_y + l.desc_h, c.desc_bg[1], c.desc_bg[2], c.desc_bg[3], c.desc_bg[4])
        text.draw(font.desc, desc_rx - desc_w + l.pad_x, desc_y + (l.desc_h - text.height(font.desc))/2 + l.text_off_y,
            c.text_desc[1], c.text_desc[2], c.text_desc[3], c.text_desc[4], desc_str)
    end

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
    -- Don't go back to Home — tabs are top level
    if input.key_just_pressed(VK.BACK) or input.key_just_pressed(VK.ESCAPE) then
        local parent = menu.page_parent()
        if parent and parent ~= "Home" and parent ~= "" then
            menu.go_back()
        end
    end

    local sel = menu.selected_index()
    local item = menu.get_item(sel)
    if not item then return end
    local t = item.type

    if input.key_just_pressed(VK.SPACE) then
        if t == item_type.input_text or t == item_type.input_int or t == item_type.input_float
            or t == item_type.slider or t == item_type.int_option
            or t == item_type.float_toggle or t == item_type.int_toggle then
            menu.open_input_popup()
        elseif t == item_type.search then
            menu.set_input_buffer(item.text or "")
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
