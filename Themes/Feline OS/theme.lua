-- Feline OS
-- Animated split-panel cat theme.

text.set_font_family("Bahnschrift")
local ICON_FONT_FILE="Themes\\Feline OS\\fonts\\fa-solid-900.ttf"
local ICON_FONT_REL="Themes/Feline OS/fonts/fa-solid-900.ttf"
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
text.set_size(font.title,26)
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

local HEADER_FILE="Themes\\Feline OS\\textures\\cat_glasses.gif"
local HEADER_REL="Themes/Feline OS/textures/cat_glasses.gif"
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
        "media0.giphy.com",
        "/media/v1.Y2lkPTc5MGI3NjExamIzYTlydzIxendkbHh6NGc2MDNsYmlrenZ3bTJtYnk3aGFweDdqaCZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/KbdF8DCgaoIVC8BHTK/giphy.gif",
        function(data)
            if data and #data>=6 and data:sub(1,3)=="GIF" then
                header_downloaded=file.write(HEADER_FILE,data)
            end
        end,
        function() end
    )
end
local SETTINGS_FILE="feline_os.ini"
menu.clear_settings()
menu.add_setting_color("Cat Pink",232,151,170,255,"Selected option and detail color")
menu.add_setting_color("Cat Cream",242,233,217,255,"Text and value color")
menu.add_setting_slider("Cat Console Width",400,320,560,10,"Width of the control console")
menu.add_setting_slider("Cat Rows",8,6,12,1,"Visible options")
menu.add_setting_slider("Cat Opacity",96,60,100,1,"Console opacity")
menu.add_setting_toggle("Cat Paws",true,"Show paw and option icons")
menu.add_setting_action("Reset Theme","Reset Feline OS settings")

local function setting(name) return menu.get_setting(name) end
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
local function fa(cp)
    if cp<0x80 then return string.char(cp) end
    if cp<0x800 then return string.char(0xC0+math.floor(cp/0x40),0x80+cp%0x40) end
    if cp<0x10000 then return string.char(0xE0+math.floor(cp/0x1000),0x80+(math.floor(cp/0x40)%0x40),0x80+cp%0x40) end
    return string.char(0xF0+math.floor(cp/0x40000),0x80+(math.floor(cp/0x1000)%0x40),0x80+(math.floor(cp/0x40)%0x40),0x80+cp%0x40)
end

local ICON={paw=fa(0xF1B0),folder=fa(0xF054),toggle=fa(0xF111),action=fa(0xF0E7),choice=fa(0xF021),slider=fa(0xF1DE),color=fa(0xF53F),check=fa(0xF00C)}
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
        if key=="pink" or key=="cream" then
            local r,g,b,a=value:match("(%d+),(%d+),(%d+),(%d+)")
            if r then menu.set_setting(key=="pink" and "Cat Pink" or "Cat Cream",tonumber(r),tonumber(g),tonumber(b),tonumber(a)) end
        elseif key=="width" then menu.set_setting("Cat Console Width",tonumber(value) or 400)
        elseif key=="rows" then menu.set_setting("Cat Rows",tonumber(value) or 8)
        elseif key=="opacity" then menu.set_setting("Cat Opacity",tonumber(value) or 96)
        elseif key=="icons" then menu.set_setting("Cat Paws",value=="1") end
    end
end

local function serialize()
    local pink=setting("Cat Pink") or {r=232,g=151,b=170,a=255}
    local cream=setting("Cat Cream") or {r=242,g=233,b=217,a=255}
    local width=setting("Cat Console Width") or {f_val=400}
    local rows=setting("Cat Rows") or {f_val=8}
    local opacity=setting("Cat Opacity") or {f_val=96}
    local icons=setting("Cat Paws") or {on=true}
    return table.concat({
        "pink="..pink.r..","..pink.g..","..pink.b..","..pink.a,
        "cream="..cream.r..","..cream.g..","..cream.b..","..cream.a,
        "width="..width.f_val,"rows="..rows.f_val,"opacity="..opacity.f_val,"icons="..(icons.on and "1" or "0")
    },"\n")
end

local function reset_settings()
    menu.set_setting("Cat Pink",232,151,170,255)
    menu.set_setting("Cat Cream",242,233,217,255)
    menu.set_setting("Cat Console Width",400)
    menu.set_setting("Cat Rows",8)
    menu.set_setting("Cat Opacity",96)
    menu.set_setting("Cat Paws",true)
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
    if item.name=="Reset Theme" and item.type==item_type.action then reset_settings();notify.push("Theme","Feline OS reset",1);return end
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
    local pink=setting("Cat Pink") or {r=232,g=151,b=170,a=255}
    local cream=setting("Cat Cream") or {r=242,g=233,b=217,a=255}
    theme.set_body_bg(15,14,14,250)
    theme.set_menu_bg(15,14,14,250)
    theme.set_accent_palette(pink.r,pink.g,pink.b,pink.a)
    if not menu.is_visible() then menu.set_text_editing(false);return end

    local width_setting=setting("Cat Console Width")
    local rows_setting=setting("Cat Rows")
    local opacity_setting=setting("Cat Opacity")
    local icons_setting=setting("Cat Paws")
    local console_w=clamp(width_setting and width_setting.f_val or 400,300,ctx.screen_w()-20)
    local rows=math.floor(rows_setting and rows_setting.f_val or 8)
    local alpha=math.floor(255*clamp((opacity_setting and opacity_setting.f_val or 96)/100,0.6,1))
    local show_icons=not icons_setting or icons_setting.on
    local header_h=88
    local row_h=45
    local footer_h=40
    local total_h=header_h+rows*row_h+footer_h
    local art_w=total_h
    local total_w=art_w+console_w
    local x=math.floor((ctx.screen_w()-total_w)*0.5)
    local y=math.floor((ctx.screen_h()-total_h)*0.5)
    local console_x=x+art_w
    local ox,oy=menu.drag_header(console_x,y,console_w,header_h)
    x=x+ox;y=y+oy;console_x=x+art_w
    menu.set_content_rect(console_x,y+header_h,console_w,rows*row_h)

    draw.rect(x+9,y+10,x+total_w+9,y+total_h+10,0,0,0,105,10)
    draw.rect(x,y,x+total_w,y+total_h,18,17,17,alpha,9)
    if HEADER_IMAGE and HEADER_IMAGE>=0 then draw.image(HEADER_IMAGE,x,y,x+art_w,y+total_h) end
    draw.rect_gradient(x+art_w-72,y,x+art_w,y+total_h,
        18,17,17,0,18,17,17,235,18,17,17,235,18,17,17,0)
    draw.rect(console_x,y,console_x+console_w,y+header_h,cream.r,cream.g,cream.b,255,0)
    draw.rect(console_x,y,console_x+5,y+header_h,pink.r,pink.g,pink.b,255)
    text.draw(font.tiny,console_x+18,y+13,104,96,94,255,"NENYOO LABS  //  FELINE SYSTEM")
    text.draw(font.title,console_x+18,y+31,30,28,28,255,"FELINE.OS")
    local page=(menu.page_name() or "HOME"):upper()
    text.draw(font.breadcrumb,console_x+console_w-18-text.width(font.breadcrumb,page),y+50,pink.r,pink.g,pink.b,255,page)
    draw.circle(x+23,y+23,7,225,67,72,255)
    text.draw(font.tiny,x+37,y+16,255,255,255,235,"LIVE CAT FEED")

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
                local hovered=mouse_hit(console_x,yy,console_x+console_w,yy+row_h)
                if active then
                    draw.rect(console_x,yy,console_x+console_w,yy+row_h,cream.r,cream.g,cream.b,245)
                    draw.rect(console_x,yy,console_x+5,yy+row_h,pink.r,pink.g,pink.b,255)
                elseif hovered then draw.rect(console_x,yy,console_x+console_w,yy+row_h,255,255,255,11) end
                draw.rect(console_x+14,yy+row_h-1,console_x+console_w-14,yy+row_h,65,60,59,95)
                local tx=console_x+17
                if show_icons and not item.is_header then
                    text.draw_centered(font.label,console_x+14,yy+(row_h-text.height(font.label))*0.5,console_x+39,
                        active and 40 or pink.r,active and 36 or pink.g,active and 35 or pink.b,255,item.type==item_type.sub_menu and ICON.paw or option_icon(item))
                    tx=console_x+46
                end
                if item.is_header then
                    text.draw(font.small,console_x+17,yy+(row_h-text.height(font.small))*0.5,pink.r,pink.g,pink.b,255,(item.name or ""):upper())
                else
                    text.draw_ellipsis(font.item,tx,yy+(row_h-text.height(font.item))*0.5,
                        active and 35 or cream.r,active and 32 or cream.g,active and 31 or cream.b,255,item.name or "",console_w*0.61)
                    local value=""
                    local vr,vg,vb=pink.r,pink.g,pink.b
                    if item.type==item_type.toggle then value=item.on and "YES" or "NO";if not item.on then vr,vg,vb=138,128,126 end
                    elseif item.type==item_type.float_toggle or item.type==item_type.int_toggle
                        or item.type==item_type.array_toggle or item.type==item_type.loop_toggle then
                        value=(item.on and "YES  " or "NO  ")..item_value(item);if not item.on then vr,vg,vb=138,128,126 end
                    elseif NUMERIC[item.type] or CYCLIC[item.type] or item.type==item_type.input_text
                        or item.type==item_type.input_int or item.type==item_type.input_float or item.type==item_type.search then value=item_value(item) end
                    if edit_on and edit_idx==idx then value=edit_buf..((math.floor(ctx.time()*2)%2==0) and "|" or "") end
                    if active then vr,vg,vb=50,45,43 end
                    if value~="" then text.draw(font.value,console_x+console_w-17-text.width(font.value,value),yy+(row_h-text.height(font.value))*0.5,vr,vg,vb,255,value) end
                end
                if hovered and input.mouse_clicked(0) and not menu.overlay_active() then menu.set_selected(idx);activate(item) end
                if hovered and input.mouse_clicked(1) then menu.set_selected(idx);adjust(item,-1) end
            end
        end
    end

    local fy=y+header_h+rows*row_h
    draw.rect(console_x,fy,console_x+console_w,fy+footer_h,11,10,10,alpha)
    draw.rect(console_x,fy,console_x+console_w,fy+2,pink.r,pink.g,pink.b,190)
    local counter=count>0 and tostring(sel+1).." / "..tostring(count) or "0 / 0"
    text.draw(font.small,console_x+17,fy+(footer_h-text.height(font.small))*0.5,164,153,150,255,"PAWS READY  //  ENTER SELECT")
    text.draw(font.value,console_x+console_w-17-text.width(font.value,counter),fy+(footer_h-text.height(font.value))*0.5,pink.r,pink.g,pink.b,255,counter)
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
