-- Nenyoo "Brutalist" Theme — Y2K / neo-brutalist
-- Loud, blocky, high-contrast. Off-white panel, THICK black borders, hard
-- offset drop-shadows, zero rounding, uppercase mono-ish labels, chunky
-- [ ON ]/[ OFF ] toggles. Built on THEME_API.md.

text.set_size(font.title, 26);  text.set_weight(font.title, 900)
text.set_size(font.item, 14);   text.set_weight(font.item, 700)
text.set_size(font.value, 13);  text.set_weight(font.value, 800)
text.set_size(font.breadcrumb, 11); text.set_weight(font.breadcrumb, 800)

---------------------------------------------------------------------------
local function sc(name) local s = menu.get_setting(name); if s then return {s.r,s.g,s.b,s.a} end end
local function sf(name, d) local s = menu.get_setting(name); if s then return s.f_val end; return d end

local function reload_colors()
    return {
        accent  = sc("Accent")   or {255, 61, 87, 255},   -- hot red
        accent2 = sc("Accent 2") or {45, 226, 230, 255},  -- electric cyan (Y2K)
        paper   = sc("Paper")    or {238, 236, 225, 255},  -- off-white panel
        ink     = sc("Ink")      or {17, 17, 17, 255},     -- near-black
    }
end
local function reload_layout()
    return {
        menu_w = sf("Menu Width", 440),
        item_h = sf("Row Height", 44),
        header_h = 70, sub_h = 30, desc_h = 56,
        list_max = 440, pad_x = 16,
        border = 3, shadow = 7,
    }
end

menu.clear_settings()
menu.add_setting_submenu("Colors", "Brutalist palette")
menu.add_sub_color("Accent", 255, 61, 87, 255, "Primary accent")
menu.add_sub_color("Accent 2", 45, 226, 230, 255, "Secondary accent")
menu.add_sub_color("Paper", 238, 236, 225, 255, "Panel color")
menu.add_sub_color("Ink", 17, 17, 17, 255, "Text / borders")
menu.add_setting_submenu("Layout", "Sizes")
menu.add_sub_slider("Menu Width", 440, 320, 640, 10, "Panel width (px)")
menu.add_sub_slider("Row Height", 44, 30, 64, 1, "Row height (px)")

local c = reload_colors()
local l = reload_layout()

---------------------------------------------------------------------------
local function lerp(a,b,t) return a+(b-a)*t end
local function clamp(v,lo,hi) return math.max(lo, math.min(hi,v)) end
local function ease_out(t) t=clamp(t,0,1); return 1-(1-t)^3 end

local SLIDER_W, GAP = 120, 12
local scroll, scroll_target = 0, 0
local nav_time, last_page, last_sel = 0, "", -1
local desc_anim = 0
local dragging_slider, drag_x, drag_w = -1, 0, 0
local frame = { menu_x=0, list_y=0, popup_item_y=0 }
local sb_last, dragging_sb, sb_grab = 0, false, 0

-- ink color flips to paper when the row is a solid ink highlight
local function ink(is_sel)
    if is_sel then return c.paper[1], c.paper[2], c.paper[3] end
    return c.ink[1], c.ink[2], c.ink[3]
end

-- a hard-shadowed bordered box
local function block(x1, y1, x2, y2, fr, fg, fb, fa)
    draw.rect(x1+l.shadow, y1+l.shadow, x2+l.shadow, y2+l.shadow, c.ink[1], c.ink[2], c.ink[3], 255) -- hard shadow
    draw.rect(x1, y1, x2, y2, fr, fg, fb, fa or 255)
    draw.rect_outline(x1, y1, x2, y2, c.ink[1], c.ink[2], c.ink[3], 255, 0, l.border)
end

---------------------------------------------------------------------------
-- Widgets (blocky)
---------------------------------------------------------------------------
local function draw_toggle(rx, yc, item, is_sel)
    local txt = item.on and "ON" or "OFF"
    local fillc = item.on and c.accent or (is_sel and {60,60,60} or c.paper)
    local tw = math.max(text.width(font.value, "OFF") + 22, 48)
    local th = 22
    local tx, ty = rx - tw, yc - th/2
    -- box
    draw.rect(tx, ty, tx+tw, ty+th, fillc[1], fillc[2], fillc[3], 255)
    draw.rect_outline(tx, ty, tx+tw, ty+th, is_sel and c.paper[1] or c.ink[1], is_sel and c.paper[2] or c.ink[2], is_sel and c.paper[3] or c.ink[3], 255, 0, 2)
    local tc = item.on and {255,255,255} or {c.ink[1],c.ink[2],c.ink[3]}
    if is_sel and not item.on then tc = {c.paper[1],c.paper[2],c.paper[3]} end
    local lw = text.width(font.value, txt)
    text.draw(font.value, tx+(tw-lw)/2, yc-text.height(font.value)/2, tc[1], tc[2], tc[3], 255, txt)
    return tw
end

local function draw_slider(rx, yc, item, is_sel)
    local sx = rx - SLIDER_W
    local sy = yc - 6
    local frac = 0
    if item.f_max > item.f_min then frac = clamp((item.f_val-item.f_min)/(item.f_max-item.f_min),0,1) end
    local ir, ig, ib = ink(is_sel)
    -- track box
    draw.rect(sx, sy, sx+SLIDER_W, sy+12, is_sel and 40 or 0, is_sel and 40 or 0, is_sel and 40 or 0, is_sel and 255 or 0)
    if not is_sel then draw.rect(sx, sy, sx+SLIDER_W, sy+12, 0,0,0,30) end
    -- fill
    local fw = SLIDER_W*frac
    if fw > 0 then draw.rect(sx, sy, sx+fw, sy+12, c.accent[1], c.accent[2], c.accent[3], 255) end
    draw.rect_outline(sx, sy, sx+SLIDER_W, sy+12, ir, ig, ib, 255, 0, 2)
    local vs = string.format("%.1f", item.f_val)
    text.draw(font.value, sx-10-text.width(font.value, vs), yc-text.height(font.value)/2, ir, ig, ib, 255, vs)
    return sx, SLIDER_W
end

local function draw_stepper(rx, yc, val, is_sel)
    local ir, ig, ib = ink(is_sel)
    local af, lh = font.value, text.height(font.value)
    local ry = yc - lh/2
    -- [ < val > ] bracketed block
    local txt = "[ " .. val .. " ]"
    local lw = text.width(af, txt)
    text.draw(af, rx-lw, ry, ir, ig, ib, 255, txt)
end

local function draw_widget(rx, yc, item, idx, is_sel)
    local t = item.type
    local ir, ig, ib = ink(is_sel)
    if t == item_type.sub_menu then
        text.draw(font.item, rx-text.width(font.item, ">>"), yc-text.height(font.item)/2, ir, ig, ib, 255, ">>")
    elseif t == item_type.selected_tick then
        text.draw(font.item, rx-text.width(font.item, "[*]"), yc-text.height(font.item)/2, ir, ig, ib, 255, "[*]")
    elseif t == item_type.toggle then draw_toggle(rx, yc, item, is_sel)
    elseif t == item_type.float_toggle then local w=draw_toggle(rx, yc, item, is_sel); draw_slider(rx-w-GAP, yc, item, is_sel)
    elseif t == item_type.int_toggle then local w=draw_toggle(rx, yc, item, is_sel); draw_stepper(rx-w-GAP, yc, tostring(item.i_val), is_sel)
    elseif t == item_type.array_toggle or t == item_type.loop_toggle then local w=draw_toggle(rx, yc, item, is_sel); draw_stepper(rx-w-GAP, yc, item.current_value or "?", is_sel)
    elseif t == item_type.slider then draw_slider(rx, yc, item, is_sel)
    elseif t == item_type.int_option then draw_stepper(rx, yc, tostring(item.i_val), is_sel)
    elseif t == item_type.array_option or t == item_type.loop_option then draw_stepper(rx, yc, item.current_value or "?", is_sel)
    elseif t == item_type.color then
        local s = 22
        draw.rect(rx-s, yc-s/2, rx, yc+s/2, item.r, item.g, item.b, item.a or 255)
        draw.rect_outline(rx-s, yc-s/2, rx, yc+s/2, ir, ig, ib, 255, 0, 2)
    elseif t == item_type.input_text then
        local vw = text.width(font.value, item.name)
        text.draw(font.value, rx-vw, yc-text.height(font.value)/2, ir, ig, ib, 255, item.name)
    elseif t == item_type.search then
        local q = (item.text and item.text ~= "") and ("["..item.text.."]") or "[SEARCH]"
        local qw = text.width(font.value, q)
        text.draw(font.value, rx-qw, yc-text.height(font.value)/2, ir, ig, ib, 255, q)
    elseif t == item_type.input_int then
        local vs = "["..tostring(item.i_val).."]"; text.draw(font.value, rx-text.width(font.value,vs), yc-text.height(font.value)/2, ir,ig,ib,255, vs)
    elseif t == item_type.input_float then
        local vs = "["..string.format("%.2f", item.f_val).."]"; text.draw(font.value, rx-text.width(font.value,vs), yc-text.height(font.value)/2, ir,ig,ib,255, vs)
    end
end

local function draw_hotkey_badge(x, y, vk, is_sel, lh)
    if vk == 0 then return end
    local kn = menu.vk_name(vk)
    local bw, bh = text.width(font.tiny, kn), text.height(font.tiny)
    local by = y + (lh-bh)/2 - 1
    local bgc = is_sel and c.accent2 or c.accent
    draw.rect(x-4, by-1, x+bw+4, by+bh+2, bgc[1], bgc[2], bgc[3], 255)
    draw.rect_outline(x-4, by-1, x+bw+4, by+bh+2, c.ink[1],c.ink[2],c.ink[3], 255, 0, 1)
    text.draw(font.tiny, x, by, c.ink[1],c.ink[2],c.ink[3], 255, kn)
end

---------------------------------------------------------------------------
-- Sections
---------------------------------------------------------------------------
local function draw_header(x, y)
    -- accent header strip
    draw.rect(x, y, x+l.menu_w, y+l.header_h, c.accent[1], c.accent[2], c.accent[3], 255)
    -- thick bottom border
    draw.rect(x, y+l.header_h-l.border, x+l.menu_w, y+l.header_h, c.ink[1], c.ink[2], c.ink[3], 255)
    local title = string.upper(str.brand or "NENYOO")
    text.draw_spaced(font.title, x+l.pad_x, y+(l.header_h-text.height(font.title))/2-4, 255,255,255,255, title, 2)
    -- diagonal Y2K stripes block on the right
    local bx = x+l.menu_w-58
    for i=0,4 do
        draw.rect(bx+i*10, y+12, bx+i*10+4, y+l.header_h-16, c.ink[1], c.ink[2], c.ink[3], 200)
    end
end

local function draw_subtitle(x, y)
    draw.rect(x, y, x+l.menu_w, y+l.sub_h, c.ink[1], c.ink[2], c.ink[3], 255)
    local page = string.upper(menu.page_name())
    text.draw_spaced(font.breadcrumb, x+l.pad_x, y+(l.sub_h-text.height(font.breadcrumb))/2, c.accent2[1],c.accent2[2],c.accent2[3], 255, page, 1)
    local counter = string.format("%02d/%02d", menu.selected_index()+1, menu.item_count())
    local cw = text.width(font.breadcrumb, counter)
    text.draw(font.breadcrumb, x+l.menu_w-l.pad_x-cw, y+(l.sub_h-text.height(font.breadcrumb))/2, c.paper[1],c.paper[2],c.paper[3], 230, counter)
end

local function draw_desc_box(x, y, item)
    draw.rect(x, y, x+l.menu_w, y+l.border, c.ink[1], c.ink[2], c.ink[3], 255)
    if not item then return end
    local t = ease_out(clamp((ctx.time()-desc_anim)/0.18, 0, 1))
    -- accent square bullet
    draw.rect(x+l.pad_x, y+18, x+l.pad_x+10, y+28, c.accent[1], c.accent[2], c.accent[3], math.floor(255*t))
    local tx = x+l.pad_x+20
    text.draw(font.value, tx, y+12, c.ink[1],c.ink[2],c.ink[3], math.floor(255*t), string.upper(item.name))
    if item.desc and #item.desc > 0 then
        text.draw(font.desc, tx, y+12+text.height(font.value)+3, c.ink[1],c.ink[2],c.ink[3], math.floor(170*t), item.desc, l.menu_w-(tx-x)-l.pad_x)
    end
end

local function draw_scrollbar(x, list_y, list_h, content_h)
    if content_h <= list_h then dragging_sb = false; return end
    local scroll_max = content_h - list_h
    local mx, my = input.mouse_x(), input.mouse_y()
    local near = mx >= x+l.menu_w-18 and mx <= x+l.menu_w and my >= list_y and my <= list_y+list_h
    local sw = 8
    local sx = x+l.menu_w-sw-3
    local thumb_h = math.max((list_h/content_h)*list_h, 28)
    local fr = scroll_max > 0 and (scroll/scroll_max) or 0
    local thumb_y = list_y + fr*(list_h-thumb_h)
    if not dragging_sb and input.mouse_clicked(0) and near then
        if my >= thumb_y and my <= thumb_y+thumb_h then dragging_sb=true; sb_grab=my-thumb_y
        else scroll_target = clamp((my-list_y-thumb_h*0.5)/(list_h-thumb_h),0,1)*scroll_max; scroll=scroll_target; dragging_sb=true; sb_grab=thumb_h*0.5 end
    end
    if dragging_sb then
        if input.mouse_down(0) then scroll_target = clamp((my-sb_grab-list_y)/(list_h-thumb_h),0,1)*scroll_max; scroll=scroll_target
        else dragging_sb=false end
    end
    draw.rect(sx, list_y, sx+sw, list_y+list_h, 0,0,0, 30)
    draw.rect(sx, thumb_y, sx+sw, thumb_y+thumb_h, c.accent[1], c.accent[2], c.accent[3], 255)
    draw.rect_outline(sx, thumb_y, sx+sw, thumb_y+thumb_h, c.ink[1],c.ink[2],c.ink[3], 255, 0, 2)
end

---------------------------------------------------------------------------
-- Side panel
---------------------------------------------------------------------------
local function draw_side_panel(x, y, w, item)
    if not item or not item.info then return end
    local it, info = item.info_type, item.info
    local green,red,yellow,blue = {22,163,74},{220,38,38},{202,138,4},{37,99,235}
    local valc = {c.ink[1],c.ink[2],c.ink[3],255}
    local cy = y
    local function section(t2)
        cy = cy+6
        draw.rect(x+12, cy, x+12+text.width(font.label,string.upper(t2))+8, cy+14, c.accent[1],c.accent[2],c.accent[3], 255)
        text.draw(font.label, x+16, cy+3, 255,255,255, 255, string.upper(t2)); cy=cy+18
        draw.rect(x+12, cy, x+w-12, cy+2, c.ink[1],c.ink[2],c.ink[3], 255); cy=cy+8
    end
    local function row2(k1,v1,v1c,k2,v2,v2c)
        local half = w*0.5
        text.draw(font.breadcrumb, x+14, cy+4, c.ink[1],c.ink[2],c.ink[3], 150, string.upper(k1))
        text.draw(font.breadcrumb, x+half-8-text.width(font.breadcrumb,v1), cy+4, v1c[1],v1c[2],v1c[3], 255, v1)
        if k2 and v2 then
            text.draw(font.breadcrumb, x+half+10, cy+4, c.ink[1],c.ink[2],c.ink[3], 150, string.upper(k2))
            text.draw(font.breadcrumb, x+w-14-text.width(font.breadcrumb,v2), cy+4, v2c[1],v2c[2],v2c[3], 255, v2)
        end
        cy = cy+22
    end
    local function mini_bar(bx,by,bw,frac,col)
        draw.rect(bx,by,bx+bw,by+6,0,0,0,30); draw.rect(bx,by,bx+bw*clamp(frac,0,1),by+6,col[1],col[2],col[3],255)
        draw.rect_outline(bx,by,bx+bw,by+6,c.ink[1],c.ink[2],c.ink[3],255,0,1)
    end
    local function stat_row(label,value,max_val)
        text.draw(font.small, x+14, cy+4, c.ink[1],c.ink[2],c.ink[3], 150, string.upper(label))
        local frac = clamp(value/max_val,0,1)
        local col = value>=max_val*0.7 and green or (value>=max_val*0.4 and yellow or red)
        local bw=80; local bx=x+w-14-bw
        mini_bar(bx, cy+7, bw, frac, col)
        text.draw(font.breadcrumb, bx-8-text.width(font.breadcrumb,tostring(value)), cy+3, col[1],col[2],col[3],255, tostring(value))
        cy=cy+22
    end
    local function image_box(label)
        draw.rect(x+12, cy, x+w-12, cy+76, 0,0,0,20)
        draw.rect_outline(x+12, cy, x+w-12, cy+76, c.ink[1],c.ink[2],c.ink[3], 255, 0, 2)
        text.draw(font.small, x+(w-text.width(font.small,label))/2, cy+32, c.ink[1],c.ink[2],c.ink[3], 150, label); cy=cy+84
    end
    local ph = 40; if it==1 then ph=360 elseif it==2 then ph=320 elseif it==3 then ph=300 end
    block(x, y, x+w, y+ph, c.paper[1], c.paper[2], c.paper[3], 255)
    text.draw(font.item, x+14, y+14, c.ink[1],c.ink[2],c.ink[3],255, string.upper(item.name)); cy=y+36
    if it==1 then
        section(str.general or "General")
        row2(str.rank or "Rank", tostring(info.rank), yellow, str.kd or "K/D", info.kd, valc)
        row2(str.cash or "Cash", info.cash, green, str.bank or "Bank", info.bank, green)
        section(str.status or "Status")
        text.draw(font.small, x+14, cy+4, red[1],red[2],red[3],200, str.health or "HP")
        mini_bar(x+72, cy+7, 56, info.health/100, info.health>50 and green or red)
        text.draw(font.tiny, x+134, cy+4, c.ink[1],c.ink[2],c.ink[3],200, tostring(info.health).."%")
        text.draw(font.small, x+w*0.5+6, cy+4, blue[1],blue[2],blue[3],200, str.armor or "AP")
        mini_bar(x+w*0.5+56, cy+7, 56, info.armor/100, blue)
        text.draw(font.tiny, x+w*0.5+118, cy+4, c.ink[1],c.ink[2],c.ink[3],200, tostring(info.armor).."%"); cy=cy+22
        local wstr = info.wanted==0 and (str.clear or "Clear") or tostring(info.wanted)
        row2(str.wanted or "Wanted", wstr, info.wanted==0 and green or red, str.ping or "Ping", info.ping, valc)
        section(str.equipment or "Equipment"); row2(str.weapon or "Weapon", info.weapon, valc, str.ammo or "Ammo", info.ammo, yellow)
        section(str.location or "Location")
        row2(str.zone or "Zone", info.zone, valc, str.coords or "Coords", info.coords, valc)
        row2(str.vehicle or "Vehicle", info.vehicle, valc, str.speed or "Speed", info.speed, yellow)
    elseif it==2 then
        image_box("weapon_"..string.lower(string.gsub(item.name," ","_")))
        section(item.name)
        row2(str.type or "Type", info.type, valc, str.fire_mode or "Mode", info.rof, valc)
        row2(str.clip_size or "Clip", tostring(info.clip), yellow, str.dps or "DPS", tostring(info.damage*info.firerate), red)
        section(str.stats or "Stats")
        stat_row(str.damage or "Damage", info.damage, 100); stat_row(str.fire_rate or "Fire Rate", info.firerate, 10)
        stat_row(str.range or "Range", info.range, 100); stat_row(str.accuracy or "Accuracy", info.accuracy, 100)
    elseif it==3 then
        image_box("vehicle_"..string.lower(string.gsub(item.name," ","_")))
        section(item.name)
        row2(str.cls or "Class", info.cls, valc, str.price or "Price", info.price, green)
        row2(str.top_speed or "Top Speed", info.speed, yellow, str.drivetrain or "Drive", info.drivetrain, valc)
        row2(str.seats or "Seats", tostring(info.seats), valc, nil, nil, nil)
        section(str.performance or "Performance")
        stat_row(str.acceleration or "Accel", info.accel, 100); stat_row(str.braking or "Brake", info.brake, 100); stat_row(str.handling or "Handling", info.handling, 100)
    end
end

---------------------------------------------------------------------------
-- Main
---------------------------------------------------------------------------
function draw_menu()
    c = reload_colors(); l = reload_layout()
    theme.set_body_bg(c.paper[1]-40, c.paper[2]-40, c.paper[3]-40, 255)
    if not menu.is_visible() then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local time, dt = ctx.time(), ctx.delta()

    local page = menu.page_name()
    if page ~= last_page then last_page=page; nav_time=time; scroll=0; scroll_target=0 end
    local sel = menu.selected_index()
    local sel_changed = (sel ~= last_sel)
    if sel_changed then desc_anim = time end

    local count = menu.item_count()
    local content_h = count * l.item_h
    local list_h = math.min(l.list_max, content_h+6)
    local total_h = l.header_h + l.sub_h + list_h + l.desc_h
    local max_h = l.header_h + l.sub_h + l.list_max + l.desc_h
    local mx = (sw-l.menu_w)/2
    local my = math.max(24, (sh-max_h)/2)

    -- Header drag-to-move: pass natural origin, add returned offset
    local _dox, _doy = menu.drag_header(mx, my, l.menu_w, l.header_h)
    mx = mx + _dox
    my = my + _doy

    frame.menu_x = mx

    local sel_item = menu.get_item(sel)
    if sel_item and sel_item.info_type and sel_item.info_type > 1 then draw_side_panel(mx-360-20, my, 360, sel_item) end

    -- hard shadow + paper panel + thick border
    draw.rect(mx+l.shadow, my+l.shadow, mx+l.menu_w+l.shadow, my+total_h+l.shadow, c.ink[1], c.ink[2], c.ink[3], 255)
    draw.rect(mx, my, mx+l.menu_w, my+total_h, c.paper[1], c.paper[2], c.paper[3], 255)

    local cy = my
    draw_header(mx, cy); cy = cy + l.header_h
    draw_subtitle(mx, cy); cy = cy + l.sub_h
    local list_y = cy; frame.list_y = list_y

    local scroll_max = math.max(0, content_h-list_h)
    if sel_changed then
        local st = sel*l.item_h; local sbm = st+l.item_h
        if sbm > scroll_target+list_h then scroll_target = sbm-list_h end
        if st < scroll_target then scroll_target = st end
        last_sel = sel
    end
    scroll_target = clamp(scroll_target, 0, scroll_max)
    scroll = lerp(scroll, scroll_target, clamp(dt*18,0,1))

    local imx, imy = input.mouse_x(), input.mouse_y()
    local in_list = imx>=mx and imx<=mx+l.menu_w and imy>=list_y and imy<=list_y+list_h
    if in_list and menu.popup_mode()==0 then local wh=input.mouse_wheel(); if wh~=0 then scroll_target=clamp(scroll_target-wh*l.item_h*3,0,scroll_max) end end

    if dragging_slider >= 0 then
        local di = menu.get_item(dragging_slider)
        if di and input.mouse_down(0) then
            local pct = clamp((imx-drag_x)/drag_w,0,1)
            local raw = di.f_min + pct*(di.f_max-di.f_min)
            if di.f_step > 0 then raw = di.f_min + math.floor((raw-di.f_min)/di.f_step+0.5)*di.f_step end
            menu.set_f_val(dragging_slider, clamp(raw, di.f_min, di.f_max))
        else dragging_slider = -1 end
    end

    draw.push_clip(mx, list_y, mx+l.menu_w, list_y+list_h)
    local ne = time - nav_time
    local lh = text.height(font.item)
    for i = 0, count-1 do
        local item = menu.get_item(i); if not item then goto cont end
        local t = item.type
        local is_sel = (i == sel)
        local delay = i*0.02
        local at = ne>=delay and clamp((ne-delay)/0.25,0,1) or 0; at = ease_out(at)
        local iy = list_y+3 + i*l.item_h - scroll
        if iy+l.item_h < list_y or iy > list_y+list_h then goto cont end
        local ix = mx + (1-at)*-12
        local ibx = mx+l.menu_w
        local hovered = in_list and imy>=iy and imy<=iy+l.item_h
        if is_sel then
            frame.popup_item_y = iy+l.item_h; menu.set_popup_item_y(iy+l.item_h)
            -- solid ink highlight bar
            draw.rect(mx+4, iy+2, ibx-4, iy+l.item_h-2, c.ink[1], c.ink[2], c.ink[3], math.floor(255*at))
            draw.rect(mx+4, iy+2, mx+10, iy+l.item_h-2, c.accent[1], c.accent[2], c.accent[3], math.floor(255*at))
        elseif hovered then
            draw.rect(mx+4, iy+2, ibx-4, iy+l.item_h-2, c.ink[1], c.ink[2], c.ink[3], math.floor(28*at))
        end
        if hovered and input.mouse_clicked(0) and menu.popup_mode()==0 and dragging_slider<0 then
            local handled = false
            local has_toggle = t==item_type.toggle or t==item_type.float_toggle or t==item_type.int_toggle or t==item_type.array_toggle or t==item_type.loop_toggle
            if has_toggle then
                local tw = math.max(text.width(font.value,"OFF")+22, 48)
                local tx0 = ibx-l.pad_x-tw
                if imx>=tx0 and imx<=ibx-l.pad_x and imy>=iy+l.item_h/2-12 and imy<=iy+l.item_h/2+12 then
                    menu.set_selected(i); menu.toggle_item(i)
                    notify.push(item.name, item.on and (str.disabled or "DISABLED") or (str.enabled or "ENABLED"), item.on and 2 or 1); handled=true
                end
            end
            local has_slider = t==item_type.slider
            if not handled and has_slider then
                local sl_right = ibx-l.pad_x; local sl_left = sl_right-SLIDER_W
                if imx>=sl_left and imx<=sl_right and imy>=iy+l.item_h/2-12 and imy<=iy+l.item_h/2+12 then
                    menu.set_selected(i); dragging_slider=i; drag_x=sl_left; drag_w=SLIDER_W; handled=true
                end
            end
            if not handled then
                local is_input = t==item_type.input_text or t==item_type.input_int or t==item_type.input_float or t==item_type.search
                if is_input then menu.set_selected(i); menu.open_input_popup()
                elseif is_sel then menu.activate() else menu.set_selected(i) end
            end
        end
        local ir, ig, ib = ink(is_sel)
        local tx = ix+l.pad_x
        local ty = iy+(l.item_h-lh)/2
        text.draw(font.item, tx, ty, ir, ig, ib, math.floor(255*at), string.upper(item.name))
        if item.hotkey and item.hotkey ~= 0 then draw_hotkey_badge(tx+text.width(font.item,string.upper(item.name))+8, ty, item.hotkey, is_sel, lh) end
        draw_widget(ibx-l.pad_x, iy+l.item_h/2, item, i, is_sel)
        ::cont::
    end
    draw.pop_clip()
    draw_scrollbar(mx, list_y, list_h, content_h)
    cy = cy + list_h
    draw_desc_box(mx, cy, sel_item)
    -- thick outer border on top of everything
    draw.rect_outline(mx, my, mx+l.menu_w, my+total_h, c.ink[1], c.ink[2], c.ink[3], 255, 0, l.border)

    local pm = menu.popup_mode()
    if pm==1 then draw_input_popup() end
    if pm==2 then draw_color_picker() end
    if pm==3 then draw_array_dropdown_popup() end
    if pm==4 then draw_hotkey_popup() end
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------
function handle_input()
    if not menu.is_visible() then return end
    local pm = menu.popup_mode()
    if pm==1 then handle_input_popup(); return end
    if pm==2 then handle_color_picker(); return end
    if pm==3 then handle_array_dropdown(); return end
    if pm==4 then handle_hotkey_bind(); return end
    if input.key_pressed(VK.UP) then menu.move_selection(-1) end
    if input.key_pressed(VK.DOWN) then menu.move_selection(1) end
    if input.key_just_pressed(VK.RETURN) then menu.activate() end
    if input.key_just_pressed(VK.BACK) or input.key_just_pressed(VK.ESCAPE) then menu.go_back() end
    local sel = menu.selected_index()
    local item = menu.get_item(sel); if not item then return end
    local t = item.type
    if input.key_just_pressed(VK.SPACE) then
        if t==item_type.input_text or t==item_type.input_int or t==item_type.input_float or t==item_type.search or t==item_type.slider or t==item_type.int_option or t==item_type.float_toggle or t==item_type.int_toggle then menu.open_input_popup() end
    end
    if input.key_just_pressed(0x48) and t ~= item_type.sub_menu then menu.set_popup_mode(4) end
    if input.key_just_pressed(VK.DELETE) and item.hotkey and item.hotkey ~= 0 then
        menu.set_hotkey(sel, 0); notify.push(item.name, str.cleared or "CLEARED", 0); menu.save_hotkeys(); menu.rebuild_features()
    end
    if input.key_pressed(VK.LEFT) or input.key_pressed(VK.RIGHT) then
        local dir = input.key_pressed(VK.RIGHT) and 1 or -1
        if t==item_type.slider or t==item_type.float_toggle then menu.set_f_val(sel, clamp(item.f_val+item.f_step*dir, item.f_min, item.f_max))
        elseif t==item_type.int_option or t==item_type.int_toggle then menu.set_i_val(sel, clamp(item.i_val+item.i_step*dir, item.i_min, item.i_max))
        elseif t==item_type.loop_option or t==item_type.loop_toggle then
            local idx = item.value_index+dir; if idx>=item.value_count then idx=0 end; if idx<0 then idx=item.value_count-1 end; menu.set_value_index(sel, idx)
        elseif t==item_type.array_option or t==item_type.array_toggle then menu.open_array_popup() end
    end
end

---------------------------------------------------------------------------
-- POPUPS
---------------------------------------------------------------------------
local input_cursor, input_blink, input_open_time = 0, 0, 0
function draw_input_popup()
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    draw.rect(0,0,sw,sh,0,0,0,140)
    local pw, ph = 370, 122
    local px, py = (sw-pw)/2, (sh-ph)/2
    block(px, py, px+pw, py+ph, c.paper[1],c.paper[2],c.paper[3],255)
    local item = menu.get_item(menu.input_target_item())
    text.draw(font.label, px+20, py+18, c.accent[1],c.accent[2],c.accent[3], 255, string.upper(item and item.name or (str.edit_value or "EDIT")))
    local buf = menu.get_input_buffer()
    local ix, iy, iw, ih = px+18, py+46, pw-36, 36
    draw.rect(ix, iy, ix+iw, iy+ih, 255,255,255, 255)
    draw.rect_outline(ix, iy, ix+iw, iy+ih, c.ink[1],c.ink[2],c.ink[3], 255, 0, 2)
    local tx, ty = ix+12, iy+(ih-text.height(font.item))/2
    text.draw(font.item, tx, ty, c.ink[1],c.ink[2],c.ink[3],255, buf)
    if math.fmod(ctx.time()-input_blink, 1.0) < 0.55 then
        local cw = text.width(font.item, buf:sub(1, input_cursor))
        draw.rect(tx+cw, iy+7, tx+cw+2, iy+ih-7, c.ink[1],c.ink[2],c.ink[3], 255)
    end
end
function handle_input_popup()
    local elapsed = ctx.time()-input_open_time
    if input.key_just_pressed(VK.ESCAPE) then menu.set_popup_mode(0); return end
    if input.key_just_pressed(VK.RETURN) and elapsed>0.15 then menu.confirm_input(); return end
    local buf = menu.get_input_buffer()
    local chars = input.get_chars()
    if #chars>0 then buf=buf:sub(1,input_cursor)..chars..buf:sub(input_cursor+1); input_cursor=input_cursor+#chars; input_blink=ctx.time(); menu.set_input_buffer(buf) end
    if input.key_pressed(VK.BACK) and input_cursor>0 then buf=buf:sub(1,input_cursor-1)..buf:sub(input_cursor+1); input_cursor=input_cursor-1; input_blink=ctx.time(); menu.set_input_buffer(buf) end
    if input.key_pressed(VK.DELETE) and input_cursor<#buf then buf=buf:sub(1,input_cursor)..buf:sub(input_cursor+2); menu.set_input_buffer(buf) end
    if input.key_pressed(VK.LEFT) and input_cursor>0 then input_cursor=input_cursor-1; input_blink=ctx.time() end
    if input.key_pressed(VK.RIGHT) and input_cursor<#buf then input_cursor=input_cursor+1; input_blink=ctx.time() end
    if input.key_just_pressed(VK.HOME) then input_cursor=0; input_blink=ctx.time() end
    if input.key_just_pressed(VK.END) then input_cursor=#buf; input_blink=ctx.time() end
end
local orig_open_input = menu.open_input_popup
menu.open_input_popup = function() orig_open_input(); input_cursor=#menu.get_input_buffer(); input_blink=ctx.time(); input_open_time=ctx.time() end

local array_picker_idx, array_open_time = 0, 0
function draw_array_dropdown_popup()
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local sel = menu.selected_index()
    local item = menu.get_item(sel)
    if not item or item.value_count<=0 then menu.set_popup_mode(0); return end
    local values = menu.get_item_values(sel); if not values then menu.set_popup_mode(0); return end
    local dw, dh_item = 220, 34
    local count = item.value_count
    local dh = math.min(count*dh_item, dh_item*7)+6
    local dx = frame.menu_x+l.menu_w-dw-l.pad_x
    local dy = frame.popup_item_y or 300
    if dy+dh > sh-10 then dy = dy-dh-l.item_h end
    block(dx, dy, dx+dw, dy+dh, c.paper[1],c.paper[2],c.paper[3],255)
    local mx, my = input.mouse_x(), input.mouse_y()
    local vfh = text.height(font.value)
    for i = 1, count do
        local is_sel = ((i-1)==array_picker_idx)
        local is_cur = ((i-1)==item.value_index)
        local iy = dy+3+(i-1)*dh_item
        local hovered = mx>=dx and mx<=dx+dw and my>=iy and my<=iy+dh_item
        if hovered then array_picker_idx = i-1 end
        local ir, ig, ib = c.ink[1], c.ink[2], c.ink[3]
        if is_sel or hovered then draw.rect(dx+3, iy, dx+dw-3, iy+dh_item, c.ink[1],c.ink[2],c.ink[3], 255); ir,ig,ib = c.paper[1],c.paper[2],c.paper[3] end
        text.draw(font.value, dx+12, iy+(dh_item-vfh)/2, ir,ig,ib, 255, string.upper(values[i]))
        if is_cur then text.draw(font.value, dx+dw-22, iy+(dh_item-vfh)/2, c.accent[1],c.accent[2],c.accent[3], 255, "*") end
    end
end
function handle_array_dropdown()
    local elapsed = ctx.time()-array_open_time
    local sel = menu.selected_index()
    local item = menu.get_item(sel); if not item then menu.set_popup_mode(0); return end
    if input.key_just_pressed(VK.ESCAPE) or input.key_just_pressed(VK.BACK) then menu.set_popup_mode(0); return end
    if elapsed>0.1 then
        if input.key_pressed(VK.DOWN) and array_picker_idx<item.value_count-1 then array_picker_idx=array_picker_idx+1 end
        if input.key_pressed(VK.UP) and array_picker_idx>0 then array_picker_idx=array_picker_idx-1 end
        if input.key_just_pressed(VK.RETURN) then menu.set_value_index(sel, array_picker_idx); menu.set_popup_mode(0); return end
        local mx, my = input.mouse_x(), input.mouse_y()
        if input.mouse_clicked(0) and elapsed>0.15 then
            local dw, dh_item = 220, 34
            local dx = frame.menu_x+l.menu_w-dw-l.pad_x
            local dy = (frame.popup_item_y or 300)+3
            if mx>=dx and mx<=dx+dw and my>=dy and my<=dy+item.value_count*dh_item then
                local idx = math.floor((my-dy)/dh_item)
                if idx>=0 and idx<item.value_count then menu.set_value_index(sel, idx); menu.set_popup_mode(0); return end
            else menu.set_popup_mode(0); return end
        end
    end
end
local orig_open_array = menu.open_array_popup
menu.open_array_popup = function() orig_open_array(); local it=menu.get_item(menu.selected_index()); array_picker_idx = it and it.value_index or 0; array_open_time=ctx.time() end

function draw_hotkey_popup()
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    draw.rect(0,0,sw,sh,0,0,0,140)
    local pw, ph = 300, 80
    local px, py = (sw-pw)/2, (sh-ph)/2
    block(px, py, px+pw, py+ph, c.paper[1],c.paper[2],c.paper[3],255)
    local title = string.upper(str.press_key or "PRESS ANY KEY")
    text.draw(font.item, px+(pw-text.width(font.item,title))/2, py+18, c.ink[1],c.ink[2],c.ink[3],255, title)
    local hint = str.esc_cancel or "ESC TO CANCEL"
    text.draw(font.desc, px+(pw-text.width(font.desc,hint))/2, py+18+text.height(font.item)+8, c.ink[1],c.ink[2],c.ink[3],150, hint)
end
function handle_hotkey_bind()
    if input.key_just_pressed(VK.ESCAPE) then menu.set_popup_mode(0); notify.push("HOTKEY", str.cancelled or "CANCELLED", 0); return end
    local skip = {[27]=true,[1]=true,[2]=true,[4]=true,[16]=true,[17]=true,[18]=true,[160]=true,[161]=true,[162]=true,[163]=true,[164]=true,[165]=true}
    for vk = 1, 255 do
        if not skip[vk] and input.key_just_pressed(vk) then
            local sel = menu.selected_index()
            menu.set_hotkey(sel, vk)
            notify.push(menu.get_item(sel).name, (str.bound_to or "BOUND TO").." "..menu.vk_name(vk), 1)
            menu.save_hotkeys(); menu.rebuild_features(); menu.set_popup_mode(0); return
        end
    end
end

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
    draw.rect(0,0,sw,sh,0,0,0,140)
    local pw, ph = 400, 452
    local px, py = (sw-pw)/2, (sh-ph)/2
    block(px, py, px+pw, py+ph, c.paper[1],c.paper[2],c.paper[3],255)
    local tab_w, tab_h, tab_y = 90, 26, py+18
    local tabs = {string.upper(str.palette or "PALETTE"), string.upper(str.custom or "CUSTOM")}
    local mx, my = input.mouse_x(), input.mouse_y()
    for i=1,2 do
        local tx = px+18+(i-1)*(tab_w+8)
        local active = (cp_tab==i-1)
        draw.rect(tx, tab_y, tx+tab_w, tab_y+tab_h, active and c.accent[1] or c.paper[1], active and c.accent[2] or c.paper[2], active and c.accent[3] or c.paper[3], 255)
        draw.rect_outline(tx, tab_y, tx+tab_w, tab_y+tab_h, c.ink[1],c.ink[2],c.ink[3], 255, 0, 2)
        local tc = active and {255,255,255} or {c.ink[1],c.ink[2],c.ink[3]}
        text.draw(font.tagline, tx+(tab_w-text.width(font.tagline,tabs[i]))/2, tab_y+(tab_h-text.height(font.tagline))/2, tc[1],tc[2],tc[3], 255, tabs[i])
        if mx>=tx and mx<=tx+tab_w and my>=tab_y and my<=tab_y+tab_h and input.mouse_clicked(0) then cp_tab=i-1 end
    end
    local content_y = tab_y+tab_h+16
    if cp_tab==0 then
        local cell, gap = 36, 5
        local gx, gy = px+18, content_y
        for i=1,32 do
            local col, row = (i-1)%8, math.floor((i-1)/8)
            local cx, cyy = gx+col*(cell+gap), gy+row*(cell+gap)
            local pc = palette[i]
            draw.rect(cx, cyy, cx+cell, cyy+cell, pc[1],pc[2],pc[3],pc[4])
            draw.rect_outline(cx, cyy, cx+cell, cyy+cell, c.ink[1],c.ink[2],c.ink[3], 255, 0, 1)
            if cp_palette_idx==i-1 then draw.rect_outline(cx-3, cyy-3, cx+cell+3, cyy+cell+3, c.accent[1],c.accent[2],c.accent[3], 255, 0, 3) end
            if mx>=cx and mx<=cx+cell and my>=cyy and my<=cyy+cell and input.mouse_clicked(0) then cp_palette_idx=i-1 end
        end
        local pc = palette[cp_palette_idx+1]
        if pc then
            local prev_y = gy+4*(cell+gap)+14
            draw.rect(gx, prev_y, gx+48, prev_y+48, pc[1],pc[2],pc[3],pc[4])
            draw.rect_outline(gx, prev_y, gx+48, prev_y+48, c.ink[1],c.ink[2],c.ink[3], 255, 0, 2)
            text.draw(font.small, gx+60, prev_y+6, c.ink[1],c.ink[2],c.ink[3],255, string.format("R %d  G %d  B %d", pc[1],pc[2],pc[3]))
            text.draw(font.small, gx+60, prev_y+24, c.ink[1],c.ink[2],c.ink[3],180, string.format("#%02X%02X%02X", pc[1],pc[2],pc[3]))
        end
    else
        local sv_x, sv_y = px+18, content_y
        local sv_w, sv_h = 200, 180
        local hue_x, hue_w = sv_x+sv_w+14, 20
        local hr, hg, hb = util.hsv_to_rgb(cp_hue, 1, 1)
        draw.rect(sv_x, sv_y, sv_x+sv_w, sv_y+sv_h, hr, hg, hb, 255)
        draw.rect_gradient(sv_x, sv_y, sv_x+sv_w, sv_y+sv_h, 255,255,255,255,255,255,255,0,255,255,255,0,255,255,255,255)
        draw.rect_gradient(sv_x, sv_y, sv_x+sv_w, sv_y+sv_h, 0,0,0,0,0,0,0,0,0,0,0,255,0,0,0,255)
        draw.rect_outline(sv_x, sv_y, sv_x+sv_w, sv_y+sv_h, c.ink[1],c.ink[2],c.ink[3], 255, 0, 2)
        local scx, scy = sv_x+cp_sat*sv_w, sv_y+(1-cp_val)*sv_h
        draw.circle_outline(scx, scy, 6, 255,255,255,255, 2); draw.circle(scx, scy, 4, 0,0,0,200)
        for i=0,11 do
            local y1, y2 = sv_y+(i/12)*sv_h, sv_y+((i+1)/12)*sv_h
            local r1,g1,b1 = util.hsv_to_rgb((i/12)*360,1,1)
            local r2,g2,b2 = util.hsv_to_rgb(((i+1)/12)*360,1,1)
            draw.rect_gradient(hue_x, y1, hue_x+hue_w, y2, r1,g1,b1,255, r1,g1,b1,255, r2,g2,b2,255, r2,g2,b2,255)
        end
        draw.rect_outline(hue_x, sv_y, hue_x+hue_w, sv_y+sv_h, c.ink[1],c.ink[2],c.ink[3], 255, 0, 2)
        local hcy = sv_y+(cp_hue/360)*sv_h
        draw.rect_outline(hue_x-2, hcy-3, hue_x+hue_w+2, hcy+3, c.ink[1],c.ink[2],c.ink[3],255, 0, 2)
        local pr,pg,pb = util.hsv_to_rgb(cp_hue, cp_sat, cp_val)
        local prev_y = sv_y+sv_h+14
        draw.rect(sv_x, prev_y, sv_x+48, prev_y+48, pr,pg,pb,255)
        draw.rect_outline(sv_x, prev_y, sv_x+48, prev_y+48, c.ink[1],c.ink[2],c.ink[3], 255, 0, 2)
        text.draw(font.small, sv_x+60, prev_y+4, c.ink[1],c.ink[2],c.ink[3],255, string.format("R %d  G %d  B %d", pr,pg,pb))
        text.draw(font.small, sv_x+60, prev_y+20, c.ink[1],c.ink[2],c.ink[3],180, string.format("H %.0f  S %.0f%%  V %.0f%%", cp_hue, cp_sat*100, cp_val*100))
        text.draw(font.small, sv_x+60, prev_y+36, c.ink[1],c.ink[2],c.ink[3],180, string.format("#%02X%02X%02X", pr,pg,pb))
        if input.mouse_down(0) then
            if cp_dragging_sv or (mx>=sv_x and mx<=sv_x+sv_w and my>=sv_y and my<=sv_y+sv_h) then cp_dragging_sv=true; cp_sat=clamp((mx-sv_x)/sv_w,0,1); cp_val=1-clamp((my-sv_y)/sv_h,0,1) end
            if cp_dragging_hue or (mx>=hue_x and mx<=hue_x+hue_w and my>=sv_y and my<=sv_y+sv_h) then cp_dragging_hue=true; cp_hue=clamp((my-sv_y)/sv_h,0,1)*360 end
        else cp_dragging_sv=false; cp_dragging_hue=false end
    end
end
function handle_color_picker()
    local elapsed = ctx.time()-cp_open_time
    if input.key_just_pressed(VK.ESCAPE) or input.key_just_pressed(VK.BACK) then menu.set_popup_mode(0); return end
    if input.key_just_pressed(VK.RETURN) and elapsed>0.15 then
        local sel = menu.selected_index()
        if cp_tab==0 then local pc=palette[cp_palette_idx+1]; if pc then menu.set_item_color(sel, pc[1],pc[2],pc[3],pc[4]) end
        else local r,g,b = util.hsv_to_rgb(cp_hue,cp_sat,cp_val); menu.set_item_color(sel, r,g,b,255) end
        menu.set_popup_mode(0); return
    end
    if input.key_just_pressed(VK.TAB) then cp_tab = 1-cp_tab end
    if cp_tab==0 then
        if input.key_just_pressed(VK.RIGHT) then cp_palette_idx=math.min(cp_palette_idx+1,31) end
        if input.key_just_pressed(VK.LEFT) then cp_palette_idx=math.max(cp_palette_idx-1,0) end
        if input.key_just_pressed(VK.DOWN) then cp_palette_idx=math.min(cp_palette_idx+8,31) end
        if input.key_just_pressed(VK.UP) then cp_palette_idx=math.max(cp_palette_idx-8,0) end
    else
        if input.key_pressed(VK.LEFT) then cp_sat=clamp(cp_sat-0.02,0,1) end
        if input.key_pressed(VK.RIGHT) then cp_sat=clamp(cp_sat+0.02,0,1) end
        if input.key_pressed(VK.UP) then cp_val=clamp(cp_val+0.02,0,1) end
        if input.key_pressed(VK.DOWN) then cp_val=clamp(cp_val-0.02,0,1) end
        if input.key_down(VK.SHIFT) then
            if input.key_pressed(VK.LEFT) then cp_hue=(cp_hue-5)%360 end
            if input.key_pressed(VK.RIGHT) then cp_hue=(cp_hue+5)%360 end
        end
    end
end
local orig_activate = menu.activate
menu.activate = function()
    local sel = menu.selected_index()
    local item = menu.get_item(sel)
    if item and item.type==item_type.color then
        menu.set_popup_mode(2); cp_tab,cp_palette_idx,cp_open_time = 0,0,ctx.time()
        cp_hue,cp_sat,cp_val = util.rgb_to_hsv(item.r, item.g, item.b); return
    end
    orig_activate()
end
