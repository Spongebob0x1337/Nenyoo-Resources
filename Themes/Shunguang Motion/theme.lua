-- Shunguang Motion
-- Animated cinematic theme.

text.set_font_family("Bahnschrift")
local ICON_FONT_FILE="Themes\\Shunguang Motion\\fonts\\fa-solid-900.ttf"
local ICON_FONT_REL="Themes/Shunguang Motion/fonts/fa-solid-900.ttf"
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
text.set_size(font.title,22)
text.set_weight(font.title,900)
text.set_size(font.breadcrumb,12)
text.set_weight(font.breadcrumb,800)
text.set_size(font.item,14)
text.set_weight(font.item,600)
text.set_size(font.value,12)
text.set_weight(font.value,700)
text.set_size(font.small,10)
text.set_size(font.tiny,9)
text.set_size(font.label,12)

local HEADER_FILE="Themes\\Shunguang Motion\\textures\\shunguang_header.gif"
local HEADER_REL="Themes/Shunguang Motion/textures/shunguang_header.gif"
local HEADER_IMAGE=0
local header_downloaded=false

local function has_header_gif()
    local data=file.read(HEADER_FILE)
    return data and #data>=6 and data:sub(1,3)=="GIF"
end

if has_header_gif() then
    HEADER_IMAGE=draw.load_image(HEADER_REL)
elseif net and net.get then
    net.get(
        "preview.redd.it",
        "/who-else-is-skipping-the-2-4-banners-for-ye-shunguang-v0-e4r48hc48a3g1.gif?width=374&auto=webp&s=905feee29efbe4c98ff671e94a0adb9e369ad4ae",
        function(data)
            if data and #data>=6 and data:sub(1,3)=="GIF" then
                header_downloaded=file.write(HEADER_FILE,data)
            end
        end,
        function() end
    )
end
local SETTINGS_FILE="shunguang_motion.ini"
menu.clear_settings()
menu.add_setting_color("Motion Crimson",190,49,67,255,"Selected option and detail color")
menu.add_setting_color("Motion Gold",238,184,92,255,"Values and highlight color")
menu.add_setting_slider("Motion Width",430,340,600,10,"Menu width")
menu.add_setting_slider("Motion Rows",10,7,15,1,"Visible options")
menu.add_setting_slider("Motion Opacity",92,55,100,1,"Body opacity")
menu.add_setting_toggle("Motion Icons",true,"Show option type icons")
menu.add_setting_action("Reset Theme","Reset Shunguang Motion settings")

local function setting(name) return menu.get_setting(name) end
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
local function fa(cp)
    if cp<0x80 then return string.char(cp) end
    if cp<0x800 then return string.char(0xC0+math.floor(cp/0x40),0x80+cp%0x40) end
    if cp<0x10000 then return string.char(0xE0+math.floor(cp/0x1000),0x80+(math.floor(cp/0x40)%0x40),0x80+cp%0x40) end
    return string.char(0xF0+math.floor(cp/0x40000),0x80+(math.floor(cp/0x1000)%0x40),0x80+(math.floor(cp/0x40)%0x40),0x80+cp%0x40)
end

local ICON={folder=fa(0xF054),toggle=fa(0xF111),action=fa(0xF0E7),choice=fa(0xF021),slider=fa(0xF1DE),color=fa(0xF53F),check=fa(0xF00C)}
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
        if key=="crimson" or key=="gold" then
            local r,g,b,a=value:match("(%d+),(%d+),(%d+),(%d+)")
            if r then menu.set_setting(key=="crimson" and "Motion Crimson" or "Motion Gold",tonumber(r),tonumber(g),tonumber(b),tonumber(a)) end
        elseif key=="width" then menu.set_setting("Motion Width",tonumber(value) or 430)
        elseif key=="rows" then menu.set_setting("Motion Rows",tonumber(value) or 10)
        elseif key=="opacity" then menu.set_setting("Motion Opacity",tonumber(value) or 92)
        elseif key=="icons" then menu.set_setting("Motion Icons",value=="1") end
    end
end

local function serialize()
    local crimson=setting("Motion Crimson") or {r=190,g=49,b=67,a=255}
    local gold=setting("Motion Gold") or {r=238,g=184,b=92,a=255}
    local width=setting("Motion Width") or {f_val=430}
    local rows=setting("Motion Rows") or {f_val=10}
    local opacity=setting("Motion Opacity") or {f_val=92}
    local icons=setting("Motion Icons") or {on=true}
    return table.concat({
        "crimson="..crimson.r..","..crimson.g..","..crimson.b..","..crimson.a,
        "gold="..gold.r..","..gold.g..","..gold.b..","..gold.a,
        "width="..width.f_val,"rows="..rows.f_val,"opacity="..opacity.f_val,"icons="..(icons.on and "1" or "0")
    },"\n")
end

local function reset_settings()
    menu.set_setting("Motion Crimson",190,49,67,255)
    menu.set_setting("Motion Gold",238,184,92,255)
    menu.set_setting("Motion Width",430)
    menu.set_setting("Motion Rows",10)
    menu.set_setting("Motion Opacity",92)
    menu.set_setting("Motion Icons",true)
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
    if item.name=="Reset Theme" and item.type==item_type.action then reset_settings();notify.push("Theme","Shunguang Motion reset",1);return end
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

local function option_icon(item)
    if item.type==item_type.sub_menu then return ICON.folder end
    if item.type==item_type.toggle or item.type==item_type.float_toggle or item.type==item_type.int_toggle
        or item.type==item_type.array_toggle or item.type==item_type.loop_toggle then return ICON.toggle end
    if item.type==item_type.selected_tick then return ICON.check end
    if item.type==item_type.color then return ICON.color end
    if NUMERIC[item.type] then return ICON.slider end
    if CYCLIC[item.type] then return ICON.choice end
    return ICON.action
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
    if icon_font_downloaded then apply_icon_font();icon_font_downloaded=false end
    if HEADER_IMAGE==0 and header_downloaded then
        HEADER_IMAGE=draw.load_image(HEADER_REL)
        header_downloaded=false
    end
    local crimson=setting("Motion Crimson") or {r=190,g=49,b=67,a=255}
    local gold=setting("Motion Gold") or {r=238,g=184,b=92,a=255}
    theme.set_body_bg(8,12,24,245)
    theme.set_menu_bg(8,12,24,245)
    theme.set_accent_palette(crimson.r,crimson.g,crimson.b,crimson.a)
    if not menu.is_visible() then menu.set_text_editing(false);return end

    local width_setting=setting("Motion Width")
    local rows_setting=setting("Motion Rows")
    local opacity_setting=setting("Motion Opacity")
    local icons_setting=setting("Motion Icons")
    local width=clamp(width_setting and width_setting.f_val or 430,320,ctx.screen_w()-20)
    local rows=math.floor(rows_setting and rows_setting.f_val or 10)
    local alpha=math.floor(255*clamp((opacity_setting and opacity_setting.f_val or 92)/100,0.55,1))
    local show_icons=not icons_setting or icons_setting.on
    local header_h=width*0.5
    local row_h=39
    local footer_h=34
    local total_h=header_h+rows*row_h+footer_h
    local x=math.floor(ctx.screen_w()*0.075)
    local y=math.floor((ctx.screen_h()-total_h)*0.5)
    local ox,oy=menu.drag_header(x,y,width,header_h)
    x=x+ox;y=y+oy
    menu.set_content_rect(x,y+header_h,width,rows*row_h)

    draw.rect(x+7,y+8,x+width+7,y+total_h+8,0,0,0,105,8)
    draw.rect(x,y,x+width,y+total_h,7,11,24,alpha,7)
    if HEADER_IMAGE and HEADER_IMAGE>=0 then draw.image(HEADER_IMAGE,x,y,x+width,y+header_h) end
    draw.rect_gradient(x,y+header_h-76,x+width,y+header_h,
        7,11,24,0,7,11,24,0,7,11,24,245,7,11,24,245)
    draw.rect(x,y+header_h-3,x+width,y+header_h,crimson.r,crimson.g,crimson.b,235)
    text.draw(font.tiny,x+14,y+header_h-53,238,238,244,235,"NENYOO  //  MOTION")
    text.draw(font.title,x+14,y+header_h-38,255,248,244,255,"SHUNGUANG")
    local page=(menu.page_name() or "HOME"):upper()
    text.draw(font.breadcrumb,x+width-14-text.width(font.breadcrumb,page),y+header_h-31,gold.r,gold.g,gold.b,255,page)

    local count=menu.item_count()
    local sel=menu.selected_index()
    local start=math.floor(sel/rows)*rows
    for row=0,rows-1 do
        local idx=start+row
        local yy=y+header_h+row*row_h
        if idx<count then
            local item=menu.get_item(idx)
            if item then
                item._idx=idx
                local active=idx==sel
                local hovered=mouse_hit(x,yy,x+width,yy+row_h)
                if active then
                    draw.rect_gradient(x,yy,x+width,yy+row_h,crimson.r,crimson.g,crimson.b,220,crimson.r,crimson.g,crimson.b,70,crimson.r,crimson.g,crimson.b,70,crimson.r,crimson.g,crimson.b,220)
                    draw.rect(x,yy,x+4,yy+row_h,gold.r,gold.g,gold.b,255)
                elseif hovered then draw.rect(x,yy,x+width,yy+row_h,255,255,255,14) end
                draw.rect(x+12,yy+row_h-1,x+width-12,yy+row_h,62,69,88,75)
                local tx=x+15
                if show_icons and not item.is_header then
                    text.draw_centered(font.label,x+12,yy+(row_h-text.height(font.label))*0.5,x+35,
                        active and 255 or 133,active and 239 or 144,active and 226 or 164,255,option_icon(item))
                    tx=x+42
                end
                if item.is_header then
                    text.draw(font.small,x+14,yy+(row_h-text.height(font.small))*0.5,gold.r,gold.g,gold.b,255,(item.name or ""):upper())
                else
                    text.draw_ellipsis(font.item,tx,yy+(row_h-text.height(font.item))*0.5,
                        active and 255 or 226,active and 247 or 229,active and 243 or 239,255,item.name or "",width*0.62)
                    local value=""
                    local vr,vg,vb=gold.r,gold.g,gold.b
                    if item.type==item_type.toggle then value=item.on and "ON" or "OFF";if not item.on then vr,vg,vb=139,148,166 end
                    elseif item.type==item_type.float_toggle or item.type==item_type.int_toggle
                        or item.type==item_type.array_toggle or item.type==item_type.loop_toggle then
                        value=(item.on and "ON  " or "OFF  ")..item_value(item);if not item.on then vr,vg,vb=139,148,166 end
                    elseif NUMERIC[item.type] or CYCLIC[item.type] or item.type==item_type.input_text
                        or item.type==item_type.input_int or item.type==item_type.input_float or item.type==item_type.search then value=item_value(item) end
                    if edit_on and edit_idx==idx then value=edit_buf..((math.floor(ctx.time()*2)%2==0) and "|" or "") end
                    if value~="" then text.draw(font.value,x+width-15-text.width(font.value,value),yy+(row_h-text.height(font.value))*0.5,vr,vg,vb,255,value) end
                end
                if hovered and input.mouse_clicked(0) and not menu.overlay_active() then menu.set_selected(idx);activate(item) end
                if hovered and input.mouse_clicked(1) then menu.set_selected(idx);adjust(item,-1) end
            end
        end
    end

    local fy=y+header_h+rows*row_h
    draw.rect(x,fy,x+width,fy+footer_h,5,9,19,alpha)
    draw.rect(x,fy,x+width,fy+1,crimson.r,crimson.g,crimson.b,130)
    local counter=count>0 and tostring(sel+1).." / "..tostring(count) or "0 / 0"
    text.draw(font.small,x+14,fy+(footer_h-text.height(font.small))*0.5,133,144,164,255,"ENTER SELECT    BACKSPACE BACK")
    text.draw(font.value,x+width-14-text.width(font.value,counter),fy+(footer_h-text.height(font.value))*0.5,gold.r,gold.g,gold.b,255,counter)
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
