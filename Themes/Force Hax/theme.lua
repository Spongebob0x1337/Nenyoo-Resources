-- Force Hax
-- Centered classic GTA Force Hax-inspired menu.

text.set_font_family("Bahnschrift")
local TITLE_FONT_FILE="Themes\\Force Hax\\fonts\\force-title-anton.ttf"
local TITLE_FONT_REL="Themes/Force Hax/fonts/force-title-anton.ttf"
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
        net.get("raw.githubusercontent.com","/google/fonts/main/ofl/anton/Anton-Regular.ttf",function(body)
            if valid_font_data(body) then title_font_downloaded=file.write(TITLE_FONT_FILE,body) end
        end,function() end)
    end
end
text.set_size(font.title,50)
text.set_weight(font.title,900)
text.set_size(font.breadcrumb,19)
text.set_weight(font.breadcrumb,700)
text.set_size(font.item,18)
text.set_weight(font.item,600)
text.set_size(font.value,15)
text.set_weight(font.value,700)
text.set_size(font.desc,18)
text.set_weight(font.desc,800)
text.set_size(font.small,13)
text.set_size(font.tiny,11)

local SETTINGS_FILE="force_hax_v2.ini"
menu.clear_settings()
menu.add_setting_color("Force Hax Blue",24,151,204,255,"Logo subtitle and submenu color")
menu.add_setting_color("Force Hax Green",64,181,72,255,"Page title and enabled color")
menu.add_setting_slider("Force Hax Width",500,380,680,10,"Menu width")
menu.add_setting_slider("Force Hax Rows",15,9,18,1,"Visible option rows")
menu.add_setting_slider("Force Hax Opacity",84,55,100,1,"Panel opacity")
menu.add_setting_slider("Force Hax Row Height",52,42,64,1,"Option spacing")
menu.add_setting_action("Reset Theme","Reset Force Hax settings")

local function setting(name) return menu.get_setting(name) end
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
local CYCLIC={
    [item_type.array_option]=true,[item_type.loop_option]=true,
    [item_type.array_toggle]=true,[item_type.loop_toggle]=true
}
local NUMERIC={
    [item_type.slider]=true,[item_type.int_option]=true,
    [item_type.float_toggle]=true,[item_type.int_toggle]=true
}

local function load_settings()
    local body=file.read(SETTINGS_FILE)
    if not body then return end
    for line in body:gmatch("[^\r\n]+") do
        local key,value=line:match("^(.-)=(.*)$")
        if key=="blue" or key=="green" then
            local r,g,b,a=value:match("(%d+),(%d+),(%d+),(%d+)")
            if r then menu.set_setting(key=="blue" and "Force Hax Blue" or "Force Hax Green",tonumber(r),tonumber(g),tonumber(b),tonumber(a)) end
        elseif key=="width" then menu.set_setting("Force Hax Width",tonumber(value) or 500)
        elseif key=="rows" then menu.set_setting("Force Hax Rows",tonumber(value) or 15)
        elseif key=="opacity" then menu.set_setting("Force Hax Opacity",tonumber(value) or 84)
        elseif key=="row_height" then menu.set_setting("Force Hax Row Height",tonumber(value) or 52) end
    end
end

local function serialize()
    local blue=setting("Force Hax Blue") or {r=24,g=151,b=204,a=255}
    local green=setting("Force Hax Green") or {r=64,g=181,b=72,a=255}
    local width=setting("Force Hax Width") or {f_val=500}
    local rows=setting("Force Hax Rows") or {f_val=15}
    local opacity=setting("Force Hax Opacity") or {f_val=84}
    local row_height=setting("Force Hax Row Height") or {f_val=52}
    return table.concat({
        "blue="..blue.r..","..blue.g..","..blue.b..","..blue.a,
        "green="..green.r..","..green.g..","..green.b..","..green.a,
        "width="..width.f_val,"rows="..rows.f_val,
        "opacity="..opacity.f_val,"row_height="..row_height.f_val
    },"\n")
end

local function reset_settings()
    menu.set_setting("Force Hax Blue",24,151,204,255)
    menu.set_setting("Force Hax Green",64,181,72,255)
    menu.set_setting("Force Hax Width",500)
    menu.set_setting("Force Hax Rows",15)
    menu.set_setting("Force Hax Opacity",84)
    menu.set_setting("Force Hax Row Height",52)
    file.remove(SETTINGS_FILE)
end

load_settings()
local last_settings=serialize()
local save_pending=false
local save_at=0
local edit_on=false
local edit_idx=-1
local edit_type=0
local edit_buf=""
local edit_frame=-1

local function mouse_hit(x1,y1,x2,y2)
    local mx,my=input.mouse_x(),input.mouse_y()
    return mx>=x1 and mx<x2 and my>=y1 and my<y2
end

local function item_value(item)
    if CYCLIC[item.type] then return item.current_value or "" end
    if item.type==item_type.input_text or item.type==item_type.search then return item.text and item.text~="" and item.text or "..." end
    if item.type==item_type.input_int or item.type==item_type.int_option or item.type==item_type.int_toggle then return tostring(item.i_val or 0) end
    if item.type==item_type.input_float or item.type==item_type.slider or item.type==item_type.float_toggle then
        return string.format((item.f_step or 1)<1 and "%.1f" or "%.0f",item.f_val or 0)
    end
    return ""
end

local function adjust(item,dir)
    if not item then return false end
    local idx=item._idx
    if CYCLIC[item.type] and (item.value_count or 0)>0 then
        local value=((item.value_index or 0)+dir)%item.value_count
        if value<0 then value=value+item.value_count end
        menu.set_value_index(idx,value);return true
    elseif item.type==item_type.int_option or item.type==item_type.int_toggle then
        local step=(item.i_step or 0)~=0 and item.i_step or 1
        menu.set_i_val(idx,clamp((item.i_val or 0)+dir*step,item.i_min or -2147483648,item.i_max or 2147483647));return true
    elseif item.type==item_type.slider or item.type==item_type.float_toggle then
        local step=(item.f_step or 0)~=0 and item.f_step or 0.1
        menu.set_f_val(idx,clamp((item.f_val or 0)+dir*step,item.f_min or -1000000,item.f_max or 1000000));return true
    end
    return false
end

local function activate(item)
    if not item then return end
    if item.name=="Reset Theme" and item.type==item_type.action then reset_settings();notify.push("Theme","Force Hax reset",1);return end
    if item.type==item_type.array_toggle or item.type==item_type.loop_toggle then menu.activate()
    elseif CYCLIC[item.type] then adjust(item,1)
    elseif item.type==item_type.input_text or item.type==item_type.input_int or item.type==item_type.input_float
        or item.type==item_type.search or item.type==item_type.slider or item.type==item_type.int_option then
        edit_on=true;edit_idx=item._idx;edit_type=item.type;edit_frame=ctx.frame()
        if item.type==item_type.input_int or item.type==item_type.int_option then edit_buf=tostring(item.i_val or 0)
        elseif item.type==item_type.input_float or item.type==item_type.slider then edit_buf=string.format("%.2f",item.f_val or 0)
        else edit_buf=item.text or "" end
    else menu.activate() end
end

local function process_edit()
    if not edit_on then return end
    local chars=input.get_chars()
    if chars~="" then
        for ch in chars:gmatch(".") do
            local byte=string.byte(ch)
            if edit_type==item_type.input_text or edit_type==item_type.search then
                if #edit_buf<63 then edit_buf=edit_buf..ch end
            elseif (byte>=48 and byte<=57) or (byte==45 and #edit_buf==0)
                or (byte==46 and (edit_type==item_type.input_float or edit_type==item_type.slider) and not edit_buf:find("%.")) then edit_buf=edit_buf..ch end
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

function draw_menu()
    if title_font_downloaded then apply_title_font();title_font_downloaded=false end
    local blue=setting("Force Hax Blue") or {r=24,g=151,b=204,a=255}
    local green=setting("Force Hax Green") or {r=64,g=181,b=72,a=255}
    theme.set_body_bg(12,13,14,220)
    theme.set_menu_bg(12,13,14,220)
    theme.set_accent_palette(blue.r,blue.g,blue.b,blue.a)
    if not menu.is_visible() then menu.set_text_editing(false);return end

    local width_setting=setting("Force Hax Width")
    local rows_setting=setting("Force Hax Rows")
    local opacity_setting=setting("Force Hax Opacity")
    local row_setting=setting("Force Hax Row Height")
    local width=clamp(width_setting and width_setting.f_val or 500,360,ctx.screen_w()-20)
    local rows=math.floor(rows_setting and rows_setting.f_val or 15)
    local alpha=math.floor(255*clamp((opacity_setting and opacity_setting.f_val or 84)/100,0.55,1))
    local row_h=clamp(row_setting and row_setting.f_val or 52,42,64)
    local logo_h=122
    local page_h=0
    local footer_h=56
    local count=menu.item_count()
    local sel=menu.selected_index()
    local start=math.floor(sel/rows)*rows
    local visible=math.min(rows,math.max(0,count-start))
    local total_h=logo_h+page_h+visible*row_h+footer_h
    local y=math.floor(ctx.screen_h()*0.045)
    if total_h>ctx.screen_h()-y-12 then
        row_h=math.max(38,(ctx.screen_h()-y-12-logo_h-page_h-footer_h)/math.max(1,visible))
        total_h=logo_h+page_h+visible*row_h+footer_h
    end
    local x=math.floor((ctx.screen_w()-width)*0.5)
    menu.set_content_rect(x,y+logo_h+page_h,width,visible*row_h)

    draw.rect(x,y,x+width,y+total_h,11,12,13,alpha)
    draw.rect(x,y,x+width,y+logo_h,13,14,15,242)
    local logo="gta force hax"
    text.draw_outlined(font.title,x+(width-text.width(font.title,logo))*0.5,y+17,
        252,252,252,255,0,0,0,235,1.2,logo)
    text.draw_centered(font.desc,x,y+88,x+width,blue.r,blue.g,blue.b,255,"ONLINE VEHICLE SPAWNER")
    for row=0,visible-1 do
        local idx=start+row
        local yy=y+logo_h+page_h+row*row_h
        if idx<count then
            local item=menu.get_item(idx)
            if item then
                item._idx=idx
                local active=idx==sel
                local hovered=mouse_hit(x,yy,x+width,yy+row_h)
                if hovered and not active then draw.rect(x,yy,x+width,yy+row_h,255,255,255,18) end
                if active then draw.rect(x,yy,x+width,yy+row_h,213,213,213,245) end
                if item.is_header then
                    text.draw_centered(font.small,x,yy+(row_h-text.height(font.small))*0.5,x+width,
                        active and 30 or blue.r,active and 30 or blue.g,active and 30 or blue.b,255,(item.name or ""):upper())
                else
                    local nr,ng,nb=232,232,232
                    if item.type==item_type.sub_menu then
                        local tone=idx%7
                        if tone==0 then nr,ng,nb=212,175,65
                        elseif tone==1 or tone==2 then nr,ng,nb=blue.r,blue.g,blue.b end
                    end
                    if active then nr,ng,nb=32,32,32 end
                    local name=item.name or ""
                    text.draw_centered(font.item,x+28,yy+(row_h-text.height(font.item))*0.5,x+width-28,nr,ng,nb,255,name)
                    if item.type==item_type.sub_menu then
                        local name_w=text.width(font.item,name)
                        text.draw(font.item,x+width*0.5+name_w*0.5+8,yy+(row_h-text.height(font.item))*0.5,
                            active and 35 or blue.r,active and 35 or blue.g,active and 35 or blue.b,255,">")
                    end
                    local value=""
                    local vr,vg,vb=225,225,225
                    if item.type==item_type.toggle then value=item.on and "ON" or "OFF";if item.on then vr,vg,vb=63,210,69 else vr,vg,vb=211,61,68 end
                    elseif item.type==item_type.float_toggle or item.type==item_type.int_toggle
                        or item.type==item_type.array_toggle or item.type==item_type.loop_toggle then
                        value=item.on and "ON" or "OFF";if item.on then vr,vg,vb=63,210,69 else vr,vg,vb=211,61,68 end
                    elseif NUMERIC[item.type] or CYCLIC[item.type] or item.type==item_type.input_text
                        or item.type==item_type.input_int or item.type==item_type.input_float or item.type==item_type.search then value=item_value(item) end
                    if edit_on and edit_idx==idx then value=edit_buf..((math.floor(ctx.time()*2)%2==0) and "|" or "") end
                    if value~="" then
                        if active then vr,vg,vb=45,45,45 end
                        text.draw(font.value,x+width-18-text.width(font.value,value),yy+(row_h-text.height(font.value))*0.5,vr,vg,vb,255,value)
                    end
                end
                if hovered and input.mouse_clicked(0) and not menu.overlay_active() then menu.set_selected(idx);activate(item) end
                if hovered and input.mouse_clicked(1) then menu.set_selected(idx);adjust(item,-1) end
            end
        end
    end

    local fy=y+total_h-footer_h
    draw.rect(x,fy,x+width,fy+2,235,235,235,230)
    local arrow_x=x+width*0.5
    draw.line(arrow_x-10,fy+20,arrow_x,fy+10,245,245,245,255,3)
    draw.line(arrow_x,fy+10,arrow_x+10,fy+20,245,245,245,255,3)
    draw.line(arrow_x-10,fy+34,arrow_x,fy+44,245,245,245,255,3)
    draw.line(arrow_x,fy+44,arrow_x+10,fy+34,245,245,245,255,3)
    local counter=count>0 and tostring(sel+1).." / "..tostring(count) or "0 / 0"
    text.draw(font.item,x+width-28-text.width(font.item,counter),fy+(footer_h-text.height(font.item))*0.5,238,238,238,255,counter)
    process_edit()
    menu.set_text_editing(edit_on)
    local signature=serialize()
    if signature~=last_settings then last_settings=signature;save_pending=true;save_at=ctx.time() end
    if save_pending and ctx.time()-save_at>0.4 then file.write(SETTINGS_FILE,last_settings);save_pending=false end
end

function handle_input()
    if not menu.is_visible() or edit_on then return end
    if input.key_pressed(VK.DOWN) then menu.move_selection(1) end
    if input.key_pressed(VK.UP) then menu.move_selection(-1) end
    local item=menu.get_item(menu.selected_index())
    if item then item._idx=menu.selected_index() end
    if input.key_pressed(VK.RIGHT) and item and adjust(item,1) then
    elseif input.key_just_pressed(VK.RIGHT) and item then activate(item) end
    if input.key_pressed(VK.LEFT) and item and adjust(item,-1) then
    elseif input.key_just_pressed(VK.LEFT) then menu.go_back() end
    if input.key_just_pressed(VK.RETURN) and item then activate(item) end
    if input.key_just_pressed(VK.BACK) or input.key_just_pressed(VK.ESCAPE) then menu.go_back() end
end
