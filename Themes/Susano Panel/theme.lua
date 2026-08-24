-- Susano Panel
-- Full-width web-panel click GUI with grouped navigation and modular option cards.

text.set_font_family("Bahnschrift")
local ICON_FONT_FILE="Themes\\Susano Panel\\fonts\\fa-solid-900.ttf"
local ICON_FONT_REL="Themes/Susano Panel/fonts/fa-solid-900.ttf"
local icon_font_downloaded=false
local function valid_font_data(data)
    if not data or #data<1024 then return false end
    local sig=data:sub(1,4)
    return sig=="OTTO" or (data:byte(1)==0 and data:byte(2)==1 and data:byte(3)==0 and data:byte(4)==0)
end
local function apply_icon_font() text.set_icon_font(font.label,ICON_FONT_REL) end
do
    local data=file.read(ICON_FONT_FILE)
    if valid_font_data(data) then
        apply_icon_font()
    elseif net and net.get then
        net.get("cdnjs.cloudflare.com","/ajax/libs/font-awesome/6.7.2/webfonts/fa-solid-900.ttf",function(body)
            if valid_font_data(body) then icon_font_downloaded=file.write(ICON_FONT_FILE,body) end
        end,function() end)
    end
end
text.set_size(font.title, 24)
text.set_weight(font.title, 900)
text.set_size(font.breadcrumb, 13)
text.set_weight(font.breadcrumb, 700)
text.set_size(font.item, 12)
text.set_weight(font.item, 600)
text.set_size(font.value, 11)
text.set_weight(font.value, 600)
text.set_size(font.desc, 11)
text.set_size(font.small, 10)
text.set_size(font.tiny, 9)
text.set_size(font.label, 15)

local SETTINGS_FILE = "Themes\\Susano Panel\\settings.ini"
menu.clear_settings()
menu.add_setting_color("Susano Accent", 239, 91, 58, 255, "Coral accent used by tabs, controls, and selected navigation")
menu.add_setting_slider("Susano Width", 1760, 1050, 1920, 10, "Width of the complete web panel")
menu.add_setting_slider("Susano Rows", 7, 4, 10, 1, "Maximum controls displayed in each module card")
menu.add_setting_slider("Susano Opacity", 98, 72, 100, 1, "Panel opacity percentage")
menu.add_setting_toggle("Susano Sidebar", true, "Show grouped category navigation")
menu.add_setting_action("Reset Theme", "Reset Susano Panel settings")

local function setting(name)
    return menu.get_setting(name)
end

local function load_settings()
    local body = file.read(SETTINGS_FILE)
    if not body then return end
    for line in body:gmatch("[^\r\n]+") do
        local key, value = line:match("^(.-)=(.*)$")
        if key == "accent" then
            local r,g,b,a = value:match("(%d+),(%d+),(%d+),(%d+)")
            if r then menu.set_setting("Susano Accent", tonumber(r), tonumber(g), tonumber(b), tonumber(a)) end
        elseif key == "width" then
            menu.set_setting("Susano Width", tonumber(value) or 1760)
        elseif key == "rows" then
            menu.set_setting("Susano Rows", tonumber(value) or 7)
        elseif key == "opacity" then
            menu.set_setting("Susano Opacity", tonumber(value) or 98)
        elseif key == "sidebar" then
            menu.set_setting("Susano Sidebar", value == "1")
        end
    end
end

local function serialize_settings()
    local a = setting("Susano Accent") or {r=239,g=91,b=58,a=255}
    local w = setting("Susano Width") or {f_val=1760}
    local rows = setting("Susano Rows") or {f_val=7}
    local opacity = setting("Susano Opacity") or {f_val=98}
    local sidebar = setting("Susano Sidebar") or {on=true}
    return table.concat({
        "accent="..a.r..","..a.g..","..a.b..","..a.a,
        "width="..tostring(w.f_val),
        "rows="..tostring(rows.f_val),
        "opacity="..tostring(opacity.f_val),
        "sidebar="..(sidebar.on and "1" or "0")
    }, "\n")
end

local function reset_settings()
    menu.set_setting("Susano Accent", 239, 91, 58, 255)
    menu.set_setting("Susano Width", 1760)
    menu.set_setting("Susano Rows", 7)
    menu.set_setting("Susano Opacity", 98)
    menu.set_setting("Susano Sidebar", true)
    file.remove(SETTINGS_FILE)
end

load_settings()
local last_settings = serialize_settings()
local save_at = 0
local save_pending = false

local C = {
    bg={4,4,4}, panel={10,10,10}, panel2={15,15,15}, line={31,31,31},
    text={237,237,237}, muted={126,126,126}, faint={67,67,67}, white={255,255,255},
    green={33,211,138}, red={239,91,58}, amber={245,180,40}
}

local ROW_H = 34
local PAD = 14
local selected_page = -1
local home_handles = nil
local edit_on, edit_idx, edit_type, edit_buf, edit_frame = false, -1, 0, "", -1
local hotkey_on, hotkey_idx = false, -1
local color_on, color_idx, color_handle, color_value = false, -1, nil, {239,91,58,255}
local module_open = {}
local board_page = ""
local board_selected = nil
local board_scroll = 0
local board_content_h = 0
local board_drag_handle = nil
local board_tab_by_page = {}
local board_tab_offset = {}
local network_player_handle = nil
local network_player_name = "SELECT A PLAYER"

local function fa(cp)
    if cp < 0x80 then return string.char(cp) end
    if cp < 0x800 then return string.char(0xC0+math.floor(cp/0x40),0x80+(cp%0x40)) end
    if cp < 0x10000 then
        return string.char(0xE0+math.floor(cp/0x1000),0x80+(math.floor(cp/0x40)%0x40),0x80+(cp%0x40))
    end
    return string.char(0xF0+math.floor(cp/0x40000),0x80+(math.floor(cp/0x1000)%0x40),0x80+(math.floor(cp/0x40)%0x40),0x80+(cp%0x40))
end

local ICON = {
    Home=fa(0xF015), Network=fa(0xF6FF), Self=fa(0xF007), Vehicle=fa(0xF1B9),
    Weapon=fa(0xE19B), VFX=fa(0xE2CA), World=fa(0xF0AC), Misc=fa(0xF0C9),
    Teleport=fa(0xF3C5), Scripts=fa(0xF121), Spooner=fa(0xF1B2),
    Protections=fa(0xF3ED), Settings=fa(0xF013), Info=fa(0xF05A),
    Right=fa(0xF054), Check=fa(0xF00C), Game=fa(0xF11B), Sliders=fa(0xF1DE)
}

local NUMERIC = {
    [item_type.slider]=true, [item_type.int_option]=true,
    [item_type.float_toggle]=true, [item_type.int_toggle]=true
}
local CYCLIC = {
    [item_type.array_option]=true, [item_type.loop_option]=true,
    [item_type.array_toggle]=true, [item_type.loop_toggle]=true
}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function hit(x1,y1,x2,y2)
    local mx,my=input.mouse_x(),input.mouse_y()
    return mx>=x1 and mx<x2 and my>=y1 and my<y2
end
local function click(x1,y1,x2,y2)
    return hit(x1,y1,x2,y2) and input.mouse_clicked(0)
end
local function rgba(c,a) return c[1],c[2],c[3],a or c[4] or 255 end

local function accent()
    local s=setting("Susano Accent")
    if s then return {s.r,s.g,s.b,s.a} end
    return {239,91,58,255}
end

local function panel(x1,y1,x2,y2,alpha,title,ac)
    draw.rect_gradient(x1,y1,x2,y2,
        C.panel2[1],C.panel2[2],C.panel2[3],alpha,
        C.panel[1],C.panel[2],C.panel[3],alpha,
        C.panel[1],C.panel[2],C.panel[3],alpha,
        C.panel[1],C.panel[2],C.panel[3],alpha)
    draw.rect_outline(x1,y1,x2,y2,C.line[1],C.line[2],C.line[3],235,4,1)
    if title then
        draw.rect(x1,y1,x2,y1+36,C.panel2[1],C.panel2[2],C.panel2[3],alpha,4)
        draw.rect(x1,y1+35,x2,y1+36,C.line[1],C.line[2],C.line[3],210)
        text.draw(font.breadcrumb,x1+PAD,y1+(36-text.height(font.breadcrumb))*0.5,
            ac[1],ac[2],ac[3],255,title:upper())
    end
end

local function item_value(item)
    if CYCLIC[item.type] then return item.current_value or "" end
    if item.type==item_type.input_text or item.type==item_type.search then
        return item.text and item.text~="" and item.text or "..."
    end
    if item.type==item_type.input_int or item.type==item_type.int_option or item.type==item_type.int_toggle then
        return tostring(item.i_val or 0)
    end
    if item.type==item_type.input_float or item.type==item_type.slider or item.type==item_type.float_toggle then
        return string.format((item.f_step or 1)<1 and "%.1f" or "%.0f",item.f_val or 0)
    end
    return ""
end

local function adjust(item,dir)
    local i=item._idx
    if CYCLIC[item.type] and (item.value_count or 0)>0 then
        local v=((item.value_index or 0)+dir)%item.value_count
        if v<0 then v=v+item.value_count end
        menu.set_value_index(i,v)
        return true
    elseif item.type==item_type.int_option or item.type==item_type.int_toggle then
        menu.set_i_val(i,(item.i_val or 0)+dir*((item.i_step or 0)~=0 and item.i_step or 1))
        return true
    elseif item.type==item_type.slider or item.type==item_type.float_toggle then
        menu.set_f_val(i,(item.f_val or 0)+dir*((item.f_step or 0)~=0 and item.f_step or 0.1))
        return true
    end
    return false
end

local function activate(item)
    if item.name=="Reset Theme" and item.type==item_type.action then
        reset_settings()
        notify.push("Theme","Susano Panel reset",1)
        return
    end
    if item.type==item_type.color then
        color_on=true;color_idx=item._idx;color_handle=nil;color_value={item.r,item.g,item.b,item.a}
    elseif item.type==item_type.sub_menu then
        board_selected=item
    elseif item.type==item_type.array_toggle or item.type==item_type.loop_toggle then
        menu.activate()
    elseif CYCLIC[item.type] then
        adjust(item,1)
    elseif item.type==item_type.input_text or item.type==item_type.input_int
        or item.type==item_type.input_float or item.type==item_type.search
        or item.type==item_type.slider or item.type==item_type.int_option then
        edit_on=true;edit_idx=item._idx;edit_type=item.type;edit_frame=ctx.frame()
        if item.type==item_type.input_int or item.type==item_type.int_option then edit_buf=tostring(item.i_val or 0)
        elseif item.type==item_type.input_float or item.type==item_type.slider then edit_buf=string.format("%.2f",item.f_val or 0)
        else edit_buf=item.text or "" end
    else
        menu.activate()
    end
end

local function draw_switch(x,y,on,ac)
    local w,h=34,18
    draw.rect(x,y,x+w,y+h,on and ac[1] or 35,on and ac[2] or 35,on and ac[3] or 35,255,9)
    draw.circle(on and x+w-9 or x+9,y+9,6,on and 255 or 99,on and 255 or 99,on and 255 or 99,255)
end

local function board_adjust(item,dir)
    local h=item.handle
    if not h then return false end
    if CYCLIC[item.type] and (item.value_count or 0)>0 then
        local v=((item.value_index or 0)+dir)%item.value_count
        if v<0 then v=v+item.value_count end
        items.set_value_index(h,v)
        return true
    elseif item.type==item_type.int_option or item.type==item_type.int_toggle then
        local step=(item.i_step or 0)~=0 and item.i_step or 1
        items.set_i_val(h,clamp((item.i_val or 0)+dir*step,item.i_min or -2147483648,item.i_max or 2147483647))
        return true
    elseif item.type==item_type.slider or item.type==item_type.float_toggle then
        local step=(item.f_step or 0)~=0 and item.f_step or 0.1
        items.set_f_val(h,clamp((item.f_val or 0)+dir*step,item.f_min or -1000000,item.f_max or 1000000))
        return true
    end
    return false
end

local function activate_in_place(item)
    if not item or not item.handle then return false end
    local page=item.page
    local page_id=item.page_id
    if not page or page=="" or not page_id or page_id==0 then return false end
    local target_index=nil
    for index,handle in ipairs(items.page_items(page) or {}) do
        if handle==item.handle then target_index=index-1;break end
    end
    if target_index==nil then return false end
    local origin=menu.page_id()
    local origin_selected=menu.selected_index()
    if origin~=page_id then menu.navigate(page_id) end
    menu.set_selected(target_index)
    menu.activate()
    if origin~=page_id then
        menu.go_back()
    else
        menu.set_selected(origin_selected)
    end
    return true
end

local function board_activate(item)
    if not item or not item.handle then return end
    board_selected=item
    if item.name=="Reset Theme" and item.type==item_type.action then
        reset_settings()
        notify.push("Theme","Susano Panel reset",1)
    elseif item.type==item_type.color then
        color_on=true
        color_idx=-1
        color_handle=item.handle
        color_value={item.r,item.g,item.b,item.a}
    elseif item.type==item_type.slider then
        return
    elseif item.type==item_type.toggle or item.type==item_type.float_toggle or item.type==item_type.int_toggle
        or item.type==item_type.array_toggle or item.type==item_type.loop_toggle then
        if not activate_in_place(item) then items.toggle(item.handle) end
    elseif item.type==item_type.action or item.type==item_type.selected_tick then
        if not activate_in_place(item) then items.set_on(item.handle,true) end
    elseif not board_adjust(item,1) then
        if not activate_in_place(item) then items.activate(item.handle) end
    end
end

local function draw_board_row(item,x,y,w,ac,clip_top,clip_bottom)
    local h=36
    local inside_clip=not clip_top or (y+h>clip_top and y<clip_bottom)
    local hovered=inside_clip and hit(x,y,x+w,y+h)
    local click_consumed=false
    if hovered then draw.rect(x,y,x+w,y+h,23,18,16,230) end
    draw.rect(x+12,y+h-1,x+w-12,y+h,C.line[1],C.line[2],C.line[3],115)
    local name=item.name or "Option"
    if item.is_header then
        text.draw_spaced(font.tiny,x+16,y+(h-text.height(font.tiny))*0.5,
            ac[1],ac[2],ac[3],255,name:gsub("^[%-%s]+",""):gsub("[%-%s]+$",""):upper(),1)
        return
    end
    text.draw_ellipsis(font.item,x+16,y+(h-text.height(font.item))*0.5,
        C.text[1],C.text[2],C.text[3],255,name,w*0.43)
    local rx=x+w-16
    if item.type==item_type.toggle then
        draw_switch(rx-34,y+(h-18)*0.5,item.on,ac)
    elseif item.type==item_type.sub_menu then
        text.draw(font.label,rx-11,y+(h-text.height(font.label))*0.5,ac[1],ac[2],ac[3],255,ICON.Right)
    elseif item.type==item_type.selected_tick then
        text.draw(font.label,rx-14,y+(h-text.height(font.label))*0.5,C.green[1],C.green[2],C.green[3],255,ICON.Check)
    elseif item.type==item_type.color then
        draw.rect(rx-34,y+8,rx,y+h-8,item.r,item.g,item.b,item.a,5)
        draw.rect_outline(rx-34,y+8,rx,y+h-8,58,58,58,255,5,1)
    elseif NUMERIC[item.type] or CYCLIC[item.type] then
        local value=item_value(item)
        local toggle_type=item.type==item_type.float_toggle or item.type==item_type.int_toggle
            or item.type==item_type.array_toggle or item.type==item_type.loop_toggle
        local right_edge=toggle_type and rx-48 or rx
        if item.type==item_type.slider or item.type==item_type.float_toggle then
            local bx=math.max(x+w*0.55,right_edge-145)
            local ex=right_edge-34
            local lo=item.f_min or 0
            local hi=item.f_max or 1
            local ratio=hi>lo and clamp(((item.f_val or 0)-lo)/(hi-lo),0,1) or 0
            local over_track=inside_clip and hit(bx-8,y,ex+8,y+h)
            if over_track and input.mouse_clicked(0) then
                board_drag_handle=item.handle
                board_selected=item
                click_consumed=true
            end
            if board_drag_handle==item.handle then
                click_consumed=true
                if input.mouse_down(0) then
                    local next_ratio=clamp((input.mouse_x()-bx)/(ex-bx),0,1)
                    local next_value=lo+(hi-lo)*next_ratio
                    local step=item.f_step or 0
                    if step>0 then next_value=lo+math.floor((next_value-lo)/step+0.5)*step end
                    items.set_f_val(item.handle,clamp(next_value,lo,hi))
                    ratio=next_ratio
                else
                    board_drag_handle=nil
                end
            end
            draw.rect(bx,y+h*0.5-2,ex,y+h*0.5+2,47,47,47,255,2)
            draw.rect(bx,y+h*0.5-2,bx+(ex-bx)*ratio,y+h*0.5+2,ac[1],ac[2],ac[3],255,2)
            draw.circle(bx+(ex-bx)*ratio,y+h*0.5,6,255,125,91,255)
            text.draw(font.tiny,right_edge-text.width(font.tiny,value),y+(h-text.height(font.tiny))*0.5,
                ac[1],ac[2],ac[3],255,value)
        else
            local box_w=math.max(72,math.min(138,text.width(font.value,value)+28))
            draw.rect(right_edge-box_w,y+6,right_edge,y+h-6,22,22,22,255,5)
            draw.rect_outline(right_edge-box_w,y+6,right_edge,y+h-6,43,43,43,255,5,1)
            text.draw_ellipsis(font.value,right_edge-box_w+11,y+(h-text.height(font.value))*0.5,
                C.text[1],C.text[2],C.text[3],255,value,box_w-22)
        end
        if item.type==item_type.float_toggle or item.type==item_type.int_toggle
            or item.type==item_type.array_toggle or item.type==item_type.loop_toggle then
            draw_switch(rx-34,y+(h-18)*0.5,item.on,ac)
        end
    elseif item.type==item_type.action then
        text.draw(font.label,rx-12,y+(h-text.height(font.label))*0.5,ac[1],ac[2],ac[3],255,ICON.Right)
    end
    if hovered and input.mouse_clicked(0) and not click_consumed then board_activate(item) end
    if hovered and input.mouse_clicked(1) then board_selected=item;board_adjust(item,-1) end
end

local function child_page_name(parent,item)
    for _,name in ipairs(items.page_children(parent) or {}) do
        if util.joaat(name)==item.sub_menu then return name end
    end
    return item.name
end

local function collect_page_cards(page_name,label,cards,depth,seen)
    if not page_name or page_name=="" or depth>6 or seen[page_name] then return end
    seen[page_name]=true
    local group={}
    local group_name=(label or page_name or "OPTIONS"):upper()
    local function flush_group()
        if #group>0 then
            cards[#cards+1]={name=group_name,items=group}
            group={}
        end
    end
    for _,handle in ipairs(items.page_items(page_name) or {}) do
        local child=items.at(handle)
        if child then
            if child.is_header then
                flush_group()
                group_name=(child.name or "OPTIONS"):upper()
            elseif child.type==item_type.sub_menu then
                flush_group()
                collect_page_cards(child_page_name(page_name,child),child.name,cards,depth+1,seen)
                group_name=(label or page_name or "OPTIONS"):upper()
            else
                group[#group+1]=child
            end
        end
    end
    flush_group()
    seen[page_name]=nil
end

local function draw_module_board(main_x,main_w,top,bottom,opacity,ac,current,menu_items,sel)
    local columns=main_w>=760 and 2 or 1
    local gap=14
    local col_w=(main_w-gap*(columns-1))/columns
    local col_y={}
    for c=1,columns do col_y[c]=top end
    local module_count=0
    for _,module in ipairs(menu_items) do
        if module.type==item_type.sub_menu then module_count=module_count+1 end
    end

    if module_count==0 then
        local fake={name=current,handle=nil,type=item_type.sub_menu}
        local children=items.page_items(current) or {}
        menu_items={fake}
        module_count=1
        module_open[current.."::__page"]=true
        fake._children=children
    end

    local max_rows_setting=setting("Susano Rows")
    local max_rows=math.floor(max_rows_setting and max_rows_setting.f_val or 7)
    local ordinal=0
    for _,module in ipairs(menu_items) do
        if module.type==item_type.sub_menu then
            ordinal=ordinal+1
            local col=((ordinal-1)%columns)+1
            local cx=main_x+(col-1)*(col_w+gap)
            local cy=col_y[col]
            local page_name=module._children and current or child_page_name(current,module)
            local key=current.."::"..(module.name or page_name)
            if module_open[key]==nil then module_open[key]=true end
            local open=module_open[key]
            local handles=module._children or items.page_items(page_name) or {}
            local visible=math.min(#handles,max_rows)
            local more=open and #handles>visible
            local mh=44+(open and visible*36+8 or 0)+(more and 24 or 0)
            if cy+mh>bottom and open then open=false;mh=44 end
            if cy+44<=bottom then
                draw.rect(cx,cy,cx+col_w,cy+mh,C.panel2[1],C.panel2[2],C.panel2[3],opacity,8)
                draw.rect_outline(cx,cy,cx+col_w,cy+mh,C.line[1],C.line[2],C.line[3],245,8,1)
                local active=module._idx==sel
                if active then draw.rect(cx,cy,cx+3,cy+44,ac[1],ac[2],ac[3],255,2) end
                if hit(cx,cy,cx+col_w-40,cy+44) then draw.rect(cx,cy,cx+col_w-40,cy+44,ac[1],ac[2],ac[3],24,8) end
                text.draw_ellipsis(font.breadcrumb,cx+16,cy+(44-text.height(font.breadcrumb))*0.5,
                    C.text[1],C.text[2],C.text[3],255,
                    (module.name or current):upper(),col_w-70)
                text.draw(font.small,cx+col_w-25,cy+(44-text.height(font.small))*0.5,
                    C.muted[1],C.muted[2],C.muted[3],255,open and "-" or "+")
                draw.rect(cx+12,cy+43,cx+col_w-12,cy+44,C.line[1],C.line[2],C.line[3],160)
                if click(cx,cy,cx+col_w-40,cy+44) then
                    module_open[key]=not open
                end
                if module.handle and click(cx+col_w-40,cy,cx+col_w,cy+44) then items.activate(module.handle) end
                if module.handle then
                    text.draw(font.label,cx+col_w-32,cy+(44-text.height(font.label))*0.5,
                        C.muted[1],C.muted[2],C.muted[3],255,ICON.Right)
                end
                if open then
                    for n=1,visible do
                        local child=items.at(handles[n])
                        if child then draw_board_row(child,cx,cy+44+(n-1)*36,col_w,ac) end
                    end
                    if more then
                        local my=cy+44+visible*36
                        text.draw_centered(font.tiny,cx,my+6,cx+col_w,C.muted[1],C.muted[2],C.muted[3],255,
                            "+ "..tostring(#handles-visible).." MORE OPTIONS")
                        if module.handle and click(cx,my,cx+col_w,my+24) then items.activate(module.handle) end
                    end
                end
                col_y[col]=cy+mh+gap
            end
        end
    end
end

local function draw_card_grid(cards,area_x,area_w,top,bottom,opacity,ac,columns)
    local gap=14
    columns=math.max(1,columns or 1)
    local col_w=(area_w-gap*(columns-1))/columns
    local col_heights={}
    for c=1,columns do col_heights[c]=0 end
    draw.push_clip(area_x,top,area_x+area_w,bottom)
    for _,card in ipairs(cards) do
        local col=1
        for c=2,columns do if col_heights[c]<col_heights[col] then col=c end end
        local cx=area_x+(col-1)*(col_w+gap)
        local cy=top+col_heights[col]-board_scroll
        local mh=52+#card.items*36
        if cy<bottom and cy+mh>top then
            draw.rect(cx,cy,cx+col_w,cy+mh,C.panel2[1],C.panel2[2],C.panel2[3],opacity,8)
            draw.rect_outline(cx,cy,cx+col_w,cy+mh,C.line[1],C.line[2],C.line[3],245,8,1)
            draw.rect(cx,cy,cx+3,cy+44,ac[1],ac[2],ac[3],255,2)
            text.draw_ellipsis(font.breadcrumb,cx+16,cy+(44-text.height(font.breadcrumb))*0.5,
                C.text[1],C.text[2],C.text[3],255,card.name,col_w-74)
            local count=tostring(#card.items)
            text.draw(font.tiny,cx+col_w-18-text.width(font.tiny,count),
                cy+(44-text.height(font.tiny))*0.5,C.faint[1],C.faint[2],C.faint[3],255,count)
            draw.rect(cx+12,cy+43,cx+col_w-12,cy+44,C.line[1],C.line[2],C.line[3],160)
            for index,item in ipairs(card.items) do
                draw_board_row(item,cx,cy+44+(index-1)*36,col_w,ac,top,bottom)
            end
        end
        col_heights[col]=col_heights[col]+mh+gap
    end
    draw.pop_clip()
    local tallest=0
    for c=1,columns do tallest=math.max(tallest,col_heights[c]) end
    return math.max(0,tallest-gap)
end

local function draw_network_players(main_x,main_w,top,bottom,opacity,ac)
    local gap=14
    local list_w=math.max(250,main_w*0.26)
    local detail_x=main_x+list_w+gap
    local detail_w=main_w-list_w-gap
    local handles=items.page_items("Players") or {}
    local list_h=52+#handles*36
    local cy=top-board_scroll
    draw.push_clip(main_x,top,main_x+list_w,bottom)
    if cy<bottom and cy+list_h>top then
        draw.rect(main_x,cy,main_x+list_w,cy+list_h,C.panel2[1],C.panel2[2],C.panel2[3],opacity,8)
        draw.rect_outline(main_x,cy,main_x+list_w,cy+list_h,C.line[1],C.line[2],C.line[3],245,8,1)
        draw.rect(main_x,cy,main_x+3,cy+44,ac[1],ac[2],ac[3],255,2)
        text.draw(font.breadcrumb,main_x+16,cy+(44-text.height(font.breadcrumb))*0.5,
            C.text[1],C.text[2],C.text[3],255,"PLAYER LIST")
        text.draw(font.tiny,main_x+list_w-18-text.width(font.tiny,tostring(#handles)),
            cy+(44-text.height(font.tiny))*0.5,C.faint[1],C.faint[2],C.faint[3],255,tostring(#handles))
        draw.rect(main_x+12,cy+43,main_x+list_w-12,cy+44,C.line[1],C.line[2],C.line[3],160)
        for index,handle in ipairs(handles) do
            local player=items.at(handle)
            if player then
                local ry=cy+44+(index-1)*36
                local visible=ry+36>top and ry<bottom
                local hovered=visible and hit(main_x,ry,main_x+list_w,ry+36)
                local selected=network_player_name==player.name
                if hovered or selected then
                    draw.rect(main_x,ry,main_x+list_w,ry+36,
                        selected and 60 or 23,selected and 31 or 18,selected and 25 or 16,selected and 255 or 230)
                end
                if selected then draw.rect(main_x,ry,main_x+3,ry+36,ac[1],ac[2],ac[3],255) end
                text.draw_ellipsis(font.item,main_x+16,ry+(36-text.height(font.item))*0.5,
                    C.text[1],C.text[2],C.text[3],255,player.name or "Player",list_w-52)
                text.draw(font.label,main_x+list_w-26,ry+(36-text.height(font.label))*0.5,
                    ac[1],ac[2],ac[3],255,ICON.Right)
                draw.rect(main_x+12,ry+35,main_x+list_w-12,ry+36,C.line[1],C.line[2],C.line[3],115)
                if hovered and input.mouse_clicked(0) then
                    network_player_handle=handle
                    network_player_name=player.name or "PLAYER"
                    board_selected=player
                    items.set_on(handle,true)
                end
            end
        end
    end
    draw.pop_clip()

    local cards={}
    if network_player_handle then
        collect_page_cards("Network Player",network_player_name,cards,0,{})
    end
    if #cards==0 then cards[1]={name=network_player_name,items={}} end
    local columns=detail_w>=760 and 2 or 1
    local detail_h=draw_card_grid(cards,detail_x,detail_w,top,bottom,opacity,ac,columns)
    return math.max(list_h,detail_h)
end

local function draw_flat_module_board(main_x,main_w,top,bottom,opacity,ac,current,menu_items,sel)
    if board_drag_handle and not input.mouse_down(0) then board_drag_handle=nil end
    local modules={}
    for _,item in ipairs(menu_items) do
        if item.type==item_type.sub_menu then modules[#modules+1]=item end
    end

    local active_name=board_tab_by_page[current]
    local active=nil
    for _,module in ipairs(modules) do
        if module.name==active_name then active=module;break end
    end
    if not active and #modules>0 then
        active=modules[1]
        board_tab_by_page[current]=active.name
    end

    if current=="Network" and active and active.name=="Players" then
        return draw_network_players(main_x,main_w,top,bottom,opacity,ac)
    end

    local cards={}
    if active then
        collect_page_cards(child_page_name(current,active),active.name,cards,0,{})
    else
        collect_page_cards(current,current,cards,0,{})
    end
    if #cards==0 then cards[1]={name=(active and active.name or current):upper(),items={}} end
    local columns=main_w>=760 and 2 or 1
    return draw_card_grid(cards,main_x,main_w,top,bottom,opacity,ac,columns)
end

local function draw_row(item,x,y,w,is_selected,ac)
    local hovered=hit(x,y,x+w,y+ROW_H)
    if is_selected or hovered then
        draw.rect_gradient(x,y,x+w,y+ROW_H,
            ac[1],ac[2],ac[3],is_selected and 230 or 95,
            ac[1],ac[2],ac[3],is_selected and 155 or 55,
            ac[1],ac[2],ac[3],is_selected and 155 or 55,
            ac[1],ac[2],ac[3],is_selected and 230 or 95)
        if is_selected then
            draw.rect(x,y,x+3,y+ROW_H,ac[1],ac[2],ac[3],255)
            draw.rect(x,y+ROW_H-2,x+w,y+ROW_H,ac[1],ac[2],ac[3],180)
        end
    end
    draw.rect(x,y+ROW_H-1,x+w,y+ROW_H,C.line[1],C.line[2],C.line[3],100)

    if item.is_header then
        text.draw(font.small,x+PAD,y+(ROW_H-text.height(font.small))*0.5,
            ac[1],ac[2],ac[3],255,(item.name or ""):gsub("^[%-%s]+",""):gsub("[%-%s]+$",""):upper())
        return
    end

    local tc=is_selected and C.white or C.text
    text.draw_ellipsis(font.item,x+PAD,y+(ROW_H-text.height(font.item))*0.5,tc[1],tc[2],tc[3],255,item.name or "",w*0.57)
    local rx=x+w-PAD
    local tp=item.type
    if tp==item_type.toggle then
        draw_switch(rx-17,y+(ROW_H-17)*0.5,item.on,ac)
    elseif tp==item_type.sub_menu then
        text.draw(font.label,rx-13,y+(ROW_H-text.height(font.label))*0.5,tc[1],tc[2],tc[3],255,ICON.Right)
    elseif tp==item_type.selected_tick then
        text.draw(font.label,rx-15,y+(ROW_H-text.height(font.label))*0.5,C.green[1],C.green[2],C.green[3],255,ICON.Check)
    elseif tp==item_type.color then
        draw.rect(rx-28,y+10,rx,y+ROW_H-10,item.r,item.g,item.b,item.a,2)
        draw.rect_outline(rx-28,y+10,rx,y+ROW_H-10,150,160,176,220,2,1)
    elseif NUMERIC[tp] or CYCLIC[tp] or tp==item_type.input_text or tp==item_type.input_int
        or tp==item_type.input_float or tp==item_type.search then
        local value=(edit_on and edit_idx==item._idx) and (edit_buf..((math.floor(ctx.time()*2)%2==0) and "|" or "")) or item_value(item)
        local vw=text.width(font.value,value)
        local value_x=rx-vw
        text.draw(font.value,value_x,y+(ROW_H-text.height(font.value))*0.5,
            is_selected and 255 or ac[1],is_selected and 255 or ac[2],is_selected and 255 or ac[3],255,value)
        if tp==item_type.slider and (item.f_max or 0)>(item.f_min or 0) then
            local tx1=x+w*0.58
            local tx2=math.max(tx1+20,value_x-12)
            local ratio=clamp(((item.f_val or 0)-item.f_min)/(item.f_max-item.f_min),0,1)
            draw.rect(tx1,y+ROW_H-8,tx2,y+ROW_H-5,C.line[1],C.line[2],C.line[3],255,2)
            draw.rect(tx1,y+ROW_H-8,tx1+(tx2-tx1)*ratio,y+ROW_H-5,ac[1],ac[2],ac[3],255,2)
        elseif CYCLIC[tp] then
            text.draw(font.value,value_x-13,y+(ROW_H-text.height(font.value))*0.5,tc[1],tc[2],tc[3],210,"‹")
            text.draw(font.value,rx+4,y+(ROW_H-text.height(font.value))*0.5,tc[1],tc[2],tc[3],210,"›")
        end
        if tp==item_type.float_toggle or tp==item_type.int_toggle or tp==item_type.array_toggle or tp==item_type.loop_toggle then
            draw.circle(rx-vw-12,y+ROW_H*0.5,4,item.on and C.green[1] or C.faint[1],item.on and C.green[2] or C.faint[2],item.on and C.green[3] or C.faint[3],255)
        end
    end

    if item.hotkey and item.hotkey~=0 then
        local key=menu.vk_name(item.hotkey)
        local kw=text.width(font.tiny,key)+10
        local bx=x+PAD+text.width(font.item,item.name or "")+8
        draw.rect(bx,y+9,bx+kw,y+ROW_H-9,ac[1],ac[2],ac[3],170,3)
        text.draw(font.tiny,bx+5,y+(ROW_H-text.height(font.tiny))*0.5,255,255,255,255,key)
    end

    if hovered and input.mouse_clicked(0) and not menu.overlay_active() and not color_on then
        menu.set_selected(item._idx)
        activate(item)
    end
end

local function draw_color_popup(x,y,ac)
    if not color_on then return end
    local w,h=290,170
    local px=x-w-12
    local py=y
    panel(px,py,px+w,py+h,252,"COLOR",ac)
    local labels={"R","G","B","A"}
    for n=1,4 do
        local yy=py+46+(n-1)*27
        text.draw(font.small,px+14,yy,C.muted[1],C.muted[2],C.muted[3],255,labels[n])
        local bx=px+38
        local bw=w-70
        draw.rect(bx,yy+3,bx+bw,yy+9,C.line[1],C.line[2],C.line[3],255,3)
        draw.rect(bx,yy+3,bx+bw*(color_value[n]/255),yy+9,
            n==1 and 239 or (n==2 and 34 or (n==3 and 59 or ac[1])),
            n==2 and 197 or (n==3 and 130 or ac[2]),
            n==3 and 246 or ac[3],255,3)
        text.draw(font.tiny,bx+bw+7,yy,color_value[n]==nil and 0 or C.text[1],C.text[2],C.text[3],255,tostring(color_value[n]))
        if hit(bx,yy-5,bx+bw,yy+17) and input.mouse_down(0) then
            color_value[n]=math.floor(clamp((input.mouse_x()-bx)/bw,0,1)*255+0.5)
        end
    end
    draw.rect(px+14,py+h-27,px+70,py+h-12,color_value[1],color_value[2],color_value[3],color_value[4],3)
    local done_x=px+w-62
    draw.rect(done_x,py+h-29,px+w-14,py+h-10,ac[1],ac[2],ac[3],255,3)
    text.draw(font.tiny,done_x+10,py+h-27,255,255,255,255,"DONE")
    if color_handle then
        items.set_color(color_handle,color_value[1],color_value[2],color_value[3],color_value[4])
    else
        menu.set_item_color(color_idx,color_value[1],color_value[2],color_value[3],color_value[4])
    end
    if click(done_x,py+h-29,px+w-14,py+h-10) then color_on=false;color_handle=nil end
end

local function process_edit()
    if not edit_on then return end
    local chars=input.get_chars()
    if chars~="" then
        for ch in chars:gmatch(".") do
            local b=string.byte(ch)
            if edit_type==item_type.input_text or edit_type==item_type.search then
                if #edit_buf<63 then edit_buf=edit_buf..ch end
            elseif (b>=48 and b<=57) or (b==45 and #edit_buf==0)
                or (b==46 and (edit_type==item_type.input_float or edit_type==item_type.slider) and not edit_buf:find("%.")) then
                edit_buf=edit_buf..ch
            end
        end
    end
    if input.key_just_pressed(VK.BACK) and #edit_buf>0 then edit_buf=edit_buf:sub(1,-2) end
    if input.key_just_pressed(VK.ESCAPE) then edit_on=false end
    if input.key_just_pressed(VK.RETURN) and ctx.frame()~=edit_frame then
        menu.set_selected(edit_idx)
        if edit_type==item_type.input_int or edit_type==item_type.int_option then local v=tonumber(edit_buf);if v then menu.set_i_val(edit_idx,math.floor(v)) end
        elseif edit_type==item_type.input_float or edit_type==item_type.slider then local v=tonumber(edit_buf);if v then menu.set_f_val(edit_idx,v) end
        else menu.set_input_buffer(edit_buf);menu.confirm_input() end
        edit_on=false
    end
end

local function draw_menu_legacy()
    if icon_font_downloaded then apply_icon_font();icon_font_downloaded=false end
    local ac=accent()
    theme.set_body_bg(C.bg[1],C.bg[2],C.bg[3],255)
    theme.set_menu_bg(C.bg[1],C.bg[2],C.bg[3],255)
    theme.set_accent_palette(ac[1],ac[2],ac[3],ac[4])
    if not menu.is_visible() then menu.set_text_editing(false);return end

    local ws=setting("Click GUI Width")
    local rs=setting("Click GUI Rows")
    local os=setting("Click GUI Opacity")
    local ss=setting("Click GUI Sidebar")
    local width=clamp(ws and ws.f_val or 1180,760,ctx.screen_w()-24)
    local rows=math.floor(rs and rs.f_val or 12)
    local opacity=math.floor(255*clamp((os and os.f_val or 96)/100,0.65,1))
    local sidebar_on=not ss or ss.on
    ROW_H=clamp((ctx.screen_h()-260)/rows,28,37)
    local header_h=104
    local footer_h=40
    local body_h=rows*ROW_H+98
    local total_h=header_h+body_h+footer_h
    local x=math.floor((ctx.screen_w()-width)*0.5)
    local y=math.floor((ctx.screen_h()-total_h)*0.5)
    local ox,oy=menu.drag_header(x,y,width,header_h)
    x=x+ox;y=y+oy

    draw.rect(x,y,x+width,y+total_h,C.bg[1],C.bg[2],C.bg[3],opacity,8)
    draw.rect_outline(x,y,x+width,y+total_h,C.line[1],C.line[2],C.line[3],240,8,1)
    draw.rect_gradient(x,y,x+width,y+header_h,
        7,13,23,opacity,3,8,15,opacity,3,8,15,opacity,7,13,23,opacity)
    local brand_w=width*0.36
    draw.rect_gradient(x,y,x+brand_w,y+header_h,
        ac[1],ac[2],ac[3],255,
        math.floor(ac[1]*0.45),math.floor(ac[2]*0.45),math.floor(ac[3]*0.45),245,
        math.floor(ac[1]*0.25),math.floor(ac[2]*0.25),math.floor(ac[3]*0.25),245,
        ac[1],ac[2],ac[3],235)
    for n=0,2 do
        draw.line(x+brand_w+18+n*8,y,x+brand_w-38+n*8,y+header_h,ac[1],ac[2],ac[3],190-n*45,4)
    end
    draw.rect(x,y+header_h-2,x+width,y+header_h,ac[1],ac[2],ac[3],210)
    text.draw_outlined(font.title,x+28,y+13,244,247,252,255,0,0,0,170,1.1,"NENYOO")
    text.draw_spaced(font.small,x+32,y+68,105,167,255,255,"M O D   M E N U",3)
    local info_x=x+width*0.45
    draw.line(info_x-24,y+26,info_x-24,y+78,C.line[1],C.line[2],C.line[3],230,1)
    text.draw(font.tiny,info_x,y+25,C.muted[1],C.muted[2],C.muted[3],255,"VERSION")
    text.draw(font.item,info_x,y+47,ac[1],ac[2],ac[3],255,str.version or "DEV")
    draw.line(info_x+145,y+26,info_x+145,y+78,C.line[1],C.line[2],C.line[3],230,1)
    text.draw(font.tiny,info_x+175,y+25,C.muted[1],C.muted[2],C.muted[3],255,"GAME")
    text.draw(font.item,info_x+175,y+47,ac[1],ac[2],ac[3],255,"GRAND THEFT AUTO V")
    draw.rect(x+width-86,y+18,x+width-26,y+82,3,9,17,230,5)
    draw.rect_outline(x+width-86,y+18,x+width-26,y+82,ac[1],ac[2],ac[3],235,5,2)
    text.draw_centered(font.title,x+width-86,y+25,x+width-26,255,255,255,255,"V")

    local body_y=y+header_h
    local sidebar_w=sidebar_on and math.max(180,width*0.175) or 0
    local right_w=math.max(230,width*0.225)
    local gap=10
    local main_x=x+sidebar_w+gap
    local main_w=width-sidebar_w-right_w-gap*3
    local right_x=main_x+main_w+gap
    menu.set_content_rect(main_x,body_y+46,main_w,36+rows*ROW_H)

    if sidebar_on then
        draw.rect(x,body_y,x+sidebar_w,y+total_h-footer_h,C.panel[1],C.panel[2],C.panel[3],opacity)
        draw.rect(x+sidebar_w-1,body_y,x+sidebar_w,y+total_h,C.line[1],C.line[2],C.line[3],220)
        if not home_handles or #home_handles==0 then home_handles=items.page_items("Home") end
        local current=menu.page_name()
        local parent=menu.page_parent()
        local sy=body_y+7
        for _,h in ipairs(home_handles or {}) do
            local name=items.name(h)
            local active=current==name or parent==name
            local nav_h=38
            local hov=hit(x,sy,x+sidebar_w,sy+nav_h)
            if active or hov then
                draw.rect_gradient(x,sy,x+sidebar_w,sy+nav_h,ac[1],ac[2],ac[3],active and 205 or 65,ac[1],ac[2],ac[3],active and 70 or 20,ac[1],ac[2],ac[3],active and 70 or 20,ac[1],ac[2],ac[3],active and 205 or 65)
                if active then
                    draw.rect(x,sy,x+3,sy+nav_h,ac[1],ac[2],ac[3],255)
                    draw.rect(x,sy+nav_h-2,x+sidebar_w,sy+nav_h,ac[1],ac[2],ac[3],255)
                end
            end
            local nav_icon=ICON[name] or ICON.Sliders
            text.draw_centered(font.label,x+15,sy+(nav_h-text.height(font.label))*0.5,x+37,active and 255 or C.muted[1],active and 255 or C.muted[2],active and 255 or C.muted[3],255,nav_icon)
            text.draw(font.item,x+48,sy+(nav_h-text.height(font.item))*0.5,active and 255 or C.muted[1],active and 255 or C.muted[2],active and 255 or C.muted[3],255,(name or ""):upper())
            if click(x,sy,x+sidebar_w,sy+nav_h) then items.activate(h) end
            sy=sy+nav_h
            if sy>y+total_h-footer_h-nav_h then break end
        end
    end

    local current=menu.page_name() or "OPTIONS"
    text.draw(font.breadcrumb,main_x,body_y+15,ac[1],ac[2],ac[3],255,current:upper().."  /  MODULES")
    local count=menu.item_count()
    local sel=menu.selected_index()
    if board_page~=current then
        board_page=current
        board_selected=nil
    end
    local menu_items={}
    for idx=0,count-1 do
        local item=menu.get_item(idx)
        if item then item._idx=idx;menu_items[#menu_items+1]=item end
    end
    draw_module_board(main_x,main_w,body_y+44,y+total_h-footer_h-12,opacity,ac,current,menu_items,sel)
    local page=0
    local page_count=1

    panel(right_x,body_y+12,right_x+right_w,y+total_h-footer_h-12,opacity,"INFORMATION",ac)
    local chosen=board_selected or menu.get_item(sel)
    local iy=body_y+60
    draw.rect(right_x+right_w-52,iy-4,right_x+right_w-PAD,iy+34,ac[1],ac[2],ac[3],28,4)
    draw.rect_outline(right_x+right_w-52,iy-4,right_x+right_w-PAD,iy+34,ac[1],ac[2],ac[3],150,4,1)
    text.draw_centered(font.label,right_x+right_w-52,iy+7,right_x+right_w-PAD,ac[1],ac[2],ac[3],255,ICON.Info)
    text.draw(font.tiny,right_x+PAD,iy,C.muted[1],C.muted[2],C.muted[3],255,"CURRENT PAGE")
    text.draw_ellipsis(font.item,right_x+PAD,iy+18,ac[1],ac[2],ac[3],255,menu.page_name() or "",right_w-82)
    iy=iy+56
    text.draw(font.tiny,right_x+PAD,iy,C.muted[1],C.muted[2],C.muted[3],255,"SELECTED OPTION")
    text.draw_ellipsis(font.item,right_x+PAD,iy+18,C.text[1],C.text[2],C.text[3],255,chosen and chosen.name or "None",right_w-PAD*2)
    iy=iy+57
    draw.rect(right_x+PAD,iy,right_x+right_w-PAD,iy+1,C.line[1],C.line[2],C.line[3],220)
    iy=iy+15
    local type_names={
        [item_type.sub_menu]="CATEGORY",[item_type.toggle]="TOGGLE",[item_type.action]="ACTION",
        [item_type.selected_tick]="SELECTED",[item_type.slider]="SLIDER",[item_type.int_option]="NUMBER",
        [item_type.array_option]="CHOICE",[item_type.loop_option]="CHOICE",[item_type.color]="COLOR",
        [item_type.float_toggle]="TOGGLE + VALUE",[item_type.int_toggle]="TOGGLE + VALUE",
        [item_type.array_toggle]="TOGGLE + CHOICE",[item_type.loop_toggle]="TOGGLE + CHOICE",
        [item_type.input_text]="TEXT INPUT",[item_type.input_int]="NUMBER INPUT",
        [item_type.input_float]="DECIMAL INPUT",[item_type.search]="SEARCH"
    }
    local type_text=chosen and (type_names[chosen.type] or "OPTION") or "NONE"
    local state_text="READY"
    local state_color=C.text
    if chosen then
        if chosen.type==item_type.toggle or chosen.type==item_type.float_toggle or chosen.type==item_type.int_toggle
            or chosen.type==item_type.array_toggle or chosen.type==item_type.loop_toggle then
            state_text=chosen.on and "ENABLED" or "DISABLED"
            state_color=chosen.on and C.green or C.muted
        elseif NUMERIC[chosen.type] or CYCLIC[chosen.type] then
            state_text=item_value(chosen)
            state_color=ac
        elseif chosen.type==item_type.sub_menu then state_text="OPEN CATEGORY";state_color=ac end
    end
    draw.rect(right_x+PAD,iy,right_x+right_w-PAD,iy+48,C.panel2[1],C.panel2[2],C.panel2[3],210,3)
    text.draw(font.tiny,right_x+PAD+10,iy+8,C.muted[1],C.muted[2],C.muted[3],255,"TYPE")
    text.draw(font.small,right_x+PAD+10,iy+25,C.text[1],C.text[2],C.text[3],255,type_text)
    text.draw(font.tiny,right_x+right_w*0.52,iy+8,C.muted[1],C.muted[2],C.muted[3],255,"STATE / VALUE")
    text.draw_ellipsis(font.small,right_x+right_w*0.52,iy+25,state_color[1],state_color[2],state_color[3],255,state_text,right_w*0.42-PAD)
    iy=iy+63
    text.draw(font.tiny,right_x+PAD,iy,C.muted[1],C.muted[2],C.muted[3],255,"DESCRIPTION")
    iy=iy+18
    local desc=chosen and chosen.desc or ""
    if desc=="" and chosen then desc="Configure "..chosen.name.."." end
    text.draw(font.desc,right_x+PAD,iy,C.muted[1],C.muted[2],C.muted[3],255,desc,right_w-PAD*2)
    local stat_y=y+total_h-footer_h-108
    draw.rect(right_x+PAD,stat_y,right_x+right_w-PAD,stat_y+1,C.line[1],C.line[2],C.line[3],180)
    text.draw(font.tiny,right_x+PAD,stat_y+14,C.muted[1],C.muted[2],C.muted[3],255,"OPTION")
    text.draw(font.small,right_x+right_w-PAD-text.width(font.small,(sel+1).." / "..count),stat_y+12,ac[1],ac[2],ac[3],255,(sel+1).." / "..count)
    text.draw(font.tiny,right_x+PAD,stat_y+38,C.muted[1],C.muted[2],C.muted[3],255,"DASHBOARD PAGE")
    text.draw(font.small,right_x+right_w-PAD-text.width(font.small,(page+1).." / "..page_count),stat_y+36,C.text[1],C.text[2],C.text[3],255,(page+1).." / "..page_count)
    text.draw(font.tiny,right_x+PAD,stat_y+62,C.muted[1],C.muted[2],C.muted[3],255,"HOTKEY")
    local hotkey=(chosen and chosen.hotkey and chosen.hotkey~=0) and menu.vk_name(chosen.hotkey) or "NOT BOUND"
    text.draw(font.small,right_x+right_w-PAD-text.width(font.small,hotkey),stat_y+60,C.text[1],C.text[2],C.text[3],255,hotkey)

    local fy=y+total_h-footer_h
    draw.rect(x,fy,x+width,y+total_h,C.panel2[1],C.panel2[2],C.panel2[3],opacity,0)
    draw.rect(x,fy,x+width,fy+1,C.line[1],C.line[2],C.line[3],220)
    local hints="ARROWS  NAVIGATE      LEFT / RIGHT  CHANGE VALUE      BACKSPACE  BACK      ENTER  SELECT      H  HOTKEY"
    text.draw(font.small,x+(width-text.width(font.small,hints))*0.5,fy+(footer_h-text.height(font.small))*0.5,C.text[1],C.text[2],C.text[3],255,hints)

    draw_color_popup(right_x,body_y+74,ac)
    process_edit()
    menu.set_text_editing(edit_on)

    local sig=serialize_settings()
    if sig~=last_settings then last_settings=sig;save_pending=true;save_at=ctx.time() end
    if save_pending and ctx.time()-save_at>0.4 then file.write(SETTINGS_FILE,last_settings);save_pending=false end
end

local NAV_GROUPS={
    {"COMBAT",{"Weapon"}},
    {"VISUALS",{"VFX","World"}},
    {"PLAYER",{"Self"}},
    {"ONLINE",{"Network"}},
    {"VEHICLES",{"Vehicle"}},
    {"SYSTEM",{"Misc","Teleport","Scripts","Spooner","Protections","Settings"}}
}

function draw_menu()
    if icon_font_downloaded then apply_icon_font();icon_font_downloaded=false end
    local ac=accent()
    theme.set_body_bg(C.bg[1],C.bg[2],C.bg[3],255)
    theme.set_menu_bg(C.bg[1],C.bg[2],C.bg[3],255)
    theme.set_accent_palette(ac[1],ac[2],ac[3],ac[4])
    if not menu.is_visible() then menu.set_text_editing(false);return end

    local ws=setting("Susano Width")
    local os=setting("Susano Opacity")
    local ss=setting("Susano Sidebar")
    local width=clamp(ws and ws.f_val or 1760,980,ctx.screen_w()-20)
    local total_h=math.min(ctx.screen_h()-20,900)
    local opacity=math.floor(255*clamp((os and os.f_val or 98)/100,0.72,1))
    local sidebar_on=not ss or ss.on
    local top_h=42
    local footer_h=30
    local x=math.floor((ctx.screen_w()-width)*0.5)
    local y=math.floor((ctx.screen_h()-total_h)*0.5)
    local ox,oy=menu.drag_header(x,y,width,top_h)
    x=x+ox;y=y+oy

    draw.rect(x,y,x+width,y+total_h,C.bg[1],C.bg[2],C.bg[3],opacity,5)
    draw.rect_outline(x,y,x+width,y+total_h,25,25,25,250,5,1)
    draw.rect(x,y,x+width,y+top_h,7,7,7,opacity,5)
    draw.rect(x,y+top_h-1,x+width,y+top_h,30,30,30,230)

    draw.circle(x+19,y+18,8,237,237,237,255)
    text.draw_centered(font.label,x+11,y+10,x+27,8,8,8,255,ICON.Game)
    text.draw(font.breadcrumb,x+32,y+8,C.text[1],C.text[2],C.text[3],255,"SUSANO")
    text.draw_spaced(font.tiny,x+33,y+25,ac[1],ac[2],ac[3],255,"L I T E",1)
    draw.rect(x+92,y+10,x+93,y+32,35,35,35,255)
    text.draw_spaced(font.tiny,x+111,y+16,C.muted[1],C.muted[2],C.muted[3],255,"W E B",1)
    text.draw_spaced(font.tiny,x+154,y+16,ac[1],ac[2],ac[3],255,"P A N E L",1)

    local status="CONNECTED"
    local status_w=text.width(font.tiny,status)+42
    local sx=x+width-status_w-54
    draw.rect(sx,y+10,sx+status_w,y+32,16,18,18,255,11)
    draw.rect_outline(sx,y+10,sx+status_w,y+32,34,37,37,255,11,1)
    draw.circle(sx+14,y+21,4,C.green[1],C.green[2],C.green[3],255)
    text.draw(font.tiny,sx+25,y+15,C.text[1],C.text[2],C.text[3],255,status)
    text.draw(font.tiny,x+width-43,y+16,C.muted[1],C.muted[2],C.muted[3],255,ctx.edition() or "V")

    local body_y=y+top_h
    local sidebar_w=sidebar_on and clamp(width*0.105,185,225) or 0
    local content_x=x+sidebar_w
    if sidebar_on then
        draw.rect(x,body_y,x+sidebar_w,y+total_h,C.panel[1],C.panel[2],C.panel[3],opacity)
        draw.rect(x+sidebar_w-1,body_y,x+sidebar_w,y+total_h,27,27,27,255)
        if not home_handles or #home_handles==0 then home_handles=items.page_items("Home") end
        local by_name={}
        for _,h in ipairs(home_handles or {}) do by_name[items.name(h)]=h end
        local current=menu.page_name() or "Home"
        local parent=menu.page_parent() or ""
        local sy=body_y+14
        for _,group in ipairs(NAV_GROUPS) do
            local has_any=false
            for _,name in ipairs(group[2]) do if by_name[name] then has_any=true;break end end
            if has_any then
                text.draw_spaced(font.tiny,x+13,sy,C.faint[1],C.faint[2],C.faint[3],255,group[1],1)
                sy=sy+18
                for _,name in ipairs(group[2]) do
                    local h=by_name[name]
                    if h then
                        local nh=31
                        local active=current==name or parent==name
                        local hov=hit(x,sy,x+sidebar_w,sy+nh)
                        if active then draw.rect(x,sy,x+sidebar_w,sy+nh,60,31,25,255) end
                        if hov and not active then draw.rect(x,sy,x+sidebar_w,sy+nh,18,18,18,255) end
                        if active then draw.rect(x,sy,x+2,sy+nh,ac[1],ac[2],ac[3],255) end
                        local nav_icon=ICON[name] or ICON.Sliders
                        text.draw_centered(font.label,x+13,sy+(nh-text.height(font.label))*0.5,x+35,
                            active and ac[1] or C.faint[1],active and ac[2] or C.faint[2],active and ac[3] or C.faint[3],255,nav_icon)
                        text.draw(font.small,x+42,sy+(nh-text.height(font.small))*0.5,
                            active and C.text[1] or C.muted[1],active and C.text[2] or C.muted[2],active and C.text[3] or C.muted[3],255,name)
                        if click(x,sy,x+sidebar_w,sy+nh) then items.activate(h) end
                        sy=sy+nh
                    end
                end
                sy=sy+10
            end
        end
    end

    local main_x=content_x+28
    local main_w=width-sidebar_w-56
    local current=menu.page_name() or "Home"
    local count=menu.item_count()
    local sel=menu.selected_index()
    local chosen=board_selected or menu.get_item(sel)
    if board_page~=current then
        board_page=current;board_selected=nil;chosen=menu.get_item(sel)
        board_scroll=0;board_content_h=0
    end

    text.draw_spaced(font.tiny,main_x,body_y+24,ac[1],ac[2],ac[3],255,(menu.page_parent() or "PANEL"):upper(),1)
    local page_title=current=="Home" and "Dashboard"
        or (current:find("Settings",1,true) and current or current.." Settings")
    text.draw(font.title,main_x,body_y+42,C.text[1],C.text[2],C.text[3],255,page_title)
    local description=chosen and chosen.desc or ""
    if description=="" then description="Configure "..current:lower().." options and modules." end
    text.draw_ellipsis(font.desc,main_x,body_y+72,C.muted[1],C.muted[2],C.muted[3],255,description,main_w)
    draw.rect(main_x,body_y+94,main_x+main_w,body_y+95,24,24,24,255)

    local menu_items={}
    for idx=0,count-1 do
        local item=menu.get_item(idx)
        if item then item._idx=idx;menu_items[#menu_items+1]=item end
    end

    local tabs_y=body_y+112
    draw.rect(main_x,tabs_y,main_x+main_w,tabs_y+36,10,10,10,255,7)
    draw.rect_outline(main_x,tabs_y,main_x+main_w,tabs_y+36,27,27,27,255,7,1)
    local tab_modules={}
    for _,item in ipairs(menu_items) do
        if item.type==item_type.sub_menu then tab_modules[#tab_modules+1]=item end
    end
    local tab_count=#tab_modules
    if tab_count>0 then
        local visible_count=math.min(7,tab_count)
        local has_pager=tab_count>visible_count
        local pager_w=has_pager and 64 or 0
        local offset=clamp(board_tab_offset[current] or 1,1,math.max(1,tab_count-visible_count+1))
        board_tab_offset[current]=offset
        local tx=main_x+5+(has_pager and 32 or 0)
        local available=main_w-10-pager_w
        local tw=available/visible_count
        if has_pager then
            local left_hover=hit(main_x+5,tabs_y+5,main_x+31,tabs_y+31)
            local right_hover=hit(main_x+main_w-31,tabs_y+5,main_x+main_w-5,tabs_y+31)
            if left_hover then draw.rect(main_x+5,tabs_y+5,main_x+31,tabs_y+31,24,24,24,255,5) end
            if right_hover then draw.rect(main_x+main_w-31,tabs_y+5,main_x+main_w-5,tabs_y+31,24,24,24,255,5) end
            text.draw_centered(font.label,main_x+5,tabs_y+12,main_x+31,C.muted[1],C.muted[2],C.muted[3],255,"<")
            text.draw_centered(font.label,main_x+main_w-31,tabs_y+12,main_x+main_w-5,C.muted[1],C.muted[2],C.muted[3],255,">")
            if left_hover and input.mouse_clicked(0) then board_tab_offset[current]=math.max(1,offset-visible_count) end
            if right_hover and input.mouse_clicked(0) then board_tab_offset[current]=math.min(tab_count-visible_count+1,offset+visible_count) end
        end
        for n=0,visible_count-1 do
            local item=tab_modules[offset+n]
            if item then
                local x1=tx+n*tw
                local x2=tx+(n+1)*tw-4
                local label=(item.name or "MODULE"):upper()
                local active=board_tab_by_page[current]==item.name or (not board_tab_by_page[current] and n==0 and offset==1)
                if active then draw.rect(x1,tabs_y+5,x2,tabs_y+31,ac[1],ac[2],ac[3],255,5) end
                text.draw_ellipsis(font.tiny,x1+10,tabs_y+13,
                    active and 255 or C.muted[1],active and 255 or C.muted[2],active and 255 or C.muted[3],255,label,x2-x1-20)
                if click(x1,tabs_y+5,x2,tabs_y+31) then
                    board_tab_by_page[current]=item.name
                    board_selected=item
                    board_scroll=0
                    board_content_h=0
                    menu.set_selected(item._idx)
                end
            end
        end
    else
        local tx=main_x+5
        draw.rect(tx,tabs_y+5,tx+112,tabs_y+31,ac[1],ac[2],ac[3],255,5)
        text.draw_centered(font.tiny,tx,tabs_y+13,tx+112,255,255,255,255,"OVERVIEW")
    end

    local cards_top=tabs_y+52
    local cards_bottom=y+total_h-footer_h-12
    menu.set_content_rect(main_x,cards_top,main_w,cards_bottom-cards_top)
    if hit(main_x,cards_top,main_x+main_w,cards_bottom) then
        local wheel=input.mouse_wheel()
        if wheel~=0 then board_scroll=board_scroll-wheel*54 end
    end
    local max_scroll=math.max(0,board_content_h-(cards_bottom-cards_top))
    board_scroll=clamp(board_scroll,0,max_scroll)
    board_content_h=draw_flat_module_board(main_x,main_w,cards_top,cards_bottom,opacity,ac,current,menu_items,sel)
    max_scroll=math.max(0,board_content_h-(cards_bottom-cards_top))
    board_scroll=clamp(board_scroll,0,max_scroll)
    if max_scroll>0 then
        local track_x=main_x+main_w-3
        local view_h=cards_bottom-cards_top
        local thumb_h=math.max(36,view_h*(view_h/board_content_h))
        local thumb_y=cards_top+(view_h-thumb_h)*(board_scroll/max_scroll)
        draw.rect(track_x,cards_top,track_x+2,cards_bottom,31,31,31,180,1)
        draw.rect(track_x,thumb_y,track_x+2,thumb_y+thumb_h,ac[1],ac[2],ac[3],230,1)
    end

    local fy=y+total_h-footer_h
    draw.rect(x,fy,x+width,y+total_h,8,8,8,opacity)
    draw.rect(x,fy,x+width,fy+1,25,25,25,255)
    text.draw(font.tiny,x+14,fy+10,C.muted[1],C.muted[2],C.muted[3],255,"ESC  RETURN TO DASHBOARD")
    local hints="LEFT CLICK  ACTIVATE    CLICK + DRAG  SLIDERS    MOUSE WHEEL  SCROLL"
    text.draw(font.tiny,x+width-18-text.width(font.tiny,hints),fy+10,C.muted[1],C.muted[2],C.muted[3],255,hints)

    draw_color_popup(main_x+main_w,body_y+96,ac)
    process_edit()
    menu.set_text_editing(edit_on)

    local sig=serialize_settings()
    if sig~=last_settings then last_settings=sig;save_pending=true;save_at=ctx.time() end
    if save_pending and ctx.time()-save_at>0.4 then file.write(SETTINGS_FILE,last_settings);save_pending=false end
end

function handle_input()
    -- Susano Panel is intentionally mouse-only. The menu visibility key is handled by the host.
end
