-- ArabicGuy
-- Compact translucent blue classic GTA menu.

text.set_font_family("Trebuchet MS")

local TITLE_FONT_FILE="Themes\\ArabicGuy\\fonts\\KaushanScript-Regular.ttf"
local TITLE_FONT_REL="Themes/ArabicGuy/fonts/KaushanScript-Regular.ttf"
local ICON_FONT_FILE="Themes\\ArabicGuy\\fonts\\fa-solid-900.ttf"
local ICON_FONT_REL="Themes/ArabicGuy/fonts/fa-solid-900.ttf"
local title_font_downloaded=false
local icon_font_downloaded=false

local function valid_font_data(data)
    if not data or #data<1024 then return false end
    local sig=data:sub(1,4)
    return sig=="OTTO" or (data:byte(1)==0 and data:byte(2)==1 and data:byte(3)==0 and data:byte(4)==0)
end

local function apply_title_font() text.set_font_for(font.title,TITLE_FONT_REL) end
local function apply_icon_font() text.set_icon_font(font.label,ICON_FONT_REL) end

do
    local data=file.read(TITLE_FONT_FILE)
    if valid_font_data(data) then
        apply_title_font()
    elseif net and net.get then
        net.get("raw.githubusercontent.com","/google/fonts/main/ofl/kaushanscript/KaushanScript-Regular.ttf",function(body)
            if valid_font_data(body) then title_font_downloaded=file.write(TITLE_FONT_FILE,body) end
        end,function() end)
    end
end

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

text.set_size(font.title,34)
text.set_weight(font.title,500)
text.set_size(font.item,18)
text.set_weight(font.item,600)
text.set_size(font.value,16)
text.set_weight(font.value,500)
text.set_size(font.small,14)
text.set_weight(font.small,600)
text.set_size(font.tiny,11)
text.set_size(font.label,17)

local SETTINGS_FILE="arabicguy_theme.ini"
menu.clear_settings()
menu.add_setting_color("ArabicGuy Blue",8,70,92,255,"Blue row and header color")
menu.add_setting_color("ArabicGuy Selected",248,222,45,255,"Selected option text color")
menu.add_setting_slider("ArabicGuy Width",430,330,620,10,"Menu width")
menu.add_setting_slider("ArabicGuy Rows",13,7,18,1,"Visible option rows")
menu.add_setting_slider("ArabicGuy Opacity",86,45,100,1,"Panel transparency")
menu.add_setting_action("Reset Theme","Reset ArabicGuy settings")

local function setting(name) return menu.get_setting(name) end
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end

local function fa(cp)
    if cp<0x80 then return string.char(cp) end
    if cp<0x800 then return string.char(0xC0+math.floor(cp/0x40),0x80+cp%0x40) end
    if cp<0x10000 then
        return string.char(0xE0+math.floor(cp/0x1000),0x80+(math.floor(cp/0x40)%0x40),0x80+cp%0x40)
    end
    return string.char(0xF0+math.floor(cp/0x40000),0x80+(math.floor(cp/0x1000)%0x40),0x80+(math.floor(cp/0x40)%0x40),0x80+cp%0x40)
end

local STAR=fa(0xF005)
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
        if key=="blue" or key=="selected" then
            local r,g,b,a=value:match("(%d+),(%d+),(%d+),(%d+)")
            if r then
                menu.set_setting(key=="blue" and "ArabicGuy Blue" or "ArabicGuy Selected",
                    tonumber(r),tonumber(g),tonumber(b),tonumber(a))
            end
        elseif key=="width" then menu.set_setting("ArabicGuy Width",tonumber(value) or 430)
        elseif key=="rows" then menu.set_setting("ArabicGuy Rows",tonumber(value) or 13)
        elseif key=="opacity" then menu.set_setting("ArabicGuy Opacity",tonumber(value) or 86)
        end
    end
end

local function serialize_settings()
    local blue=setting("ArabicGuy Blue") or {r=8,g=70,b=92,a=255}
    local selected=setting("ArabicGuy Selected") or {r=248,g=222,b=45,a=255}
    local width=setting("ArabicGuy Width") or {f_val=430}
    local rows=setting("ArabicGuy Rows") or {f_val=13}
    local opacity=setting("ArabicGuy Opacity") or {f_val=86}
    return table.concat({
        "blue="..blue.r..","..blue.g..","..blue.b..","..blue.a,
        "selected="..selected.r..","..selected.g..","..selected.b..","..selected.a,
        "width="..width.f_val,
        "rows="..rows.f_val,
        "opacity="..opacity.f_val
    },"\n")
end

local function reset_settings()
    menu.set_setting("ArabicGuy Blue",8,70,92,255)
    menu.set_setting("ArabicGuy Selected",248,222,45,255)
    menu.set_setting("ArabicGuy Width",430)
    menu.set_setting("ArabicGuy Rows",13)
    menu.set_setting("ArabicGuy Opacity",86)
    file.remove(SETTINGS_FILE)
end

load_settings()
local last_settings=serialize_settings()
local save_pending=false
local save_at=0
local edit_on=false
local edit_idx=-1
local edit_type=0
local edit_buf=""
local edit_frame=-1

local function hit(x1,y1,x2,y2)
    local mx,my=input.mouse_x(),input.mouse_y()
    return mx>=x1 and mx<x2 and my>=y1 and my<y2
end

local function item_value(item)
    if CYCLIC[item.type] then return item.current_value or "" end
    if item.type==item_type.input_text or item.type==item_type.search then
        return item.text~="" and item.text or "..."
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
        notify.push("Theme","ArabicGuy reset",1)
        return
    end
    if item.type==item_type.array_toggle or item.type==item_type.loop_toggle then
        menu.activate()
    elseif CYCLIC[item.type] then
        adjust(item,1)
    elseif item.type==item_type.input_text or item.type==item_type.input_int or item.type==item_type.input_float
        or item.type==item_type.search or item.type==item_type.slider or item.type==item_type.int_option then
        edit_on=true
        edit_idx=item._idx
        edit_type=item.type
        edit_frame=ctx.frame()
        if item.type==item_type.input_int or item.type==item_type.int_option then
            edit_buf=tostring(item.i_val or 0)
        elseif item.type==item_type.input_float or item.type==item_type.slider then
            edit_buf=string.format("%.2f",item.f_val or 0)
        else
            edit_buf=item.text or ""
        end
    else
        menu.activate()
    end
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
                or (byte==46 and (edit_type==item_type.input_float or edit_type==item_type.slider)
                    and not edit_buf:find("%.")) then
                edit_buf=edit_buf..ch
            end
        end
    end
    if input.key_just_pressed(VK.BACK) and #edit_buf>0 then edit_buf=edit_buf:sub(1,-2) end
    if input.key_just_pressed(VK.ESCAPE) then edit_on=false end
    if input.key_just_pressed(VK.RETURN) and ctx.frame()~=edit_frame then
        menu.set_selected(edit_idx)
        if edit_type==item_type.input_int or edit_type==item_type.int_option then
            local value=tonumber(edit_buf)
            if value then menu.set_i_val(edit_idx,math.floor(value)) end
        elseif edit_type==item_type.input_float or edit_type==item_type.slider then
            local value=tonumber(edit_buf)
            if value then menu.set_f_val(edit_idx,value) end
        else
            menu.set_input_buffer(edit_buf)
            menu.confirm_input()
        end
        edit_on=false
    end
end

local function draw_globe(x,y,w,h,blue)
    draw.push_clip(x,y,x+w,y+h)
    local cx=x+w-68
    local cy=y+h*0.52
    local radius=74
    draw.circle_outline(cx,cy,radius,122,173,190,58,5)
    draw.circle_outline(cx-25,cy,radius,122,173,190,38,4)
    draw.circle_outline(cx+25,cy,radius,122,173,190,38,4)
    draw.line(cx-radius,cy,cx+radius,cy,122,173,190,38,4)
    draw.line(cx-radius*0.88,cy-29,cx+radius*0.88,cy-29,122,173,190,30,3)
    draw.line(cx-radius*0.88,cy+29,cx+radius*0.88,cy+29,122,173,190,30,3)
    draw.pop_clip()
end

function draw_menu()
    if title_font_downloaded then apply_title_font();title_font_downloaded=false end
    if icon_font_downloaded then apply_icon_font();icon_font_downloaded=false end

    local blue=setting("ArabicGuy Blue") or {r=8,g=70,b=92,a=255}
    local selected=setting("ArabicGuy Selected") or {r=248,g=222,b=45,a=255}
    theme.set_body_bg(3,13,18,255)
    theme.set_menu_bg(3,13,18,255)
    theme.set_accent_palette(blue.r,blue.g,blue.b,255)
    if not menu.is_visible() then menu.set_text_editing(false);return end

    local width_setting=setting("ArabicGuy Width")
    local row_setting=setting("ArabicGuy Rows")
    local opacity_setting=setting("ArabicGuy Opacity")
    local width=clamp(width_setting and width_setting.f_val or 430,330,ctx.screen_w()-20)
    local rows=math.floor(row_setting and row_setting.f_val or 13)
    local alpha=math.floor(255*clamp((opacity_setting and opacity_setting.f_val or 86)/100,0.45,1))
    local count=menu.item_count()
    local sel=menu.selected_index()
    local start=math.floor(sel/rows)*rows
    local visible=math.min(rows,math.max(0,count-start))
    local header_h=82
    local row_h=38
    local footer_h=35
    local height=header_h+visible*row_h+footer_h
    local x=math.floor(ctx.screen_w()*0.035)
    local y=math.floor(ctx.screen_h()*0.035)
    local ox,oy=menu.drag_header(x,y,width,header_h)
    x=x+ox;y=y+oy
    menu.set_content_rect(x,y+header_h,width,visible*row_h)

    draw.rect(x,y,x+width,y+height,2,10,14,alpha)
    draw.rect_gradient(x,y,x+width,y+header_h,
        blue.r,blue.g,blue.b,alpha,blue.r+14,blue.g+20,blue.b+22,alpha,
        blue.r+14,blue.g+20,blue.b+22,alpha,blue.r,blue.g,blue.b,alpha)
    draw_globe(x,y,width,header_h,blue)
    local page=menu.page_name() or "Home"
    local title=page=="Home" and "ArabicGuy" or page
    text.draw_outlined(font.title,x+17,y+(header_h-text.height(font.title))*0.5-2,
        247,247,247,255,0,0,0,190,1.1,title)
    draw.rect(x,y+header_h-2,x+width,y+header_h,175,220,233,155)

    for row=0,visible-1 do
        local idx=start+row
        local yy=y+header_h+row*row_h
        local item=menu.get_item(idx)
        if item then
            item._idx=idx
            local active=idx==sel
            local hovered=hit(x,yy,x+width,yy+row_h)
            local alt=(row%2)==1
            local rr=alt and blue.r or 8
            local rg=alt and blue.g or 14
            local rb=alt and blue.b or 19
            draw.rect(x,yy,x+width,yy+row_h,rr,rg,rb,alpha)
            if active then draw.rect(x,yy,x+width,yy+row_h,79,78,83,218) end
            if hovered and not active then draw.rect(x,yy,x+width,yy+row_h,74,100,109,85) end
            draw.rect(x,yy+row_h-2,x+width,yy+row_h,191,226,237,145)

            if item.is_header then
                text.draw(font.small,x+14,yy+(row_h-text.height(font.small))*0.5,
                    active and selected.r or 213,active and selected.g or 234,active and selected.b or 240,255,
                    (item.name or ""):gsub("^[%-%s]+",""):gsub("[%-%s]+$",""):upper())
            else
                text.draw_centered(font.label,x+10,yy+(row_h-text.height(font.label))*0.5,x+39,
                    247,247,247,255,STAR)
                text.draw_ellipsis(font.item,x+43,yy+(row_h-text.height(font.item))*0.5,
                    active and selected.r or 235,active and selected.g or 235,active and selected.b or 235,255,
                    item.name or "",width*0.68)

                local value=""
                local toggle_type=item.type==item_type.toggle or item.type==item_type.float_toggle
                    or item.type==item_type.int_toggle or item.type==item_type.array_toggle
                    or item.type==item_type.loop_toggle
                if item.type==item_type.sub_menu then value=">"
                elseif item.type==item_type.selected_tick then value="selected"
                elseif not toggle_type and (NUMERIC[item.type] or CYCLIC[item.type]
                    or item.type==item_type.input_text or item.type==item_type.input_int
                    or item.type==item_type.input_float or item.type==item_type.search) then
                    value=item_value(item)
                elseif toggle_type and item.type~=item_type.toggle then
                    value=item_value(item)
                end
                if edit_on and edit_idx==idx then value=edit_buf..((math.floor(ctx.time()*2)%2==0) and "|" or "") end

                local indicator_x=x+width-22
                if toggle_type then
                    draw.circle(indicator_x,yy+row_h*0.5,8,
                        item.on and 35 or 231,item.on and 222 or 28,item.on and 65 or 35,255)
                elseif item.type==item_type.selected_tick then
                    draw.circle(indicator_x,yy+row_h*0.5,8,35,222,65,255)
                    value=""
                end
                if value~="" then
                    local right=toggle_type and indicator_x-18 or x+width-14
                    text.draw(font.value,right-text.width(font.value,value),yy+(row_h-text.height(font.value))*0.5,
                        active and selected.r or 235,active and selected.g or 235,active and selected.b or 235,255,value)
                end
            end

            if hovered and input.mouse_clicked(0) and not menu.overlay_active() then
                menu.set_selected(idx)
                activate(item)
            end
            if hovered and input.mouse_clicked(1) then
                menu.set_selected(idx)
                adjust(item,-1)
            end
        end
    end

    if count>visible and visible>0 then
        local track_x=x+width-8
        local track_y=y+header_h
        local track_h=visible*row_h
        draw.rect(track_x,track_y,track_x+7,track_y+track_h,207,213,219,110)
        local thumb_h=math.max(24,track_h*(visible/count))
        local max_start=math.max(1,count-visible)
        local thumb_y=track_y+(track_h-thumb_h)*clamp(start/max_start,0,1)
        draw.rect(track_x,thumb_y,track_x+7,thumb_y+thumb_h,232,235,238,235)
    end

    local footer_y=y+header_h+visible*row_h
    draw.rect(x,footer_y,x+width,footer_y+footer_h,blue.r,blue.g,blue.b,alpha)
    draw.rect(x,footer_y,x+width,footer_y+2,191,226,237,120)
    text.draw(font.item,x+12,footer_y+(footer_h-text.height(font.item))*0.5,238,238,238,255,"Ver: 1.0")
    local counter=count>0 and tostring(sel+1).." / "..tostring(count) or "0 / 0"
    text.draw(font.item,x+width-14-text.width(font.item,counter),footer_y+(footer_h-text.height(font.item))*0.5,
        238,238,238,255,counter)

    process_edit()
    menu.set_text_editing(edit_on)
    local signature=serialize_settings()
    if signature~=last_settings then last_settings=signature;save_pending=true;save_at=ctx.time() end
    if save_pending and ctx.time()-save_at>0.4 then
        file.write(SETTINGS_FILE,last_settings)
        save_pending=false
    end
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
