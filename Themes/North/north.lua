-- North-style Click GUI — top icon tab-bar, left sub-page sidebar,
-- 2-column auto-flattened section panels. Dark navy + bright blue.
-- Built on the Nenyoo theme API + items registry (see Cherax for reference).

-- ── Fonts ──
text.set_size(font.title, 22);      text.set_weight(font.title, 800)
text.set_size(font.item, 12);       text.set_weight(font.item, 500)
text.set_size(font.breadcrumb, 12); text.set_weight(font.breadcrumb, 600)
text.set_size(font.small, 11);      text.set_weight(font.small, 700)
text.set_size(font.value, 12);      text.set_weight(font.value, 600)
text.set_size(font.tiny, 9);        text.set_weight(font.tiny, 600)

-- Icon font (FontAwesome) — reuse Cherax's bundled file; degrade gracefully
local have_icons = false
pcall(function()
    text.set_icon_font(font.label, "themes/Cherax/fonts/FontAwesome.ttf")
    text.set_size(font.label, 16)
    text.set_weight(font.label, 400)
    have_icons = true
end)

-- A pool of FontAwesome glyphs mapped to categories by index
local fa_pool = {
    "\xEF\x80\x87", -- user
    "\xEF\x81\x9B", -- crosshairs
    "\xEF\x86\xB9", -- car
    "\xEF\x84\xA4", -- location-arrow
    "\xEF\x89\xB9", -- map
    "\xEF\x83\x80", -- users
    "\xEF\x84\xB2", -- shield
    "\xEF\x83\x96", -- usd
    "\xEF\x82\xAC", -- globe
    "\xEF\x83\xA7", -- bolt
    "\xEF\x82\xAD", -- wrench
    "\xEF\x80\xBA", -- list
    "\xEF\x80\x85", -- star
    "\xEF\x80\x93", -- cog
}

-- ── Settings ──
menu.clear_settings()
menu.add_setting_submenu("Colors", "Theme colors")
menu.add_sub_color("Accent", 59, 130, 246, 255, "Primary accent")
menu.add_sub_color("Background", 16, 21, 34, 255, "Window background")
menu.add_setting_submenu("Window", "Sizing")
menu.add_sub_slider("Window Width", 700, 520, 1000, 10, "Window width (px)")
menu.add_sub_slider("Window Height", 520, 360, 800, 10, "Window height (px)")

-- ── Colors ──
local function sc(name) local s=menu.get_setting(name); if s then return {s.r,s.g,s.b,s.a} end end
local function sf(name,d) local s=menu.get_setting(name); if s then return s.f_val end; return d end
local function make_colors()
    local acc = sc("Accent") or {59,130,246,255}
    local bg  = sc("Background") or {16,21,34,255}
    return {
        bg    = {bg[1], bg[2], bg[3], 250},
        hdr   = {math.floor(bg[1]*0.5), math.floor(bg[2]*0.5), math.floor(bg[3]*0.52), 255},
        hdr2  = {math.floor(bg[1]*0.36), math.floor(bg[2]*0.36), math.floor(bg[3]*0.4), 255},
        side  = {math.floor(bg[1]*0.6), math.floor(bg[2]*0.6), math.floor(bg[3]*0.62), 255},
        panel = {bg[1]+9, bg[2]+12, bg[3]+18, 255},
        sec   = {bg[1]+14, bg[2]+18, bg[3]+26, 255},
        acc   = acc,
        acc2  = {math.max(acc[1]-24,0), math.max(acc[2]-40,0), math.max(acc[3]-30,0), 255},
        txt   = {224, 230, 240, 255},
        txt2  = {120, 134, 158, 255},
        hov   = {255, 255, 255, 12},
        div   = {44, 54, 78, 200},
        sli   = {34, 42, 62, 255},
        chk   = {30, 38, 58, 255},
        inp   = {26, 33, 50, 255},
        bdr   = {60, 80, 120, 160},
        btn   = acc,
        btn_h = {math.min(acc[1]+30,255), math.min(acc[2]+30,255), math.min(acc[3]+20,255), 255},
    }
end
local C = make_colors()

-- ── Layout ──
local WIN_W, WIN_H = 700, 520
local HDR_H   = 46
local SIDE_W  = 124
local TABICON = 40
local ITEM_H  = 22
local SEC_H   = 22
local BTN_H   = 22
local BTN_PAD = 5
local PAD     = 9
local CHK     = 13
local SLI_H   = 4
local SCROLL_W= 3

-- ── State ──
local win_x, win_y
-- Manual drag state removed: handled by menu.drag_header() in draw_menu
local cats, cats_built = {}, false
local active_cat = 0
local scroll_l, scroll_r, scroll_tl, scroll_tr = 0,0,0,0
local hover_idx = -1
local click_consumed = false

local drag_sl, drag_sl_x, drag_sl_w = -1, 0, 0
local drag_sl_mn, drag_sl_mx, drag_sl_int, drag_sl_handle = 0, 0, false, false

local edit_on, edit_idx, edit_buf, edit_type = false, -1, "", 0
local edit_handle = false

local cpick, cpick_idx, cpick_handle = false, -1, false
local cpick_v, cpick_drag, cpick_frame = {0,0,0,255}, 0, 0
local cpick_x, cpick_y, cpick_mode = 0, 0, 0
local cpick_h, cpick_s, cpick_val = 0, 1, 1
local cpick_sv_drag, cpick_hue_drag = false, false

local dd_open, dd_idx, dd_handle = false, -1, false
local dd_x, dd_y, dd_w, dd_values, dd_scroll, dd_frame = 0,0,0,{},0,0

local sub_tabs, sub_sel, sub_parent, has_gen = {}, -1, "", false

-- ── Icons ──
local IMG = {}
local function load_icon(key, file)
    local h = draw.load_image("textures/"..file)
    if h and h > 0 then IMG[key] = h end
end
local function icon_h(key, x, cy, target_h, r,g,b,a)
    local h = IMG[key]; if not h then return 0 end
    local iw, ih = draw.image_size(h)
    if not iw or iw==0 then return 0 end
    local w = iw * (target_h/ih)
    local iy2 = cy - target_h*0.5
    if r then draw.image_colored(h, x, iy2, x+w, iy2+target_h, r,g,b,a)
    else draw.image(h, x, iy2, x+w, iy2+target_h) end
    return w
end
load_icon("search", "search.png")

-- ── Helpers ──
local function lerp(a,b,t) return a+(b-a)*t end
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
local function hit(x1,y1,x2,y2)
    local mx,my=input.mouse_x(),input.mouse_y()
    return mx>=x1 and mx<x2 and my>=y1 and my<y2
end
local function clk(x1,y1,x2,y2) return hit(x1,y1,x2,y2) and input.mouse_clicked(0) end
local function ctxt(f,x1,x2,y,s,r,g,b,a) text.draw(f,x1+(x2-x1-text.width(f,s))*0.5,y,r,g,b,a,s) end
local function init_pos() if not win_x then win_x=(ctx.screen_w()-WIN_W)/2; win_y=(ctx.screen_h()-WIN_H)/2 end end

-- ── Categories (dynamic, read from root) ──
local function build_cats()
    cats = {}
    while menu.page_parent() ~= "" do menu.go_back() end
    local n = menu.item_count()
    for i=0,n-1 do
        local it = menu.get_item(i)
        if it and it.type == item_type.sub_menu then
            table.insert(cats, {label=it.name, idx=i})
        end
    end
    cats_built = true
end

local function rebuild_subs()
    sub_tabs = {}; has_gen = false; sub_parent = menu.page_name()
    local count = menu.item_count()
    for i=0,count-1 do
        local it = menu.get_item(i)
        if it then
            if it.type == item_type.sub_menu then
                table.insert(sub_tabs, {name=it.name, idx=i})
            else has_gen = true end
        end
    end
    if not has_gen and #sub_tabs > 0 then
        menu.set_selected(sub_tabs[1].idx); menu.activate(); sub_sel = 1
    else sub_sel = -1 end
end

local function depth()
    if menu.page_name() == sub_parent then return 0 end
    if menu.page_parent() == sub_parent then return 1 end
    return 2
end

local function reset_scroll() scroll_tl=0;scroll_tr=0;scroll_l=0;scroll_r=0 end

local function go_cat(i)
    active_cat = i
    while menu.page_parent() ~= "" do menu.go_back() end
    if cats[i+1] then menu.set_selected(cats[i+1].idx); menu.activate() end
    rebuild_subs(); reset_scroll()
    hover_idx=-1; cpick=false; edit_on=false; dd_open=false
end

local function go_sub(i)
    if sub_sel ~= -1 and depth() >= 1 then menu.go_back() end
    if i == -1 then sub_sel = -1
    else menu.set_selected(sub_tabs[i].idx); menu.activate(); sub_sel = i end
    reset_scroll(); hover_idx=-1; cpick=false; edit_on=false; dd_open=false
end

-- ── Edit (text/number input) ──
local function apply_edit()
    if not edit_on then return end
    if edit_type==item_type.input_float or edit_type==item_type.slider or edit_type==item_type.float_toggle then
        local v=tonumber(edit_buf); if v then if edit_handle then items.set_f_val(edit_idx,v) else menu.set_f_val(edit_idx,v) end end
    elseif edit_type==item_type.input_int or edit_type==item_type.int_option or edit_type==item_type.int_toggle then
        local v=tonumber(edit_buf); if v then if edit_handle then items.set_i_val(edit_idx,math.floor(v)) else menu.set_i_val(edit_idx,math.floor(v)) end end
    else
        menu.set_selected(edit_idx); menu.set_input_buffer(edit_buf); menu.confirm_input()
    end
    edit_on=false
end
local function proc_edit()
    if not edit_on then return end
    local chars = input.get_chars()
    if chars ~= "" then
        for ch in chars:gmatch(".") do
            local b=string.byte(ch)
            if edit_type==item_type.input_text or edit_type==item_type.search then if #edit_buf<127 then edit_buf=edit_buf..ch end
            else
                local ok=(b>=48 and b<=57) or (b==45 and #edit_buf==0)
                    or (b==46 and (edit_type==item_type.input_float or edit_type==item_type.slider or edit_type==item_type.float_toggle) and not edit_buf:find("%."))
                if ok then edit_buf=edit_buf..ch end
            end
        end
    end
    if input.key_just_pressed(VK.BACK) and #edit_buf>0 then edit_buf=edit_buf:sub(1,-2) end
    if input.key_just_pressed(VK.RETURN) then apply_edit() end
    if input.key_just_pressed(VK.ESCAPE) then edit_on=false end
end

-- ── Header with category icon tabs ──
local function draw_header(x, y, w)
    draw.rect_gradient(x, y, x+w, y+HDR_H, C.hdr[1],C.hdr[2],C.hdr[3],255, C.hdr[1],C.hdr[2],C.hdr[3],255, C.hdr2[1],C.hdr2[2],C.hdr2[3],255, C.hdr2[1],C.hdr2[2],C.hdr2[3],255)
    -- brand
    text.draw(font.title, x+18, y+(HDR_H-text.height(font.title))*0.5, 255,255,255,255, string.upper(str.brand or "NORTH"))

    -- category icon tabs (right-aligned)
    local n = #cats
    local total = n * TABICON
    local tx0 = x + w - total - 12
    for i=1,n do
        local ci = i-1
        local tx = tx0 + (i-1)*TABICON
        local sel = ci == active_cat
        local hov = hit(tx, y+5, tx+TABICON-4, y+HDR_H-5)
        local cy = y + HDR_H*0.5
        if sel then
            draw.rect(tx+2, y+6, tx+TABICON-4, y+HDR_H-6, C.acc[1],C.acc[2],C.acc[3],40, 6)
            draw.rect(tx+2, y+HDR_H-5, tx+TABICON-4, y+HDR_H-2, C.acc[1],C.acc[2],C.acc[3],255, 1)
        elseif hov then
            draw.rect(tx+2, y+6, tx+TABICON-4, y+HDR_H-6, C.hov[1],C.hov[2],C.hov[3],C.hov[4], 6)
        end
        local col = sel and C.acc or (hov and C.txt or C.txt2)
        if have_icons then
            local gl = fa_pool[((i-1) % #fa_pool)+1]
            local iw, ih = text.width(font.label, gl), text.height(font.label)
            text.draw(font.label, tx+(TABICON-iw)*0.5, cy-ih*0.5, col[1],col[2],col[3],col[4], gl)
        else
            local lab = (cats[i].label or "?"):sub(1,1)
            local iw = text.width(font.item, lab)
            text.draw(font.item, tx+(TABICON-iw)*0.5, cy-text.height(font.item)*0.5, col[1],col[2],col[3],col[4], lab)
        end
        if clk(tx, y+5, tx+TABICON-4, y+HDR_H-5) then go_cat(ci); click_consumed=true end
    end

    -- Header drag is now handled by menu.drag_header() (see draw_menu)
end

-- ── Left sub-page sidebar ──
local function draw_sidebar(x, y, w, h)
    draw.rect(x, y, x+w, y+h, C.side[1],C.side[2],C.side[3],255)
    draw.line(x+w, y, x+w, y+h, C.div[1],C.div[2],C.div[3],C.div[4])
    local iy = y + 8
    local cell = 27
    local entries = {}
    if has_gen then table.insert(entries, {name=(str.general or "General"), sel=-1}) end
    for i,tab in ipairs(sub_tabs) do table.insert(entries, {name=tab.name, sel=i}) end
    for _,e in ipairs(entries) do
        local sel = sub_sel == e.sel
        local hov = hit(x, iy, x+w, iy+cell)
        if sel then
            draw.rect(x, iy, x+3, iy+cell, C.acc[1],C.acc[2],C.acc[3],255)
            draw.rect(x+3, iy, x+w, iy+cell, C.acc[1],C.acc[2],C.acc[3],26)
        elseif hov then
            draw.rect(x, iy, x+w, iy+cell, C.hov[1],C.hov[2],C.hov[3],C.hov[4])
        end
        local col = sel and C.txt or (hov and C.txt or C.txt2)
        text.draw(font.item, x+14, iy+(cell-text.height(font.item))*0.5, col[1],col[2],col[3],255, e.name)
        if clk(x, iy, x+w, iy+cell) and not sel then go_sub(e.sel); click_consumed=true end
        iy = iy + cell
    end
end

-- ── Breadcrumb (deep nav) ──
local function draw_bc(x, y, w)
    local h = 24
    local s = "< " .. menu.page_name()
    text.draw(font.breadcrumb, x+PAD, y+(h-text.height(font.breadcrumb))*0.5, C.txt[1],C.txt[2],C.txt[3],220, s)
    if clk(x, y, x+text.width(font.breadcrumb,s)+PAD+10, y+h) then menu.go_back(); reset_scroll() end
    draw.line(x, y+h-1, x+w, y+h-1, C.div[1],C.div[2],C.div[3],80)
    return h
end

-- ── Widgets ──
local function draw_chk(x, y, on)
    if on then
        draw.rect(x, y, x+CHK, y+CHK, C.acc[1],C.acc[2],C.acc[3],255, 3)
        draw.line(x+3, y+CHK*0.52, x+CHK*0.42, y+CHK-3, 255,255,255,255, 2)
        draw.line(x+CHK*0.42, y+CHK-3, x+CHK-3, y+3, 255,255,255,255, 2)
    else
        draw.rect(x, y, x+CHK, y+CHK, C.chk[1],C.chk[2],C.chk[3],255, 3)
        draw.rect_outline(x, y, x+CHK, y+CHK, 70,86,120,200, 3)
    end
end

local function draw_sli_track(idx, x, y, w, val, mn, mx, is_int, is_handle)
    local t = (mx~=mn) and clamp((val-mn)/(mx-mn),0,1) or 0
    draw.rect(x, y, x+w, y+SLI_H, C.sli[1],C.sli[2],C.sli[3],255, 2)
    local fw = t*w
    if fw > 0 then
        draw.rect_gradient(x, y, x+fw, y+SLI_H, C.acc2[1],C.acc2[2],C.acc2[3],255, C.acc[1],C.acc[2],C.acc[3],255, C.acc[1],C.acc[2],C.acc[3],255, C.acc2[1],C.acc2[2],C.acc2[3],255)
        draw.circle(x+fw, y+SLI_H*0.5, 5, 255,255,255,255)
    end
    if input.mouse_clicked(0) and hit(x-4,y-7,x+w+4,y+SLI_H+7) and not click_consumed then
        drag_sl=idx; drag_sl_x=x; drag_sl_w=w; drag_sl_mn=mn; drag_sl_mx=mx; drag_sl_int=is_int; drag_sl_handle=is_handle or false
    end
end

-- ── Single item ──
local function draw_single(idx, x, y, w, ih, ct, cb, uh)
    local item = uh and items.at(idx) or menu.get_item(idx)
    if not item then return 0 end
    local mx,my = input.mouse_x(), input.mouse_y()
    local hov = mx>=x and mx<x+w and my>=y and my<y+ih and my>=ct and my<cb
    local th = text.height(font.item)
    local ty = y+(ih-th)*0.5
    local tp = item.type
    local extra = 0
    if hov then draw.rect(x,y,x+w,y+ih, C.hov[1],C.hov[2],C.hov[3],C.hov[4]); hover_idx=idx end

    if tp==item_type.toggle or tp==item_type.float_toggle or tp==item_type.int_toggle or tp==item_type.array_toggle or tp==item_type.loop_toggle then
        draw_chk(x+PAD, y+(ih-CHK)*0.5, item.on)
        text.draw(font.item, x+PAD+CHK+7, ty, C.txt[1],C.txt[2],C.txt[3], hov and 255 or 210, item.name)
        if item.on then
            if tp==item_type.float_toggle then
                local vs=string.format("%.2f",item.f_val)
                text.draw(font.value, x+w-PAD-text.width(font.value,vs), ty, C.txt2[1],C.txt2[2],C.txt2[3],255, vs); extra=11
                draw_sli_track(idx, x+PAD, y+ih+2, w-PAD*2, item.f_val, item.f_min, item.f_max, false, uh)
            elseif tp==item_type.int_toggle then
                local vs=tostring(item.i_val)
                text.draw(font.value, x+w-PAD-text.width(font.value,vs), ty, C.txt2[1],C.txt2[2],C.txt2[3],255, vs); extra=11
                draw_sli_track(idx, x+PAD, y+ih+2, w-PAD*2, item.i_val, item.i_min, item.i_max, true, uh)
            elseif tp==item_type.array_toggle or tp==item_type.loop_toggle then
                local cv=item.current_value or ""; local aw=text.width(font.value,"v"); local cvw=text.width(font.value,cv)
                text.draw(font.value, x+w-PAD-cvw-aw-4, ty, C.acc[1],C.acc[2],C.acc[3],255, cv)
                text.draw(font.value, x+w-PAD-aw, ty, C.txt2[1],C.txt2[2],C.txt2[3],180, "v")
            end
        end
        if hov and not click_consumed and input.mouse_clicked(0) then
            if item.on and (tp==item_type.array_toggle or tp==item_type.loop_toggle) and mx>x+w*0.6 then
                dd_open=true; dd_idx=idx; dd_handle=uh or false; dd_frame=ctx.frame(); dd_x=x; dd_y=y+ih; dd_w=w
                dd_values=(uh and items.values(idx)) or menu.get_item_values(idx) or {}; dd_scroll=0; cpick=false; edit_on=false
            else
                if uh then items.toggle(idx) else menu.toggle_item(idx) end
            end
        end

    elseif tp==item_type.slider then
        text.draw(font.item, x+PAD, ty, C.txt[1],C.txt[2],C.txt[3], hov and 255 or 210, item.name)
        local vs=string.format("%.2f",item.f_val)
        text.draw(font.value, x+w-PAD-text.width(font.value,vs), ty, C.txt2[1],C.txt2[2],C.txt2[3],255, vs); extra=9
        draw_sli_track(idx, x+PAD, y+ih, w-PAD*2, item.f_val, item.f_min, item.f_max, false, uh)

    elseif tp==item_type.int_option then
        text.draw(font.item, x+PAD, ty, C.txt[1],C.txt[2],C.txt[3], hov and 255 or 210, item.name)
        local vs=tostring(item.i_val)
        text.draw(font.value, x+w-PAD-text.width(font.value,vs), ty, C.txt2[1],C.txt2[2],C.txt2[3],255, vs); extra=9
        draw_sli_track(idx, x+PAD, y+ih, w-PAD*2, item.i_val, item.i_min, item.i_max, true, uh)

    elseif tp==item_type.sub_menu then
        text.draw(font.item, x+PAD, ty, C.txt[1],C.txt[2],C.txt[3], hov and 255 or 210, item.name)
        text.draw(font.value, x+w-PAD-text.width(font.value,">"), ty, C.txt2[1],C.txt2[2],C.txt2[3],200, ">")
        if hov and not click_consumed and input.mouse_clicked(0) then
            if uh then items.activate(idx) else menu.set_selected(idx); menu.activate() end
            reset_scroll()
        end

    elseif tp==item_type.array_option or tp==item_type.loop_option then
        -- North-style full-width dropdown box
        local bx, bw2 = x+PAD, w-PAD*2
        local by, bh = y+2, ih-4
        draw.rect(bx, by, bx+bw2, by+bh, C.inp[1],C.inp[2],C.inp[3],255, 3)
        draw.rect_outline(bx, by, bx+bw2, by+bh, C.bdr[1],C.bdr[2],C.bdr[3],hov and 220 or 120, 3)
        text.draw(font.item, bx+8, by+(bh-th)*0.5, C.txt[1],C.txt[2],C.txt[3],230, item.current_value or item.name)
        text.draw(font.value, bx+bw2-16, by+(bh-text.height(font.value))*0.5, C.txt2[1],C.txt2[2],C.txt2[3],200, "v")
        if hov and not click_consumed and input.mouse_clicked(0) then
            if dd_open and dd_idx==idx then dd_open=false
            else
                dd_open=true; dd_idx=idx; dd_handle=uh or false; dd_frame=ctx.frame(); dd_x=bx; dd_y=by+bh; dd_w=bw2
                dd_values=(uh and items.values(idx)) or menu.get_item_values(idx) or {}; dd_scroll=0; cpick=false; edit_on=false
            end
        end

    elseif tp==item_type.color then
        text.draw(font.item, x+PAD, ty, C.txt[1],C.txt[2],C.txt[3], hov and 255 or 210, item.name)
        local sw=20; local shh=ih-8; local sx=x+w-PAD-sw; local sy=y+4
        draw.rect(sx,sy,sx+sw,sy+shh, item.r,item.g,item.b,item.a, 3)
        draw.rect_outline(sx,sy,sx+sw,sy+shh, 60,76,108,200, 3)
        if hov and not click_consumed and input.mouse_clicked(0) then
            if cpick and cpick_idx==idx then cpick=false
            else
                cpick=true; cpick_idx=idx; cpick_handle=uh or false; cpick_v={item.r,item.g,item.b,item.a}; edit_on=false
                cpick_frame=ctx.frame(); cpick_x=x; cpick_y=y
                cpick_h,cpick_s,cpick_val = util.rgb_to_hsv(item.r,item.g,item.b); cpick_sv_drag=false; cpick_hue_drag=false
            end
        end

    elseif tp==item_type.input_text or tp==item_type.input_int or tp==item_type.input_float then
        local ed = edit_on and edit_idx==idx
        text.draw(font.item, x+PAD, ty, C.txt[1],C.txt[2],C.txt[3], hov and 255 or 210, item.name)
        local bx=x+w*0.46; local bw2=w*0.54-PAD; local by=y+3; local bh=ih-6
        draw.rect(bx,by,bx+bw2,by+bh, C.inp[1],C.inp[2],C.inp[3],255, 3)
        draw.rect_outline(bx,by,bx+bw2,by+bh, (ed and C.acc or C.bdr)[1],(ed and C.acc or C.bdr)[2],(ed and C.acc or C.bdr)[3],ed and 255 or 130, 3)
        local disp
        if ed then disp=edit_buf..(math.floor(ctx.time()*2)%2==0 and "|" or "")
        elseif tp==item_type.input_float then disp=string.format("%.2f",item.f_val)
        elseif tp==item_type.input_int then disp=tostring(item.i_val) else disp="" end
        draw.push_clip(bx+2,by,bx+bw2-2,by+bh)
        local dw=text.width(font.value,disp); local dx=bx+bw2-PAD-dw; if dx<bx+4 then dx=bx+4 end
        text.draw(font.value, dx, by+(bh-text.height(font.value))*0.5, C.txt[1],C.txt[2],C.txt[3],255, disp)
        draw.pop_clip()
        if hov and not click_consumed and input.mouse_clicked(0) then
            if ed then apply_edit()
            else edit_on=true; edit_idx=idx; edit_type=tp; edit_handle=uh or false; cpick=false
                if tp==item_type.input_float then edit_buf=string.format("%.2f",item.f_val)
                elseif tp==item_type.input_int then edit_buf=tostring(item.i_val) else edit_buf="" end
            end
        end

    elseif tp==item_type.search then
        -- search item: label on left, input box on right with search.png icon at far right
        local ed = edit_on and edit_idx==idx
        text.draw(font.item, x+PAD, ty, C.txt[1],C.txt[2],C.txt[3], hov and 255 or 210, item.name)
        -- reserve space for icon on the right (14px + padding)
        local icon_sz = 14
        local icon_pad = PAD + icon_sz + 3
        local bx=x+w*0.46; local bw2=w*0.54-PAD-icon_sz-4; local by=y+3; local bh=ih-6
        draw.rect(bx,by,bx+bw2,by+bh, C.inp[1],C.inp[2],C.inp[3],255, 3)
        draw.rect_outline(bx,by,bx+bw2,by+bh, (ed and C.acc or C.bdr)[1],(ed and C.acc or C.bdr)[2],(ed and C.acc or C.bdr)[3],ed and 255 or 130, 3)
        local q
        if ed then q=edit_buf..(math.floor(ctx.time()*2)%2==0 and "|" or "")
        elseif item.text and item.text~="" then q=item.text
        else q="Search\xe2\x80\xa6" end  -- "Search…" via UTF-8
        local dim_txt = (not ed) and (not (item.text and item.text~=""))
        draw.push_clip(bx+2,by,bx+bw2-2,by+bh)
        local dw=text.width(font.value,q); local dx=bx+bw2-PAD-dw; if dx<bx+4 then dx=bx+4 end
        text.draw(font.value, dx, by+(bh-text.height(font.value))*0.5,
            C.txt[1],C.txt[2],C.txt[3], dim_txt and 110 or 255, q)
        draw.pop_clip()
        -- search icon on the right
        local cy2 = y + ih*0.5
        local idrawn = icon_h("search", x+w-PAD-icon_sz, cy2, icon_sz, C.txt2[1],C.txt2[2],C.txt2[3],220)
        if idrawn==0 then
            -- fallback glyph if texture unavailable
            text.draw(font.value, x+w-PAD-text.width(font.value,"[S]"), ty, C.txt2[1],C.txt2[2],C.txt2[3],160, "[S]")
        end
        if hov and not click_consumed and input.mouse_clicked(0) then
            if ed then apply_edit()
            else edit_on=true; edit_idx=idx; edit_type=tp; edit_handle=uh or false; cpick=false
                edit_buf = item.text or ""
            end
        end
    end
    return ih + extra
end

local function draw_btn(idx, x, y, w, h, ct, cb, uh)
    local item = uh and items.at(idx) or menu.get_item(idx)
    if not item then return end
    local hov = hit(x,y,x+w,y+h) and input.mouse_y()>=ct and input.mouse_y()<cb
    local bg = hov and C.btn_h or C.btn
    draw.rect(x,y,x+w,y+h, bg[1],bg[2],bg[3],255, 4)
    ctxt(font.item, x,x+w, y+(h-text.height(font.item))*0.5, item.name, 255,255,255,255)
    if hov then hover_idx=idx end
    if hov and not click_consumed and input.mouse_clicked(0) then
        if uh then items.activate(idx) else menu.set_selected(idx); menu.activate() end
    end
end

local function draw_selected_tick_btn(idx, x, y, w, h, ct, cb, uh)
    local item = uh and items.at(idx) or menu.get_item(idx)
    if not item then return end
    local hov = hit(x,y,x+w,y+h) and input.mouse_y()>=ct and input.mouse_y()<cb
    local bg = hov and C.btn_h or C.btn
    draw.rect(x,y,x+w,y+h, bg[1],bg[2],bg[3],255, 4)
    -- label left-aligned with padding (leaves room for tick on right)
    local th = text.height(font.item)
    text.draw(font.item, x+PAD, y+(h-th)*0.5, 255,255,255,255, item.name)
    -- tick checkmark on right edge
    local tk = "\xE2\x9C\x93"
    local tkw = text.width(font.item, tk)
    text.draw(font.item, x+w-PAD-tkw, y+(h-th)*0.5, 255,255,255,200, tk)
    if hov then hover_idx=idx end
    if hov and not click_consumed and input.mouse_clicked(0) then
        if uh then items.activate(idx) else menu.set_selected(idx); menu.activate() end
    end
end

-- ── Plain toggle cell (for 2-up grid) ──
local function draw_toggle_cell(idx, x, y, w, ih, ct, cb, uh)
    local item = uh and items.at(idx) or menu.get_item(idx)
    if not item then return end
    local mx,my = input.mouse_x(), input.mouse_y()
    local hov = mx>=x and mx<x+w and my>=y and my<y+ih and my>=ct and my<cb
    if hov then draw.rect(x,y,x+w,y+ih, C.hov[1],C.hov[2],C.hov[3],C.hov[4]); hover_idx=idx end
    draw_chk(x+PAD, y+(ih-CHK)*0.5, item.on)
    local tx = x+PAD+CHK+7
    draw.push_clip(tx, y, x+w-2, y+ih)
    text.draw(font.item, tx, y+(ih-text.height(font.item))*0.5, C.txt[1],C.txt[2],C.txt[3], hov and 255 or 210, item.name)
    draw.pop_clip()
    if hov and not click_consumed and input.mouse_clicked(0) then
        if uh then items.toggle(idx) else menu.toggle_item(idx) end
    end
end

-- ── Section of items ──
local function draw_section_items(item_list, uh, x, y, w, clip_y, clip_h)
    local iy, total, i = y, 0, 1
    while i <= #item_list do
        local idx = item_list[i]
        local it = uh and items.at(idx) or menu.get_item(idx)
        if not it then i=i+1; goto cont end
        -- pure toggles render as a 2-up grid (North "Mods" style)
        if it.type == item_type.toggle then
            local ni = i < #item_list and (uh and items.at(item_list[i+1]) or menu.get_item(item_list[i+1])) or nil
            if ni and ni.type == item_type.toggle then
                local cwd = w*0.5
                draw_toggle_cell(idx, x, iy, cwd, ITEM_H, clip_y, clip_y+clip_h, uh)
                draw_toggle_cell(item_list[i+1], x+cwd, iy, w-cwd, ITEM_H, clip_y, clip_y+clip_h, uh)
                iy=iy+ITEM_H; total=total+ITEM_H; i=i+2; goto cont
            else
                draw_toggle_cell(idx, x, iy, w, ITEM_H, clip_y, clip_y+clip_h, uh)
                iy=iy+ITEM_H; total=total+ITEM_H; i=i+1; goto cont
            end
        end
        if it.type == item_type.selected_tick then
            draw_selected_tick_btn(idx, x+PAD, iy+2, w-PAD*2, BTN_H, clip_y, clip_y+clip_h, uh)
            iy=iy+BTN_H+BTN_PAD; total=total+BTN_H+BTN_PAD; i=i+1; goto cont
        end
        if it.type == item_type.action then
            local ni = i < #item_list and (uh and items.at(item_list[i+1]) or menu.get_item(item_list[i+1])) or nil
            if ni and ni.type == item_type.action then
                local bw=(w-PAD*2-BTN_PAD)*0.5
                draw_btn(idx, x+PAD, iy+2, bw, BTN_H, clip_y, clip_y+clip_h, uh)
                draw_btn(item_list[i+1], x+PAD+bw+BTN_PAD, iy+2, bw, BTN_H, clip_y, clip_y+clip_h, uh)
                iy=iy+BTN_H+BTN_PAD; total=total+BTN_H+BTN_PAD; i=i+2; goto cont
            else
                draw_btn(idx, x+PAD, iy+2, w-PAD*2, BTN_H, clip_y, clip_y+clip_h, uh)
                iy=iy+BTN_H+BTN_PAD; total=total+BTN_H+BTN_PAD; i=i+1; goto cont
            end
        end
        local h2 = draw_single(idx, x, iy, w, ITEM_H, clip_y, clip_y+clip_h, uh)
        iy=iy+h2; total=total+h2; i=i+1
        ::cont::
    end
    return total
end

-- ── Column with section panels ──
local function section_header(x, iy, w, title)
    -- raised blue gradient bar (North style)
    local ht = {math.min(math.floor(C.acc[1]*0.5+18),255), math.min(math.floor(C.acc[2]*0.5+24),255), math.min(math.floor(C.acc[3]*0.5+34),255)}
    local hb = {math.floor(C.acc[1]*0.26+14), math.floor(C.acc[2]*0.26+18), math.floor(C.acc[3]*0.26+26)}
    draw.rect_gradient(x, iy, x+w, iy+SEC_H,
        ht[1],ht[2],ht[3],255, ht[1],ht[2],ht[3],255,
        hb[1],hb[2],hb[3],255, hb[1],hb[2],hb[3],255)
    draw.line(x, iy, x+w, iy, math.min(ht[1]+34,255),math.min(ht[2]+34,255),math.min(ht[3]+34,255),220)
    draw.line(x, iy+SEC_H-1, x+w, iy+SEC_H-1, C.acc[1],C.acc[2],C.acc[3],160)
    text.draw(font.small, x+10, iy+(SEC_H-text.height(font.small))*0.5, 255,255,255,255, title)
    return SEC_H
end

local function draw_panel(x, iy, w, clip_y, clip_h, title, list, uh)
    local start = iy
    if title and title ~= "" then iy = iy + section_header(x, iy, w, title) end
    iy = iy + draw_section_items(list, uh, x, iy, w, clip_y, clip_h)
    local hgt = iy - start
    if hgt > SEC_H*0.5 then
        draw.rect_outline(x, start, x+w, start+hgt, C.bdr[1],C.bdr[2],C.bdr[3],70, 4)
    end
    return hgt
end

local function draw_col(col_items, x, y, w, h, scr, header, extra_sections)
    draw.push_clip(x, y, x+w, y+h)
    local iy = y - scr
    local total = 0
    if (header and header ~= "") or #col_items > 0 then
        local hgt = draw_panel(x, iy, w, y, h, header, col_items, false)
        iy=iy+hgt; total=total+hgt
    end
    if extra_sections then
        for _,sec in ipairs(extra_sections) do
            iy=iy+8; total=total+8
            local hgt = draw_panel(x, iy, w, y, h, sec.header, sec.handles, true)
            iy=iy+hgt; total=total+hgt
        end
    end
    draw.pop_clip()
    return total
end

-- ── Dropdown popup ──
local function draw_dropdown(wx, wy, wh)
    if not dd_open then return end
    local item = dd_handle and items.at(dd_idx) or menu.get_item(dd_idx)
    if not item or #dd_values==0 then dd_open=false; return end
    local DDH, MAX_VIS = 22, 8
    local vis = math.min(#dd_values, MAX_VIS)
    local pw, ph = dd_w, vis*DDH+4
    local px, py = dd_x, dd_y
    if py+ph > wy+wh then py = dd_y - ph - ITEM_H end
    draw.rect(px, py, px+pw, py+ph, C.panel[1],C.panel[2],C.panel[3],252, 4)
    draw.rect_outline(px, py, px+pw, py+ph, C.acc[1],C.acc[2],C.acc[3],140, 4)
    local whl = input.mouse_wheel()
    if whl~=0 and hit(px,py,px+pw,py+ph) then dd_scroll = clamp(dd_scroll-whl, 0, math.max(#dd_values-MAX_VIS,0)) end
    draw.push_clip(px, py+2, px+pw, py+ph-2)
    local iy = py+2
    for i=1+dd_scroll, math.min(#dd_values, dd_scroll+MAX_VIS) do
        local val = dd_values[i]
        local sel = (i-1)==item.value_index
        local hov2 = hit(px, iy, px+pw, iy+DDH)
        if sel then draw.rect(px+2,iy,px+pw-2,iy+DDH, C.acc[1],C.acc[2],C.acc[3],44, 2)
        elseif hov2 then draw.rect(px+2,iy,px+pw-2,iy+DDH, C.hov[1],C.hov[2],C.hov[3],20, 2) end
        local tc = sel and C.acc or C.txt
        text.draw(font.item, px+PAD, iy+(DDH-text.height(font.item))*0.5, tc[1],tc[2],tc[3], hov2 and 255 or 210, val)
        if hov2 and input.mouse_clicked(0) then
            if dd_handle then items.set_value_index(dd_idx, i-1) else menu.set_value_index(dd_idx, i-1) end
            dd_open=false
        end
        iy=iy+DDH
    end
    draw.pop_clip()
    if #dd_values>MAX_VIS then
        local ratio=MAX_VIS/#dd_values; local bh=math.max(ratio*(ph-4),12)
        local ms=#dd_values-MAX_VIS; local t=ms>0 and dd_scroll/ms or 0
        draw.rect(px+pw-4, py+2+t*((ph-4)-bh), px+pw-1, py+2+t*((ph-4)-bh)+bh, C.acc[1],C.acc[2],C.acc[3],90, 1)
    end
    if ctx.frame()>dd_frame and input.mouse_clicked(0) and not hit(px,py,px+pw,py+ph) then dd_open=false end
end

-- ── Color popup ──
local function draw_cpick(wx, wy, ww, wh)
    if not cpick then return end
    local item = cpick_handle and items.at(cpick_idx) or menu.get_item(cpick_idx)
    if not item then cpick=false; return end
    local SV_W,SV_H,HUE_W,ALPHA_H,TAB_ROW,SPAD = 140,120,16,12,18,6
    local PW = cpick_mode==0 and 200 or (SV_W+HUE_W+SPAD*4)
    local PH = cpick_mode==0 and 110 or (TAB_ROW+SV_H+ALPHA_H+SPAD*4+20)
    local px,py = cpick_x+30, cpick_y
    if px+PW>wx+ww then px=wx+ww-PW-4 end
    if py+PH>wy+wh then py=wy+wh-PH-4 end
    if px<wx then px=wx+4 end
    if py<wy then py=wy+4 end
    draw.rect(px,py,px+PW,py+PH, C.panel[1],C.panel[2],C.panel[3],252, 4)
    draw.rect_outline(px,py,px+PW,py+PH, C.acc[1],C.acc[2],C.acc[3],160, 4)
    local tab_w = PW/2
    for ti=0,1 do
        local tx=px+ti*tab_w; local sel=cpick_mode==ti; local hov2=hit(tx,py,tx+tab_w,py+TAB_ROW)
        if sel then draw.rect(tx,py+TAB_ROW-2,tx+tab_w,py+TAB_ROW, C.acc[1],C.acc[2],C.acc[3],255) end
        local tc=sel and C.acc or (hov2 and C.txt or C.txt2)
        ctxt(font.tiny, tx,tx+tab_w, py+(TAB_ROW-text.height(font.tiny))*0.5, ti==0 and "Sliders" or "Picker", tc[1],tc[2],tc[3],tc[4])
        if clk(tx,py,tx+tab_w,py+TAB_ROW) then cpick_mode=ti; if ti==1 then cpick_h,cpick_s,cpick_val=util.rgb_to_hsv(cpick_v[1],cpick_v[2],cpick_v[3]) end end
    end
    local cy = py+TAB_ROW+SPAD
    if cpick_mode==0 then
        local labs={"R","G","B","A"}; local ry=cy
        for ci=1,4 do
            text.draw(font.tiny, px+6, ry+4, C.txt2[1],C.txt2[2],C.txt2[3],255, labs[ci])
            local bx=px+18; local bw=PW-18-36; local by=ry+(20-SLI_H)*0.5+1
            draw.rect(bx,by,bx+bw,by+SLI_H, C.sli[1],C.sli[2],C.sli[3],255, 2)
            local tv=cpick_v[ci]/255
            if tv>0 then draw.rect_gradient(bx,by,bx+tv*bw,by+SLI_H, C.acc2[1],C.acc2[2],C.acc2[3],255, C.acc[1],C.acc[2],C.acc[3],255, C.acc[1],C.acc[2],C.acc[3],255, C.acc2[1],C.acc2[2],C.acc2[3],255) end
            local vs=tostring(math.floor(cpick_v[ci]))
            text.draw(font.tiny, px+PW-text.width(font.tiny,vs)-6, ry+4, C.acc[1],C.acc[2],C.acc[3],255, vs)
            if input.mouse_clicked(0) and hit(bx,by-4,bx+bw,by+SLI_H+4) then cpick_drag=ci end
            if cpick_drag==ci and input.mouse_down(0) then cpick_v[ci]=math.floor(clamp((input.mouse_x()-bx)/bw,0,1)*255+0.5) end
            ry=ry+20
        end
        if input.mouse_released(0) then cpick_drag=0 end
    else
        local svx,svy = px+SPAD, cy
        local hx,hy = svx+SV_W+SPAD, svy
        local hr,hg,hb = util.hsv_to_rgb(cpick_h,1,1)
        draw.rect_gradient(svx,svy,svx+SV_W,svy+SV_H, 255,255,255,255, hr,hg,hb,255, hr,hg,hb,255, 255,255,255,255)
        draw.rect_gradient(svx,svy,svx+SV_W,svy+SV_H, 0,0,0,0, 0,0,0,0, 0,0,0,255, 0,0,0,255)
        local ccx=svx+cpick_s*SV_W; local ccy=svy+(1-cpick_val)*SV_H
        draw.circle_outline(ccx,ccy,5,255,255,255,255,1.5); draw.circle_outline(ccx,ccy,4,0,0,0,200,1)
        if input.mouse_clicked(0) and hit(svx,svy,svx+SV_W,svy+SV_H) then cpick_sv_drag=true end
        if cpick_sv_drag and input.mouse_down(0) then
            cpick_s=clamp((input.mouse_x()-svx)/SV_W,0,1); cpick_val=clamp(1-(input.mouse_y()-svy)/SV_H,0,1)
            local nr,ng,nb=util.hsv_to_rgb(cpick_h,cpick_s,cpick_val); cpick_v[1]=math.floor(nr);cpick_v[2]=math.floor(ng);cpick_v[3]=math.floor(nb)
        end
        local steps=12; local hstep=SV_H/steps
        for hi=0,steps-1 do
            local r1,g1,b1=util.hsv_to_rgb(hi/steps*360,1,1); local r2,g2,b2=util.hsv_to_rgb((hi+1)/steps*360,1,1)
            draw.rect_gradient(hx, hy+hi*hstep, hx+HUE_W, hy+(hi+1)*hstep, r1,g1,b1,255, r1,g1,b1,255, r2,g2,b2,255, r2,g2,b2,255)
        end
        local hcy=hy+(cpick_h/360)*SV_H
        draw.rect(hx-2,hcy-2,hx+HUE_W+2,hcy+2,255,255,255,255,1); draw.rect_outline(hx-2,hcy-2,hx+HUE_W+2,hcy+2,0,0,0,200,1)
        if input.mouse_clicked(0) and hit(hx-2,hy,hx+HUE_W+2,hy+SV_H) then cpick_hue_drag=true end
        if cpick_hue_drag and input.mouse_down(0) then
            cpick_h=clamp((input.mouse_y()-hy)/SV_H,0,0.999)*360
            local nr,ng,nb=util.hsv_to_rgb(cpick_h,cpick_s,cpick_val); cpick_v[1]=math.floor(nr);cpick_v[2]=math.floor(ng);cpick_v[3]=math.floor(nb)
        end
        local ay=svy+SV_H+SPAD; local aw=SV_W+SPAD+HUE_W
        draw.rect(svx,ay,svx+aw,ay+ALPHA_H, C.sli[1],C.sli[2],C.sli[3],255, 1)
        local at=cpick_v[4]/255
        draw.rect_gradient(svx,ay,svx+at*aw,ay+ALPHA_H, cpick_v[1],cpick_v[2],cpick_v[3],80, cpick_v[1],cpick_v[2],cpick_v[3],255, cpick_v[1],cpick_v[2],cpick_v[3],255, cpick_v[1],cpick_v[2],cpick_v[3],80)
        text.draw(font.tiny, svx+2, ay+(ALPHA_H-text.height(font.tiny))*0.5, 255,255,255,200, "A")
        local avs=tostring(cpick_v[4]); text.draw(font.tiny, svx+aw-text.width(font.tiny,avs)-2, ay+(ALPHA_H-text.height(font.tiny))*0.5, 255,255,255,200, avs)
        if input.mouse_clicked(0) and hit(svx,ay-2,svx+aw,ay+ALPHA_H+2) then cpick_drag=5 end
        if cpick_drag==5 and input.mouse_down(0) then cpick_v[4]=math.floor(clamp((input.mouse_x()-svx)/aw,0,1)*255+0.5) end
        if input.mouse_released(0) then cpick_sv_drag=false; cpick_hue_drag=false; cpick_drag=0 end
    end
    if cpick_mode==0 and input.mouse_released(0) then cpick_drag=0 end
    if cpick_v[1]~=item.r or cpick_v[2]~=item.g or cpick_v[3]~=item.b or cpick_v[4]~=item.a then
        if cpick_handle then items.set_color(cpick_idx, cpick_v[1],cpick_v[2],cpick_v[3],cpick_v[4]) else menu.set_item_color(cpick_idx, cpick_v[1],cpick_v[2],cpick_v[3],cpick_v[4]) end
    end
    local fy=py+PH-20
    draw.rect(px+SPAD,fy,px+SPAD+20,fy+14, cpick_v[1],cpick_v[2],cpick_v[3],cpick_v[4], 2)
    draw.rect_outline(px+SPAD,fy,px+SPAD+20,fy+14, 60,76,108,180, 2)
    text.draw(font.tiny, px+SPAD+24, fy+2, C.txt2[1],C.txt2[2],C.txt2[3],200, string.format("#%02X%02X%02X", cpick_v[1],cpick_v[2],cpick_v[3]))
    local dbx=px+PW-40; local dbh2=hit(dbx,fy,dbx+34,fy+14); local dbc=dbh2 and C.btn_h or C.acc2
    draw.rect(dbx,fy,dbx+34,fy+14, dbc[1],dbc[2],dbc[3],255, 2)
    ctxt(font.tiny, dbx,dbx+34, fy+2, "Done", 255,255,255,255)
    if clk(dbx,fy,dbx+34,fy+14) then cpick=false end
    if ctx.frame()>cpick_frame and input.mouse_clicked(0) and not hit(px,py,px+PW,py+PH) then cpick=false end
end

local function draw_sb(x,y,h,content_h,scr)
    if content_h<=h then return end
    local r=h/content_h; local bh=math.max(r*h,18); local ms=content_h-h; local t=ms>0 and scr/ms or 0
    draw.rect(x, y+t*(h-bh), x+SCROLL_W, y+t*(h-bh)+bh, C.acc[1],C.acc[2],C.acc[3],90, 1)
end

-- ══════════════════════════ MAIN ══════════════════════════
function draw_menu()
    C = make_colors()
    WIN_W = math.floor(sf("Window Width", 700))
    WIN_H = math.floor(sf("Window Height", 520))
    theme.set_body_bg(C.bg[1]-6, C.bg[2]-6, C.bg[3]-6, 255)
    if not menu.is_visible() then return end
    init_pos()
    click_consumed = cpick or dd_open

    if not cats_built then build_cats(); if #cats>0 then go_cat(0) end end
    if sub_parent=="" then rebuild_subs() end

    -- Drag is now handled by menu.drag_header() called below
    if drag_sl>=0 then
        if input.mouse_down(0) then
            local t=clamp((input.mouse_x()-drag_sl_x)/drag_sl_w,0,1)
            local nv=drag_sl_mn+t*(drag_sl_mx-drag_sl_mn)
            if drag_sl_handle then
                if drag_sl_int then items.set_i_val(drag_sl,math.floor(nv+0.5)) else items.set_f_val(drag_sl,nv) end
            else
                if drag_sl_int then menu.set_i_val(drag_sl,math.floor(nv+0.5)) else menu.set_f_val(drag_sl,nv) end
            end
        else drag_sl=-1 end
    end

    -- Compute fresh natural position each frame (centered)
    local x = (ctx.screen_w() - WIN_W) / 2
    local y = (ctx.screen_h() - WIN_H) / 2

    -- Header drag-to-move: pass natural origin, add returned offset
    local _dox, _doy = menu.drag_header(x, y, WIN_W, HDR_H)
    x = x + _dox
    y = y + _doy

    -- Store for any code that needs to reference the position
    win_x, win_y = x, y

    -- soft drop shadow
    draw.rect(x-8, y-6, x+WIN_W+8, y+WIN_H+12, 0,0,0,90, 10)
    -- blue outer glow (North signature)
    for i=1,5 do
        draw.rect_outline(x-i, y-i, x+WIN_W+i, y+WIN_H+i, C.acc[1],C.acc[2],C.acc[3], math.floor(46/(i+0.5)), 6+i, 1)
    end
    -- window body
    draw.rect(x, y, x+WIN_W, y+WIN_H, C.bg[1],C.bg[2],C.bg[3],C.bg[4], 6)

    draw_header(x, y, WIN_W)
    draw_sidebar(x, y+HDR_H, SIDE_W, WIN_H-HDR_H)
    -- bright blue frame + brighter top edge
    draw.rect_outline(x, y, x+WIN_W, y+WIN_H, C.acc[1],C.acc[2],C.acc[3], 220, 6, 2)
    draw.line(x+8, y+1, x+WIN_W-8, y+1, math.min(C.acc[1]+60,255),math.min(C.acc[2]+60,255),255, 200)
    -- divider under header
    draw.line(x, y+HDR_H, x+WIN_W, y+HDR_H, C.acc[1],C.acc[2],C.acc[3],80)

    local d = depth()
    if d==0 and sub_sel~=-1 then sub_sel=-1 end

    local cx = x + SIDE_W + 1
    local cw = WIN_W - SIDE_W - 1
    local bar_y = y + HDR_H
    local extra = 0
    if d >= 2 then extra = draw_bc(cx, bar_y, cw) end

    local cyt = bar_y + extra + 6
    local ch = WIN_H - HDR_H - extra - 8

    d = depth()
    local page = menu.page_name()
    local count = menu.item_count()
    hover_idx = -1
    local skip_subs = (d==0 and #sub_tabs>0)

    local col_w = math.floor((cw - 16) / 2)
    local lx = cx + 8
    local rx = cx + 8 + col_w + 8

    -- flatten child submenus into section panels when inside a sub-page
    local flat_list = nil
    if d >= 1 then
        flat_list = {}
        for i=0,count-1 do local it=menu.get_item(i); if it and it.type==item_type.sub_menu then table.insert(flat_list, it.name) end end
        if #flat_list==0 then flat_list=nil end
    end

    local lt, rt
    if flat_list then
        local all_sections = {}
        local parent_items = {}
        for i=0,count-1 do local it=menu.get_item(i); if it and it.type~=item_type.sub_menu then table.insert(parent_items, i) end end
        if #parent_items>0 then table.insert(all_sections, {header=page, items=parent_items, use_handle=false}) end
        for _,child in ipairs(flat_list) do
            local handles = items.page_items(child)
            if handles and #handles>0 then table.insert(all_sections, {header=child, items=handles, use_handle=true}) end
        end
        -- balance sections across two columns
        local left_sec,right_sec,lc,rc = {},{},0,0
        for _,sec in ipairs(all_sections) do
            if lc<=rc then table.insert(left_sec,sec); lc=lc+#sec.items+2 else table.insert(right_sec,sec); rc=rc+#sec.items+2 end
        end
        local function page_items(list) local p={}; for _,s in ipairs(list) do if not s.use_handle then for _,idx in ipairs(s.items) do table.insert(p,idx) end end end; return p end
        local function extras(list) local e={}; for _,s in ipairs(list) do if s.use_handle then table.insert(e,{header=s.header, handles=s.items}) end end; return #e>0 and e or nil end
        -- header for the page-relative section in each column (if present)
        local function first_hdr(list) for _,s in ipairs(list) do if not s.use_handle then return s.header end end; return nil end
        lt = draw_col(page_items(left_sec), lx, cyt, col_w, ch, scroll_l, first_hdr(left_sec), extras(left_sec))
        rt = draw_col(page_items(right_sec), rx, cyt, col_w, ch, scroll_r, first_hdr(right_sec), extras(right_sec))
    else
        local visible = {}
        for i=0,count-1 do
            local it = menu.get_item(i)
            if it and not (skip_subs and it.type==item_type.sub_menu) then table.insert(visible, i) end
        end
        local mid = math.ceil(#visible/2)
        local li,ri = {},{}
        for i=1,#visible do if i<=mid then table.insert(li, visible[i]) else table.insert(ri, visible[i]) end end
        lt = draw_col(li, lx, cyt, col_w, ch, scroll_l, page)
        rt = draw_col(ri, rx, cyt, col_w, ch, scroll_r, nil)
    end

    draw.line(cx+8+col_w+4, cyt, cx+8+col_w+4, cyt+ch, C.div[1],C.div[2],C.div[3],100)
    draw_sb(lx+col_w-SCROLL_W, cyt, ch, lt, scroll_l)
    draw_sb(rx+col_w-SCROLL_W, cyt, ch, rt, scroll_r)

    local mxp = input.mouse_x()
    local wh = input.mouse_wheel()
    if wh~=0 and hit(cx,cyt,cx+cw,cyt+ch) and drag_sl<0 then
        if mxp < cx+8+col_w+4 then scroll_tl = clamp(scroll_tl-wh*ITEM_H*2, 0, math.max(lt-ch,0))
        else scroll_tr = clamp(scroll_tr-wh*ITEM_H*2, 0, math.max(rt-ch,0)) end
    end
    scroll_l = lerp(scroll_l, scroll_tl, clamp(ctx.delta()*14,0,1))
    scroll_r = lerp(scroll_r, scroll_tr, clamp(ctx.delta()*14,0,1))

    draw_dropdown(x, y, WIN_H)
    draw_cpick(x, y, WIN_W, WIN_H)
    proc_edit()
end

function handle_input()
    if edit_on then return end
    if input.key_just_pressed(VK.ESCAPE) then
        if cpick then cpick=false
        elseif dd_open then dd_open=false
        elseif menu.page_parent()~="" and depth()>=2 then menu.go_back(); reset_scroll() end
    end
end
