-- Lexis Theme — Clean rounded card style

-- Load assets
local arrow_img = draw.load_image("themes/Lexis/icons/RightArrow.png")
local toggle_on_img = draw.load_image("themes/Lexis/icons/On.png")
local toggle_off_img = draw.load_image("themes/Lexis/icons/Off.png")
local logo_img = draw.load_image("themes/Lexis/icons/logo.png")
local tick_img = draw.load_image("textures/tick.png")
local search_img = draw.load_image("textures/search.png")

-- Load font
text.load_font("themes/Lexis/fonts/Roboto-Regular.ttf")

-- Font sizes
local fs = 15
text.set_size(font.title, 22)
text.set_size(font.item, fs)
text.set_size(font.breadcrumb, fs)
text.set_size(font.desc, fs - 1)
text.set_size(font.label, fs)
text.set_size(font.tagline, fs - 1)
text.set_size(font.value, fs)
text.set_size(font.small, 11)
text.set_size(font.tiny, 10)

-- Font weights
local fw = 400
text.set_weight(font.title, 500)
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
    bg           = {18, 16, 26, 240},       -- card background
    selected     = {140, 60, 80, 60},       -- rose/pink highlight
    accent       = {160, 70, 90, 255},      -- accent color
    text         = {220, 220, 225, 255},    -- item text
    text_sel     = {255, 255, 255, 255},    -- selected item text
    text_dim     = {140, 140, 150, 160},    -- dimmed text (dots)
    text_value   = {180, 180, 190, 220},    -- widget values
    text_footer  = {180, 160, 170, 200},    -- footer text
    footer_bg    = {140, 60, 80, 40},       -- footer rose tint
    separator    = {255, 255, 255, 0},      -- item separators (off)
    scrollbar    = {140, 70, 90, 120},      -- scrollbar
    icon_toggle  = {255, 255, 255, 255},    -- toggle icons
    rounding     = 12,                       -- card corner rounding
}

-- Layout
local l = {
    menu_w       = 400,
    header_h     = 80,
    item_h       = 42,
    footer_h     = 36,
    list_max_h   = 10 * 42,
    pad_x        = 18,
    scrollbar_w  = 3,
    toggle_w     = 10,
    toggle_h     = 10,
    text_off_y   = 0,
    logo_size    = 36,
}

-- Register settings
menu.clear_settings()
menu.add_setting_submenu("Colors", "Theme colors")
menu.add_sub_color("Accent", c.accent[1], c.accent[2], c.accent[3], 255, "Accent color")
menu.add_sub_color("Background", c.bg[1], c.bg[2], c.bg[3], c.bg[4], "Card background")

-- Snow particles (configurable)
local snow = {}
local snow_count = 15
local snow_speed_min = 15
local snow_speed_max = 45
local snow_size_min = 1
local snow_size_max = 3.5
local snow_alpha_min = 20
local snow_alpha_max = 60
local snow_drift = 20
for i = 1, snow_count do
    snow[i] = {
        x = math.random() * 1000,
        y = math.random() * 1000,
        speed = snow_speed_min + math.random() * (snow_speed_max - snow_speed_min),
        size = snow_size_min + math.random() * (snow_size_max - snow_size_min),
        alpha = snow_alpha_min + math.random() * (snow_alpha_max - snow_alpha_min),
        drift = (math.random() - 0.5) * snow_drift,
    }
end

-- Tick snow positions (call once per frame with total height from card top to desc bottom)
local function tick_snow(w, total_h, dt)
    for i = 1, snow_count do
        local p = snow[i]
        p.y = p.y + p.speed * dt
        p.x = p.x + p.drift * dt
        if p.y > total_h then p.y = -p.size; p.x = math.random() * w end
        if p.x > w then p.x = 0 end
        if p.x < 0 then p.x = w end
    end
end

-- Draw snow clipped to a rect (same particle positions, different clip)
local function draw_snow_clipped(ox, oy, cx1, cy1, cx2, cy2)
    draw.push_clip(cx1, cy1, cx2, cy2)
    for i = 1, snow_count do
        local p = snow[i]
        draw.circle(ox + p.x, oy + p.y, p.size, 255, 255, 255, math.floor(p.alpha))
    end
    draw.pop_clip()
end

-- State
local scroll = 0
local scroll_target = 0
local last_page = ""
local last_sel = -1

-- Helpers
local function lerp(a, b, t) return a + (b - a) * t end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function ease_out(t) t = clamp(t, 0, 1); return 1 - (1 - t)^2 end

-- Draw widget
local function draw_widget(rx, yc, item, idx, is_sel)
    local t = item.type

    if t == item_type.sub_menu then
        -- Three dots like Lexis
        local dots = "\xc2\xb7\xc2\xb7\xc2\xb7"
        local dw = text.width(font.value, dots)
        text.draw(font.value, rx - dw, yc - text.height(font.value)/2, c.text_dim[1], c.text_dim[2], c.text_dim[3], c.text_dim[4], dots)

    elseif t == item_type.selected_tick then
        -- Tick/checkmark on the right to mark the active selection
        if tick_img and tick_img > 0 then
            local th = 12
            draw.image_colored(tick_img, rx - th, yc - th/2, rx, yc + th/2,
                c.icon_toggle[1], c.icon_toggle[2], c.icon_toggle[3], c.icon_toggle[4])
        end

    elseif t == item_type.toggle or t == item_type.float_toggle or t == item_type.int_toggle
        or t == item_type.array_toggle or t == item_type.loop_toggle then
        if toggle_on_img > 0 and toggle_off_img > 0 then
            local img = item.on and toggle_on_img or toggle_off_img
            draw.image_colored(img, rx - l.toggle_w, yc - l.toggle_h/2, rx, yc + l.toggle_h/2,
                c.icon_toggle[1], c.icon_toggle[2], c.icon_toggle[3], c.icon_toggle[4])
        else
            local txt = item.on and "On" or "Off"
            local col = item.on and c.accent or c.text_dim
            text.draw(font.value, rx - text.width(font.value, txt), yc - text.height(font.value)/2, col[1], col[2], col[3], col[4], txt)
        end

    elseif t == item_type.slider then
        local sw = 100
        local th = 3
        local sx = rx - sw
        local sy = yc - th/2
        local frac = 0
        if item.f_max > item.f_min then frac = clamp((item.f_val - item.f_min) / (item.f_max - item.f_min), 0, 1) end
        draw.rect(sx, sy, sx + sw - 36, sy + th, 255,255,255, 15, 2)
        if frac > 0 then
            draw.rect(sx, sy, sx + (sw-36)*frac, sy + th, c.accent[1], c.accent[2], c.accent[3], 200, 2)
        end
        local vs = string.format("%.1f", item.f_val)
        local vw = text.width(font.value, vs)
        text.draw(font.value, rx - vw, yc - text.height(font.value)/2, c.text_value[1], c.text_value[2], c.text_value[3], is_sel and 255 or 160, vs)

    elseif t == item_type.int_option then
        local vs = tostring(item.i_val)
        local vw = text.width(font.value, vs)
        text.draw(font.value, rx - vw, yc - text.height(font.value)/2, c.text_value[1], c.text_value[2], c.text_value[3], is_sel and 255 or 160, vs)

    elseif t == item_type.array_option or t == item_type.loop_option then
        local vt = item.current_value or "?"
        local vw = text.width(font.value, vt)
        text.draw(font.value, rx - vw, yc - text.height(font.value)/2, c.text_value[1], c.text_value[2], c.text_value[3], is_sel and 255 or 160, vt)

    elseif t == item_type.color then
        local s = 14
        draw.rect(rx - s, yc - s/2, rx, yc + s/2, item.r, item.g, item.b, item.a or 255, 3)

    elseif t == item_type.search then
        -- icon on the far right
        local icon_sz = 14
        if search_img and search_img > 0 then
            draw.image_colored(search_img, rx - icon_sz, yc - icon_sz/2, rx, yc + icon_sz/2,
                c.icon_toggle[1], c.icon_toggle[2], c.icon_toggle[3], c.icon_toggle[4])
        end
        -- query text (or placeholder) to the left of the icon
        local q = (item.text and item.text ~= "") and item.text or "Search…"
        local col = (item.text and item.text ~= "") and c.text_value or c.text_dim
        local qw = text.width(font.value, q)
        text.draw(font.value, rx - icon_sz - 6 - qw, yc - text.height(font.value)/2,
            col[1], col[2], col[3], col[4], q)
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
    draw.rect(px, py, px+pw, py+ph, c.bg[1], c.bg[2], c.bg[3], 255, c.rounding)
    local item = menu.get_item(menu.input_target_item())
    text.draw(font.label, px+16, py+14, c.accent[1], c.accent[2], c.accent[3], 180, item and item.name or str.edit_value)
    local buf = menu.get_input_buffer()
    draw.rect(px+12, py+36, px+pw-12, py+60, 255,255,255, 8, 4)
    text.draw(font.item, px+18, py+41, 255,255,255,255, buf)
    if math.fmod(ctx.time() - input_blink, 1.0) < 0.55 then
        local cw = text.width(font.item, buf:sub(1, input_cursor))
        draw.rect(px+18+cw, py+39, px+18+cw+1.5, py+58, c.accent[1], c.accent[2], c.accent[3], 255)
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
    local dw, dih = 180, l.item_h
    local dh = math.min(#values * dih, dih * 8)
    local dx = frame.menu_x + l.menu_w - dw - 4
    local dy = frame.popup_item_y or 300
    if dy + dh > ctx.screen_h() - 10 then dy = dy - dh - l.item_h end
    draw.rect(dx, dy, dx+dw, dy+dh, c.bg[1], c.bg[2], c.bg[3], 255, c.rounding)
    local mx, my = input.mouse_x(), input.mouse_y()
    for i = 1, #values do
        local iy = dy + (i-1)*dih
        local hov = mx >= dx and mx <= dx+dw and my >= iy and my <= iy+dih
        if hov then array_idx = i-1 end
        if (i-1) == array_idx then
            draw.rect(dx+2, iy, dx+dw-2, iy+dih, c.accent[1], c.accent[2], c.accent[3], 200, 4)
        end
        text.draw(font.value, dx+10, iy+(dih-text.height(font.value))/2, 255,255,255, ((i-1)==array_idx) and 255 or 150, values[i])
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
    draw.rect(px, py, px+pw, py+ph, c.bg[1], c.bg[2], c.bg[3], 255, c.rounding)
    local tw = text.width(font.item, str.press_key)
    text.draw(font.item, px+(pw-tw)/2, py+10, 255,255,255,230, str.press_key)
    local hw = text.width(font.desc, str.esc_cancel)
    text.draw(font.desc, px+(pw-hw)/2, py+30, 255,255,255,80, str.esc_cancel)
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
    draw.rect(px, py, px+pw, py+ph, c.bg[1], c.bg[2], c.bg[3], 255, c.rounding)
    local cell, gap = 32, 4
    local gx, gy = px + 14, py + 14
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
    elseif item and item.type == item_type.search then
        -- seed the input buffer from the committed query, then open the text popup
        menu.set_input_buffer(item.text or "")
        menu.open_input_popup()
        return
    end
    orig_activate()
end

---------------------------------------------------------------------------
-- Player Info Panel (shown on Online Players page)
---------------------------------------------------------------------------
local fake_player = {
    name = "LightSee0",
    rank = 5, distance = "1471.86",
    health = "Full", armor = 50,
    playtime = "00:02:00", bounty = "$0",
    bank = "$0", wallet = "$0",
    wanted = "0/5", ammo = "None",
    weapon = "Tear Gas",
    organisation = "Color Of Nation",
    language = "Russian",
    zone = "Mission Row", street = "Olympic Fwy",
    kd = "0.00", pos = "275, -1158, 36",
    heading = "West (279)", speed = "0.00 (KPH)",
    rockstar = "226185229", nat = "Moderate",
    ping = "119MS", connection = "P2P",
    ip = "46.188.123.136", port = "5156",
    peer_token = "0x4CD060447E742885",
    country = "Moscow, Russia", timezone = "Europe/Moscow",
    region = "Moscow", zip = "103073", isp = "COM",
    crew_tag = "GUUT", crew_color = "#00FF00",
    crew_name = "PrincessWackelGutrun", crew_rank = "Rank4",
    crew_motto = "Die GUUTe deutsche Crew",
}

-- Info panel colors
local pi = {
    label   = {140, 140, 155, 200},   -- row labels (muted gray)
    value   = {255, 255, 255, 240},   -- row values (bright white)
    header  = {200, 200, 210, 240},   -- header title
    card_bg = {20, 18, 28, 240},      -- panel background
    head_bg = {28, 32, 42, 250},      -- header bar
    border  = {50, 50, 65, 70},       -- panel outline
    sep     = {60, 60, 75, 100},      -- column separator
}

-- Single-column info section
local function draw_info_section(x, y, w, title, rows)
    local row_h = 22
    local header_h = 26
    local h = header_h + #rows * row_h + 4
    draw.rect(x, y, x + w, y + h, pi.card_bg[1], pi.card_bg[2], pi.card_bg[3], pi.card_bg[4], 6)
    draw.rect_outline(x, y, x + w, y + h, pi.border[1], pi.border[2], pi.border[3], pi.border[4], 6)
    draw.rect(x, y, x + w, y + header_h, pi.head_bg[1], pi.head_bg[2], pi.head_bg[3], pi.head_bg[4], 6)
    local tw = text.width(font.tiny, title)
    text.draw(font.tiny, x + (w - tw)/2, y + (header_h - text.height(font.tiny))/2, pi.header[1], pi.header[2], pi.header[3], pi.header[4], title)
    for i, row in ipairs(rows) do
        local ry = y + header_h + (i-1) * row_h + 2
        text.draw(font.tiny, x + 10, ry + (row_h - text.height(font.tiny))/2, pi.label[1], pi.label[2], pi.label[3], pi.label[4], row.label)
        local vw = text.width(font.tiny, row.value)
        local vc = row.color or pi.value
        text.draw(font.tiny, x + w - 10 - vw, ry + (row_h - text.height(font.tiny))/2, vc[1], vc[2], vc[3], vc[4], row.value)
    end
    return h
end

-- Two-column info section
local function draw_info_section_2col(x, y, w, title, rows)
    local row_h = 22
    local header_h = 26
    local h = header_h + #rows * row_h + 4
    local half = w / 2
    draw.rect(x, y, x + w, y + h, pi.card_bg[1], pi.card_bg[2], pi.card_bg[3], pi.card_bg[4], 6)
    draw.rect_outline(x, y, x + w, y + h, pi.border[1], pi.border[2], pi.border[3], pi.border[4], 6)
    draw.rect(x, y, x + w, y + header_h, pi.head_bg[1], pi.head_bg[2], pi.head_bg[3], pi.head_bg[4], 6)
    local tw = text.width(font.tiny, title)
    text.draw(font.tiny, x + (w - tw)/2, y + (header_h - text.height(font.tiny))/2, pi.header[1], pi.header[2], pi.header[3], pi.header[4], title)
    for i, row in ipairs(rows) do
        local ry = y + header_h + (i-1) * row_h + 2
        local ty = ry + (row_h - text.height(font.tiny))/2
        -- Left pair
        text.draw(font.tiny, x + 10, ty, pi.label[1], pi.label[2], pi.label[3], pi.label[4], row[1])
        local v1w = text.width(font.tiny, row[2])
        local v1c = row[5] or pi.value
        text.draw(font.tiny, x + half - 10 - v1w, ty, v1c[1], v1c[2], v1c[3], v1c[4], row[2])
        -- Separator + right pair
        if row[3] then
            text.draw(font.tiny, x + half - 4, ty, pi.sep[1], pi.sep[2], pi.sep[3], pi.sep[4], "|")
            text.draw(font.tiny, x + half + 10, ty, pi.label[1], pi.label[2], pi.label[3], pi.label[4], row[3])
            local v2w = text.width(font.tiny, row[4])
            local v2c = row[6] or pi.value
            text.draw(font.tiny, x + w - 10 - v2w, ty, v2c[1], v2c[2], v2c[3], v2c[4], row[4])
        end
    end
    return h
end

local function draw_player_info(menu_left, menu_right, menu_top)
    local p = fake_player
    local gap = 6
    local pw = 340

    -- RIGHT SIDE: Stats → Network → Crew
    local rx = menu_right + 12
    local ry = menu_top

    local h1 = draw_info_section_2col(rx, ry, pw, p.name, {
        {"Rank",        tostring(p.rank),  "Distance",   p.distance},
        {"Health",      p.health,          "Armor",      tostring(p.armor)},
        {"Playtime",    p.playtime,        "Bounty",     p.bounty},
        {"Bank",        p.bank,            "Wallet",     p.wallet},
        {"Wanted Level",p.wanted,          "Ammo",       p.ammo},
        {"Weapon",      p.weapon},
        {"Organisation",p.organisation,    nil, nil, {34,197,94,255}},
        {"Language",    p.language},
        {"Zone",        p.zone},
        {"Street",      p.street},
        {"K/D",         p.kd,              "Pos",        p.pos},
        {"Heading",     p.heading,         "Speed",      p.speed},
    })
    ry = ry + h1 + gap

    local h2 = draw_info_section_2col(rx, ry, pw, "Network", {
        {"Rockstar",    p.rockstar,        "Nat",        p.nat, nil, {220,140,40,255}},
        {"Ping",        p.ping,            "Connection", p.connection},
        {"IP",          p.ip,              "Port",       p.port},
        {"Peer Token",  p.peer_token},
    })
    ry = ry + h2 + gap

    draw_info_section_2col(rx, ry, pw, "Crew", {
        {"Tag",   p.crew_tag,   "Color", p.crew_color, nil, {0,255,0,255}},
        {"Name",  p.crew_name},
        {"Rank",  p.crew_rank},
        {"Motto", p.crew_motto},
    })

    -- LEFT SIDE: Geo → Properties
    local lx = menu_left - pw - 12
    if lx < 10 then lx = 10 end
    local ly = menu_top

    local h4 = draw_info_section(lx, ly, pw, "Geo", {
        {label = "Country",  value = p.country},
        {label = "Timezone", value = p.timezone},
        {label = "Region",   value = p.region},
        {label = "Zip",      value = p.zip},
        {label = "ISP",      value = p.isp},
    })
    ly = ly + h4 + gap

    draw_info_section(lx, ly, pw, "Properties", {
        {label = "3 Alta St, Apt 57",          value = "Eclipse Towers, Apt 9"},
        {label = "0069 Cougar Ave, Apt 19",    value = "1237 Prosperity St, Apt 21"},
        {label = "0112 S Rockford Dr, Apt 13", value = "Eclipse Towers, Apt 9"},
        {label = "Eclipse Towers, Apt 40",     value = "Del Perro Heights, Apt 20"},
        {label = "Ron Alternates Wind Farm",   value = "Facility"},
    })
end

---------------------------------------------------------------------------
-- Main draw
---------------------------------------------------------------------------
function draw_menu()
    theme.set_body_bg(12, 10, 18, 255)
    if not menu.is_visible() then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local dt = ctx.delta()

    local page = menu.page_name()
    if page ~= last_page then last_page = page; scroll = 0; scroll_target = 0 end
    local sel = menu.selected_index()
    local sel_changed = (sel ~= last_sel)
    last_sel = sel

    local count = menu.item_count()
    local content_h = count * l.item_h
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

    -- Card background (rounded)
    draw.rect(mx, my, mx + l.menu_w, my + card_h, c.bg[1], c.bg[2], c.bg[3], c.bg[4], c.rounding)

    -- Snow: tick across full height (card + gap + desc), draw clipped to card
    local desc_total_h = card_h + 10 + 60  -- card + gap + desc box
    tick_snow(l.menu_w, desc_total_h, dt)
    draw_snow_clipped(mx, my, mx, my, mx + l.menu_w, my + card_h)

    local cy = my

    -- Header: logo with background rect + page name
    local ls = l.logo_size
    local logo_x = mx + l.pad_x
    local logo_y = cy + (l.header_h - ls) / 2
    -- Rounded rect behind logo
    draw.rect(logo_x - 4, logo_y - 4, logo_x + ls + 4, logo_y + ls + 4, c.accent[1], c.accent[2], c.accent[3], 80, 8)
    if logo_img > 0 then
        draw.image(logo_img, logo_x, logo_y, logo_x + ls, logo_y + ls)
    end
    local title_x = logo_x + ls + 14
    text.draw(font.title, title_x, cy + (l.header_h - text.height(font.title))/2 + l.text_off_y,
        c.text_sel[1], c.text_sel[2], c.text_sel[3], c.text_sel[4], page)
    cy = cy + l.header_h

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
            -- Full-width rose/pink tint
            draw.rect(mx + 6, iy + 2, mx + l.menu_w - 6, iy + l.item_h - 2,
                c.selected[1], c.selected[2], c.selected[3], c.selected[4], 6)
        end

        -- Hover
        local hovered = in_list and imy >= iy and imy <= iy + l.item_h
        if hovered and not is_sel then
            draw.rect(mx + 6, iy + 2, mx + l.menu_w - 6, iy + l.item_h - 2, 255,255,255, 5, 6)
        end
        if hovered and input.mouse_clicked(0) and menu.popup_mode() == 0 then
            if is_sel then menu.activate() else menu.set_selected(i) end
        end

        -- Name
        local tc = is_sel and c.text_sel or c.text
        text.draw(font.item, mx + l.pad_x, iy + (l.item_h - text.height(font.item))/2 + l.text_off_y,
            tc[1], tc[2], tc[3], tc[4], item.name)

        -- Hotkey badge
        if item.hotkey and item.hotkey ~= 0 then
            local kn = menu.vk_name(item.hotkey)
            local nw = text.width(font.item, item.name)
            local bw = text.width(font.tiny, kn)
            local bx = mx + l.pad_x + nw + 5
            local by = iy + (l.item_h - text.height(font.tiny))/2
            draw.rect(bx - 2, by - 1, bx + bw + 2, by + text.height(font.tiny) + 1, c.accent[1], c.accent[2], c.accent[3], is_sel and 50 or 15, 3)
            text.draw(font.tiny, bx, by, c.accent[1], c.accent[2], c.accent[3], is_sel and 180 or 60, kn)
        end

        -- Widget
        draw_widget(mx + l.menu_w - l.pad_x, iy + l.item_h/2, item, i, is_sel)

        -- Separator
        if i < count - 1 and not is_sel then
            draw.line(mx + l.pad_x, iy + l.item_h, mx + l.menu_w - l.pad_x, iy + l.item_h,
                c.separator[1], c.separator[2], c.separator[3], c.separator[4])
        end

        ::cont::
    end
    draw.pop_clip()
    cy = list_y + list_h

    -- Scrollbar (outside card, right side with dark track)
    if scroll_max > 0 then
        local sb_x = mx + l.menu_w + 6
        local sb_track_w = 6
        -- Track
        draw.rect(sb_x, list_y, sb_x + sb_track_w, list_y + list_h, 20, 18, 30, 200, 3)
        -- Thumb
        local sb_thumb_h = math.max(30, list_h * (list_h / content_h))
        local sb_frac = scroll / scroll_max
        local sb_y = list_y + sb_frac * (list_h - sb_thumb_h)
        draw.rect(sb_x, sb_y, sb_x + sb_track_w, sb_y + sb_thumb_h, 80, 75, 95, 200, 3)
    end

    -- Footer
    local fy = cy + (l.footer_h - text.height(font.small))/2
    -- Badge behind version text
    local ver_str = "v1.0 Nenyoo"
    local ver_w = text.width(font.small, ver_str)
    draw.rect(mx + l.pad_x - 6, fy - 4, mx + l.pad_x + ver_w + 6, fy + text.height(font.small) + 4,
        c.accent[1], c.accent[2], c.accent[3], 40, 6)
    text.draw(font.small, mx + l.pad_x, fy + l.text_off_y, c.text_footer[1], c.text_footer[2], c.text_footer[3], c.text_footer[4], ver_str)
    -- Badge behind counter
    local counter = string.format("%d/%d", sel + 1, count)
    local cnt_w = text.width(font.small, counter)
    draw.rect(mx + l.menu_w - l.pad_x - cnt_w - 6, fy - 4, mx + l.menu_w - l.pad_x + 6, fy + text.height(font.small) + 4,
        c.accent[1], c.accent[2], c.accent[3], 40, 6)
    text.draw(font.small, mx + l.menu_w - l.pad_x - cnt_w, fy + l.text_off_y, c.text_footer[1], c.text_footer[2], c.text_footer[3], c.text_footer[4], counter)

    -- Description box (below card, separate)
    local desc_item = menu.get_item(sel)
    if desc_item and desc_item.desc and #desc_item.desc > 0 then
        local desc_y = my + card_h + 10
        local desc_str = desc_item.desc
        local desc_h = 60
        draw.rect(mx, desc_y, mx + l.menu_w, desc_y + desc_h, c.bg[1], c.bg[2], c.bg[3], c.bg[4], c.rounding)
        -- Same snow, clipped to desc box (continuous from card)
        draw_snow_clipped(mx, my, mx, desc_y, mx + l.menu_w, desc_y + desc_h)
        text.draw(font.item, mx + l.pad_x, desc_y + 10 + l.text_off_y, c.text_sel[1], c.text_sel[2], c.text_sel[3], c.text_sel[4], desc_str)
        text.draw(font.desc, mx + l.pad_x, desc_y + 32 + l.text_off_y, c.text_dim[1], c.text_dim[2], c.text_dim[3], c.text_dim[4], "Press H to set a hotkey")
    end

    -- Popups
    -- Player info panels (on Players page)
    -- Disabled: the bundled scripts/player_panel.lua overlay now draws the real player panel
    -- (overrides the global by name) so this mock-data panel no longer double-draws.
    -- if page == "Players" then
    --     draw_player_info(mx, mx + l.menu_w, my)
    -- end

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
