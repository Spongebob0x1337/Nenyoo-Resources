-- Cherax
-- Neon-purple mouse-driven click GUI with sidebar navigation and card columns.

text.set_font_family("Trebuchet MS")

local TITLE_FONT_FILE="Themes\\Cherax\\fonts\\Orbitron-Bold.ttf"
local TITLE_FONT_REL="Themes/Cherax/fonts/Orbitron-Bold.ttf"
local title_font_downloaded=false

local function valid_font_data(data)
    if not data or #data<1024 then return false end
    local sig=data:sub(1,4)
    return sig=="OTTO" or (data:byte(1)==0 and data:byte(2)==1 and data:byte(3)==0 and data:byte(4)==0)
end

local function apply_title_font() text.set_font_for(font.title,TITLE_FONT_REL) end

do
    local data=file.read(TITLE_FONT_FILE)
    if valid_font_data(data) then
        apply_title_font()
    elseif net and net.get then
        net.get("raw.githubusercontent.com","/google/fonts/main/ofl/orbitron/static/Orbitron-Bold.ttf",function(body)
            if valid_font_data(body) then title_font_downloaded=file.write(TITLE_FONT_FILE,body) end
        end,function() end)
    end
end

-- ── Font Setup ──
text.set_size(font.title, 20)
text.set_size(font.item, 12)
text.set_size(font.breadcrumb, 11)
text.set_size(font.desc, 10)
text.set_size(font.label, 9)
text.set_size(font.value, 11)
text.set_size(font.small, 10)
text.set_size(font.tiny, 8)

text.set_weight(font.title, 700)
text.set_weight(font.item, 400)
text.set_weight(font.breadcrumb, 500)
text.set_weight(font.value, 500)
text.set_weight(font.desc, 400)

-- ── Settings ──
menu.clear_settings()
menu.add_setting_submenu("Colors", "Click GUI colors")
menu.add_sub_color("Accent", 190, 0, 255, 255, "Primary neon-purple accent")
menu.add_sub_color("Background", 7, 2, 14, 248, "Window background")

menu.add_setting_submenu("Layout", "Window dimensions")
menu.add_sub_slider("Width", 900, 650, 1200, 10, "Window width")
menu.add_sub_slider("Height", 620, 440, 850, 10, "Window height")
menu.add_sub_slider("Item Height", 30, 22, 44, 1, "Control row height")

-- ── Settings Readers ──
local function sc(name)
    local s = menu.get_setting(name)
    if s then return {s.r, s.g, s.b, s.a} end
    return nil
end
local function sf(name, def)
    local s = menu.get_setting(name)
    if s then return s.f_val end
    return def
end

-- ── Colors ──
local function make_colors()
    local acc = sc("Accent") or {190, 0, 255, 255}
    local bg  = sc("Background") or {7, 2, 14, 248}
    return {
        bg      = bg,
        header  = {math.max(bg[1]-6,0), math.max(bg[2]-6,0), math.max(bg[3]-6,0), 255},
        tab_bg  = {math.max(bg[1]-4,0), math.max(bg[2]-4,0), math.max(bg[3]-4,0), 255},
        stab_bg = {math.max(bg[1]-2,0), math.max(bg[2]-2,0), math.max(bg[3]-2,0), 255},
        accent  = acc,
        accent_d= {math.max(acc[1]-30,0), math.max(acc[2]-30,0), math.max(acc[3]-35,0), 255},
        txt     = {238, 230, 248, 255},
        txt_dim = {145, 126, 162, 255},
        hover   = {210, 45, 255, 18},
        div     = {79, 15, 104, 210},
        chk_bg  = {28, 7, 39, 255},
        sli_bg  = {39, 7, 54, 255},
        desc_bg = {math.max(bg[1]-8,0), math.max(bg[2]-8,0), math.max(bg[3]-8,0), 255},
        inp_bg  = {22, 22, 34, 255},
        btn_bg  = {26, 26, 38, 255},
        btn_hov = {36, 36, 52, 255},
    }
end
local CLR = make_colors()

-- ── Layout Constants ──
local HDR_H    = 46
local TAB_H    = 32
local STAB_H   = 30
local DESC_H   = 28
local SIDE_W   = 58
local CARD_GAP = 10
local PAD      = 10
local CHECK_SZ = 14
local SLIDER_H = 5
local SCROLL_W = 4

-- ── Categories ──
local cats = {
    {label="S", page="Self"}, {label="N", page="Network"},
    {label="V", page="Vehicle"}, {label="W", page="Weapon"},
    {label="X", page="VFX"}, {label="O", page="World"},
    {label="M", page="Misc"}, {label="T", page="Teleport"},
    {label="/", page="Scripts"}, {label="P", page="Spooner"},
    {label="!", page="Protections"}, {label="*", page="Settings"},
}

-- ── State ──
local win_x, win_y
local dragging_win = false
local drag_ox, drag_oy = 0, 0
local active_cat = 0
local scroll = 0
local scroll_tgt = 0
local last_page = ""
local hover_idx = -1

local drag_slider = -1
local drag_sl_x, drag_sl_w = 0, 0
local drag_sl_min, drag_sl_max = 0, 0
local drag_sl_int = false

local edit_active = false
local edit_idx = -1
local edit_buf = ""
local edit_type = 0

local cpick_open = false
local cpick_idx = -1
local cpick_vals = {0, 0, 0, 255}
local cpick_drag = 0

-- ── Sub-tab State ──
local sub_tabs = {}         -- {name, idx} from root page submenu items
local sub_tab_sel = -1      -- -1 = general tab, 1+ = sub-tab
local sub_tab_parent = ""   -- root page these tabs belong to
local has_general = false   -- root page has non-submenu items

-- ── Helpers ──
local function lerp(a, b, t) return a + (b - a) * t end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function in_rect(x1, y1, x2, y2)
    local mx, my = input.mouse_x(), input.mouse_y()
    return mx >= x1 and mx < x2 and my >= y1 and my < y2
end

local function click_in(x1, y1, x2, y2)
    return in_rect(x1, y1, x2, y2) and input.mouse_clicked(0)
end

local function center_text(fnt, x1, x2, y, s, r, g, b, a)
    local w = text.width(fnt, s)
    text.draw(fnt, x1 + (x2 - x1 - w) * 0.5, y, r, g, b, a, s)
end

local function init_pos()
    if not win_x then
        local W = sf("Width", 900)
        local H = sf("Height", 620)
        win_x = (ctx.screen_w() - W) / 2
        win_y = (ctx.screen_h() - H) / 2
    end
end

-- ── Sub-tab Building ──
local function rebuild_sub_tabs()
    sub_tabs = {}
    has_general = false
    local count = menu.item_count()
    for i = 0, count - 1 do
        local item = menu.get_item(i)
        if item then
            if item.type == item_type.sub_menu then
                table.insert(sub_tabs, {name = item.name, idx = i})
            else
                has_general = true
            end
        end
    end
    sub_tab_parent = menu.page_name()

    if not has_general and #sub_tabs > 0 then
        menu.set_selected(sub_tabs[1].idx)
        menu.activate()
        sub_tab_sel = 1
    else
        sub_tab_sel = -1
    end
end

-- depth: 0 = root page, 1 = sub-tab, 2+ = deeper
local function get_depth()
    if menu.page_name() == sub_tab_parent then return 0 end
    if menu.page_parent() == sub_tab_parent then return 1 end
    return 2
end

-- ── Navigate to Category ──
local function go_cat(idx)
    active_cat = idx
    last_page = cats[idx + 1].page
    while menu.page_parent() ~= "" do menu.go_back() end
    menu.navigate(cats[idx + 1].page)
    rebuild_sub_tabs()
    scroll_tgt = 0
    scroll = 0
    hover_idx = -1
    cpick_open = false
    edit_active = false
end

-- ── Apply Text Input ──
local function apply_edit()
    if not edit_active then return end
    if edit_type == item_type.input_float or edit_type == item_type.slider
       or edit_type == item_type.float_toggle then
        local v = tonumber(edit_buf)
        if v then menu.set_f_val(edit_idx, v) end
    elseif edit_type == item_type.input_int or edit_type == item_type.int_option
           or edit_type == item_type.int_toggle then
        local v = tonumber(edit_buf)
        if v then menu.set_i_val(edit_idx, math.floor(v)) end
    else
        menu.set_selected(edit_idx)
        menu.set_input_buffer(edit_buf)
        menu.confirm_input()
    end
    edit_active = false
end

-- ── Keyboard Input for Editing ──
local function process_edit_keys()
    if not edit_active then return end
    local chars = input.get_chars()
    if chars ~= "" then
        for ch in chars:gmatch(".") do
            local b = string.byte(ch)
            if edit_type == item_type.input_text or edit_type == item_type.search then
                if #edit_buf < 127 then edit_buf = edit_buf .. ch end
            else
                local ok = (b >= 48 and b <= 57)
                    or (b == 45 and #edit_buf == 0)
                    or (b == 46
                        and (edit_type == item_type.input_float
                             or edit_type == item_type.slider
                             or edit_type == item_type.float_toggle)
                        and not edit_buf:find("%."))
                if ok then edit_buf = edit_buf .. ch end
            end
        end
    end
    if input.key_just_pressed(VK.BACK) and #edit_buf > 0 then
        edit_buf = edit_buf:sub(1, -2)
    end
    if input.key_just_pressed(VK.RETURN) then apply_edit() end
    if input.key_just_pressed(VK.ESCAPE) then edit_active = false end
end

-- ── Draw: Header ──
local function draw_header(x, y, w)
    draw.rect(x, y, x + w, y + HDR_H, CLR.header[1], CLR.header[2], CLR.header[3], 250, 5)
    draw.rect(x, y + HDR_H - 5, x + w, y + HDR_H, CLR.header[1], CLR.header[2], CLR.header[3], 250)
    draw.rect_gradient(x, y, x + w, y + 2,
        CLR.accent_d[1],CLR.accent_d[2],CLR.accent_d[3],255,
        CLR.accent[1],CLR.accent[2],CLR.accent[3],255,
        CLR.accent[1],CLR.accent[2],CLR.accent[3],255,
        CLR.accent_d[1],CLR.accent_d[2],CLR.accent_d[3],255)
    local th = text.height(font.title)
    center_text(font.title,x,x+w,y+(HDR_H-th)*0.5,"CHERAX",245,243,250,255)
    text.draw(font.item,x+w-54,y+(HDR_H-text.height(font.item))*0.5,
        230,225,238,235,"Q")
    text.draw(font.title,x+w-28,y+(HDR_H-th)*0.5,
        245,243,250,255,"*")
    -- Header drag handled by menu.drag_header() in draw_menu
end

-- ── Draw: Vertical Category Bar ──
local function draw_cats(x, y, h)
    draw.rect(x, y, x + SIDE_W, y + h, CLR.tab_bg[1], CLR.tab_bg[2], CLR.tab_bg[3], 250)
    draw.line(x+SIDE_W-1,y,x+SIDE_W-1,y+h,CLR.div[1],CLR.div[2],CLR.div[3],180)
    local ih = h / #cats
    for i, cat in ipairs(cats) do
        local ci = i - 1
        local iy = y + ci * ih
        local sel = ci == active_cat
        local hov = in_rect(x,iy,x+SIDE_W,iy+ih)
        if sel then
            draw.rect(x+5,iy+4,x+SIDE_W-5,iy+ih-4,
                CLR.accent_d[1],CLR.accent_d[2],CLR.accent_d[3],220,5)
            draw.rect(x,iy+5,x+3,iy+ih-5,CLR.accent[1],CLR.accent[2],CLR.accent[3],255,2)
        elseif hov then
            draw.rect(x+5,iy+4,x+SIDE_W-5,iy+ih-4,
                CLR.hover[1], CLR.hover[2], CLR.hover[3], CLR.hover[4])
        end
        local c = sel and CLR.accent or (hov and CLR.txt or CLR.txt_dim)
        local tth = text.height(font.title)
        center_text(font.title,x,x+SIDE_W,iy+(ih-tth)*0.5,
            cat.label, c[1], c[2], c[3], c[4])
        if hov then
            local label=cat.page
            local lw=text.width(font.small,label)+14
            draw.rect(x+SIDE_W+4,iy+(ih-22)*0.5,x+SIDE_W+4+lw,iy+(ih+22)*0.5,
                12,4,20,235,3)
            text.draw(font.small,x+SIDE_W+11,iy+(ih-text.height(font.small))*0.5,
                CLR.txt[1],CLR.txt[2],CLR.txt[3],255,label)
        end
        if click_in(x,iy,x+SIDE_W,iy+ih) then go_cat(ci) end
    end
end

-- ── Draw: Sub-Tabs ── returns height used (0 if none)
local function draw_sub_tabs(x, y, w, depth)
    if #sub_tabs == 0 or depth >= 2 then return 0 end

    draw.rect(x, y, x + w, y + STAB_H,
        CLR.stab_bg[1], CLR.stab_bg[2], CLR.stab_bg[3], 255)
    draw.line(x, y + STAB_H - 1, x + w, y + STAB_H - 1,
        CLR.div[1], CLR.div[2], CLR.div[3], 80)

    local n = #sub_tabs + (has_general and 1 or 0)
    local tw = w / n
    local ti = 0

    -- General tab (non-submenu items from root page)
    if has_general then
        local tx = x
        local sel = sub_tab_sel == -1
        local hov = in_rect(tx, y, tx + tw, y + STAB_H)
        if sel then
            draw.rect(tx, y + STAB_H - 2, tx + tw, y + STAB_H,
                CLR.accent[1], CLR.accent[2], CLR.accent[3], 255)
        elseif hov then
            draw.rect(tx, y, tx + tw, y + STAB_H,
                CLR.hover[1], CLR.hover[2], CLR.hover[3], CLR.hover[4])
        end
        local c = sel and CLR.txt or (hov and CLR.txt or CLR.txt_dim)
        local sth = text.height(font.small)
        center_text(font.small, tx, tx + tw, y + (STAB_H - sth) * 0.5,
            "General", c[1], c[2], c[3], c[4])
        if click_in(tx, y, tx + tw, y + STAB_H) and sub_tab_sel ~= -1 then
            menu.go_back()
            sub_tab_sel = -1
            scroll_tgt = 0
            scroll = 0
        end
        ti = 1
    end

    -- Sub-tabs
    for i, tab in ipairs(sub_tabs) do
        local tx = x + (ti + i - 1) * tw
        local sel = sub_tab_sel == i
        local hov = in_rect(tx, y, tx + tw, y + STAB_H)
        if sel then
            draw.rect(tx, y + STAB_H - 2, tx + tw, y + STAB_H,
                CLR.accent[1], CLR.accent[2], CLR.accent[3], 255)
        elseif hov then
            draw.rect(tx, y, tx + tw, y + STAB_H,
                CLR.hover[1], CLR.hover[2], CLR.hover[3], CLR.hover[4])
        end
        local c = sel and CLR.txt or (hov and CLR.txt or CLR.txt_dim)
        local sth = text.height(font.small)
        center_text(font.small, tx, tx + tw, y + (STAB_H - sth) * 0.5,
            tab.name, c[1], c[2], c[3], c[4])
        if click_in(tx, y, tx + tw, y + STAB_H) and sub_tab_sel ~= i then
            if sub_tab_sel ~= -1 then
                menu.go_back()
            end
            menu.set_selected(tab.idx)
            menu.activate()
            sub_tab_sel = i
            scroll_tgt = 0
            scroll = 0
        end
    end

    return STAB_H
end

-- ── Draw: Breadcrumb (depth 2+) ── returns height
local function draw_breadcrumb(x, y, w)
    local page = menu.page_name()
    local th = text.height(font.breadcrumb)
    local BC_H = 22
    local ty = y + (BC_H - th) * 0.5
    local s = "< " .. page
    text.draw(font.breadcrumb, x + PAD, ty,
        CLR.txt[1], CLR.txt[2], CLR.txt[3], 200, s)
    local sw = text.width(font.breadcrumb, s)
    if click_in(x, y, x + PAD + sw + 8, y + BC_H) then
        menu.go_back()
        scroll_tgt = 0
        scroll = 0
    end
    return BC_H
end

-- ── Draw: Checkbox ──
local function draw_check(x, y, checked)
    draw.rect(x, y, x + CHECK_SZ, y + CHECK_SZ,
        CLR.chk_bg[1], CLR.chk_bg[2], CLR.chk_bg[3], 255, 2)
    if checked then
        draw.rect(x, y, x + CHECK_SZ, y + CHECK_SZ,
            CLR.accent[1], CLR.accent[2], CLR.accent[3], 255, 2)
        draw.line(x+3, y+CHECK_SZ*0.5,
            x+CHECK_SZ*0.45, y+CHECK_SZ-3, 255,255,255,255, 1.5)
        draw.line(x+CHECK_SZ*0.45, y+CHECK_SZ-3,
            x+CHECK_SZ-3, y+3, 255,255,255,255, 1.5)
    else
        draw.rect_outline(x, y, x + CHECK_SZ, y + CHECK_SZ,
            55, 55, 75, 200, 2)
    end
end

-- ── Draw: Slider Track ──
local function draw_sli(idx, x, y, w, val, mn, mx, is_int)
    local t = (mx ~= mn) and (val - mn) / (mx - mn) or 0
    t = clamp(t, 0, 1)
    draw.rect(x, y, x + w, y + SLIDER_H,
        CLR.sli_bg[1], CLR.sli_bg[2], CLR.sli_bg[3], 255, 2)
    local fw = t * w
    if fw > 1 then
        draw.rect_gradient(x, y, x + fw, y + SLIDER_H,
            CLR.accent_d[1], CLR.accent_d[2], CLR.accent_d[3], 255,
            CLR.accent[1],   CLR.accent[2],   CLR.accent[3],   255,
            CLR.accent[1],   CLR.accent[2],   CLR.accent[3],   255,
            CLR.accent_d[1], CLR.accent_d[2], CLR.accent_d[3], 255)
    end
    local kx = x + fw
    local ky = y + SLIDER_H * 0.5
    draw.circle(kx, ky, 5, CLR.accent[1], CLR.accent[2], CLR.accent[3], 255)
    draw.circle(kx, ky, 3, 255, 255, 255, 240)
    if input.mouse_clicked(0) and in_rect(x - 6, y - 8, x + w + 6, y + SLIDER_H + 8) then
        drag_slider = idx
        drag_sl_x = x
        drag_sl_w = w
        drag_sl_min = mn
        drag_sl_max = mx
        drag_sl_int = is_int
    end
end

-- ── Draw Single Item ──
-- skip_subs: if true, skip sub_menu items (they're rendered as tabs)
local function draw_item(idx, x, y, w, ih, clip_top, clip_bot, skip_subs)
    local item = menu.get_item(idx)
    if not item then return 0 end
    if skip_subs and item.type == item_type.sub_menu then return 0 end

    local mx, my = input.mouse_x(), input.mouse_y()
    local hov = mx >= x and mx < x + w and my >= y and my < y + ih
                and my >= clip_top and my < clip_bot
    local th = text.height(font.item)
    local ty = y + (ih - th) * 0.5
    local t = item.type
    local extra = 0

    if hov then
        draw.rect(x, y, x + w, y + ih,
            CLR.hover[1], CLR.hover[2], CLR.hover[3], CLR.hover[4])
        hover_idx = idx
    end

    -- ── Toggle types ──
    if t == item_type.toggle or t == item_type.float_toggle or t == item_type.int_toggle
       or t == item_type.array_toggle or t == item_type.loop_toggle then
        local cx = x + PAD
        local cy = y + (ih - CHECK_SZ) * 0.5
        draw_check(cx, cy, item.on)
        text.draw(font.item, cx + CHECK_SZ + 6, ty,
            CLR.txt[1], CLR.txt[2], CLR.txt[3], hov and 255 or 200, item.name)
        if item.on then
            if t == item_type.float_toggle then
                local vs = string.format("%.2f", item.f_val)
                local vw = text.width(font.value, vs)
                text.draw(font.value, x + w - PAD - vw, ty,
                    CLR.accent[1], CLR.accent[2], CLR.accent[3], 255, vs)
                extra = 14
                local sx = x + PAD + CHECK_SZ + 6
                local sw = w - PAD * 2 - CHECK_SZ - 6
                draw_sli(idx, sx, y + ih + 2, sw, item.f_val, item.f_min, item.f_max, false)
            elseif t == item_type.int_toggle then
                local vs = tostring(item.i_val)
                local vw = text.width(font.value, vs)
                text.draw(font.value, x + w - PAD - vw, ty,
                    CLR.accent[1], CLR.accent[2], CLR.accent[3], 255, vs)
                extra = 14
                local sx = x + PAD + CHECK_SZ + 6
                local sw = w - PAD * 2 - CHECK_SZ - 6
                draw_sli(idx, sx, y + ih + 2, sw, item.i_val, item.i_min, item.i_max, true)
            elseif t == item_type.array_toggle or t == item_type.loop_toggle then
                local cv = item.current_value or ""
                local vw = text.width(font.value, cv)
                text.draw(font.value, x + w - PAD - vw, ty,
                    CLR.accent[1], CLR.accent[2], CLR.accent[3], 255, cv)
            end
        end
        if hov and input.mouse_clicked(0) then
            if item.on and (t == item_type.array_toggle or t == item_type.loop_toggle) then
                if mx > x + w * 0.6 then
                    menu.set_value_index(idx, (item.value_index + 1) % item.value_count)
                else
                    menu.toggle_item(idx)
                end
            else
                menu.toggle_item(idx)
            end
        end

    -- ── Slider (float) ──
    elseif t == item_type.slider then
        text.draw(font.item, x + PAD, ty,
            CLR.txt[1], CLR.txt[2], CLR.txt[3], hov and 255 or 200, item.name)
        local vs = string.format("%.2f", item.f_val)
        local vw = text.width(font.value, vs)
        text.draw(font.value, x + w - PAD - vw, ty,
            CLR.accent[1], CLR.accent[2], CLR.accent[3], 255, vs)
        extra = 10
        draw_sli(idx, x + PAD, y + ih, w - PAD * 2, item.f_val, item.f_min, item.f_max, false)

    -- ── Int Option ──
    elseif t == item_type.int_option then
        text.draw(font.item, x + PAD, ty,
            CLR.txt[1], CLR.txt[2], CLR.txt[3], hov and 255 or 200, item.name)
        local vs = tostring(item.i_val)
        local vw = text.width(font.value, vs)
        text.draw(font.value, x + w - PAD - vw, ty,
            CLR.accent[1], CLR.accent[2], CLR.accent[3], 255, vs)
        extra = 10
        draw_sli(idx, x + PAD, y + ih, w - PAD * 2, item.i_val, item.i_min, item.i_max, true)

    -- ── Submenu (only shown at depth 2+ where they're not tabs) ──
    elseif t == item_type.sub_menu then
        text.draw(font.item, x + PAD, ty,
            CLR.txt[1], CLR.txt[2], CLR.txt[3], hov and 255 or 200, item.name)
        local aw = text.width(font.value, ">")
        text.draw(font.value, x + w - PAD - aw, ty,
            CLR.txt_dim[1], CLR.txt_dim[2], CLR.txt_dim[3], 180, ">")
        if hov and input.mouse_clicked(0) then
            menu.set_selected(idx)
            menu.activate()
            scroll_tgt = 0
            scroll = 0
        end

    -- ── Action ──
    elseif t == item_type.action then
        local bx = x + PAD
        local bw = w - PAD * 2
        local by = y + 3
        local bh = ih - 6
        local bg = hov and CLR.btn_hov or CLR.btn_bg
        draw.rect(bx, by, bx + bw, by + bh, bg[1], bg[2], bg[3], 255, 3)
        draw.rect_outline(bx, by, bx + bw, by + bh, 50, 50, 70, 150, 3)
        center_text(font.item, bx, bx + bw, by + (bh - th) * 0.5,
            item.name, CLR.txt[1], CLR.txt[2], CLR.txt[3], 255)
        if hov and input.mouse_clicked(0) then
            menu.set_selected(idx)
            menu.activate()
        end

    -- ── Selected Tick ──
    elseif t == item_type.selected_tick then
        local bx = x + PAD
        local bw = w - PAD * 2
        local by = y + 3
        local bh = ih - 6
        local bg = hov and CLR.btn_hov or CLR.btn_bg
        draw.rect(bx, by, bx + bw, by + bh, bg[1], bg[2], bg[3], 255, 3)
        draw.rect_outline(bx, by, bx + bw, by + bh, 50, 50, 70, 150, 3)
        local nc = hov and CLR.txt or {CLR.txt[1], CLR.txt[2], CLR.txt[3], 200}
        text.draw(font.item, bx + PAD, by + (bh - th) * 0.5,
            nc[1], nc[2], nc[3], nc[4] or 255, item.name)
        local tw2 = text.width(font.value, "v")
        local tc = hov and CLR.accent or CLR.txt_dim
        text.draw(font.value, bx + bw - PAD - tw2, by + (bh - th) * 0.5,
            tc[1], tc[2], tc[3], 220, "v")
        if hov and input.mouse_clicked(0) then
            menu.set_selected(idx)
            menu.activate()
        end

    -- ── Array / Loop ──
    elseif t == item_type.array_option or t == item_type.loop_option then
        text.draw(font.item, x + PAD, ty,
            CLR.txt[1], CLR.txt[2], CLR.txt[3], hov and 255 or 200, item.name)
        local cv = item.current_value or ""
        local rw = text.width(font.value, ">")
        local lw = text.width(font.value, "<")
        local vw = text.width(font.value, cv)
        local rx = x + w - PAD - rw
        local vx = rx - vw - 6
        local lx = vx - lw - 6
        text.draw(font.value, lx, ty,
            CLR.txt_dim[1], CLR.txt_dim[2], CLR.txt_dim[3], hov and 200 or 140, "<")
        text.draw(font.value, vx, ty,
            CLR.accent[1], CLR.accent[2], CLR.accent[3], 255, cv)
        text.draw(font.value, rx, ty,
            CLR.txt_dim[1], CLR.txt_dim[2], CLR.txt_dim[3], hov and 200 or 140, ">")
        if hov and input.mouse_clicked(0) then
            if mx > x + w * 0.5 then
                menu.set_value_index(idx, (item.value_index + 1) % item.value_count)
            else
                local ni = item.value_index - 1
                if ni < 0 then ni = item.value_count - 1 end
                menu.set_value_index(idx, ni)
            end
        end

    -- ── Color ──
    elseif t == item_type.color then
        text.draw(font.item, x + PAD, ty,
            CLR.txt[1], CLR.txt[2], CLR.txt[3], hov and 255 or 200, item.name)
        local sw2 = 24
        local sh2 = ih - 8
        local sx2 = x + w - PAD - sw2
        local sy2 = y + 4
        draw.rect(sx2, sy2, sx2 + sw2, sy2 + sh2, item.r, item.g, item.b, item.a, 2)
        draw.rect_outline(sx2, sy2, sx2 + sw2, sy2 + sh2, 60, 60, 80, 200, 2)
        if hov and input.mouse_clicked(0) then
            if cpick_open and cpick_idx == idx then
                cpick_open = false
            else
                cpick_open = true
                cpick_idx = idx
                cpick_vals = {item.r, item.g, item.b, item.a}
                edit_active = false
            end
        end

    -- ── Input types ──
    elseif t == item_type.input_text or t == item_type.input_int or t == item_type.input_float then
        local editing = edit_active and edit_idx == idx
        text.draw(font.item, x + PAD, ty,
            CLR.txt[1], CLR.txt[2], CLR.txt[3], hov and 255 or 200, item.name)
        local bx2 = x + w * 0.45
        local bw2 = w * 0.55 - PAD
        local by2 = y + 3
        local bh2 = ih - 6
        local bdr = editing and CLR.accent or {50, 50, 72, 200}
        draw.rect(bx2, by2, bx2 + bw2, by2 + bh2,
            CLR.inp_bg[1], CLR.inp_bg[2], CLR.inp_bg[3], 255, 2)
        draw.rect_outline(bx2, by2, bx2 + bw2, by2 + bh2,
            bdr[1], bdr[2], bdr[3], bdr[4], 2)
        local disp
        if editing then
            local blink = math.floor(ctx.time() * 2) % 2 == 0
            disp = edit_buf .. (blink and "|" or "")
        elseif t == item_type.input_float then
            disp = string.format("%.2f", item.f_val)
        elseif t == item_type.input_int then
            disp = tostring(item.i_val)
        else
            disp = ""
        end
        draw.push_clip(bx2 + 2, by2, bx2 + bw2 - 2, by2 + bh2)
        local dw = text.width(font.value, disp)
        local dx = bx2 + bw2 - PAD - dw
        if dx < bx2 + 3 then dx = bx2 + 3 end
        local vth = text.height(font.value)
        text.draw(font.value, dx, by2 + (bh2 - vth) * 0.5,
            CLR.txt[1], CLR.txt[2], CLR.txt[3], 255, disp)
        draw.pop_clip()
        if hov and input.mouse_clicked(0) then
            if editing then
                apply_edit()
            else
                edit_active = true
                edit_idx = idx
                edit_type = t
                if t == item_type.input_float then
                    edit_buf = string.format("%.2f", item.f_val)
                elseif t == item_type.input_int then
                    edit_buf = tostring(item.i_val)
                else
                    edit_buf = ""
                end
                cpick_open = false
            end
        end

    -- ── Search ──
    elseif t == item_type.search then
        local editing = edit_active and edit_idx == idx
        local bx2 = x + PAD
        local bw2 = w - PAD * 2
        local by2 = y + 3
        local bh2 = ih - 6
        local bdr = editing and CLR.accent or {50, 50, 72, 200}
        draw.rect(bx2, by2, bx2 + bw2, by2 + bh2,
            CLR.inp_bg[1], CLR.inp_bg[2], CLR.inp_bg[3], 255, 2)
        draw.rect_outline(bx2, by2, bx2 + bw2, by2 + bh2,
            bdr[1], bdr[2], bdr[3], bdr[4], 2)
        -- search glyph on right
        local glyph = "[/]"
        local gw = text.width(font.value, glyph)
        local vth = text.height(font.value)
        local gc = editing and CLR.accent or CLR.txt_dim
        text.draw(font.value, bx2 + bw2 - PAD - gw, by2 + (bh2 - vth) * 0.5,
            gc[1], gc[2], gc[3], 200, glyph)
        -- query text / placeholder
        local disp
        if editing then
            local blink = math.floor(ctx.time() * 2) % 2 == 0
            disp = edit_buf .. (blink and "|" or "")
        elseif item.text and item.text ~= "" then
            disp = item.text
        else
            disp = "Search..."
        end
        local tc = (not editing and (not item.text or item.text == "")) and CLR.txt_dim or CLR.txt
        draw.push_clip(bx2 + PAD, by2, bx2 + bw2 - PAD * 2 - gw - 4, by2 + bh2)
        text.draw(font.value, bx2 + PAD, by2 + (bh2 - vth) * 0.5,
            tc[1], tc[2], tc[3], 255, disp)
        draw.pop_clip()
        if hov and input.mouse_clicked(0) then
            if editing then
                apply_edit()
            else
                edit_active = true
                edit_idx = idx
                edit_type = t
                edit_buf = item.text or ""
                cpick_open = false
            end
        end
    end

    return ih + extra
end

local function item_draw_height(item,ih)
    if not item then return 0 end
    if item.type==item_type.slider or item.type==item_type.int_option then return ih+10 end
    if item.on and (item.type==item_type.float_toggle or item.type==item_type.int_toggle) then return ih+14 end
    return ih
end

local function build_sections(count,skip_subs,ih)
    local sections={}
    local current=nil
    local function ensure_section()
        if not current then
            current={title=menu.page_name() or "Options",items={},height=34}
            table.insert(sections,current)
        end
    end
    for i=0,count-1 do
        local item=menu.get_item(i)
        if item and not (skip_subs and item.type==item_type.sub_menu) then
            if item.is_header then
                local name=(item.name or "Options"):gsub("^[%-%s]+",""):gsub("[%-%s]+$","")
                current={title=name,items={},height=34}
                table.insert(sections,current)
            else
                ensure_section()
                table.insert(current.items,i)
                current.height=current.height+item_draw_height(item,ih)
            end
        end
    end
    for _,section in ipairs(sections) do section.height=section.height+8 end
    return sections
end

local function draw_cards(x,y,w,h,ih,count,skip_subs,clip_top,clip_bot)
    local sections=build_sections(count,skip_subs,ih)
    local col_w=(w-CARD_GAP)/2
    local heights={0,0}
    for _,section in ipairs(sections) do
        local col=heights[1]<=heights[2] and 1 or 2
        local cx=x+(col-1)*(col_w+CARD_GAP)
        local cy=y+heights[col]
        draw.rect(cx,cy,cx+col_w,cy+section.height,11,4,19,225,4)
        draw.rect_outline(cx,cy,cx+col_w,cy+section.height,
            CLR.accent_d[1],CLR.accent_d[2],CLR.accent_d[3],145,4,1)
        draw.rect_gradient(cx,cy,cx+col_w,cy+3,
            CLR.accent_d[1],CLR.accent_d[2],CLR.accent_d[3],230,
            CLR.accent[1],CLR.accent[2],CLR.accent[3],230,
            CLR.accent[1],CLR.accent[2],CLR.accent[3],230,
            CLR.accent_d[1],CLR.accent_d[2],CLR.accent_d[3],230)
        center_text(font.title,cx,cx+col_w,cy+7,section.title,
            CLR.txt[1],CLR.txt[2],CLR.txt[3],255)
        draw.line(cx+8,cy+33,cx+col_w-8,cy+33,CLR.div[1],CLR.div[2],CLR.div[3],150)
        local iy=cy+35
        for _,idx in ipairs(section.items) do
            local used=draw_item(idx,cx+5,iy,col_w-10,ih,clip_top,clip_bot,false)
            iy=iy+used
        end
        heights[col]=heights[col]+section.height+CARD_GAP
    end
    return math.max(heights[1],heights[2])+PAD*2
end

-- ── Draw: Color Picker Popup ──
local function draw_color_popup(wx, wy, ww, wh)
    if not cpick_open then return end
    local item = menu.get_item(cpick_idx)
    if not item then cpick_open = false; return end

    local PW, PH = 200, 130
    local px = wx + ww - PW - 10
    local py = wy + wh - PH - DESC_H - 10

    draw.rect(px, py, px + PW, py + PH, 20, 20, 28, 250, 4)
    draw.rect_outline(px, py, px + PW, py + PH,
        CLR.accent[1], CLR.accent[2], CLR.accent[3], 180, 4)

    local labels = {"R", "G", "B", "A"}
    local ry = py + 8

    for ci = 1, 4 do
        text.draw(font.tiny, px + 6, ry + 4,
            CLR.txt_dim[1], CLR.txt_dim[2], CLR.txt_dim[3], 255, labels[ci])
        local bx = px + 18
        local bw = PW - 18 - 38
        local by = ry + (22 - SLIDER_H) * 0.5 + 2
        draw.rect(bx, by, bx + bw, by + SLIDER_H,
            CLR.sli_bg[1], CLR.sli_bg[2], CLR.sli_bg[3], 255, 2)
        local tv = cpick_vals[ci] / 255
        if tv > 0 then
            draw.rect_gradient(bx, by, bx + tv * bw, by + SLIDER_H,
                CLR.accent_d[1], CLR.accent_d[2], CLR.accent_d[3], 255,
                CLR.accent[1],   CLR.accent[2],   CLR.accent[3],   255,
                CLR.accent[1],   CLR.accent[2],   CLR.accent[3],   255,
                CLR.accent_d[1], CLR.accent_d[2], CLR.accent_d[3], 255)
        end
        local vs = tostring(math.floor(cpick_vals[ci]))
        local vw = text.width(font.tiny, vs)
        text.draw(font.tiny, px + PW - vw - 6, ry + 4,
            CLR.accent[1], CLR.accent[2], CLR.accent[3], 255, vs)

        if input.mouse_clicked(0) and in_rect(bx, by - 4, bx + bw, by + SLIDER_H + 4) then
            cpick_drag = ci
        end
        if cpick_drag == ci and input.mouse_down(0) then
            local nmx = input.mouse_x()
            local nt = clamp((nmx - bx) / bw, 0, 1)
            cpick_vals[ci] = math.floor(nt * 255 + 0.5)
        end

        ry = ry + 22
    end

    if input.mouse_released(0) then cpick_drag = 0 end

    if cpick_vals[1] ~= item.r or cpick_vals[2] ~= item.g
       or cpick_vals[3] ~= item.b or cpick_vals[4] ~= item.a then
        menu.set_item_color(cpick_idx,
            cpick_vals[1], cpick_vals[2], cpick_vals[3], cpick_vals[4])
    end

    draw.rect(px + 6, ry, px + 30, ry + 16,
        cpick_vals[1], cpick_vals[2], cpick_vals[3], cpick_vals[4], 2)
    draw.rect_outline(px + 6, ry, px + 30, ry + 16, 60, 60, 80, 180, 2)

    local db_x = px + PW - 44
    local db_hov = in_rect(db_x, ry, db_x + 38, ry + 16)
    local db_c = db_hov and CLR.btn_hov or CLR.btn_bg
    draw.rect(db_x, ry, db_x + 38, ry + 16, db_c[1], db_c[2], db_c[3], 255, 3)
    center_text(font.tiny, db_x, db_x + 38, ry + 3,
        "Done", CLR.txt[1], CLR.txt[2], CLR.txt[3], 255)
    if click_in(db_x, ry, db_x + 38, ry + 16) then cpick_open = false end

    if input.mouse_clicked(0) and not in_rect(px, py, px + PW, py + PH) then
        cpick_open = false
    end
end

-- ── Draw: Description Bar ──
local function draw_desc(x, y, w, idx)
    draw.rect(x, y, x + w, y + DESC_H,
        CLR.desc_bg[1], CLR.desc_bg[2], CLR.desc_bg[3], 255)
    draw.line(x, y, x + w, y, CLR.div[1], CLR.div[2], CLR.div[3], 100)
    if idx<0 then idx=menu.selected_index() end
    if idx >= 0 then
        local item = menu.get_item(idx)
        if item and item.desc and item.desc ~= "" then
            local dth = text.height(font.desc)
            draw.push_clip(x + PAD, y, x + w - PAD, y + DESC_H)
            text.draw(font.desc, x + PAD, y + (DESC_H - dth) * 0.5,
                CLR.txt_dim[1], CLR.txt_dim[2], CLR.txt_dim[3], 200, item.desc)
            draw.pop_clip()
        end
    end
end

-- ── Draw: Scrollbar ──
local function draw_scrollbar(x, y, h, content_h)
    if content_h <= h then return end
    local ratio = h / content_h
    local bar_h = math.max(ratio * h, 20)
    local max_s = content_h - h
    local t = max_s > 0 and (scroll / max_s) or 0
    local bar_y = y + t * (h - bar_h)
    draw.rect(x, bar_y, x + SCROLL_W, bar_y + bar_h,
        CLR.accent[1], CLR.accent[2], CLR.accent[3], 120, 2)
end

-- ══════════════════════════════════════════════════
-- MAIN DRAW
-- ══════════════════════════════════════════════════

function draw_menu()
    if title_font_downloaded then apply_title_font();title_font_downloaded=false end

    theme.set_body_bg(
        math.max(CLR.bg[1] - 4, 0),
        math.max(CLR.bg[2] - 4, 0),
        math.max(CLR.bg[3] - 4, 0), 255)

    CLR = make_colors()

    if not menu.is_visible() then return end

    init_pos()
    if last_page=="" then
        local current=menu.page_name()
        local parent=menu.page_parent()
        for i,cat in ipairs(cats) do
            if current==cat.page or parent==cat.page then go_cat(i-1);break end
        end
        if last_page=="" then go_cat(0) end
    end
    local W = math.min(sf("Width",900),ctx.screen_w()-24)
    local H = math.min(sf("Height",620),ctx.screen_h()-24)
    local ITEM_H = sf("Item Height",30)

    -- Window drag handled by menu.drag_header() below

    -- Slider drag
    if drag_slider >= 0 then
        if input.mouse_down(0) then
            local nmx = input.mouse_x()
            local t = clamp((nmx - drag_sl_x) / drag_sl_w, 0, 1)
            local nv = drag_sl_min + t * (drag_sl_max - drag_sl_min)
            if drag_sl_int then
                menu.set_i_val(drag_slider, math.floor(nv + 0.5))
            else
                menu.set_f_val(drag_slider, nv)
            end
        else
            drag_slider = -1
        end
    end

    local x, y = win_x, win_y

    -- Header drag-to-move: pass natural origin, add returned offset
    local _dox, _doy = menu.drag_header(x, y, W, HDR_H)
    x = x + _dox
    y = y + _doy

    local depth = get_depth()

    -- Sync sub_tab_sel if user went back via keyboard
    if depth == 0 and sub_tab_sel ~= -1 then
        sub_tab_sel = -1
    end

    -- Window and neon edge glow
    for glow=4,1,-1 do
        draw.rect_outline(x-glow*2,y-glow*2,x+W+glow*2,y+H+glow*2,
            CLR.accent[1],CLR.accent[2],CLR.accent[3],18+(4-glow)*11,7,2)
    end
    draw.rect(x,y,x+W,y+H,CLR.bg[1],CLR.bg[2],CLR.bg[3],CLR.bg[4],6)
    draw.rect_outline(x,y,x+W,y+H,CLR.accent[1],CLR.accent[2],CLR.accent[3],210,6,1)

    draw_header(x, y, W)
    local main_x=x+SIDE_W
    local main_w=W-SIDE_W

    -- Sub-tabs or breadcrumb
    local bar_y = y + HDR_H
    local extra_h = 0
    if depth >= 2 then
        extra_h = draw_breadcrumb(main_x,bar_y,main_w)
    else
        extra_h = draw_sub_tabs(main_x,bar_y,main_w,depth)
    end
    if extra_h==0 then
        extra_h=STAB_H
        draw.rect(main_x,bar_y,main_x+main_w,bar_y+extra_h,
            CLR.stab_bg[1],CLR.stab_bg[2],CLR.stab_bg[3],245)
        text.draw(font.small,main_x+PAD,bar_y+(extra_h-text.height(font.small))*0.5,
            CLR.accent[1],CLR.accent[2],CLR.accent[3],255,(menu.page_name() or "Options"):upper())
        draw.line(main_x,bar_y+extra_h-1,main_x+main_w,bar_y+extra_h-1,
            CLR.div[1],CLR.div[2],CLR.div[3],140)
    end

    -- Content area
    local cy = bar_y + extra_h
    local ch=H-HDR_H-extra_h-DESC_H
    local count = menu.item_count()

    hover_idx = -1

    -- On General tab (depth 0), skip sub_menu items (they're tabs)
    local skip_subs = (depth == 0 and #sub_tabs > 0)

    menu.set_content_rect(main_x,cy,main_w,ch)
    draw.push_clip(main_x,cy,main_x+main_w-SCROLL_W-3,cy+ch)

    local cards_x=main_x+PAD
    local cards_w=main_w-PAD*2-SCROLL_W-3
    local total_h=draw_cards(cards_x,cy+PAD-scroll,cards_w,ch,ITEM_H,count,skip_subs,cy,cy+ch)

    draw.pop_clip()

    draw_scrollbar(x+W-SCROLL_W-2,cy,ch,total_h)

    -- Scroll wheel
    if in_rect(main_x,cy,x+W,cy+ch) and drag_slider<0 then
        local wh = input.mouse_wheel()
        if wh ~= 0 then
            scroll_tgt = scroll_tgt - wh * ITEM_H * 2
            if scroll_tgt < 0 then scroll_tgt = 0 end
            local ms = total_h - ch
            if ms < 0 then ms = 0 end
            if scroll_tgt > ms then scroll_tgt = ms end
        end
    end

    scroll = lerp(scroll, scroll_tgt, clamp(ctx.delta() * 14, 0, 1))

    draw_desc(main_x,y+H-DESC_H,main_w,hover_idx)

    draw_cats(x,y+HDR_H,H-HDR_H)

    draw_color_popup(x, y, W, H)

    process_edit_keys()
end

-- ══════════════════════════════════════════════════
-- INPUT
-- ══════════════════════════════════════════════════

function handle_input()
    if input.key_just_pressed(VK.INSERT) then
        menu.set_visible(not menu.is_visible())
        if not menu.is_visible() then
            edit_active = false
            cpick_open = false
        end
    end

    if edit_active then return end

    if input.key_just_pressed(VK.ESCAPE) then
        if cpick_open then
            cpick_open = false
        elseif menu.page_parent() ~= "" then
            menu.go_back()
            scroll_tgt = 0
            scroll = 0
        end
    end
end
