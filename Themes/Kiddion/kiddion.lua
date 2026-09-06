-- Kiddion's Modest Menu style — full-width list, blue title/footer bars,
-- lime-green selection with dark text, right-aligned checkboxes / steppers.
-- Standard menu API.

text.set_size(font.title, 15);  text.set_weight(font.title, 700)
text.set_size(font.item, 14);   text.set_weight(font.item, 700)
text.set_size(font.value, 13);  text.set_weight(font.value, 700)
text.set_size(font.small, 12);  text.set_weight(font.small, 700)

-- ── Settings ──
local function sc(name) local s=menu.get_setting(name); if s then return {s.r,s.g,s.b,s.a} end end
local function sf(name,d) local s=menu.get_setting(name); if s then return s.f_val end; return d end
local function reload()
    local title = sc("Title Bar") or {42, 80, 128, 255}
    return {
        sel    = sc("Selection") or {176, 200, 8, 255},
        title  = title,
        title2 = {math.floor(title[1]*0.55), math.floor(title[2]*0.55), math.floor(title[3]*0.6), 255},
        bg     = sc("Background") or {16, 26, 40, 235},
        ink    = {18, 26, 12},        -- text on the green selection bar
        txt    = {236, 239, 242},
        val    = {210, 220, 230},
        w      = sf("Menu Width", 372),
        ih     = sf("Row Height", 22),
    }
end
menu.clear_settings()
menu.add_setting_submenu("Colors", "Kiddion palette")
menu.add_sub_color("Selection", 176, 200, 8, 255, "Highlight bar")
menu.add_sub_color("Title Bar", 42, 80, 128, 255, "Title/footer bar")
menu.add_sub_color("Background", 16, 26, 40, 235, "List background")
menu.add_setting_submenu("Layout", "Sizes")
menu.add_sub_slider("Menu Width", 372, 240, 600, 4, "Width (px)")
menu.add_sub_slider("Row Height", 22, 16, 40, 1, "Row height (px)")

local c = reload()

-- ── Helpers / state ──
local function lerp(a,b,t) return a+(b-a)*t end
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
local TITLE_H, FOOT_H, PAD = 28, 26, 12
local scroll, scroll_t = 0, 0
local last_page, last_sel = "", -1
local dragging_slider, drag_x, drag_w = -1, 0, 0
local frame = { x=0, list_y=0, popup_item_y=0 }

local function ink(is_sel) if is_sel then return c.ink[1],c.ink[2],c.ink[3] else return c.txt[1],c.txt[2],c.txt[3] end end

-- ── Widgets ──
local function draw_check(rx, yc, on, is_sel)
    local s = 13
    local x1 = rx - s
    local r,g,b = ink(is_sel)
    draw.rect_outline(x1, yc-s/2, rx, yc+s/2, r,g,b, is_sel and 255 or 190, 0, 1)
    if on then
        draw.line(x1+3, yc+1, x1+s*0.42, yc+s/2-3, r,g,b,255, 2)
        draw.line(x1+s*0.42, yc+s/2-3, rx-2, yc-s/2+2, r,g,b,255, 2)
    end
end

local function tri_l(cx, cy, r,g,b,a)
    draw.line(cx-4, cy, cx+3, cy-4, r,g,b,a, 2)
    draw.line(cx-4, cy, cx+3, cy+4, r,g,b,a, 2)
    draw.line(cx+3, cy-4, cx+3, cy+4, r,g,b,a, 2)
end
local function tri_r(cx, cy, r,g,b,a)
    draw.line(cx+4, cy, cx-3, cy-4, r,g,b,a, 2)
    draw.line(cx+4, cy, cx-3, cy+4, r,g,b,a, 2)
    draw.line(cx-3, cy-4, cx-3, cy+4, r,g,b,a, 2)
end

local function draw_stepper(rx, yc, val_text, is_sel)
    local r,g,b = ink(is_sel)
    local fh = text.height(font.value)
    local ra_cx = rx - 5
    tri_r(ra_cx, yc, r,g,b, 255)
    local vw = text.width(font.value, val_text)
    local v_right = ra_cx - 7
    local v_left = v_right - vw
    text.draw(font.value, v_left, yc-fh/2, r,g,b, 255, val_text)
    tri_l(v_left - 7, yc, r,g,b, 255)
    return v_left - 7 - 5
end

local function draw_widget(rx, yc, item, is_sel)
    local t = item.type
    if t == item_type.toggle then
        draw_check(rx, yc, item.on, is_sel)
    elseif t == item_type.float_toggle then
        draw_check(rx, yc, item.on, is_sel)
        draw_stepper(rx-22, yc, string.format("%.2f", item.f_val), is_sel)
    elseif t == item_type.int_toggle then
        draw_check(rx, yc, item.on, is_sel)
        draw_stepper(rx-22, yc, tostring(item.i_val), is_sel)
    elseif t == item_type.array_toggle or t == item_type.loop_toggle then
        draw_check(rx, yc, item.on, is_sel)
        draw_stepper(rx-22, yc, item.current_value or "?", is_sel)
    elseif t == item_type.slider then
        draw_stepper(rx, yc, string.format("%.2f", item.f_val), is_sel)
    elseif t == item_type.int_option then
        draw_stepper(rx, yc, tostring(item.i_val), is_sel)
    elseif t == item_type.array_option or t == item_type.loop_option then
        draw_stepper(rx, yc, item.current_value or "?", is_sel)
    elseif t == item_type.color then
        local s = 16
        draw.rect(rx-s, yc-s/2, rx, yc+s/2, item.r, item.g, item.b, item.a or 255)
        local r,g,b = ink(is_sel)
        draw.rect_outline(rx-s, yc-s/2, rx, yc+s/2, r,g,b, is_sel and 255 or 160, 0, 1)
    elseif t == item_type.selected_tick then
        local s = 13
        local r,g,b = ink(is_sel)
        draw.line(rx-s+3, yc+1, rx-s*0.58, yc+s/2-3, r,g,b,255, 2)
        draw.line(rx-s*0.58, yc+s/2-3, rx-2, yc-s/2+2, r,g,b,255, 2)
    elseif t == item_type.input_text then
        local r,g,b = ink(is_sel)
        text.draw(font.value, rx-text.width(font.value,item.name), yc-text.height(font.value)/2, r,g,b, 255, item.name)
    elseif t == item_type.input_int then
        local r,g,b = ink(is_sel); local vs=tostring(item.i_val)
        text.draw(font.value, rx-text.width(font.value,vs), yc-text.height(font.value)/2, r,g,b, 255, vs)
    elseif t == item_type.input_float then
        local r,g,b = ink(is_sel); local vs=string.format("%.2f",item.f_val)
        text.draw(font.value, rx-text.width(font.value,vs), yc-text.height(font.value)/2, r,g,b, 255, vs)
    elseif t == item_type.search then
        -- magnifier glyph on the far right (procedural, no PNG)
        local r,g,b = ink(is_sel)
        local gr = 7   -- glyph radius
        local gcx = rx - gr - 1
        draw.circle_outline(gcx, yc, gr, r,g,b, is_sel and 255 or 190, 1.5)
        local hoff = math.floor(gr * 0.707 + 0.5)
        draw.line(gcx+hoff, yc+hoff, gcx+hoff+5, yc+hoff+5, r,g,b, is_sel and 255 or 190, 2)
        -- query text to the left of the glyph
        local q = (item.text and item.text ~= "") and item.text or "Search..."
        local qr, qg, qb
        if item.text and item.text ~= "" then qr,qg,qb = r,g,b else qr,qg,qb = 100,110,120 end
        local qw = text.width(font.value, q)
        local glyph_w = gr*2 + 7
        text.draw(font.value, rx - glyph_w - 6 - qw, yc - text.height(font.value)/2, qr,qg,qb, 255, q)
    end
end

-- ══════════════════ MAIN ══════════════════
function draw_menu()
    c = reload()
    theme.set_body_bg(10, 14, 20, 255)
    if not menu.is_visible() then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local dt = ctx.delta()
    local page = menu.page_name()
    if page ~= last_page then last_page=page; scroll=0; scroll_t=0 end
    local sel = menu.selected_index()
    local sel_changed = (sel ~= last_sel)
    local count = menu.item_count()

    local mx, my = 10, 10

    -- Header drag-to-move: pass natural origin, add returned offset
    local _dox, _doy = menu.drag_header(mx, my, c.w, TITLE_H)
    mx = mx + _dox
    my = my + _doy

    frame.x = mx
    local list_max = sh - my - TITLE_H - FOOT_H - 10
    local content_h = count * c.ih
    local list_h = math.min(list_max, content_h)
    local total_h = TITLE_H + list_h + FOOT_H
    local R = 3

    -- panel body (rounded)
    draw.rect(mx, my, mx+c.w, my+total_h, c.bg[1],c.bg[2],c.bg[3],c.bg[4], R)

    -- ── Title bar (rounded top, squared bottom) ──
    draw.rect(mx, my, mx+c.w, my+TITLE_H, c.title[1],c.title[2],c.title[3],255, R)
    draw.rect(mx, my+TITLE_H-R, mx+c.w, my+TITLE_H, c.title[1],c.title[2],c.title[3],255)
    draw.rect(mx, my+TITLE_H-2, mx+c.w, my+TITLE_H, c.title2[1],c.title2[2],c.title2[3],255)
    draw.rect(mx+R, my+1, mx+c.w-R, my+2, 255,255,255,55)
    local ttl = (menu.page_parent()=="" ) and string.upper(str.brand or "Nenyoo") or menu.page_name()
    local tw = text.width(font.title, ttl)
    text.draw(font.title, mx+(c.w-tw)/2, my+(TITLE_H-text.height(font.title))/2, 255,255,255,255, ttl)

    -- ── List ──
    local list_y = my + TITLE_H
    frame.list_y = list_y

    -- scroll to keep selection visible
    local scroll_max = math.max(0, content_h - list_h)
    if sel_changed then
        local st = sel*c.ih; local sb = st+c.ih
        if sb > scroll_t+list_h then scroll_t = sb-list_h end
        if st < scroll_t then scroll_t = st end
        last_sel = sel
    end
    scroll_t = clamp(scroll_t, 0, scroll_max)
    scroll = lerp(scroll, scroll_t, clamp(dt*18,0,1))

    local imx, imy = input.mouse_x(), input.mouse_y()
    local in_list = imx>=mx and imx<=mx+c.w and imy>=list_y and imy<=list_y+list_h
    if in_list and menu.popup_mode()==0 then
        local wh = input.mouse_wheel()
        if wh~=0 then scroll_t = clamp(scroll_t - wh*c.ih*3, 0, scroll_max) end
    end

    if dragging_slider >= 0 then
        local di = menu.get_item(dragging_slider)
        if di and input.mouse_down(0) then
            local pct = clamp((imx-drag_x)/drag_w,0,1)
            local raw = di.f_min + pct*(di.f_max-di.f_min)
            if di.f_step>0 then raw = di.f_min + math.floor((raw-di.f_min)/di.f_step+0.5)*di.f_step end
            menu.set_f_val(dragging_slider, clamp(raw, di.f_min, di.f_max))
        else dragging_slider=-1 end
    end

    -- ── Rows ──
    draw.push_clip(mx, list_y, mx+c.w, list_y+list_h)
    local fh = text.height(font.item)
    for i=0,count-1 do
        local item = menu.get_item(i); if not item then goto cont end
        local is_sel = (i==sel)
        local iy = list_y + i*c.ih - scroll
        if iy+c.ih < list_y or iy > list_y+list_h then goto cont end
        local hovered = in_list and imy>=iy and imy<=iy+c.ih

        if is_sel then
            menu.set_popup_item_y(iy+c.ih); frame.popup_item_y = iy+c.ih
            draw.rect(mx, iy, mx+c.w, iy+c.ih, c.sel[1],c.sel[2],c.sel[3],255)
            draw.rect(mx, iy, mx+c.w, iy+1, math.min(c.sel[1]+30,255),math.min(c.sel[2]+30,255),math.min(c.sel[3]+30,255),160)
        elseif hovered then
            draw.rect(mx, iy, mx+c.w, iy+c.ih, 255,255,255,12)
        end
        -- separator
        draw.rect(mx, iy+c.ih-1, mx+c.w, iy+c.ih, 0,0,0,is_sel and 0 or 40)

        -- mouse interaction
        if hovered and input.mouse_clicked(0) and menu.popup_mode()==0 and dragging_slider<0 then
            local t=item.type
            local handled=false
            if t==item_type.toggle or t==item_type.float_toggle or t==item_type.int_toggle or t==item_type.array_toggle or t==item_type.loop_toggle then
                if imx >= mx+c.w-24 then menu.set_selected(i); menu.toggle_item(i)
                    notify.push(item.name, item.on and "Disabled" or "Enabled", item.on and 2 or 1); handled=true end
            end
            if not handled then if is_sel then menu.activate() else menu.set_selected(i) end end
        end

        local r,g,b = ink(is_sel)
        text.draw(font.item, mx+PAD, iy+(c.ih-fh)/2, r,g,b, 255, item.name)
        draw_widget(mx+c.w-PAD, iy+c.ih/2, item, is_sel)
        ::cont::
    end
    draw.pop_clip()

    -- thin scroll indicator
    if content_h > list_h then
        local th = math.max((list_h/content_h)*list_h, 20)
        local fr = scroll_max>0 and scroll/scroll_max or 0
        draw.rect(mx+c.w-3, list_y+fr*(list_h-th), mx+c.w, list_y+fr*(list_h-th)+th, c.sel[1],c.sel[2],c.sel[3],160)
    end

    -- ── Footer (flat text on dark body — Kiddion style) ──
    local fy = list_y + list_h
    draw.rect(mx+6, fy, mx+c.w-6, fy+1, c.title[1],c.title[2],c.title[3],110)
    local cnt = string.format("%d / %d", sel+1, count)
    local cw = text.width(font.small, cnt)
    text.draw(font.small, mx+(c.w-cw)/2, fy+(FOOT_H-text.height(font.small))/2, 200,212,226,220, cnt)

    -- subtle dark edge (no bright border)
    draw.rect_outline(mx, my, mx+c.w, my+total_h, 6,10,16,200, R, 1)

    local pm = menu.popup_mode()
    if pm==1 then draw_input_popup() end
    if pm==2 then draw_color_picker() end
    if pm==4 then draw_hotkey_popup() end
end

-- ══════════════════ INPUT ══════════════════
function handle_input()
    if not menu.is_visible() then return end
    local pm = menu.popup_mode()
    if pm==1 then handle_input_popup(); return end
    if pm==2 then handle_color_picker(); return end
    if pm==4 then handle_hotkey_bind(); return end

    if input.key_pressed(VK.UP) then menu.move_selection(-1) end
    if input.key_pressed(VK.DOWN) then menu.move_selection(1) end
    if input.key_just_pressed(VK.RETURN) then menu.activate() end
    if input.key_just_pressed(VK.BACK) or input.key_just_pressed(VK.ESCAPE) then menu.go_back() end

    local sel = menu.selected_index()
    local item = menu.get_item(sel); if not item then return end
    local t = item.type

    if input.key_just_pressed(VK.SPACE) then
        if t==item_type.input_text or t==item_type.input_int or t==item_type.input_float then menu.open_input_popup()
        elseif t==item_type.search then
            menu.set_input_buffer(item.text or ""); menu.open_input_popup()
        end
    end
    if input.key_just_pressed(0x48) and t ~= item_type.sub_menu then menu.set_popup_mode(4) end
    if input.key_just_pressed(VK.DELETE) and item.hotkey and item.hotkey ~= 0 then
        menu.set_hotkey(sel, 0); notify.push(item.name, str.cleared or "Cleared", 0); menu.save_hotkeys(); menu.rebuild_features()
    end

    if input.key_pressed(VK.LEFT) or input.key_pressed(VK.RIGHT) then
        local dir = input.key_pressed(VK.RIGHT) and 1 or -1
        if t==item_type.slider or t==item_type.float_toggle then menu.set_f_val(sel, clamp(item.f_val+item.f_step*dir, item.f_min, item.f_max))
        elseif t==item_type.int_option or t==item_type.int_toggle then menu.set_i_val(sel, clamp(item.i_val+item.i_step*dir, item.i_min, item.i_max))
        elseif t==item_type.array_option or t==item_type.array_toggle or t==item_type.loop_option or t==item_type.loop_toggle then
            local idx=item.value_index+dir
            if idx>=item.value_count then idx=0 end; if idx<0 then idx=item.value_count-1 end
            menu.set_value_index(sel, idx)
        end
    end
end

-- ══════════════════ POPUPS ══════════════════
local input_cursor, input_blink, input_open_time = 0, 0, 0
function draw_input_popup()
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    draw.rect(0,0,sw,sh,0,0,0,150)
    local pw, ph = 340, 110
    local px, py = (sw-pw)/2, (sh-ph)/2
    draw.rect(px,py,px+pw,py+ph, c.bg[1],c.bg[2],c.bg[3],255)
    draw.rect(px,py,px+pw,py+3, c.title[1],c.title[2],c.title[3],255)
    draw.rect_outline(px,py,px+pw,py+ph, 0,0,0,160, 0, 1)
    local item = menu.get_item(menu.input_target_item())
    text.draw(font.small, px+16, py+14, c.sel[1],c.sel[2],c.sel[3],255, string.upper(item and item.name or "Edit"))
    local buf = menu.get_input_buffer()
    local ix,iy,iw,ih = px+16, py+40, pw-32, 32
    draw.rect(ix,iy,ix+iw,iy+ih, 8,14,22,255)
    draw.rect_outline(ix,iy,ix+iw,iy+ih, c.title[1],c.title[2],c.title[3],200, 0, 1)
    local tx,ty = ix+10, iy+(ih-text.height(font.item))/2
    text.draw(font.item, tx, ty, c.txt[1],c.txt[2],c.txt[3],255, buf)
    if math.fmod(ctx.time()-input_blink,1.0)<0.55 then
        local cwd=text.width(font.item, buf:sub(1,input_cursor))
        draw.rect(tx+cwd, iy+6, tx+cwd+2, iy+ih-6, c.sel[1],c.sel[2],c.sel[3],255)
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
    if input.key_pressed(VK.LEFT) and input_cursor>0 then input_cursor=input_cursor-1; input_blink=ctx.time() end
    if input.key_pressed(VK.RIGHT) and input_cursor<#buf then input_cursor=input_cursor+1; input_blink=ctx.time() end
end
local orig_open_input = menu.open_input_popup
menu.open_input_popup = function() orig_open_input(); input_cursor=#menu.get_input_buffer(); input_blink=ctx.time(); input_open_time=ctx.time() end

function draw_hotkey_popup()
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    draw.rect(0,0,sw,sh,0,0,0,150)
    local pw, ph = 280, 70
    local px, py = (sw-pw)/2, (sh-ph)/2
    draw.rect(px,py,px+pw,py+ph, c.bg[1],c.bg[2],c.bg[3],255)
    draw.rect(px,py,px+pw,py+3, c.sel[1],c.sel[2],c.sel[3],255)
    draw.rect_outline(px,py,px+pw,py+ph, 0,0,0,160, 0, 1)
    local title = str.press_key or "Press any key..."
    text.draw(font.item, px+(pw-text.width(font.item,title))/2, py+16, 255,255,255,235, title)
    local hint = str.esc_cancel or "ESC to cancel"
    text.draw(font.small, px+(pw-text.width(font.small,hint))/2, py+16+text.height(font.item)+8, c.val[1],c.val[2],c.val[3],200, hint)
end
function handle_hotkey_bind()
    if input.key_just_pressed(VK.ESCAPE) then menu.set_popup_mode(0); notify.push("Hotkey", str.cancelled or "Cancelled", 0); return end
    local skip = {[27]=true,[1]=true,[2]=true,[4]=true,[16]=true,[17]=true,[18]=true,[160]=true,[161]=true,[162]=true,[163]=true,[164]=true,[165]=true}
    for vk=1,255 do
        if not skip[vk] and input.key_just_pressed(vk) then
            local sel=menu.selected_index(); menu.set_hotkey(sel, vk)
            notify.push(menu.get_item(sel).name, (str.bound_to or "Bound to").." "..menu.vk_name(vk), 1)
            menu.save_hotkeys(); menu.rebuild_features(); menu.set_popup_mode(0); return
        end
    end
end

-- ── Color picker (simple, Kiddion-ish) ──
local cp_hue, cp_sat, cp_val = 0,1,1
local cp_sv, cp_hd, cp_open = false, false, 0
function draw_color_picker()
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    draw.rect(0,0,sw,sh,0,0,0,150)
    local pw, ph = 300, 250
    local px, py = (sw-pw)/2, (sh-ph)/2
    draw.rect(px,py,px+pw,py+ph, c.bg[1],c.bg[2],c.bg[3],255)
    draw.rect(px,py,px+pw,py+3, c.title[1],c.title[2],c.title[3],255)
    draw.rect_outline(px,py,px+pw,py+ph, 0,0,0,160, 0, 1)
    local mx,my = input.mouse_x(), input.mouse_y()
    local svx,svy,svw,svh = px+16, py+20, pw-16-30-16, ph-20-60
    local hx,hw = svx+svw+12, 18
    local hr,hg,hb = util.hsv_to_rgb(cp_hue,1,1)
    draw.rect(svx,svy,svx+svw,svy+svh, hr,hg,hb,255)
    draw.rect_gradient(svx,svy,svx+svw,svy+svh, 255,255,255,255,255,255,255,0,255,255,255,0,255,255,255,255)
    draw.rect_gradient(svx,svy,svx+svw,svy+svh, 0,0,0,0,0,0,0,0,0,0,0,255,0,0,0,255)
    draw.circle_outline(svx+cp_sat*svw, svy+(1-cp_val)*svh, 5, 255,255,255,255, 2)
    for i=0,11 do
        local y1=svy+(i/12)*svh; local y2=svy+((i+1)/12)*svh
        local r1,g1,b1=util.hsv_to_rgb(i/12*360,1,1); local r2,g2,b2=util.hsv_to_rgb((i+1)/12*360,1,1)
        draw.rect_gradient(hx,y1,hx+hw,y2, r1,g1,b1,255,r1,g1,b1,255,r2,g2,b2,255,r2,g2,b2,255)
    end
    draw.rect(hx-2, svy+(cp_hue/360)*svh-2, hx+hw+2, svy+(cp_hue/360)*svh+2, 255,255,255,255)
    local pr,pg,pb = util.hsv_to_rgb(cp_hue,cp_sat,cp_val)
    draw.rect(px+16, py+ph-46, px+16+40, py+ph-16, pr,pg,pb,255)
    text.draw(font.small, px+64, py+ph-42, c.txt[1],c.txt[2],c.txt[3],255, string.format("#%02X%02X%02X", pr,pg,pb))
    text.draw(font.small, px+64, py+ph-26, c.val[1],c.val[2],c.val[3],200, "Enter: apply   Esc: cancel")
    if input.mouse_down(0) then
        if cp_sv or (mx>=svx and mx<=svx+svw and my>=svy and my<=svy+svh) then cp_sv=true; cp_sat=clamp((mx-svx)/svw,0,1); cp_val=clamp(1-(my-svy)/svh,0,1) end
        if cp_hd or (mx>=hx and mx<=hx+hw and my>=svy and my<=svy+svh) then cp_hd=true; cp_hue=clamp((my-svy)/svh,0,0.999)*360 end
    else cp_sv=false; cp_hd=false end
end
function handle_color_picker()
    if input.key_just_pressed(VK.ESCAPE) or input.key_just_pressed(VK.BACK) then menu.set_popup_mode(0); return end
    if input.key_just_pressed(VK.RETURN) and ctx.time()-cp_open>0.15 then
        local r,g,b = util.hsv_to_rgb(cp_hue,cp_sat,cp_val)
        menu.set_item_color(menu.selected_index(), r,g,b,255); menu.set_popup_mode(0); return
    end
end
local orig_activate = menu.activate
menu.activate = function()
    local sel = menu.selected_index(); local item = menu.get_item(sel)
    if item and item.type==item_type.color then
        menu.set_popup_mode(2); cp_open=ctx.time(); cp_hue,cp_sat,cp_val = util.rgb_to_hsv(item.r,item.g,item.b); return
    end
    if item and item.type==item_type.search then
        menu.set_input_buffer(item.text or ""); menu.open_input_popup(); return
    end
    orig_activate()
end
