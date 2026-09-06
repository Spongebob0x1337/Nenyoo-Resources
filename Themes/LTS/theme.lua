-- LTS
-- Tall translucent right-side menu inspired by the classic console theme.

text.set_font_family("Trebuchet MS")
text.set_size(font.title,40)
text.set_weight(font.title,800)
text.set_size(font.item,24)
text.set_weight(font.item,500)
text.set_size(font.breadcrumb,30)
text.set_weight(font.breadcrumb,900)
text.set_size(font.value,18)
text.set_weight(font.value,600)
text.set_size(font.small,15)
text.set_size(font.tiny,12)

local SETTINGS_FILE="lts_v2.ini"
menu.clear_settings()
menu.add_setting_color("LTS Lime",176,255,94,255,"Main Menu title color")
menu.add_setting_slider("LTS Width",540,360,680,10,"Width of the right-side panel")
menu.add_setting_slider("LTS Position",68,45,78,1,"Horizontal position percentage")
menu.add_setting_slider("LTS Opacity",70,30,90,1,"Background opacity")
menu.add_setting_slider("LTS Row Height",58,42,72,1,"Option spacing")
menu.add_setting_action("Reset Theme","Reset LTS settings")

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
        if key=="lime" then
            local r,g,b,a=value:match("(%d+),(%d+),(%d+),(%d+)")
            if r then menu.set_setting("LTS Lime",tonumber(r),tonumber(g),tonumber(b),tonumber(a)) end
        elseif key=="width" then menu.set_setting("LTS Width",tonumber(value) or 540)
        elseif key=="position" then menu.set_setting("LTS Position",tonumber(value) or 68)
        elseif key=="opacity" then menu.set_setting("LTS Opacity",tonumber(value) or 70)
        elseif key=="row_height" then menu.set_setting("LTS Row Height",tonumber(value) or 58) end
    end
end

local function serialize()
    local lime=setting("LTS Lime") or {r=176,g=255,b=94,a=255}
    local width=setting("LTS Width") or {f_val=540}
    local position=setting("LTS Position") or {f_val=68}
    local opacity=setting("LTS Opacity") or {f_val=70}
    local row_height=setting("LTS Row Height") or {f_val=58}
    return table.concat({
        "lime="..lime.r..","..lime.g..","..lime.b..","..lime.a,
        "width="..width.f_val,"position="..position.f_val,
        "opacity="..opacity.f_val,"row_height="..row_height.f_val
    },"\n")
end

local function reset_settings()
    menu.set_setting("LTS Lime",176,255,94,255)
    menu.set_setting("LTS Width",540)
    menu.set_setting("LTS Position",68)
    menu.set_setting("LTS Opacity",70)
    menu.set_setting("LTS Row Height",58)
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
    if not item then return end
    if item.name=="Reset Theme" and item.type==item_type.action then
        reset_settings();notify.push("Theme","LTS reset",1);return
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
    local lime=setting("LTS Lime") or {r=176,g=255,b=94,a=255}
    theme.set_body_bg(0,0,0,145)
    theme.set_menu_bg(0,0,0,145)
    theme.set_accent_palette(lime.r,lime.g,lime.b,lime.a)
    if not menu.is_visible() then menu.set_text_editing(false);return end

    local width_setting=setting("LTS Width")
    local position_setting=setting("LTS Position")
    local opacity_setting=setting("LTS Opacity")
    local row_setting=setting("LTS Row Height")
    local width=clamp(width_setting and width_setting.f_val or 540,340,ctx.screen_w()-20)
    local position=clamp((position_setting and position_setting.f_val or 68)/100,0.45,0.78)
    local alpha=math.floor(255*clamp((opacity_setting and opacity_setting.f_val or 70)/100,0.3,0.9))
    local row_h=clamp(row_setting and row_setting.f_val or 58,42,72)
    local header_h=140
    local footer_h=76
    local x=math.floor(ctx.screen_w()*position)
    if x+width>ctx.screen_w()-8 then x=ctx.screen_w()-width-8 end
    local y=0
    local panel_h=ctx.screen_h()-y
    local capacity=math.max(1,math.floor((panel_h-header_h-footer_h)/row_h))
    local count=menu.item_count()
    local sel=menu.selected_index()
    local start=math.floor(sel/capacity)*capacity
    menu.set_content_rect(x,y+header_h,width,capacity*row_h)

    draw.rect(x,y,x+width,y+panel_h,0,0,0,alpha)
    text.draw_centered(font.title,x,y+78-text.height(font.title)*0.5,x+width,
        lime.r,lime.g,lime.b,255,"Main Menu")

    for row=0,capacity-1 do
        local idx=start+row
        if idx<count then
            local item=menu.get_item(idx)
            local yy=y+header_h+row*row_h
            if item then
                item._idx=idx
                local active=idx==sel
                local hovered=mouse_hit(x,yy,x+width,yy+row_h)
                if active then draw.rect(x,yy,x+width,yy+row_h,0,0,0,238) end
                if hovered and not active then draw.rect(x,yy,x+width,yy+row_h,0,0,0,55) end
                if item.is_header then
                    text.draw(font.small,x+14,yy+(row_h-text.height(font.small))*0.5,
                        lime.r,lime.g,lime.b,255,(item.name or ""):upper())
                else
                    local name_font=active and font.breadcrumb or font.item
                    text.draw_ellipsis(name_font,x+14,yy+(row_h-text.height(name_font))*0.5,
                        active and 255 or 226,active and 255 or 226,active and 255 or 226,255,item.name or "",width*0.66)
                    local value=""
                    if item.type==item_type.toggle then value=item.on and "On" or "Off"
                    elseif item.type==item_type.float_toggle or item.type==item_type.int_toggle
                        or item.type==item_type.array_toggle or item.type==item_type.loop_toggle then
                        value=(item.on and "On  " or "Off  ")..item_value(item)
                    elseif NUMERIC[item.type] or CYCLIC[item.type] or item.type==item_type.input_text
                        or item.type==item_type.input_int or item.type==item_type.input_float or item.type==item_type.search then value=item_value(item) end
                    if edit_on and edit_idx==idx then value=edit_buf..((math.floor(ctx.time()*2)%2==0) and "|" or "") end
                    if value~="" then
                        text.draw(font.value,x+width-14-text.width(font.value,value),yy+(row_h-text.height(font.value))*0.5,
                            active and 255 or 220,active and 255 or 220,active and 255 or 220,255,value)
                    end
                end
                if hovered and input.mouse_clicked(0) and not menu.overlay_active() then menu.set_selected(idx);activate(item) end
                if hovered and input.mouse_clicked(1) then menu.set_selected(idx);adjust(item,-1) end
            end
        end
    end

    local counter=count>0 and tostring(sel+1).."/"..tostring(count) or "0/0"
    text.draw_centered(font.item,x,y+panel_h-footer_h+16,x+width,238,238,238,255,counter)
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
