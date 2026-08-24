-- ClickGUI — compact windowed list, rebuilt on the ui.* library.
--
-- Same look as before (dark window, horizontal tab strip, one scrolling column of rows, description
-- strip at the bottom), but the machinery underneath is gone:
--   * 20 file-scope globals (several dead) -> none; per-widget state lives in ui.state
--   * hand-rolled scroll offset + one-frame-stale clamp -> the scroll container owns it
--   * hit tests like `mouse_x > x + w * 0.5` while drawing the arrow somewhere else -> hit rects ARE
--     the drawn rects
--   * the colour popup drawing over rows that still received the click (no consumption flag existed
--     here at all) -> ui.clicked consumes, and popups sit on their own layer
--   * a hardcoded 3-entry category list that had drifted from the real menu -> menu.tab_*

menu.clear_settings()
menu.add_setting_submenu("Colors", "Click GUI colors")
menu.add_sub_color("Accent", 130, 80, 255, 255, "Primary accent color")
menu.add_sub_color("Background", 18, 18, 24, 255, "Window background")

menu.add_setting_submenu("Layout", "Window dimensions")
menu.add_sub_slider("Width", 600, 400, 900, 10, "Window width")
menu.add_sub_slider("Height", 460, 300, 700, 10, "Window height")
menu.add_sub_slider("Item Height", 28, 20, 44, 1, "Row height")

local function sc(name)
    local s = menu.get_setting(name)
    if s then return { s.r, s.g, s.b, s.a } end
    return nil
end

local function sf(name, def)
    local s = menu.get_setting(name)
    if s then return s.f_val end
    return def
end

local HDR_H, TAB_H, DESC_H = 30, 26, 22

-- Restyle the shared widget set into ClickGUI's flatter, squarer look. Layout, hit-testing, clipping
-- and scrolling all still come from the library -- only appearance is overridden here.
local function apply_skin()
    local acc = sc("Accent") or { 130, 80, 255, 255 }
    local bg = sc("Background") or { 18, 18, 24, 255 }
    local function dim(c, n) return { math.max(c[1] - n, 0), math.max(c[2] - n, 0), math.max(c[3] - n, 0), 255 } end

    local sk = ui.skin
    sk.radius      = 4
    sk.pill_radius = 4
    sk.row_h       = sf("Item Height", 28)
    sk.btn_h       = math.max(20, sk.row_h - 4)
    sk.gap         = 2
    sk.card_pad    = 8
    sk.card_head   = 0
    sk.card_bot    = 0
    sk.toggle_w    = 26
    sk.toggle_h    = 14
    sk.toggle_knob = 4
    sk.scrollbar_w = 3

    local c = sk.col
    c.bg         = bg
    c.panel      = dim(bg, 6)
    c.card       = bg
    c.card_hover = bg
    c.card_bdr   = { 0, 0, 0, 0 }
    c.acc        = acc
    c.pill       = { 26, 26, 38, 255 }
    c.pill_hover = { 36, 36, 52, 255 }
    c.toggle_off = { 26, 26, 38, 255 }
    c.track      = { 30, 30, 44, 255 }
    c.field      = { 22, 22, 34, 255 }
    c.field_bdr  = { 40, 40, 56, 200 }
    c.txt        = { 220, 220, 235, 255 }
    c.txt_dim    = { 170, 170, 190, 255 }
    c.txt_off    = { 110, 110, 130, 255 }
    c.div        = { 40, 40, 56, 200 }
    c.scrollbar  = acc
    return sk
end

function draw_menu()
    if not menu.is_visible() then return end
    ui.begin_frame()
    local sk = apply_skin()
    ui.auto_accent = false   -- this theme owns its whole palette

    local W, H = sf("Width", 600), sf("Height", 460)
    local x, y = ui.window("clickgui", W, H, sk, HDR_H)

    local list_h = H - HDR_H - TAB_H - DESC_H
    local tree = ui.column{
        gap = 0,
        ui.fixed(HDR_H, function(fx, fy, fw, fh)
            local c = sk.col.panel
            draw.rect(fx, fy, fx + fw, fy + fh, c[1], c[2], c[3], 255, 0)
            local t = sk.col.txt
            text.draw_centered(sk.font.title, fx, fy + (fh - text.height(sk.font.title)) * 0.5, fx + fw,
                               t[1], t[2], t[3], 255, menu.page_name())
        end),
        ui.tab_bar{ h = TAB_H },
        ui.scroll{
            id = ui.id("clickgui", "list", menu.page_id()),
            h = list_h,
            ui.column{ gap = sk.gap, pad = 6, table.unpack(ui.rows_for_page()) },
        },
        ui.desc_bar{ h = DESC_H },
    }

    ui.draw(tree, x, y, W, sk)
    ui.end_frame()
end

function handle_input()
    -- Arrows move the focus ring, Enter activates through the same path a click takes, Escape/Back
    -- go up a page. Without this the menu is mouse-only.
    ui.keyboard_nav()
end
