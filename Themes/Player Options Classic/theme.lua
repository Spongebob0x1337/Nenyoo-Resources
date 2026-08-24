-- Player Options Classic
-- Narrow translucent charcoal list inspired by early GTA V menus.

text.set_font_family("Trebuchet MS")

local TITLE_FONT_FILE="Themes\\Player Options Classic\\fonts\\KaushanScript-Regular.ttf"
local TITLE_FONT_REL="Themes/Player Options Classic/fonts/KaushanScript-Regular.ttf"
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

text.set_size(font.title,36)
text.set_weight(font.title,500)
text.set_size(font.item,17)
text.set_weight(font.item,600)
text.set_size(font.value,16)
text.set_weight(font.value,500)
text.set_size(font.small,14)
text.set_weight(font.small,600)
text.set_size(font.tiny,11)
text.set_size(font.label,17)

local SETTINGS_FILE="player_options_classic.ini"
menu.clear_settings()
menu.add_setting_color("Classic Highlight",29,178,207,255,"Selected option text color")
menu.add_setting_color("Classic Toggle On",20,235,50,255,"Enabled indicator color")
menu.add_setting_slider("Classic Width",520,390,700,10,"Menu width")
menu.add_setting_slider("Classic Rows",24,10,26,1,"Visible option rows")
menu.add_setting_slider("Classic Opacity",78,45,95,1,"Panel transparency")
menu.add_setting_slider("Classic Position",55,35,78,1,"Horizontal position percentage")
menu.add_setting_action("Reset Theme","Reset Player Options Classic settings")

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
                menu.set_setting(key=="highlight" and "Classic Highlight" or "Classic Toggle On",
                    tonumber(r),tonumber(g),tonumber(b),tonumber(a))
            end
        elseif key=="width" then menu.set_setting("Classic Width",tonumber(value) or 520)
        elseif key=="rows" then menu.set_setting("Classic Rows",tonumber(value) or 24)
        elseif key=="opacity" then menu.set_setting("Classic Opacity",tonumber(value) or 78)
        elseif key=="position" then menu.set_setting("Classic Position",tonumber(value) or 55)
        end
    end
end

local function serialize_settings()
    local highlight=setting("Classic Highlight") or {r=29,g=178,b=207,a=255}
    local toggle_on=setting("Classic Toggle On") or {r=20,g=235,b=50,a=255}
    local width=setting("Classic Width") or {f_val=520}
    local rows=setting("Classic Rows") or {f_val=24}
    local opacity=setting("Classic Opacity") or {f_val=78}
    local position=setting("Classic Position") or {f_val=55}
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
    menu.set_setting("Classic Highlight",29,178,207,255)
    menu.set_setting("Classic Toggle On",20,235,50,255)
    menu.set_setting("Classic Width",520)
    menu.set_setting("Classic Rows",24)
    menu.set_setting("Classic Opacity",78)
    menu.set_setting("Classic Position",55)
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
        notify.push("Theme","Player Options Classic reset",1)
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

local TITLE_MAP={
    Home="Main Options",Network="Online Options",Self="Player Options",Vehicle="Vehicle Options",
    Weapon="Weapon Options",VFX="Visual Options",World="World Options",Misc="Misc Options",
    Teleport="Teleport Options",Scripts="Script Options",Spooner="Spooner Options",
    Protections="Protection Options",Settings="Settings"
}

function draw_menu()
    if title_font_downloaded then apply_title_font();title_font_downloaded=false end

    local highlight=setting("Classic Highlight") or {r=29,g=178,b=207,a=255}
    local toggle_on=setting("Classic Toggle On") or {r=20,g=235,b=50,a=255}
    theme.set_body_bg(25,29,33,255)
    theme.set_menu_bg(25,29,33,255)
    theme.set_accent_palette(highlight.r,highlight.g,highlight.b,255)
    if not menu.is_visible() then menu.set_text_editing(false);return end

    local width_setting=setting("Classic Width")
    local row_setting=setting("Classic Rows")
    local opacity_setting=setting("Classic Opacity")
    local position_setting=setting("Classic Position")
    local width=clamp(width_setting and width_setting.f_val or 520,390,ctx.screen_w()-20)
    local requested_rows=math.floor(row_setting and row_setting.f_val or 24)
    local alpha=math.floor(255*clamp((opacity_setting and opacity_setting.f_val or 78)/100,0.45,0.95))
    local position=clamp(position_setting and position_setting.f_val or 55,10,90)/100
    local count=menu.item_count()
    local sel=menu.selected_index()
    local header_h=72
    local row_h=31
    local footer_h=58
    local rows=math.min(requested_rows,math.max(7,math.floor((ctx.screen_h()-header_h-footer_h-28)/row_h)))
    local start=math.floor(sel/rows)*rows
    local visible=math.min(rows,math.max(0,count-start))
    local height=header_h+visible*row_h+footer_h
    local x=math.floor(clamp(ctx.screen_w()*position,8,ctx.screen_w()-width-8))
    local y=math.floor((ctx.screen_h()-height)*0.42)
    local ox,oy=menu.drag_header(x,y,width,header_h)
    x=x+ox;y=y+oy
    menu.set_content_rect(x,y+header_h,width,visible*row_h)

    draw.rect(x,y,x+width,y+height,30,34,38,alpha)
    draw.rect(x,y,x+width,y+header_h,58,63,69,math.min(240,alpha+22))
    draw.rect_outline(x,y,x+width,y+height,135,145,154,130,0,1)
    local page=menu.page_name() or "Home"
    local title=TITLE_MAP[page] or page
    text.draw_outlined(font.title,x+16,y+(header_h-text.height(font.title))*0.5-1,
        247,247,247,255,0,0,0,190,1.1,title)
    draw.rect(x,y+header_h-2,x+width,y+header_h,114,124,133,165)

    for row=0,visible-1 do
        local idx=start+row
        local yy=y+header_h+row*row_h
        local item=menu.get_item(idx)
        if item then
            item._idx=idx
            local active=idx==sel
            local hovered=hit(x,yy,x+width,yy+row_h)
            local shade=(row%2)==0 and 43 or 33
            draw.rect(x,yy,x+width,yy+row_h,shade,shade+4,shade+7,alpha)
            if active then draw.rect(x,yy,x+width,yy+row_h,68,74,79,math.min(245,alpha+30)) end
            if hovered and not active then draw.rect(x,yy,x+width,yy+row_h,73,80,86,105) end
            draw.rect(x,yy+row_h-1,x+width,yy+row_h,137,147,155,145)

            if item.is_header then
                text.draw(font.small,x+12,yy+(row_h-text.height(font.small))*0.5,
                    active and highlight.r or 207,active and highlight.g or 215,active and highlight.b or 220,255,
                    (item.name or ""):gsub("^[%-%s]+",""):gsub("[%-%s]+$",""):upper())
            else
                text.draw_ellipsis(font.item,x+15,yy+(row_h-text.height(font.item))*0.5,
                    active and highlight.r or 235,active and highlight.g or 235,active and highlight.b or 235,255,
                    item.name or "",width*0.72)

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

                local indicator_x=x+width-20
                if toggle_type then
                    draw.circle(indicator_x,yy+row_h*0.5,7,
                        item.on and toggle_on.r or 218,item.on and toggle_on.g or 24,item.on and toggle_on.b or 30,255)
                    draw.circle_outline(indicator_x,yy+row_h*0.5,8,255,255,255,45,1)
                elseif item.type==item_type.selected_tick then
                    draw.circle(indicator_x,yy+row_h*0.5,7,toggle_on.r,toggle_on.g,toggle_on.b,255)
                elseif action_mark then
                    text.draw(font.small,x+width-22-text.width(font.small,"R"),yy+(row_h-text.height(font.small))*0.5,
                        active and highlight.r or 238,active and highlight.g or 238,active and highlight.b or 238,255,"R")
                end
                if value~="" then
                    local right=toggle_type and indicator_x-18 or x+width-14
                    text.draw(font.value,right-text.width(font.value,value),yy+(row_h-text.height(font.value))*0.5,
                        active and highlight.r or 235,active and highlight.g or 235,active and highlight.b or 235,255,value)
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

    local footer_y=y+header_h+visible*row_h
    draw.rect(x,footer_y,x+width,footer_y+footer_h,35,39,43,math.min(245,alpha+15))
    draw.rect(x,footer_y,x+width,footer_y+1,146,156,164,160)
    text.draw(font.small,x+12,footer_y+7,235,235,235,255,"Ver: 1.00 Offline/Online")
    local counter=count>0 and tostring(sel+1).." / "..tostring(count) or "0 / 0"
    text.draw(font.small,x+width-13-text.width(font.small,counter),footer_y+7,238,238,238,255,counter)
    draw.rect(x,footer_y+29,x+width,footer_y+30,134,144,152,135)
    text.draw(font.small,x+12,footer_y+36,230,230,230,255,"NENYOO Online")

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
