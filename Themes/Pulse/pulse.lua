-- "Pulse" — ultra-animated violet list UI
-- Aurora + particle background, gliding glowing selection with shimmer,
-- staggered entrance, spring toggles, animated sliders, sparkle bursts.
-- Standard menu API.

text.set_size(font.title, 30);  text.set_weight(font.title, 800)
text.set_size(font.item, 15);   text.set_weight(font.item, 500)
text.set_size(font.value, 13);  text.set_weight(font.value, 600)
text.set_size(font.breadcrumb, 11); text.set_weight(font.breadcrumb, 600)
text.set_size(font.desc, 11);   text.set_weight(font.desc, 400)
text.set_size(font.small, 10);  text.set_weight(font.small, 600)
text.set_size(font.tiny, 9);    text.set_weight(font.tiny, 600)

-- ── Settings ──
local function sc(n) local s=menu.get_setting(n); if s then return {s.r,s.g,s.b,s.a} end end
local function sf(n,d) local s=menu.get_setting(n); if s then return s.f_val end; return d end
local function sb(n,d) local s=menu.get_setting(n); if s then return s.on end; return d end
local function reload_colors()
    local a = sc("Accent") or {139, 92, 246, 255}
    return {
        accent  = a,
        accentL = sc("Accent Light") or {math.min(a[1]+40,255),math.min(a[2]+50,255),math.min(a[3]+12,255),255},
        accentD = {math.max(a[1]-40,0),math.max(a[2]-55,0),math.max(a[3]-25,0),255},
        bg      = sc("Background") or {12, 10, 20, 255},
        panel   = sc("Panel") or {21, 17, 33, 245},
    }
end
local function reload_layout()
    return {
        w  = sf("Menu Width", 430),
        ih = sf("Row Height", 46),
        aurora = sb("Aurora", true),
        parts  = sb("Particles", true),
        glow   = sb("Glow", true),
    }
end
menu.clear_settings()
menu.add_setting_submenu("Colors", "Violet palette")
menu.add_sub_color("Accent", 139, 92, 246, 255, "Primary violet")
menu.add_sub_color("Accent Light", 179, 142, 255, 255, "Highlight tint")
menu.add_sub_color("Background", 12, 10, 20, 255, "Base background")
menu.add_sub_color("Panel", 21, 17, 33, 245, "Card background")
menu.add_setting_submenu("Effects", "Animation toggles")
menu.add_sub_toggle("Aurora", true, "Animated aurora background")
menu.add_sub_toggle("Particles", true, "Floating particles")
menu.add_sub_toggle("Glow", true, "Breathing glow")
menu.add_setting_submenu("Layout", "Sizes")
menu.add_sub_slider("Menu Width", 430, 320, 640, 10, "Width (px)")
menu.add_sub_slider("Row Height", 46, 34, 70, 1, "Row height (px)")

local c = reload_colors()
local l = reload_layout()

-- ── Helpers ──
local function lerp(a,b,t) return a+(b-a)*t end
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
local function ease_out(t) t=clamp(t,0,1); return 1-(1-t)^3 end
local function asnap(cur, tgt, dt, sp) return lerp(cur, tgt, clamp(dt*sp,0,1)) end

-- deterministic pseudo-random (avoids math.random dependency)
local _seed = 987654321
local function rnd() _seed = (_seed*1103515245 + 12345) % 2147483648; return _seed/2147483648 end

-- ── State ──
local scroll, scroll_t = 0, 0
local nav_time, last_page, last_sel = 0, "", -1
local desc_anim = 0
local sel_y, sel_h, sel_on = 0, 0, 0      -- animated selection box
local toggle_anim = {}
local tween_f = {}
local dragging_slider, drag_x, drag_w = -1, 0, 0
local frame = { x=0, list_y=0, popup_item_y=0 }
local sb_last = 0

local particles = {}
local sparks = {}

local function init_particles(sw,sh)
    particles = {}
    for i=1,42 do particles[i]={x=rnd()*sw, y=rnd()*sh, s=rnd()*1.6+0.5, sp=rnd()*22+8, ph=rnd()*6.28} end
end
local function draw_particles(sw,sh,dt,time)
    if not l.parts then return end
    if #particles==0 then init_particles(sw,sh) end
    for _,p in ipairs(particles) do
        p.y = p.y - p.sp*dt
        if p.y < -4 then p.y = sh+4; p.x = rnd()*sw end
        local tw = 0.35 + 0.65*(0.5+0.5*math.sin(time*2+p.ph))
        draw.circle(p.x, p.y, p.s, c.accentL[1],c.accentL[2],c.accentL[3], math.floor(46*tw))
    end
end
local function draw_aurora(sw,sh,time)
    if not l.aurora then return end
    local blobs = {
        {col=c.accent,  r=380, sx=0.20, sy=0.28, px=0.16, py=0.12, a=42},
        {col=c.accentL, r=320, sx=0.16, sy=0.22, px=0.18, py=0.10, a=34},
        {col=c.accentD, r=300, sx=0.13, sy=0.18, px=0.12, py=0.14, a=40},
        {col={236,72,153}, r=260, sx=0.18, sy=0.15, px=0.10, py=0.13, a=22},
    }
    for i,b in ipairs(blobs) do
        local t = time*0.16 + i
        local cx = sw*(0.5 + math.sin(t*b.sx)*b.px)
        local cy = sh*(0.5 + math.cos(t*b.sy+i)*b.py)
        for k=3,1,-1 do draw.circle(cx, cy, b.r*(k/3), b.col[1],b.col[2],b.col[3], math.floor(b.a/k)) end
    end
end

local function spawn_sparks(x,y)
    for i=1,12 do
        local a = rnd()*6.2832
        local sp = 50 + rnd()*120
        sparks[#sparks+1] = {x=x, y=y, vx=math.cos(a)*sp, vy=math.sin(a)*sp-30, life=0, max=0.45+rnd()*0.45}
    end
end
local function update_draw_sparks(dt)
    for i=#sparks,1,-1 do
        local s=sparks[i]; s.life=s.life+dt
        if s.life>=s.max then table.remove(sparks,i)
        else
            s.x=s.x+s.vx*dt; s.y=s.y+s.vy*dt; s.vy=s.vy+260*dt
            local t=1-s.life/s.max
            draw.circle(s.x, s.y, 2.2*t+0.4, c.accentL[1],c.accentL[2],c.accentL[3], math.floor(220*t))
        end
    end
end

-- ── Widgets ──
local function draw_toggle(rx, yc, item, idx, time)
    local tw, th = 40, 22
    local an = toggle_anim[idx] or (item.on and 1 or 0)
    an = asnap(an, item.on and 1 or 0, ctx.delta(), 13)
    toggle_anim[idx] = an
    local tx, ty = rx - tw, yc - th/2
    -- track
    local r = math.floor(lerp(38, c.accent[1], an))
    local g = math.floor(lerp(34, c.accent[2], an))
    local b = math.floor(lerp(54, c.accent[3], an))
    draw.rect(tx, ty, tx+tw, ty+th, r, g, b, 255, 11)
    if an > 0.02 then
        local pulse = 0.6 + 0.4*math.sin(time*4)
        draw.rect_outline(tx-1, ty-1, tx+tw+1, ty+th+1, c.accentL[1],c.accentL[2],c.accentL[3], math.floor(120*an*pulse), 12)
    end
    local kr = th/2 - 3
    local kcx = tx + th/2 + (tw-th)*an
    draw.circle(kcx, yc, kr+1, 0,0,0,80)
    draw.circle(kcx, yc, kr, 255,255,255,255)
end

local function draw_slider(rx, yc, item, idx, is_sel, time)
    local tw = 150
    local sx, sy = rx - tw, yc - 2
    tween_f[idx] = asnap(tween_f[idx] or item.f_val, item.f_val, ctx.delta(), 12)
    local dv = tween_f[idx]
    local frac = 0
    if item.f_max>item.f_min then frac = clamp((dv-item.f_min)/(item.f_max-item.f_min),0,1) end
    draw.rect(sx, sy, sx+tw, sy+4, 255,255,255, is_sel and 30 or 16, 2)
    local fw = tw*frac
    if fw>0 then
        draw.rect_gradient(sx, sy, sx+fw, sy+4, c.accentD[1],c.accentD[2],c.accentD[3],255, c.accent[1],c.accent[2],c.accent[3],255, c.accent[1],c.accent[2],c.accent[3],255, c.accentD[1],c.accentD[2],c.accentD[3],255)
        local kr = is_sel and (5 + 0.8*math.sin(time*5)) or 4
        draw.circle(sx+fw, yc, kr+3, c.accentL[1],c.accentL[2],c.accentL[3], is_sel and 80 or 0)
        draw.circle(sx+fw, yc, kr, 255,255,255,255)
    end
    local vs = string.format("%.1f", dv)
    text.draw(font.value, sx-12-text.width(font.value,vs), yc-text.height(font.value)/2, 255,255,255, is_sel and 255 or 170, vs)
    return sx, tw
end

local function draw_stepper(rx, yc, val, is_sel)
    local af, lh = font.value, text.height(font.value)
    local ry = yc-lh/2
    local aa, va = is_sel and 220 or 110, is_sel and 255 or 190
    local rgt, lft = text.width(af,">"), text.width(af,"<")
    local vw = text.width(af, val)
    text.draw(af, rx-rgt, ry, c.accentL[1],c.accentL[2],c.accentL[3], aa, ">")
    local vx = rx-rgt-10-vw
    text.draw(af, vx, ry, 255,255,255, va, val)
    text.draw(af, vx-10-lft, ry, c.accentL[1],c.accentL[2],c.accentL[3], aa, "<")
end

local function draw_widget(rx, yc, item, idx, is_sel, time)
    local t = item.type
    if t==item_type.sub_menu then
        local off = is_sel and (3*math.sin(time*4)) or 0
        text.draw(font.item, rx-text.width(font.item,">")+off, yc-text.height(font.item)/2, c.accentL[1],c.accentL[2],c.accentL[3], is_sel and 230 or 120, ">")
    elseif t==item_type.selected_tick then
        -- selected button: tick on the right, accent-light normally, brighter on selected row
        local a = is_sel and 255 or 160
        text.draw(font.item, rx-text.width(font.item,"✓"), yc-text.height(font.item)/2, c.accentL[1],c.accentL[2],c.accentL[3], a, "✓")
    elseif t==item_type.toggle then draw_toggle(rx,yc,item,idx,time)
    elseif t==item_type.float_toggle then draw_toggle(rx,yc,item,idx,time); draw_slider(rx-40-12,yc,item,idx,is_sel,time)
    elseif t==item_type.int_toggle then draw_toggle(rx,yc,item,idx,time); draw_stepper(rx-40-12,yc,tostring(item.i_val),is_sel)
    elseif t==item_type.array_toggle or t==item_type.loop_toggle then draw_toggle(rx,yc,item,idx,time); draw_stepper(rx-40-12,yc,item.current_value or "?",is_sel)
    elseif t==item_type.slider then draw_slider(rx,yc,item,idx,is_sel,time)
    elseif t==item_type.int_option then draw_stepper(rx,yc,tostring(item.i_val),is_sel)
    elseif t==item_type.array_option or t==item_type.loop_option then draw_stepper(rx,yc,item.current_value or "?",is_sel)
    elseif t==item_type.color then
        local s=24
        draw.rect(rx-s,yc-s/2,rx,yc+s/2, item.r,item.g,item.b,item.a or 255, 5)
        if is_sel then draw.rect_outline(rx-s-1,yc-s/2-1,rx+1,yc+s/2+1, c.accentL[1],c.accentL[2],c.accentL[3], math.floor(120+80*math.sin(time*4)), 6) end
    elseif t==item_type.input_text then local vw=text.width(font.value,item.name); text.draw(font.value, rx-vw, yc-text.height(font.value)/2, 255,255,255, is_sel and 200 or 120, item.name)
    elseif t==item_type.input_int then local vs=tostring(item.i_val); text.draw(font.value, rx-text.width(font.value,vs), yc-text.height(font.value)/2, 255,255,255, is_sel and 200 or 120, vs)
    elseif t==item_type.input_float then local vs=string.format("%.2f",item.f_val); text.draw(font.value, rx-text.width(font.value,vs), yc-text.height(font.value)/2, 255,255,255, is_sel and 200 or 120, vs)
    elseif t==item_type.search then
        -- right glyph
        local gs = "[S]"
        local gw = text.width(font.value, gs)
        text.draw(font.value, rx-gw, yc-text.height(font.value)/2, c.accentL[1],c.accentL[2],c.accentL[3], is_sel and 255 or 160, gs)
        -- query text or placeholder to the left of the glyph
        local q = (item.text and item.text~="") and item.text or "Search..."
        local qa = (item.text and item.text~="") and (is_sel and 200 or 120) or (is_sel and 100 or 60)
        local qw = text.width(font.value, q)
        text.draw(font.value, rx-gw-8-qw, yc-text.height(font.value)/2, 255,255,255, qa, q)
    end
end

local function draw_hotkey_badge(x,y,vk,is_sel,lh)
    if vk==0 then return end
    local kn=menu.vk_name(vk); local bw,bh=text.width(font.tiny,kn),text.height(font.tiny)
    local by=y+(lh-bh)/2-1
    draw.rect(x-4,by-1,x+bw+4,by+bh+2, c.accent[1],c.accent[2],c.accent[3], is_sel and 60 or 30, 4)
    text.draw(font.tiny, x, by, c.accentL[1],c.accentL[2],c.accentL[3], is_sel and 230 or 140, kn)
end

-- ══════════════════ MAIN ══════════════════
function draw_menu()
    c = reload_colors(); l = reload_layout()
    theme.set_body_bg(c.bg[1], c.bg[2], c.bg[3], 255)
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local time, dt = ctx.time(), ctx.delta()

    draw_aurora(sw, sh, time)
    draw_particles(sw, sh, dt, time)
    if not menu.is_visible() then return end

    local page = menu.page_name()
    if page~=last_page then last_page=page; nav_time=time; scroll=0; scroll_t=0; tween_f={} end
    local sel = menu.selected_index()
    local sel_changed = (sel~=last_sel)
    if sel_changed then desc_anim=time end
    local count = menu.item_count()

    local content_h = count*l.ih
    local list_max = math.min(sh-220, 520)
    local list_h = math.min(list_max, content_h)
    local header_h, sub_h, desc_h, foot_h = 72, 28, 56, 30
    local total_h = header_h+sub_h+list_h+desc_h+foot_h
    local mx = (sw-l.w)/2
    local my = math.max(24, (sh-(header_h+sub_h+list_max+desc_h+foot_h))/2)

    -- Header drag-to-move: pass natural origin, add returned offset
    local _dox, _doy = menu.drag_header(mx, my, l.w, header_h)
    mx = mx + _dox
    my = my + _doy

    frame.x = mx

    -- breathing glow + panel
    if l.glow then
        local pulse = 0.5+0.5*math.sin(time*1.6)
        for k=1,5 do
            draw.rect_outline(mx-k*2, my-k*2, mx+l.w+k*2, my+total_h+k*2, c.accent[1],c.accent[2],c.accent[3], math.floor((30+20*pulse)/k), 14+k*2, 1)
        end
    end
    draw.rect(mx-6, my-4, mx+l.w+6, my+total_h+10, 0,0,0,70, 16)
    draw.rect(mx, my, mx+l.w, my+total_h, c.panel[1],c.panel[2],c.panel[3],c.panel[4], 14)
    -- glassy top highlight
    draw.rect(mx+14, my+1, mx+l.w-14, my+2, 255,255,255,30)
    draw.rect_outline(mx, my, mx+l.w, my+total_h, c.accentL[1],c.accentL[2],c.accentL[3], 40, 14)

    -- ── Header (animated glowing title) ──
    local cyc = my + header_h/2
    local title = str.brand or "Nenyoo"
    local gp = math.floor(70+60*math.sin(time*2))
    text.draw_outlined(font.title, mx+22, cyc-text.height(font.title)/2, 255,255,255,255, c.accent[1],c.accent[2],c.accent[3], gp, 3, title)
    -- animated underline sweep
    local bw = text.width(font.title, title)
    local sweep = (math.sin(time*1.5)*0.5+0.5)
    draw.rect(mx+22, cyc+text.height(font.title)/2-2, mx+22+bw, cyc+text.height(font.title)/2, c.accentD[1],c.accentD[2],c.accentD[3], 120)
    draw.rect(mx+22+ (bw-40)*sweep, cyc+text.height(font.title)/2-2, mx+22+(bw-40)*sweep+40, cyc+text.height(font.title)/2, c.accentL[1],c.accentL[2],c.accentL[3], 220)

    -- ── Breadcrumb / counter ──
    local by = my+header_h
    local crumb = menu.page_name()
    local par = menu.page_parent()
    if par and #par>0 and par~=crumb then crumb = par.."  /  "..crumb end
    text.draw(font.breadcrumb, mx+22, by+(sub_h-text.height(font.breadcrumb))/2, c.accentL[1],c.accentL[2],c.accentL[3], 220, crumb)
    local cnt = string.format("%d / %d", sel+1, count)
    text.draw(font.breadcrumb, mx+l.w-22-text.width(font.breadcrumb,cnt), by+(sub_h-text.height(font.breadcrumb))/2, 255,255,255, 110, cnt)
    draw.rect(mx+18, by+sub_h-1, mx+l.w-18, by+sub_h, 255,255,255, 14)

    -- ── List ──
    local list_y = by + sub_h
    frame.list_y = list_y
    local scroll_max = math.max(0, content_h-list_h)
    if sel_changed then
        local st=sel*l.ih; local sb2=st+l.ih
        if sb2>scroll_t+list_h then scroll_t=sb2-list_h end
        if st<scroll_t then scroll_t=st end
        last_sel=sel
    end
    scroll_t = clamp(scroll_t,0,scroll_max)
    scroll = asnap(scroll, scroll_t, dt, 14)

    local imx,imy = input.mouse_x(), input.mouse_y()
    local in_list = imx>=mx and imx<=mx+l.w and imy>=list_y and imy<=list_y+list_h
    if in_list and menu.popup_mode()==0 then local wh=input.mouse_wheel(); if wh~=0 then scroll_t=clamp(scroll_t-wh*l.ih*3,0,scroll_max) end end

    if dragging_slider>=0 then
        local di=menu.get_item(dragging_slider)
        if di and input.mouse_down(0) then
            local pct=clamp((imx-drag_x)/drag_w,0,1); local raw=di.f_min+pct*(di.f_max-di.f_min)
            if di.f_step>0 then raw=di.f_min+math.floor((raw-di.f_min)/di.f_step+0.5)*di.f_step end
            menu.set_f_val(dragging_slider, clamp(raw,di.f_min,di.f_max))
        else dragging_slider=-1 end
    end

    -- animated selection box (glides between rows)
    local target_y = list_y+2 + sel*l.ih - scroll
    if sel_y==0 then sel_y=target_y; sel_h=l.ih-4 end
    sel_y = asnap(sel_y, target_y, dt, 17)
    sel_h = asnap(sel_h, l.ih-4, dt, 17)
    sel_on = asnap(sel_on, 1, dt, 10)

    draw.push_clip(mx, list_y, mx+l.w, list_y+list_h)

    -- selection glow + gradient + shimmer (behind text)
    if count>0 and sel_y+sel_h>list_y and sel_y<list_y+list_h then
        local hx1, hx2 = mx+6, mx+l.w-6
        local hy1, hy2 = sel_y, sel_y+sel_h
        if l.glow then
            for k=1,3 do draw.rect_outline(hx1-k, hy1-k, hx2+k, hy2+k, c.accent[1],c.accent[2],c.accent[3], math.floor(40/k), 9, 1) end
        end
        draw.rect_gradient(hx1, hy1, hx2, hy2,
            c.accent[1],c.accent[2],c.accent[3], math.floor(60*sel_on),
            c.accentL[1],c.accentL[2],c.accentL[3], math.floor(26*sel_on),
            c.accentL[1],c.accentL[2],c.accentL[3], math.floor(26*sel_on),
            c.accent[1],c.accent[2],c.accent[3], math.floor(60*sel_on))
        draw.rect_outline(hx1, hy1, hx2, hy2, c.accentL[1],c.accentL[2],c.accentL[3], math.floor(110*sel_on), 9)
        -- moving shimmer band
        local band_w = 70
        local pos = ((time*180) % (l.w+band_w)) - band_w
        local bx = hx1+pos
        draw.rect_gradient(bx, hy1, bx+band_w, hy2, 255,255,255,0, 255,255,255,40, 255,255,255,40, 255,255,255,0)
        -- pulsing left accent bar
        local barw = 3 + 1.5*math.sin(time*5)
        draw.rect(hx1, hy1+6, hx1+barw, hy2-6, c.accentL[1],c.accentL[2],c.accentL[3], math.floor(255*sel_on), 2)
    end

    local ne = time - nav_time
    local lh = text.height(font.item)
    for i=0,count-1 do
        local item = menu.get_item(i); if not item then goto cont end
        local is_sel=(i==sel)
        local iy = list_y+2 + i*l.ih - scroll
        if iy+l.ih<list_y or iy>list_y+list_h then goto cont end
        -- staggered entrance
        local delay = i*0.045
        local at = ne>=delay and ease_out(clamp((ne-delay)/0.4,0,1)) or 0
        local xo = (1-at)*-26
        local hovered = in_list and imy>=iy and imy<=iy+l.ih

        if is_sel then menu.set_popup_item_y(iy+l.ih); frame.popup_item_y=iy+l.ih end
        if hovered and not is_sel then draw.rect(mx+6, iy, mx+l.w-6, iy+l.ih, 255,255,255, math.floor(10*at), 9) end

        -- mouse click
        if hovered and input.mouse_clicked(0) and menu.popup_mode()==0 and dragging_slider<0 then
            local t=item.type; local handled=false
            local has_tog = t==item_type.toggle or t==item_type.float_toggle or t==item_type.int_toggle or t==item_type.array_toggle or t==item_type.loop_toggle
            if has_tog then
                if imx>=mx+l.w-22-40 and imx<=mx+l.w-22 and imy>=iy+l.ih/2-12 and imy<=iy+l.ih/2+12 then
                    menu.set_selected(i); menu.toggle_item(i); notify.push(item.name, item.on and "Disabled" or "Enabled", item.on and 2 or 1); handled=true
                end
            end
            local has_sl = t==item_type.slider or t==item_type.float_toggle
            if not handled and has_sl then
                local sr=mx+l.w-22; if t==item_type.float_toggle then sr=sr-40-12 end
                local slf=sr-150
                if imx>=slf and imx<=sr and imy>=iy+l.ih/2-12 and imy<=iy+l.ih/2+12 then menu.set_selected(i); dragging_slider=i; drag_x=slf; drag_w=150; handled=true end
            end
            if not handled then
                if is_sel then menu.activate()
                elseif item.type==item_type.action or item.type==item_type.sub_menu or item.type==item_type.selected_tick then menu.set_selected(i); menu.activate()
                else menu.set_selected(i) end
            end
        end

        local na = math.floor((is_sel and 255 or 175)*at)
        local has_desc = item.desc and #item.desc>0
        local tx = mx+22+xo
        local ty = iy + (has_desc and 9 or (l.ih-lh)/2)
        -- clip name/desc so they never run under the right widget or out of the panel
        local t2 = item.type
        local has_val = not (t2==item_type.toggle or t2==item_type.action or t2==item_type.sub_menu)
        local rb = has_val and (mx + l.w*0.56) or (mx + l.w - 46)
        draw.push_clip(tx-2, iy, rb, iy+l.ih)
        text.draw(font.item, tx, ty, 255,255,255, na, item.name)
        if item.hotkey and item.hotkey~=0 then draw_hotkey_badge(tx+text.width(font.item,item.name)+8, ty, item.hotkey, is_sel, lh) end
        if has_desc then text.draw(font.desc, tx, ty+lh+1, 255,255,255, math.floor((is_sel and 120 or 50)*at), item.desc) end
        draw.pop_clip()

        draw_widget(mx+l.w-22+xo, iy+l.ih/2, item, i, is_sel, time)
        ::cont::
    end
    draw.pop_clip()

    -- sparks on selection change (spawn after layout so position known)
    if sel_changed then spawn_sparks(mx+l.w-30, target_y+l.ih/2) end
    update_draw_sparks(dt)

    -- scrollbar
    if content_h>list_h then
        local th=math.max((list_h/content_h)*list_h,24); local fr=scroll_max>0 and scroll/scroll_max or 0
        local ty=list_y+fr*(list_h-th)
        draw.rect(mx+l.w-5, ty, mx+l.w-2, ty+th, c.accentL[1],c.accentL[2],c.accentL[3], 180, 2)
    end

    -- ── Desc box ──
    local dy = list_y+list_h
    draw.rect(mx+18, dy, mx+l.w-18, dy+1, 255,255,255, 14)
    local sit = menu.get_item(sel)
    if sit then
        local dt2 = ease_out(clamp((time-desc_anim)/0.25,0,1))
        local yo = (1-dt2)*5
        draw.push_clip(mx, dy+2, mx+l.w, dy+desc_h)
        draw.rect(mx+22, dy+14+yo, mx+25, dy+desc_h-12+yo, c.accent[1],c.accent[2],c.accent[3], math.floor(255*dt2), 2)
        text.draw(font.value, mx+34, dy+12+yo, 255,255,255, math.floor(220*dt2), sit.name)
        if sit.desc and #sit.desc>0 then
            text.draw(font.desc, mx+34, dy+12+yo+text.height(font.value)+3, 255,255,255, math.floor(120*dt2), sit.desc, l.w-52)
        end
        draw.pop_clip()
    end

    -- ── Footer ──
    local fy = dy+desc_h
    text.draw(font.tiny, mx+22, fy+(foot_h-text.height(font.tiny))/2, 255,255,255, 70, "UP/DN move   ENTER select   ESC back")
    local br = str.brand or "Nenyoo"
    text.draw(font.tiny, mx+l.w-22-text.width(font.tiny,br), fy+(foot_h-text.height(font.tiny))/2, c.accentL[1],c.accentL[2],c.accentL[3], 150, br)

    local pm=menu.popup_mode()
    if pm==1 then draw_input_popup() end
    if pm==2 then draw_color_picker() end
    if pm==3 then draw_array_dropdown_popup() end
    if pm==4 then draw_hotkey_popup() end
end

-- ══════════════════ INPUT ══════════════════
function handle_input()
    if not menu.is_visible() then return end
    local pm=menu.popup_mode()
    if pm==1 then handle_input_popup(); return end
    if pm==2 then handle_color_picker(); return end
    if pm==3 then handle_array_dropdown(); return end
    if pm==4 then handle_hotkey_bind(); return end
    if input.key_pressed(VK.UP) then menu.move_selection(-1) end
    if input.key_pressed(VK.DOWN) then menu.move_selection(1) end
    if input.key_just_pressed(VK.RETURN) then menu.activate() end
    if input.key_just_pressed(VK.BACK) or input.key_just_pressed(VK.ESCAPE) then menu.go_back() end
    local sel=menu.selected_index(); local item=menu.get_item(sel); if not item then return end
    local t=item.type
    if input.key_just_pressed(VK.SPACE) then
        if t==item_type.input_text or t==item_type.input_int or t==item_type.input_float or t==item_type.slider or t==item_type.int_option or t==item_type.float_toggle or t==item_type.int_toggle or t==item_type.search then menu.open_input_popup() end
    end
    if input.key_just_pressed(0x48) and t~=item_type.sub_menu then menu.set_popup_mode(4) end
    if input.key_just_pressed(VK.DELETE) and item.hotkey and item.hotkey~=0 then menu.set_hotkey(sel,0); notify.push(item.name, str.cleared or "Cleared", 0); menu.save_hotkeys(); menu.rebuild_features() end
    if input.key_pressed(VK.LEFT) or input.key_pressed(VK.RIGHT) then
        local dir=input.key_pressed(VK.RIGHT) and 1 or -1
        if t==item_type.slider or t==item_type.float_toggle then menu.set_f_val(sel, clamp(item.f_val+item.f_step*dir,item.f_min,item.f_max))
        elseif t==item_type.int_option or t==item_type.int_toggle then menu.set_i_val(sel, clamp(item.i_val+item.i_step*dir,item.i_min,item.i_max))
        elseif t==item_type.loop_option or t==item_type.loop_toggle then local idx=item.value_index+dir; if idx>=item.value_count then idx=0 end; if idx<0 then idx=item.value_count-1 end; menu.set_value_index(sel,idx)
        elseif t==item_type.array_option or t==item_type.array_toggle then menu.open_array_popup() end
    end
end

-- ══════════════════ POPUPS ══════════════════
local input_cursor, input_blink, input_open = 0,0,0
function draw_input_popup()
    local sw,sh=ctx.screen_w(),ctx.screen_h()
    draw.rect(0,0,sw,sh,0,0,0,150)
    local pw,ph=360,118; local px,py=(sw-pw)/2,(sh-ph)/2
    draw.rect(px,py,px+pw,py+ph, c.panel[1],c.panel[2],c.panel[3],255, 12)
    draw.rect_outline(px,py,px+pw,py+ph, c.accent[1],c.accent[2],c.accent[3],90, 12)
    local item=menu.get_item(menu.input_target_item())
    text.draw(font.small, px+20, py+16, c.accentL[1],c.accentL[2],c.accentL[3],220, string.upper(item and item.name or "Edit"))
    local buf=menu.get_input_buffer()
    local ix,iy,iw,ih=px+18,py+44,pw-36,34
    draw.rect(ix,iy,ix+iw,iy+ih, 0,0,0,80, 8)
    draw.rect_outline(ix,iy,ix+iw,iy+ih, c.accent[1],c.accent[2],c.accent[3],110, 8)
    local tx,ty=ix+12,iy+(ih-text.height(font.item))/2
    text.draw(font.item, tx,ty, 255,255,255,255, buf)
    if math.fmod(ctx.time()-input_blink,1.0)<0.55 then local cw=text.width(font.item,buf:sub(1,input_cursor)); draw.rect(tx+cw,iy+7,tx+cw+2,iy+ih-7, c.accentL[1],c.accentL[2],c.accentL[3],255) end
end
function handle_input_popup()
    local el=ctx.time()-input_open
    if input.key_just_pressed(VK.ESCAPE) then menu.set_popup_mode(0); return end
    if input.key_just_pressed(VK.RETURN) and el>0.15 then menu.confirm_input(); return end
    local buf=menu.get_input_buffer(); local chars=input.get_chars()
    if #chars>0 then buf=buf:sub(1,input_cursor)..chars..buf:sub(input_cursor+1); input_cursor=input_cursor+#chars; input_blink=ctx.time(); menu.set_input_buffer(buf) end
    if input.key_pressed(VK.BACK) and input_cursor>0 then buf=buf:sub(1,input_cursor-1)..buf:sub(input_cursor+1); input_cursor=input_cursor-1; input_blink=ctx.time(); menu.set_input_buffer(buf) end
    if input.key_pressed(VK.LEFT) and input_cursor>0 then input_cursor=input_cursor-1; input_blink=ctx.time() end
    if input.key_pressed(VK.RIGHT) and input_cursor<#buf then input_cursor=input_cursor+1; input_blink=ctx.time() end
end
local orig_open_input=menu.open_input_popup
menu.open_input_popup=function() orig_open_input(); input_cursor=#menu.get_input_buffer(); input_blink=ctx.time(); input_open=ctx.time() end

local apick,aopen=0,0
function draw_array_dropdown_popup()
    local sw,sh=ctx.screen_w(),ctx.screen_h()
    local sel=menu.selected_index(); local item=menu.get_item(sel)
    if not item or item.value_count<=0 then menu.set_popup_mode(0); return end
    local vals=menu.get_item_values(sel); if not vals then menu.set_popup_mode(0); return end
    local dw,dh=220,34; local cnt=item.value_count
    local h=math.min(cnt*dh,dh*7)+8
    local dx=frame.x+l.w-dw-22; local dy=frame.popup_item_y or 300
    if dy+h>sh-10 then dy=dy-h-l.ih end
    draw.rect(dx,dy,dx+dw,dy+h, c.panel[1],c.panel[2],c.panel[3],255, 10)
    draw.rect_outline(dx,dy,dx+dw,dy+h, c.accent[1],c.accent[2],c.accent[3],110, 10)
    local mx,my=input.mouse_x(),input.mouse_y(); local vfh=text.height(font.value)
    for i=1,cnt do
        local issel=((i-1)==apick); local iscur=((i-1)==item.value_index)
        local iy=dy+4+(i-1)*dh; local hov=mx>=dx and mx<=dx+dw and my>=iy and my<=iy+dh
        if hov then apick=i-1 end
        if issel or hov then draw.rect(dx+4,iy,dx+dw-4,iy+dh, c.accent[1],c.accent[2],c.accent[3],44, 6) end
        text.draw(font.value, dx+14, iy+(dh-vfh)/2, 255,255,255, (issel or hov) and 255 or 150, vals[i])
        if iscur then draw.circle(dx+dw-16, iy+dh/2, 3, c.accentL[1],c.accentL[2],c.accentL[3], 255) end
    end
end
function handle_array_dropdown()
    local el=ctx.time()-aopen; local sel=menu.selected_index(); local item=menu.get_item(sel); if not item then menu.set_popup_mode(0); return end
    if input.key_just_pressed(VK.ESCAPE) or input.key_just_pressed(VK.BACK) then menu.set_popup_mode(0); return end
    if el>0.1 then
        if input.key_pressed(VK.DOWN) and apick<item.value_count-1 then apick=apick+1 end
        if input.key_pressed(VK.UP) and apick>0 then apick=apick-1 end
        if input.key_just_pressed(VK.RETURN) then menu.set_value_index(sel,apick); menu.set_popup_mode(0); return end
        local mx,my=input.mouse_x(),input.mouse_y()
        if input.mouse_clicked(0) and el>0.15 then
            local dw,dh=220,34; local dx=frame.x+l.w-dw-22; local dy=(frame.popup_item_y or 300)+4
            if mx>=dx and mx<=dx+dw and my>=dy and my<=dy+item.value_count*dh then local idx=math.floor((my-dy)/dh); if idx>=0 and idx<item.value_count then menu.set_value_index(sel,idx); menu.set_popup_mode(0); return end
            else menu.set_popup_mode(0); return end
        end
    end
end
local orig_open_array=menu.open_array_popup
menu.open_array_popup=function() orig_open_array(); local it=menu.get_item(menu.selected_index()); apick=it and it.value_index or 0; aopen=ctx.time() end

function draw_hotkey_popup()
    local sw,sh=ctx.screen_w(),ctx.screen_h()
    draw.rect(0,0,sw,sh,0,0,0,150)
    local pw,ph=290,78; local px,py=(sw-pw)/2,(sh-ph)/2
    draw.rect(px,py,px+pw,py+ph, c.panel[1],c.panel[2],c.panel[3],255, 12)
    local pulse=math.floor(120+100*math.sin(ctx.time()*4))
    draw.rect_outline(px,py,px+pw,py+ph, c.accent[1],c.accent[2],c.accent[3],pulse, 12)
    local title=str.press_key or "Press any key..."
    text.draw(font.item, px+(pw-text.width(font.item,title))/2, py+18, 255,255,255,235, title)
    local hint=str.esc_cancel or "ESC to cancel"
    text.draw(font.desc, px+(pw-text.width(font.desc,hint))/2, py+18+text.height(font.item)+8, 255,255,255,100, hint)
end
function handle_hotkey_bind()
    if input.key_just_pressed(VK.ESCAPE) then menu.set_popup_mode(0); notify.push("Hotkey", str.cancelled or "Cancelled", 0); return end
    local skip={[27]=true,[1]=true,[2]=true,[4]=true,[16]=true,[17]=true,[18]=true,[160]=true,[161]=true,[162]=true,[163]=true,[164]=true,[165]=true}
    for vk=1,255 do if not skip[vk] and input.key_just_pressed(vk) then local sel=menu.selected_index(); menu.set_hotkey(sel,vk); notify.push(menu.get_item(sel).name,(str.bound_to or "Bound to").." "..menu.vk_name(vk),1); menu.save_hotkeys(); menu.rebuild_features(); menu.set_popup_mode(0); return end end
end

-- ── Color picker ──
local cp_tab,cp_pi,cp_h,cp_s,cp_v,cp_sv,cp_hd,cp_open=0,0,0,1,1,false,false,0
local palette={
    {239,68,68,255},{249,115,22,255},{234,179,8,255},{34,197,94,255},
    {59,130,246,255},{139,92,246,255},{236,72,153,255},{255,255,255,255},
    {220,38,38,255},{234,88,12,255},{202,138,4,255},{22,163,74,255},
    {37,99,235,255},{124,58,237,255},{190,24,93,255},{120,120,120,255},
}
function draw_color_picker()
    local sw,sh=ctx.screen_w(),ctx.screen_h()
    draw.rect(0,0,sw,sh,0,0,0,150)
    local pw,ph=360,300; local px,py=(sw-pw)/2,(sh-ph)/2
    draw.rect(px,py,px+pw,py+ph, c.panel[1],c.panel[2],c.panel[3],255, 12)
    draw.rect_outline(px,py,px+pw,py+ph, c.accent[1],c.accent[2],c.accent[3],110, 12)
    local mx,my=input.mouse_x(),input.mouse_y()
    -- swatches
    local cell,gap=36,6; local gx,gy=px+18,py+18
    for i=1,16 do
        local col,row=(i-1)%8, math.floor((i-1)/8)
        local cx,cy=gx+col*(cell+gap), gy+row*(cell+gap)
        local pc=palette[i]
        draw.rect(cx,cy,cx+cell,cy+cell, pc[1],pc[2],pc[3],pc[4], 6)
        if cp_pi==i-1 then draw.rect_outline(cx-2,cy-2,cx+cell+2,cy+cell+2,255,255,255,230,7) end
        if mx>=cx and mx<=cx+cell and my>=cy and my<=cy+cell and input.mouse_clicked(0) then
            cp_pi=i-1; cp_h,cp_s,cp_v = util.rgb_to_hsv(pc[1],pc[2],pc[3])
        end
    end
    -- SV + hue
    local svy=gy+2*(cell+gap)+10
    local svx,svw,svh=px+18,200,120
    local hx,hw=svx+svw+12,18
    local hr,hg,hb=util.hsv_to_rgb(cp_h,1,1)
    draw.rect(svx,svy,svx+svw,svy+svh, hr,hg,hb,255)
    draw.rect_gradient(svx,svy,svx+svw,svy+svh,255,255,255,255,255,255,255,0,255,255,255,0,255,255,255,255)
    draw.rect_gradient(svx,svy,svx+svw,svy+svh,0,0,0,0,0,0,0,0,0,0,0,255,0,0,0,255)
    draw.circle_outline(svx+cp_s*svw, svy+(1-cp_v)*svh, 5,255,255,255,255,2)
    for i=0,11 do local y1=svy+(i/12)*svh; local y2=svy+((i+1)/12)*svh; local r1,g1,b1=util.hsv_to_rgb(i/12*360,1,1); local r2,g2,b2=util.hsv_to_rgb((i+1)/12*360,1,1); draw.rect_gradient(hx,y1,hx+hw,y2,r1,g1,b1,255,r1,g1,b1,255,r2,g2,b2,255,r2,g2,b2,255) end
    draw.rect(hx-2,svy+(cp_h/360)*svh-2,hx+hw+2,svy+(cp_h/360)*svh+2,255,255,255,255)
    local pr,pg,pb=util.hsv_to_rgb(cp_h,cp_s,cp_v)
    draw.rect(svx,svy+svh+12,svx+40,svy+svh+44, pr,pg,pb,255, 5)
    text.draw(font.small, svx+48, svy+svh+16, 255,255,255,200, string.format("#%02X%02X%02X  (Enter apply)", pr,pg,pb))
    if input.mouse_down(0) then
        if cp_sv or (mx>=svx and mx<=svx+svw and my>=svy and my<=svy+svh) then cp_sv=true; cp_s=clamp((mx-svx)/svw,0,1); cp_v=clamp(1-(my-svy)/svh,0,1) end
        if cp_hd or (mx>=hx and mx<=hx+hw and my>=svy and my<=svy+svh) then cp_hd=true; cp_h=clamp((my-svy)/svh,0,0.999)*360 end
    else cp_sv=false; cp_hd=false end
end
function handle_color_picker()
    if input.key_just_pressed(VK.ESCAPE) or input.key_just_pressed(VK.BACK) then menu.set_popup_mode(0); return end
    if input.key_just_pressed(VK.TAB) then cp_tab=1-cp_tab end
    if input.key_just_pressed(VK.RETURN) and ctx.time()-cp_open>0.15 then
        local sel=menu.selected_index()
        local pc=palette[cp_pi+1]
        -- prefer custom SV if user dragged it; else palette
        local r,g,b=util.hsv_to_rgb(cp_h,cp_s,cp_v)
        menu.set_item_color(sel, r,g,b,255); menu.set_popup_mode(0); return
    end
end
local orig_activate=menu.activate
menu.activate=function()
    local sel=menu.selected_index(); local item=menu.get_item(sel)
    if item and item.type==item_type.color then menu.set_popup_mode(2); cp_open=ctx.time(); cp_pi=0; cp_h,cp_s,cp_v=util.rgb_to_hsv(item.r,item.g,item.b); return end
    if item and item.type==item_type.search then
        menu.set_input_buffer(item.text or "")
        menu.open_input_popup()
        return
    end
    orig_activate()
end
