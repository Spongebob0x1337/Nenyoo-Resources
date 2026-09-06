-- Extortion
-- Compact old-school GTA loader theme.

text.set_font_family("Trebuchet MS")
local ICON_FONT_FILE="Themes\\Extortion\\fonts\\fa-solid-900.ttf"
local ICON_FONT_REL="Themes/Extortion/fonts/fa-solid-900.ttf"
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
text.set_size(font.title, 18)
text.set_weight(font.title, 800)
text.set_size(font.item, 14)
text.set_weight(font.item, 700)
text.set_size(font.value, 12)
text.set_weight(font.value, 600)
text.set_size(font.small, 9)
text.set_size(font.tiny, 8)
text.set_size(font.label, 15)

local SETTINGS_FILE="extortion_v2.ini"
menu.clear_settings()
menu.add_setting_color("Extortion Title",190,0,12,255,"Title and detail color")
menu.add_setting_color("Extortion Selected",25,120,60,255,"Selected option color")
menu.add_setting_slider("Extortion Width",265,210,390,5,"Menu width")
menu.add_setting_slider("Extortion Rows",14,7,20,1,"Visible options")
menu.add_setting_slider("Extortion Opacity",97,60,100,1,"Panel opacity")
menu.add_setting_toggle("Extortion Icons",true,"Show Font Awesome icons")
menu.add_setting_action("Reset Theme","Reset Extortion settings")

local function setting(name) return menu.get_setting(name) end
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
local function fa(cp)
    if cp<0x80 then return string.char(cp) end
    if cp<0x800 then return string.char(0xC0+math.floor(cp/0x40),0x80+cp%0x40) end
    if cp<0x10000 then return string.char(0xE0+math.floor(cp/0x1000),0x80+(math.floor(cp/0x40)%0x40),0x80+cp%0x40) end
    return string.char(0xF0+math.floor(cp/0x40000),0x80+(math.floor(cp/0x1000)%0x40),0x80+(math.floor(cp/0x40)%0x40),0x80+cp%0x40)
end

local ICON={
    Network=fa(0xF0C0),Self=fa(0xF007),Vehicle=fa(0xF1B9),Weapon=fa(0xF140),
    VFX=fa(0xF0D0),World=fa(0xF0AC),Misc=fa(0xF0C9),Teleport=fa(0xF3C5),
    Scripts=fa(0xF121),Spooner=fa(0xF1B2),Protections=fa(0xF3ED),Settings=fa(0xF013),
    About=fa(0xF128),folder=fa(0xF07B),toggle=fa(0xF111),action=fa(0xF0E7),
    choice=fa(0xF021),number=fa(0xF1DE),color=fa(0xF53F),check=fa(0xF00C)
}

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
        if key=="title" or key=="selected" then
            local r,g,b,a=value:match("(%d+),(%d+),(%d+),(%d+)")
            if r then menu.set_setting(key=="title" and "Extortion Title" or "Extortion Selected",tonumber(r),tonumber(g),tonumber(b),tonumber(a)) end
        elseif key=="width" then menu.set_setting("Extortion Width",tonumber(value) or 265)
        elseif key=="rows" then menu.set_setting("Extortion Rows",tonumber(value) or 14)
        elseif key=="opacity" then menu.set_setting("Extortion Opacity",tonumber(value) or 97)
        elseif key=="icons" then menu.set_setting("Extortion Icons",value=="1") end
    end
end

local function serialize()
    local t=setting("Extortion Title") or {r=190,g=0,b=12,a=255}
    local s=setting("Extortion Selected") or {r=25,g=120,b=60,a=255}
    local w=setting("Extortion Width") or {f_val=265}
    local r=setting("Extortion Rows") or {f_val=14}
    local o=setting("Extortion Opacity") or {f_val=97}
    local i=setting("Extortion Icons") or {on=true}
    return table.concat({
        "title="..t.r..","..t.g..","..t.b..","..t.a,
        "selected="..s.r..","..s.g..","..s.b..","..s.a,
        "width="..w.f_val,"rows="..r.f_val,"opacity="..o.f_val,"icons="..(i.on and "1" or "0")
    },"\n")
end

local function reset_settings()
    menu.set_setting("Extortion Title",190,0,12,255)
    menu.set_setting("Extortion Selected",25,120,60,255)
    menu.set_setting("Extortion Width",265)
    menu.set_setting("Extortion Rows",14)
    menu.set_setting("Extortion Opacity",97)
    menu.set_setting("Extortion Icons",true)
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
    if item.type==item_type.input_text or item.type==item_type.search then return item.text~="" and item.text or "..." end
    if item.type==item_type.input_int or item.type==item_type.int_option or item.type==item_type.int_toggle then return tostring(item.i_val or 0) end
    if item.type==item_type.input_float or item.type==item_type.slider or item.type==item_type.float_toggle then
        return string.format((item.f_step or 1)<1 and "%.1f" or "%.0f",item.f_val or 0)
    end
    return ""
end

local function adjust(item,dir)
    local idx=item._idx
    if CYCLIC[item.type] and (item.value_count or 0)>0 then
        local value=((item.value_index or 0)+dir)%item.value_count
        if value<0 then value=value+item.value_count end
        menu.set_value_index(idx,value)
        return true
    elseif item.type==item_type.int_option or item.type==item_type.int_toggle then
        local step=(item.i_step or 0)~=0 and item.i_step or 1
        menu.set_i_val(idx,clamp((item.i_val or 0)+dir*step,item.i_min or -2147483648,item.i_max or 2147483647))
        return true
    elseif item.type==item_type.slider or item.type==item_type.float_toggle then
        local step=(item.f_step or 0)~=0 and item.f_step or 0.1
        menu.set_f_val(idx,clamp((item.f_val or 0)+dir*step,item.f_min or -1000000,item.f_max or 1000000))
        return true
    end
    return false
end

local function activate(item)
    if item.name=="Reset Theme" and item.type==item_type.action then
        reset_settings()
        notify.push("Theme","Extortion reset",1)
        return
    end
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
    if ICON[item.name] then return ICON[item.name] end
    if item.type==item_type.sub_menu then return ICON.folder end
    if item.type==item_type.toggle or item.type==item_type.float_toggle or item.type==item_type.int_toggle
        or item.type==item_type.array_toggle or item.type==item_type.loop_toggle then return ICON.toggle end
    if item.type==item_type.action then return ICON.action end
    if item.type==item_type.selected_tick then return ICON.check end
    if item.type==item_type.color then return ICON.color end
    if NUMERIC[item.type] then return ICON.number end
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
                or (byte==46 and (edit_type==item_type.input_float or edit_type==item_type.slider) and not edit_buf:find("%.")) then
                edit_buf=edit_buf..ch
            end
        end
    end
    if input.key_just_pressed(VK.BACK) and #edit_buf>0 then edit_buf=edit_buf:sub(1,-2) end
    if input.key_just_pressed(VK.ESCAPE) then edit_on=false end
    if input.key_just_pressed(VK.RETURN) and ctx.frame()~=edit_frame then
        menu.set_selected(edit_idx)
        if edit_type==item_type.input_int or edit_type==item_type.int_option then
            local value=tonumber(edit_buf);if value then menu.set_i_val(edit_idx,math.floor(value)) end
        elseif edit_type==item_type.input_float or edit_type==item_type.slider then
            local value=tonumber(edit_buf);if value then menu.set_f_val(edit_idx,value) end
        else menu.set_input_buffer(edit_buf);menu.confirm_input() end
        edit_on=false
    end
end

function draw_menu()
    if icon_font_downloaded then apply_icon_font();icon_font_downloaded=false end
    local title=setting("Extortion Title") or {r=190,g=0,b=12,a=255}
    local selected=setting("Extortion Selected") or {r=25,g=120,b=60,a=255}
    theme.set_body_bg(0,0,0,255)
    theme.set_menu_bg(0,0,0,255)
    theme.set_accent_palette(title.r,title.g,title.b,title.a)
    if not menu.is_visible() then menu.set_text_editing(false);return end

    local width_setting=setting("Extortion Width")
    local row_setting=setting("Extortion Rows")
    local opacity_setting=setting("Extortion Opacity")
    local icon_setting=setting("Extortion Icons")
    local width=clamp(width_setting and width_setting.f_val or 265,210,ctx.screen_w()-20)
    local rows=math.floor(row_setting and row_setting.f_val or 14)
    local alpha=math.floor(255*clamp((opacity_setting and opacity_setting.f_val or 97)/100,0.6,1))
    local show_icons=not icon_setting or icon_setting.on
    local count=menu.item_count()
    local sel=menu.selected_index()
    local start=math.floor(sel/rows)*rows
    local visible=math.min(rows,math.max(0,count-start))
    local row_h=27
    local header_h=37
    local bottom_pad=9
    local height=header_h+visible*row_h+bottom_pad
    local x=math.floor(ctx.screen_w()*0.075)
    local y=math.floor(ctx.screen_h()*0.048)
    local ox,oy=menu.drag_header(x,y,width,header_h)
    x=x+ox;y=y+oy
    menu.set_content_rect(x,y+header_h,width,visible*row_h)

    draw.rect(x,y,x+width,y+height,0,0,0,alpha)
    text.draw(font.title,x+10,y+(header_h-text.height(font.title))*0.5,
        title.r,title.g,title.b,255,"Extortion GTA Load")

    for row=0,visible-1 do
        local idx=start+row
        local yy=y+header_h+row*row_h
        if idx<count then
            local item=menu.get_item(idx)
            if item then
                item._idx=idx
                local active=idx==sel
                local hovered=mouse_hit(x,yy,x+width,yy+row_h)
                local tx=x+10
                if show_icons and not item.is_header then
                    text.draw_centered(font.label,x+8,yy+(row_h-text.height(font.label))*0.5,x+30,
                        active and selected.r or 177,active and selected.g or 177,active and selected.b or 177,255,option_icon(item))
                    tx=x+36
                end
                if item.is_header then
                    text.draw(font.small,x+10,yy+(row_h-text.height(font.small))*0.5,title.r,title.g,title.b,255,
                        (item.name or ""):gsub("^[%-%s]+",""):gsub("[%-%s]+$",""):upper())
                else
                    text.draw_ellipsis(font.item,tx,yy+(row_h-text.height(font.item))*0.5,
                        active and selected.r or 205,active and selected.g or 205,active and selected.b or 205,255,item.name or "",width*0.67)
                    local value=""
                    if item.type==item_type.toggle then value=item.on and "ON" or "OFF"
                    elseif item.type==item_type.float_toggle or item.type==item_type.int_toggle
                        or item.type==item_type.array_toggle or item.type==item_type.loop_toggle then
                        value=(item.on and "ON  " or "OFF  ")..item_value(item)
                    elseif NUMERIC[item.type] or CYCLIC[item.type] or item.type==item_type.input_text
                        or item.type==item_type.input_int or item.type==item_type.input_float or item.type==item_type.search then value=item_value(item) end
                    if edit_on and edit_idx==idx then value=edit_buf..((math.floor(ctx.time()*2)%2==0) and "|" or "") end
                    if value~="" then
                        text.draw(font.value,x+width-10-text.width(font.value,value),yy+(row_h-text.height(font.value))*0.5,
                            active and selected.r or 155,active and selected.g or 155,active and selected.b or 155,255,value)
                    end
                end
                if hovered and input.mouse_clicked(0) and not menu.overlay_active() then menu.set_selected(idx);activate(item) end
                if hovered and input.mouse_clicked(1) then menu.set_selected(idx);adjust(item,-1) end
            end
        end
    end

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
