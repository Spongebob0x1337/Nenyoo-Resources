-- Lotus
-- Compact upper-right gradient menu inspired by the classic Lotus GTA V UI.

text.set_font_family("Trebuchet MS")

local TITLE_FONT_FILE="Themes\\Lotus\\fonts\\KaushanScript-Regular.ttf"
local TITLE_FONT_REL="Themes/Lotus/fonts/KaushanScript-Regular.ttf"
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
        net.get("raw.githubusercontent.com","/google/fonts/main/ofl/kaushanscript/KaushanScript-Regular.ttf",function(body)
            if valid_font_data(body) then title_font_downloaded=file.write(TITLE_FONT_FILE,body) end
        end,function() end)
    end
end

text.set_size(font.title,29)
text.set_weight(font.title,500)
text.set_size(font.item,15)
text.set_weight(font.item,600)
text.set_size(font.value,14)
text.set_weight(font.value,600)
text.set_size(font.small,12)
text.set_weight(font.small,600)
text.set_size(font.tiny,10)
text.set_size(font.label,15)
text.set_size(font.desc,12)
text.set_weight(font.desc,500)

local SETTINGS_FILE="lotus_theme.ini"
menu.clear_settings()
menu.add_setting_color("Lotus Pink",224,0,116,255,"Left side of the banner gradient")
menu.add_setting_color("Lotus Orange",255,119,45,255,"Right side of the banner gradient")
menu.add_setting_slider("Lotus Width",310,260,470,10,"Menu width")
menu.add_setting_slider("Lotus Rows",10,6,17,1,"Visible option rows")
menu.add_setting_slider("Lotus Opacity",80,45,95,1,"List background opacity")
menu.add_setting_slider("Lotus Position",74,0,85,1,"Horizontal position percentage")
menu.add_setting_action("Reset Theme","Reset Lotus settings")

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
        if key=="highlight" or key=="toggle_on" then
            local r,g,b,a=value:match("(%d+),(%d+),(%d+),(%d+)")
            if r then
                menu.set_setting(key=="highlight" and "Lotus Pink" or "Lotus Orange",
                    tonumber(r),tonumber(g),tonumber(b),tonumber(a))
            end
        elseif key=="width" then menu.set_setting("Lotus Width",tonumber(value) or 310)
        elseif key=="rows" then menu.set_setting("Lotus Rows",tonumber(value) or 10)
        elseif key=="opacity" then menu.set_setting("Lotus Opacity",tonumber(value) or 80)
        elseif key=="position" then menu.set_setting("Lotus Position",tonumber(value) or 74)
        end
    end
end

local function serialize_settings()
    local highlight=setting("Lotus Pink") or {r=224,g=0,b=116,a=255}
    local toggle_on=setting("Lotus Orange") or {r=255,g=119,b=45,a=255}
    local width=setting("Lotus Width") or {f_val=310}
    local rows=setting("Lotus Rows") or {f_val=10}
    local opacity=setting("Lotus Opacity") or {f_val=80}
    local position=setting("Lotus Position") or {f_val=74}
    return table.concat({
        "highlight="..highlight.r..","..highlight.g..","..highlight.b..","..highlight.a,
        "toggle_on="..toggle_on.r..","..toggle_on.g..","..toggle_on.b..","..toggle_on.a,
        "width="..width.f_val,
        "rows="..rows.f_val,
        "opacity="..opacity.f_val,
        "position="..position.f_val
    },"\n")
end

local function reset_settings()
    menu.set_setting("Lotus Pink",224,0,116,255)
    menu.set_setting("Lotus Orange",255,119,45,255)
    menu.set_setting("Lotus Width",310)
    menu.set_setting("Lotus Rows",10)
    menu.set_setting("Lotus Opacity",80)
    menu.set_setting("Lotus Position",74)
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
        notify.push("Theme","Lotus reset",1)
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

function draw_menu()
    if title_font_downloaded then apply_title_font();title_font_downloaded=false end

    local pink=setting("Lotus Pink") or {r=224,g=0,b=116,a=255}
    local orange=setting("Lotus Orange") or {r=255,g=119,b=45,a=255}
    theme.set_body_bg(10,10,10,255)
    theme.set_menu_bg(10,10,10,255)
    theme.set_accent_palette(pink.r,pink.g,pink.b,255)
    if not menu.is_visible() then menu.set_text_editing(false);return end

    local width_setting=setting("Lotus Width")
    local row_setting=setting("Lotus Rows")
    local opacity_setting=setting("Lotus Opacity")
    local position_setting=setting("Lotus Position")
    local width=clamp(width_setting and width_setting.f_val or 310,260,math.max(260,ctx.screen_w()-16))
    local requested_rows=math.floor(row_setting and row_setting.f_val or 10)
    local alpha=math.floor(255*clamp((opacity_setting and opacity_setting.f_val or 80)/100,0.45,0.95))
    local position=clamp(position_setting and position_setting.f_val or 74,0,85)/100
    local count=menu.item_count()
    local sel=menu.selected_index()
    local banner_h=58
    local page_h=22
    local row_h=25
    local footer_h=24
    local desc_gap=6
    local desc_h=48
    local fixed_h=banner_h+page_h+footer_h+desc_gap+desc_h+20
    local rows=math.min(requested_rows,math.max(5,math.floor((ctx.screen_h()-fixed_h)/row_h)))
    local start=math.floor(sel/rows)*rows
    local visible=math.min(rows,math.max(0,count-start))
    local list_h=banner_h+page_h+visible*row_h+footer_h
    local height=list_h+desc_gap+desc_h
    local x=math.floor(clamp(ctx.screen_w()*position,8,math.max(8,ctx.screen_w()-width-8)))
    local y=math.floor(clamp(ctx.screen_h()*0.07,8,math.max(8,ctx.screen_h()-height-8)))
    local ox,oy=menu.drag_header(x,y,width,banner_h)
    x=x+ox;y=y+oy
    menu.set_content_rect(x,y+banner_h+page_h,width,visible*row_h)

    draw.rect(x,y,x+width,y+list_h,5,5,5,alpha)
    draw.rect_gradient(x,y,x+width,y+banner_h,
        pink.r,pink.g,pink.b,250,orange.r,orange.g,orange.b,250,
        orange.r,orange.g,orange.b,250,pink.r,pink.g,pink.b,250)
    for tile=0,4 do
        local tw=width*0.09
        local tx=x+width-tw*(tile+1)
        draw.rect(tx,y,tx+tw-1,y+banner_h,255,255,255,(tile%2==0) and 16 or 8)
    end
    draw.rect(x,y+banner_h-2,x+width,y+banner_h,255,255,255,28)
    draw.rect_outline(x,y,x+width,y+list_h,12,12,12,230,0,1)
    local title="Lotus"
    local tx=x+(width-text.width(font.title,title))*0.5
    text.draw_outlined(font.title,tx,y+(banner_h-text.height(font.title))*0.5-1,
        255,255,255,255,40,10,26,170,1.1,title)

    local page=menu.page_name() or "Home"
    local page_name=(page=="Home" and "MAIN MENU" or page:upper())
    local page_y=y+banner_h
    draw.rect(x,page_y,x+width,page_y+page_h,2,2,3,245)
    text.draw(font.small,x+8,page_y+(page_h-text.height(font.small))*0.5,
        230,230,232,255,page_name)
    local counter=count>0 and tostring(sel+1).." / "..tostring(count) or "0 / 0"
    text.draw(font.small,x+width-8-text.width(font.small,counter),
        page_y+(page_h-text.height(font.small))*0.5,230,230,232,255,counter)

    for row=0,visible-1 do
        local idx=start+row
        local yy=y+banner_h+page_h+row*row_h
        local item=menu.get_item(idx)
        if item then
            item._idx=idx
            local active=idx==sel
            local hovered=hit(x,yy,x+width,yy+row_h)
            local shade=(row%2)==0 and 18 or 10
            draw.rect(x,yy,x+width,yy+row_h,shade,shade,shade,alpha)
            if active then draw.rect(x,yy,x+width,yy+row_h,239,239,240,246) end
            if hovered and not active then draw.rect(x,yy,x+width,yy+row_h,130,130,135,90) end
            draw.rect(x,yy+row_h-1,x+width,yy+row_h,220,220,222,38)

            if item.is_header then
                text.draw(font.small,x+8,yy+(row_h-text.height(font.small))*0.5,
                    active and 30 or pink.r,active and 30 or pink.g,active and 32 or pink.b,255,
                    (item.name or ""):gsub("^[%-%s]+",""):gsub("[%-%s]+$",""))
            else
                text.draw_ellipsis(font.item,x+8,yy+(row_h-text.height(font.item))*0.5,
                    active and 24 or 235,active and 24 or 235,active and 26 or 237,255,
                    item.name or "",width*0.67)

                local value=""
                local toggle_type=item.type==item_type.toggle or item.type==item_type.float_toggle
                    or item.type==item_type.int_toggle or item.type==item_type.array_toggle
                    or item.type==item_type.loop_toggle
                local action_mark=item.type==item_type.sub_menu or item.type==item_type.action
                if item.type==item_type.selected_tick then value=""
                elseif not toggle_type and (NUMERIC[item.type] or CYCLIC[item.type]
                    or item.type==item_type.input_text or item.type==item_type.input_int
                    or item.type==item_type.input_float or item.type==item_type.search) then
                    value=item_value(item)
                elseif toggle_type and item.type~=item_type.toggle then
                    value=item_value(item)
                end
                if edit_on and edit_idx==idx then value=edit_buf..((math.floor(ctx.time()*2)%2==0) and "|" or "") end

                local indicator_x=x+width-13
                if toggle_type then
                    local box=11
                    local bx=indicator_x-box*0.5
                    local by=yy+(row_h-box)*0.5
                    draw.rect_outline(bx,by,bx+box,by+box,
                        active and 35 or 228,active and 35 or 228,active and 38 or 232,245,0,1)
                    if item.on then
                        draw.rect(bx+2,by+2,bx+box-2,by+box-2,pink.r,pink.g,pink.b,255)
                    end
                elseif item.type==item_type.selected_tick then
                    draw.rect(indicator_x-4,yy+row_h*0.5-4,indicator_x+4,yy+row_h*0.5+4,
                        pink.r,pink.g,pink.b,255)
                elseif action_mark then
                    local mark=">"
                    text.draw(font.small,x+width-8-text.width(font.small,mark),yy+(row_h-text.height(font.small))*0.5,
                        active and 28 or 235,active and 28 or 235,active and 30 or 237,255,mark)
                end
                if value~="" then
                    local right=toggle_type and indicator_x-12 or x+width-10
                    text.draw(font.value,right-text.width(font.value,value),yy+(row_h-text.height(font.value))*0.5,
                        active and 28 or 235,active and 28 or 235,active and 30 or 237,255,value)
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

    local footer_y=y+banner_h+page_h+visible*row_h
    draw.rect(x,footer_y,x+width,footer_y+footer_h,3,3,4,245)
    draw.rect(x,footer_y,x+width,footer_y+1,210,210,212,70)
    local marker="^  v"
    text.draw(font.small,x+(width-text.width(font.small,marker))*0.5,
        footer_y+(footer_h-text.height(font.small))*0.5,235,235,238,255,marker)

    local desc_y=footer_y+footer_h+desc_gap
    draw.rect(x,desc_y,x+width,desc_y+desc_h,3,3,4,238)
    draw.rect_outline(x,desc_y,x+width,desc_y+desc_h,20,20,22,210,0,1)
    local selected_item=count>0 and menu.get_item(sel) or nil
    local desc=(selected_item and selected_item.desc and selected_item.desc~="") and selected_item.desc
        or (selected_item and ("Select "..(selected_item.name or "this option")..".") or "No options available.")
    draw.push_clip(x+8,desc_y+5,x+width-8,desc_y+desc_h-5)
    text.draw(font.desc,x+8,desc_y+7,236,236,238,255,desc,width-16)
    draw.pop_clip()

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
