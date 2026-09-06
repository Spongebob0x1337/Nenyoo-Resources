-- Generated Stand ThemeRepo conversion.
-- Source: https://github.com/stagnate6628/stand-themerepo

text.set_font_family("Arial")

local THEME_NAME="Minimalistic Black & White"
local LAYOUT_MODE="standard"
local TAB_BOTTOM=false
local TABS_ENABLED=true
local HEADER_FILE="Themes\\Minimalistic Black & White\\textures\\header.gif"
local HEADER_PATH="Themes/Minimalistic Black & White/textures/header.gif"
local HEADER_URL_PATH=""
local header_handle=0
local header_downloaded=false
local HEADER_OVERLAY_FILE=""
local HEADER_OVERLAY_PATH=""
local HEADER_OVERLAY_URL_PATH=""
local header_overlay_handle=0
local header_overlay_downloaded=false
local SUBHEADER_FILE=""
local SUBHEADER_PATH=""
local SUBHEADER_URL_PATH=""
local subheader_handle=0
local subheader_downloaded=false
local FOOTER_FILE=""
local FOOTER_PATH=""
local FOOTER_URL_PATH=""
local footer_handle=0
local footer_downloaded=false
local BADGE_FILE=""
local BADGE_PATH=""
local BADGE_URL_PATH=""
local BADGE_IS_LOGO=false
local badge_handle=0
local BACKGROUND_FILE=""
local BACKGROUND_PATH=""
local BACKGROUND_URL_PATH=""
local background_handle=0
local background_downloaded=false
local TOGGLE_ON_FILE=""
local TOGGLE_ON_PATH=""
local TOGGLE_ON_URL_PATH=""
local toggle_on_handle=0
local toggle_on_downloaded=false
local TOGGLE_OFF_FILE=""
local TOGGLE_OFF_PATH=""
local TOGGLE_OFF_URL_PATH=""
local toggle_off_handle=0
local toggle_off_downloaded=false
local LIST_ICON_FILE=""
local LIST_ICON_PATH=""
local LIST_ICON_URL_PATH=""
local list_icon_handle=0
local list_icon_downloaded=false
local UI_ASSETS={

}

local function load_header()
    if HEADER_PATH~="" then header_handle=draw.load_image(HEADER_PATH) end
end

local function load_structural_assets()
    if HEADER_OVERLAY_PATH~="" then header_overlay_handle=draw.load_image(HEADER_OVERLAY_PATH) end
    if SUBHEADER_PATH~="" then subheader_handle=draw.load_image(SUBHEADER_PATH) end
    if FOOTER_PATH~="" then footer_handle=draw.load_image(FOOTER_PATH) end
    if BADGE_PATH~="" then badge_handle=draw.load_image(BADGE_PATH) end
end

local function load_background()
    if BACKGROUND_PATH~="" then background_handle=draw.load_image(BACKGROUND_PATH) end
end

local function load_ui_assets()
    if TOGGLE_ON_PATH~="" then toggle_on_handle=draw.load_image(TOGGLE_ON_PATH) end
    if TOGGLE_OFF_PATH~="" then toggle_off_handle=draw.load_image(TOGGLE_OFF_PATH) end
    if LIST_ICON_PATH~="" then list_icon_handle=draw.load_image(LIST_ICON_PATH) end
end

local function fetch_asset(file_path,url_path,done)
    if file_path=="" or url_path=="" or not net or not net.get then return end
    net.get("raw.githubusercontent.com",url_path,function(body)
        if body and #body>128 then done(file.write(file_path,body)) end
    end,function() end)
end

local function prepare_asset(file_path,path,url_path,loaded)
    if file_path=="" or path=="" then return end
    local data=file.read(file_path)
    if data and #data>128 then
        loaded(draw.load_image(path))
    else
        fetch_asset(file_path,url_path,function(ok) if ok then loaded(draw.load_image(path)) end end)
    end
end

do
    if HEADER_FILE~="" then
        local data=file.read(HEADER_FILE)
        if data and #data>128 then
            load_header()
        elseif HEADER_URL_PATH~="" and net and net.get then
            net.get("raw.githubusercontent.com",HEADER_URL_PATH,function(body)
                if body and #body>128 then header_downloaded=file.write(HEADER_FILE,body) end
            end,function() end)
        end
    end
    if BACKGROUND_FILE~="" then
        local data=file.read(BACKGROUND_FILE)
        if data and #data>128 then
            load_background()
        elseif BACKGROUND_URL_PATH~="" and net and net.get then
            net.get("raw.githubusercontent.com",BACKGROUND_URL_PATH,function(body)
                if body and #body>128 then background_downloaded=file.write(BACKGROUND_FILE,body) end
            end,function() end)
        end
    end
    prepare_asset(HEADER_OVERLAY_FILE,HEADER_OVERLAY_PATH,HEADER_OVERLAY_URL_PATH,function(h) header_overlay_handle=h end)
    prepare_asset(SUBHEADER_FILE,SUBHEADER_PATH,SUBHEADER_URL_PATH,function(h) subheader_handle=h end)
    prepare_asset(FOOTER_FILE,FOOTER_PATH,FOOTER_URL_PATH,function(h) footer_handle=h end)
    prepare_asset(BADGE_FILE,BADGE_PATH,BADGE_URL_PATH,function(h) badge_handle=h end)
    local toggle_on_data=TOGGLE_ON_FILE~="" and file.read(TOGGLE_ON_FILE) or nil
    if toggle_on_data and #toggle_on_data>128 then
        load_ui_assets()
    else
        fetch_asset(TOGGLE_ON_FILE,TOGGLE_ON_URL_PATH,function(ok) toggle_on_downloaded=ok end)
    end
    local toggle_off_data=TOGGLE_OFF_FILE~="" and file.read(TOGGLE_OFF_FILE) or nil
    if toggle_off_data and #toggle_off_data>128 then
        load_ui_assets()
    else
        fetch_asset(TOGGLE_OFF_FILE,TOGGLE_OFF_URL_PATH,function(ok) toggle_off_downloaded=ok end)
    end
    local list_icon_data=LIST_ICON_FILE~="" and file.read(LIST_ICON_FILE) or nil
    if list_icon_data and #list_icon_data>128 then
        load_ui_assets()
    else
        fetch_asset(LIST_ICON_FILE,LIST_ICON_URL_PATH,function(ok) list_icon_downloaded=ok end)
    end
    for _,asset in pairs(UI_ASSETS) do
        prepare_asset(asset.file,asset.path,asset.url,function(h) asset.handle=h end)
    end
end

local function ui_asset(...)
    local keys={...}
    for i=1,#keys do
        local asset=UI_ASSETS[string.lower(keys[i] or "")]
        if asset and asset.handle and asset.handle>0 then return asset.handle end
    end
    return 0
end

local function native_height(handle,width,fallback)
    if handle and handle>0 then
        local iw,ih=draw.image_size(handle)
        if iw and ih and iw>0 and ih>0 then return math.max(1,width*ih/iw) end
    end
    return fallback
end

text.set_weight(font.title,700)
text.set_weight(font.item,500)
text.set_weight(font.value,600)
text.set_weight(font.small,600)

local applied_font_scale=-1
local function apply_font_scale(scale)
    if math.abs(applied_font_scale-scale)<0.001 then return end
    applied_font_scale=scale
    text.set_size(font.title,math.max(1,18*scale))
    text.set_size(font.item,math.max(1,16*scale))
    text.set_size(font.value,math.max(1,15*scale))
    text.set_size(font.small,math.max(1,13*scale))
    text.set_size(font.tiny,math.max(1,10*scale))
    text.set_size(font.label,math.max(1,16*scale))
end

local SETTINGS_FILE="stand_import_v3_minimalistic_black_white.ini"
menu.clear_settings()
menu.add_setting_color("Stand Accent",255,255,255,255,"Imported primary colour")
menu.add_setting_color("Stand Background",0,0,0,210,"Imported background colour")
menu.add_setting_slider("Stand Width",380,120,1200,1,"Width in Stand's 1920x1080 HUD pixels")
menu.add_setting_slider("Stand Rows",17,5,24,1,"Visible option rows")
menu.add_setting_slider("Stand Row Height",31,12,100,1,"Row height in Stand HUD pixels")
menu.add_setting_slider("Stand Position X",1300,0,1920,1,"Main-list X coordinate in Stand HUD pixels")
menu.add_setting_slider("Stand Position Y",465,0,1080,1,"Main-list Y coordinate in Stand HUD pixels")
menu.add_setting_action("Reset Theme","Reset imported theme settings")

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
        if key=="accent" or key=="background" then
            local r,g,b,a=value:match("(%d+),(%d+),(%d+),(%d+)")
            if r then
                menu.set_setting(key=="accent" and "Stand Accent" or "Stand Background",
                    tonumber(r),tonumber(g),tonumber(b),tonumber(a))
            end
        elseif key=="width" then menu.set_setting("Stand Width",tonumber(value) or 380)
        elseif key=="rows" then menu.set_setting("Stand Rows",tonumber(value) or 17)
        elseif key=="row_height" then menu.set_setting("Stand Row Height",tonumber(value) or 31)
        elseif key=="position_x" then menu.set_setting("Stand Position X",tonumber(value) or 1300)
        elseif key=="position_y" then menu.set_setting("Stand Position Y",tonumber(value) or 465)
        end
    end
end

local function serialize_settings()
    local accent=setting("Stand Accent") or {r=255,g=255,b=255,a=255}
    local background=setting("Stand Background") or {r=0,g=0,b=0,a=210}
    local width=setting("Stand Width") or {f_val=380}
    local rows=setting("Stand Rows") or {f_val=17}
    local row_height=setting("Stand Row Height") or {f_val=31}
    local position_x=setting("Stand Position X") or {f_val=1300}
    local position_y=setting("Stand Position Y") or {f_val=465}
    return table.concat({
        "accent="..accent.r..","..accent.g..","..accent.b..","..accent.a,
        "background="..background.r..","..background.g..","..background.b..","..background.a,
        "width="..width.f_val,
        "rows="..rows.f_val,
        "row_height="..row_height.f_val,
        "position_x="..position_x.f_val,
        "position_y="..position_y.f_val
    },"\n")
end

local function reset_settings()
    menu.set_setting("Stand Accent",255,255,255,255)
    menu.set_setting("Stand Background",0,0,0,210)
    menu.set_setting("Stand Width",380)
    menu.set_setting("Stand Rows",17)
    menu.set_setting("Stand Row Height",31)
    menu.set_setting("Stand Position X",1300)
    menu.set_setting("Stand Position Y",465)
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

local function indicator_asset(item,toggle_type,action_mark)
    if item.disabled then return ui_asset("disabled") end
    if toggle_type then
        local list_toggle=item.type==item_type.array_toggle or item.type==item_type.loop_toggle
        if item.on then
            return list_toggle and ui_asset("toggle on list","toggle on","enabled")
                or ui_asset("toggle on","enabled")
        end
        return list_toggle and ui_asset("toggle off list","toggle off","disabled")
            or ui_asset("toggle off","disabled")
    end
    if item.type==item_type.selected_tick then return ui_asset("enabled") end
    if item.type==item_type.search then return ui_asset("search") end
    if NUMERIC[item.type] or item.type==item_type.input_text or item.type==item_type.input_int
        or item.type==item_type.input_float then return ui_asset("edit") end
    if item.type==item_type.sub_menu then return ui_asset("list","link") end
    if action_mark then return ui_asset("link","list") end
    return 0
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
        notify.push("Theme",THEME_NAME.." reset",1)
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
    if header_downloaded then load_header();header_downloaded=false end
    if background_downloaded then load_background();background_downloaded=false end
    if toggle_on_downloaded or toggle_off_downloaded or list_icon_downloaded then
        load_ui_assets()
        toggle_on_downloaded=false;toggle_off_downloaded=false;list_icon_downloaded=false
    end

    local accent=setting("Stand Accent") or {r=255,g=255,b=255,a=255}
    local background=setting("Stand Background") or {r=0,g=0,b=0,a=210}
    theme.set_body_bg(background.r,background.g,background.b,background.a)
    theme.set_menu_bg(background.r,background.g,background.b,background.a)
    theme.set_accent_palette(accent.r,accent.g,accent.b,accent.a)
    if not menu.is_visible() then menu.set_text_editing(false);return end

    local width_setting=setting("Stand Width")
    local row_setting=setting("Stand Rows")
    local row_height_setting=setting("Stand Row Height")
    local position_x_setting=setting("Stand Position X")
    local position_y_setting=setting("Stand Position Y")
    -- Stand's DirectX API uses a fixed 1920x1080 coordinate space. Nenyoo's
    -- draw API uses logical coordinates before its UI-scale transform, so this
    -- conversion preserves the source theme's physical size at every resolution.
    local hud_sx=ctx.screen_w()/1920
    local hud_sy=ctx.screen_h()/1080
    apply_font_scale(hud_sy)
    local source_width=clamp(width_setting and width_setting.f_val or 380,120,1200)
    local width=clamp(source_width*hud_sx,1,math.max(1,ctx.screen_w()-16))
    local requested_rows=math.floor(row_setting and row_setting.f_val or 17)
    local row_h=clamp(row_height_setting and row_height_setting.f_val or 31,12,100)*hud_sy
    local position_x=clamp(position_x_setting and position_x_setting.f_val or 1300,0,1920)*hud_sx
    local position_y=clamp(position_y_setting and position_y_setting.f_val or 465,0,1080)*hud_sy
    local alpha=background.a or 210
    local count=menu.item_count()
    local sel=menu.selected_index()
    local structural_header=HEADER_PATH~="" and LAYOUT_MODE=="standard"
    local banner_h=structural_header and native_height(header_handle,width,76*hud_sy) or 0
    local page_h=SUBHEADER_PATH~="" and native_height(subheader_handle,width,28*hud_sy)
        or (TABS_ENABLED and 28*hud_sy or 0)
    local desc_h=FOOTER_PATH~="" and native_height(footer_handle,width,31*hud_sy) or 46*hud_sy
    local desired_rows=math.min(requested_rows,math.max(1,count))
    local available_h=math.max(1,ctx.screen_h()-banner_h-page_h-desc_h-24)
    if desired_rows>0 and row_h*desired_rows>available_h then
        row_h=math.max(12*hud_sy,available_h/desired_rows)
    end
    local rows=math.min(requested_rows,math.max(1,math.floor(available_h/row_h)))
    local start=math.floor(sel/rows)*rows
    local visible=math.min(rows,math.max(0,count-start))
    local body_h=visible*row_h
    local height=banner_h+page_h+body_h+desc_h
    local x=math.floor(clamp(position_x,8,math.max(8,ctx.screen_w()-width-8)))
    local content_y=math.floor(clamp(position_y,banner_h+page_h+8,math.max(banner_h+page_h+8,ctx.screen_h()-body_h-desc_h-page_h-8)))
    local page_y=TAB_BOTTOM and (content_y+body_h) or (content_y-page_h)
    local y=TAB_BOTTOM and (content_y-banner_h) or (page_y-banner_h)
    local drag_y=banner_h>0 and y or (page_h>0 and page_y or content_y)
    local drag_h=banner_h>0 and banner_h or (page_h>0 and page_h or math.max(1,row_h))
    local ox,oy=menu.drag_header(x,drag_y,width,drag_h)
    x=x+ox;y=y+oy;content_y=content_y+oy;page_y=page_y+oy
    menu.set_content_rect(x,content_y,width,visible*row_h)

    -- Stand's main-view background starts at the option list. Structural header/subheader/footer
    -- images are separate ARGB layers; filling behind them destroys their intended transparency.
    if LAYOUT_MODE=="cherax" then
        local side_w=115*hud_sx
        local panel_left=x-96*hud_sx
        local logo_left=x-207*hud_sx
        draw.rect(panel_left,content_y,x+width,content_y+body_h,13,1,21,255)
        if header_handle and header_handle>0 then
            draw.image(header_handle,logo_left,content_y,logo_left+side_w,content_y+body_h,1.0)
        end
        draw.rect(logo_left,content_y-25*hud_sy,logo_left+side_w,content_y,112,35,226,255)
    else
        draw.rect(x,content_y,x+width,content_y+body_h,background.r,background.g,background.b,alpha)
    end
    if LAYOUT_MODE~="cherax" and background_handle and background_handle>0 then
        draw.push_clip(x,content_y,x+width,content_y+body_h)
        draw.image(background_handle,x,content_y,x+width,content_y+body_h,0.78)
        draw.pop_clip()
    end
    if structural_header and header_handle and header_handle>0 then
        draw.push_clip(x,y,x+width,y+banner_h)
        draw.image(header_handle,x,y,x+width,y+banner_h,1.0)
        draw.pop_clip()
        if header_overlay_handle and header_overlay_handle>0 then
            draw.image(header_overlay_handle,x,y,x+width,y+banner_h,1.0)
        end
    elseif LAYOUT_MODE=="standard" then
        draw.rect_gradient(x,y,x+width,y+banner_h,
            accent.r,accent.g,accent.b,240,
            math.floor(accent.r*.45),math.floor(accent.g*.45),math.floor(accent.b*.45),240,
            math.floor(accent.r*.30),math.floor(accent.g*.30),math.floor(accent.b*.30),240,
            accent.r,accent.g,accent.b,240)
    end
    if 255>0 and 1>0 then
        draw.rect_outline(x,content_y,x+width,content_y+body_h,0,0,0,255,0,1)
    end
    if LAYOUT_MODE=="standard" and not (header_handle and header_handle>0) then
        local badge_w=0
        if badge_handle and badge_handle>0 then
            local iw,ih=draw.image_size(badge_handle)
            if iw and ih and iw>0 and ih>0 then
                local badge_h=math.min(banner_h-10,64)
                badge_w=badge_h*iw/ih
                local badge_x=BADGE_IS_LOGO and (x+(width-badge_w)*0.5) or (x+10)
                draw.image(badge_handle,badge_x,y+(banner_h-badge_h)*0.5,badge_x+badge_w,y+(banner_h+badge_h)*0.5,1.0)
            end
        end
        if not BADGE_IS_LOGO then
            local title_x=badge_w>0 and (x+20+badge_w) or (x+(width-text.width(font.title,THEME_NAME))*0.5)
            text.draw_outlined(font.title,title_x,y+(banner_h-text.height(font.title))*0.5,
                0,0,0,255,
                0,0,0,180,1.0,THEME_NAME)
        end
    end

    local page=menu.page_name() or "Home"
    local page_name=page=="Home" and "Main Menu" or page
    if page_h>0 then
        if subheader_handle and subheader_handle>0 then
            draw.image(subheader_handle,x,page_y,x+width,page_y+page_h,1.0)
        else
            draw.rect(x,page_y,x+width,page_y+page_h,
                math.floor(background.r*.55),math.floor(background.g*.55),math.floor(background.b*.55),math.max(alpha,220))
        end
        if TABS_ENABLED then
            text.draw(font.small,x+10,page_y+(page_h-text.height(font.small))*0.5,
                238,238,242,235,page_name)
            local counter=count>0 and tostring(sel+1).." / "..tostring(count) or "0 / 0"
            text.draw(font.small,x+width-10-text.width(font.small,counter),
                page_y+(page_h-text.height(font.small))*0.5,238,238,242,235,counter)
        end
    end

    for row=0,visible-1 do
        local idx=start+row
        local yy=content_y+row*row_h
        local item=menu.get_item(idx)
        if item then
            item._idx=idx
            local active=idx==sel
            local hovered=hit(x,yy,x+width,yy+row_h)
            if active then draw.rect(x,yy,x+width,yy+row_h,accent.r,accent.g,accent.b,accent.a) end
            if hovered and not active then draw.rect(x,yy,x+width,yy+row_h,accent.r,accent.g,accent.b,45) end
            if 255>0 then
                draw.rect(x,yy+row_h-1,x+width,yy+row_h,0,0,0,math.min(255,80))
            end

            if item.is_header then
                text.draw(font.small,x+10,yy+(row_h-text.height(font.small))*0.5,
                    active and 0 or accent.r,active and 0 or accent.g,active and 0 or accent.b,255,
                    (item.name or ""):gsub("^[%-%s]+",""):gsub("[%-%s]+$",""))
            else
                local name_icon=ui_asset(item.name or "")
                local text_x=x+10
                if name_icon and name_icon>0 then
                    local icon_size=math.min(18,row_h-7)
                    draw.image(name_icon,text_x,yy+(row_h-icon_size)*0.5,text_x+icon_size,yy+(row_h+icon_size)*0.5,1.0)
                    text_x=text_x+icon_size+7
                end
                text.draw_ellipsis(font.item,text_x,yy+(row_h-text.height(font.item))*0.5,
                    active and 0 or 238,active and 0 or 238,active and 0 or 242,active and 255 or 235,
                    item.name or "",width*0.70)

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

                local indicator_x=x+width-14
                if toggle_type then
                    local toggle_handle=indicator_asset(item,toggle_type,action_mark)
                    if not toggle_handle or toggle_handle<=0 then toggle_handle=item.on and toggle_on_handle or toggle_off_handle end
                    if toggle_handle and toggle_handle>0 then
                        local icon_size=math.min(20,row_h-6)
                        draw.image(toggle_handle,indicator_x-icon_size,yy+(row_h-icon_size)*0.5,
                            indicator_x,yy+(row_h+icon_size)*0.5,1.0)
                    else
                        draw.rect_outline(indicator_x-5,yy+row_h*0.5-5,indicator_x+5,yy+row_h*0.5+5,
                            active and 0 or 238,active and 0 or 238,active and 0 or 242,210,1,1)
                        if item.on then draw.rect(indicator_x-3,yy+row_h*0.5-3,indicator_x+3,yy+row_h*0.5+3,
                            active and 0 or accent.r,active and 0 or accent.g,active and 0 or accent.b,255,1) end
                    end
                elseif item.type==item_type.selected_tick then
                    local selected_handle=indicator_asset(item,false,false)
                    if selected_handle and selected_handle>0 then
                        local icon_size=math.min(18,row_h-7)
                        draw.image(selected_handle,indicator_x-icon_size,yy+(row_h-icon_size)*0.5,
                            indicator_x,yy+(row_h+icon_size)*0.5,1.0)
                    else
                        draw.circle(indicator_x,yy+row_h*0.5,5,accent.r,accent.g,accent.b,255)
                    end
                elseif action_mark then
                    local action_handle=indicator_asset(item,false,action_mark)
                    if not action_handle or action_handle<=0 then action_handle=list_icon_handle end
                    if action_handle and action_handle>0 then
                        local icon_size=math.min(18,row_h-7)
                        draw.image(action_handle,x+width-8-icon_size,yy+(row_h-icon_size)*0.5,
                            x+width-8,yy+(row_h+icon_size)*0.5,1.0)
                    else
                        local mark=">"
                        text.draw(font.small,x+width-10-text.width(font.small,mark),yy+(row_h-text.height(font.small))*0.5,
                            active and 0 or 238,active and 0 or 238,active and 0 or 242,255,mark)
                    end
                end
                if value~="" then
                    local right=toggle_type and indicator_x-12 or x+width-10
                    text.draw(font.value,right-text.width(font.value,value),yy+(row_h-text.height(font.value))*0.5,
                        active and 0 or 238,active and 0 or 238,active and 0 or 242,255,value)
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

    local desc_y=content_y+body_h+(TAB_BOTTOM and page_h or 0)
    if footer_handle and footer_handle>0 then
        draw.image(footer_handle,x,desc_y,x+width,desc_y+desc_h,1.0)
    else
        draw.rect(x,desc_y,x+width,desc_y+desc_h,
            math.floor(background.r*.60),math.floor(background.g*.60),math.floor(background.b*.60),math.max(alpha,210))
        draw.rect(x,desc_y,x+width,desc_y+1,accent.r,accent.g,accent.b,125)
        local selected_item=count>0 and menu.get_item(sel) or nil
        local description=(selected_item and selected_item.desc and selected_item.desc~="") and selected_item.desc
            or (selected_item and ("Select "..(selected_item.name or "this option")..".") or "No options available.")
        draw.push_clip(x+9,desc_y+4,x+width-9,desc_y+desc_h-4)
        text.draw(font.desc,x+9,desc_y+7,238,238,242,235,description,width-18)
        draw.pop_clip()
    end

    if count>rows then
        local track_y=content_y
        local track_h=visible*row_h
        local thumb_h=math.max(18,track_h*(rows/count))
        local max_start=math.max(1,count-rows)
        local thumb_y=track_y+(track_h-thumb_h)*(start/max_start)
        draw.rect(x+width-3,thumb_y,x+width,thumb_y+thumb_h,accent.r,accent.g,accent.b,190)
    end

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
