-- Bento — N-column masonry card grid, rebuilt on the ui.* library.
--
-- Bento already did masonry properly, so the visible result is unchanged: 2-4 columns from the
-- Columns setting, shortest-column placement, one shared scroll, off-screen cards culled.
--
-- What went away is the tax it paid for it. `measure_items` was a hand-maintained SECOND copy of
-- every widget's height math, needed because the draw function was the only thing that knew a row's
-- height. The two copies had already drifted -- this file used ITEM_H+9 / ITEM_H+11 where the other
-- card theme used +8 / +10 for the same controls. Now a widget declares its height once in
-- `measure` and is handed that height in `draw`, so there is nothing left to keep in sync.
--
-- Also fixed on the way past: the submenu lookup was items.page_items(it.name), which hashes a
-- TRANSLATED display name against an English page key -- it returned nothing under every non-English
-- pack, silently emptying every card. It now routes by page id (ui.cards_bucketed -> items.
-- submenu_page_id).

menu.clear_settings()
menu.add_setting_submenu("Colors", "Theme colors")
menu.add_sub_color("Accent", 124, 116, 255, 255, "Primary accent")
menu.add_sub_color("Background", 15, 16, 22, 255, "Window background")
menu.add_setting_submenu("Layout", "Grid + sizing")
menu.add_sub_slider("Columns", 3, 2, 4, 1, "Card columns")
menu.add_sub_slider("Card Radius", 10, 0, 18, 1, "Corner rounding")
menu.add_sub_slider("Window Width", 760, 560, 1100, 10, "Window width (px)")
menu.add_sub_slider("Window Height", 540, 380, 820, 10, "Window height (px)")

local HDR_H = 44
local GAP = 10

local function sc(name)
    local s = menu.get_setting(name)
    if s then return { s.r, s.g, s.b, s.a } end
    return nil
end
local function sf(name, def)
    local s = menu.get_setting(name)
    return s and s.f_val or def
end

local function apply_skin()
    local acc = sc("Accent") or { 124, 116, 255, 255 }
    local bg = sc("Background") or { 15, 16, 22, 255 }
    local sk = ui.skin
    sk.radius      = math.floor(sf("Card Radius", 10))
    sk.pill_radius = 999
    sk.row_h       = 26
    sk.btn_h       = 24
    sk.gap         = 4
    sk.card_head   = 28
    sk.card_pad    = 10
    sk.card_bot    = 10
    sk.header_h    = HDR_H
    sk.scrollbar_w = 4

    local c = sk.col
    c.bg         = bg
    c.panel      = { bg[1] + 4, bg[2] + 4, bg[3] + 6, 255 }
    c.card       = { bg[1] + 9, bg[2] + 9, bg[3] + 13, 255 }
    c.card_hover = { bg[1] + 14, bg[2] + 14, bg[3] + 20, 255 }
    c.card_bdr   = { 255, 255, 255, 20 }
    c.acc        = acc
    c.pill       = { acc[1] * 0.35, acc[2] * 0.35, acc[3] * 0.38, 255 }
    c.pill_hover = { acc[1] * 0.52, acc[2] * 0.52, acc[3] * 0.55, 255 }
    c.toggle_off = { 48, 48, 62, 255 }
    c.track      = { 44, 44, 58, 255 }
    c.field      = { bg[1] + 5, bg[2] + 5, bg[3] + 8, 255 }
    c.field_bdr  = { 70, 70, 92, 170 }
    c.scrollbar  = acc
    return sk
end

function draw_menu()
    if not menu.is_visible() then return end
    ui.begin_frame()
    ui.auto_accent = false
    local sk = apply_skin()

    local W = sf("Window Width", 760)
    local H = sf("Window Height", 540)
    local cols = math.max(2, math.min(4, math.floor(sf("Columns", 3) + 0.5)))

    local x, y = ui.window("bento", W, H, sk, HDR_H)

    local tree = ui.column{
        gap = 0,
        ui.fixed(HDR_H, function(fx, fy, fw, fh)
            local c = sk.col.panel
            draw.rect(fx, fy, fx + fw, fy + fh, c[1], c[2], c[3], 255, 0)
            local t = sk.col.txt
            text.draw(sk.font.title, fx + 18, fy + (fh - text.height(sk.font.title)) * 0.5,
                      t[1], t[2], t[3], 255, string.upper(str.brand or "NENYOO"))
            local a = sk.col.acc
            text.draw_ellipsis(sk.font.small, fx + 18, fy + fh - 14, a[1], a[2], a[3], 255,
                               menu.page_name(), fw - 36)
        end),
        ui.columns{
            n = cols,
            gap = GAP,
            id = ui.id("bento", menu.page_id()),
            h = H - HDR_H - GAP,
            independent_scroll = false,      -- one shared scroll over the whole grid, as before
            table.unpack(ui.cards_bucketed()),
        },
    }

    ui.draw(tree, x, y, W, sk)
    ui.end_frame()
end

function handle_input()
    -- Arrows move the focus ring, Enter activates through the same path a click takes, Escape/Back
    -- go up a page. Without this the menu is mouse-only.
    ui.keyboard_nav()
end
