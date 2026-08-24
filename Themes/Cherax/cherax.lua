-- Cherax — icon sidebar + two columns of group-box cards, on the ui.* library.
--
-- Visual identity is restored from the original: FontAwesome sidebar icons at a 40px pitch, the
-- moto-verse "NENYOO" wordmark, the bright purple accent, the background image and the edge glow.
-- What the library replaced is the machinery, not the look:
--   * 32 file-scope globals (incl. the drag_sl_handle / cpick_handle / dd_handle mirror set) -> none
--   * `click_consumed` hand-checked at 8 sites -> ui.clicked consumes automatically
--   * dd_frame / cpick_frame "ignore the click that opened me" guards -> layers
--   * dd_x/dd_y/dd_w stashed to redraw the dropdown at the end -> ui.defer
--   * manual flip-up + viewport clamp -> ui.popup_place
--   * scroll_l/scroll_r/scroll_tl/scroll_tr + six copies of the reset -> the scroll containers
--   * `flatten_subs`, a table with exactly ONE entry, which is why group boxes only ever worked on
--     this theme's own settings page -> every submenu is a card, on every page
--   * columns balanced by item count (5 sliders and 5 toggles both counted as 7, so they desynced)
--     -> balanced on measured pixels

menu.clear_settings()
menu.add_setting_submenu("Colors", "Theme colors")
menu.add_sub_color("Accent", 184, 14, 232, 255, "Primary accent")

-- ── Fonts ──
-- The wordmark face and the icon face. set_icon_font is required for the PUA range FontAwesome uses;
-- a plain set_font_for renders them as missing-glyph boxes.
text.set_font_for(font.tagline, "themes/Cherax/fonts/moto-verse.ttf")
text.set_size(font.tagline, 21)   -- wordmark cap height ~17 in the reference
text.set_weight(font.tagline, 400)
text.set_size(font.breadcrumb, 15)      -- card titles
text.set_weight(font.breadcrumb, 600)
text.set_size(font.item, 15)
text.set_weight(font.item, 600)
text.set_size(font.value, 15)
text.set_icon_font(font.label, "themes/Cherax/fonts/FontAwesome.ttf")
text.set_size(font.label, 26)
text.set_weight(font.label, 400)

-- FontAwesome codepoints, UTF-8 encoded. Keyed by PAGE ID (joaat of the English page key) rather
-- than by the tab's display name, which is translated.
local fa = {
    user     = "\xEF\x80\x87",  -- F007 user            Self
    users    = "\xEF\x83\x80",  -- F0C0 users           Network
    car      = "\xEF\x86\xB9",  -- F1B9 car             Vehicle
    cross    = "\xEF\x81\x9B",  -- F05B crosshairs      Weapon
    magic    = "\xEF\x83\x90",  -- F0D0 magic           VFX
    globe    = "\xEF\x82\xAC",  -- F0AC globe           World
    cube     = "\xEF\x86\xB2",  -- F1B2 cube            Misc
    marker   = "\xEF\x81\x81",  -- F041 map-marker      Teleport
    terminal = "\xEF\x84\xA0",  -- F120 terminal        Scripts
    cubes    = "\xEF\x86\xB3",  -- F1B3 cubes           Spooner
    shield   = "\xEF\x84\xB2",  -- F132 shield          Protections
    cog      = "\xEF\x80\x93",  -- F013 cog             Settings
}

local ICONS = {}
local function icon_for(page, glyph) ICONS[items.joaat(page)] = glyph end
icon_for("Self", fa.user)         icon_for("Network", fa.users)
icon_for("Vehicle", fa.car)       icon_for("Weapon", fa.cross)
icon_for("VFX", fa.magic)         icon_for("World", fa.globe)
icon_for("Misc", fa.cube)         icon_for("Teleport", fa.marker)
icon_for("Scripts", fa.terminal)  icon_for("Spooner", fa.cubes)
icon_for("Protections", fa.shield) icon_for("Settings", fa.cog)

-- ── Background images (themes/Cherax/texture/) ──
local bg_names, bg_handles = {}, {}
local bg_dir = "themes/Cherax/texture"
for _, fname in ipairs(fs.list(bg_dir) or {}) do
    local ext = fname:lower():match("%.(%w+)$")
    if ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "gif" or ext == "bmp" then
        local h = draw.load_image(bg_dir .. "/" .. fname)
        if h and h > 0 then
            bg_names[#bg_names + 1] = fname
            bg_handles[#bg_handles + 1] = h
        end
    end
end

menu.add_setting_submenu("Background", "Background image settings")
menu.add_sub_toggle("BG Enabled", true, "Show background image")
menu.add_sub_toggle("BG Full", false, "Extend to sidebar and header")
menu.add_sub_slider("BG Opacity", 0.3, 0.0, 1.0, 0.05, "Background image opacity")
if #bg_names > 0 then menu.add_sub_array("BG Image", bg_names, 0, "Select background image") end

menu.add_setting_submenu("Glow", "Edge glow effect")
menu.add_sub_toggle("Glow Enabled", true, "Show glow on window edges")
menu.add_sub_slider("Glow Size", 46, 5, 90, 0.1, "Glow spread in pixels")
menu.add_sub_slider("Glow Opacity", 0.85, 0.05, 1.0, 0.01, "Glow intensity")
menu.add_sub_color("Glow Color", 184, 14, 232, 255, "Glow color")

local WIN_W, WIN_H = 795, 737   -- reference window, measured
local SIDE_W, HDR_H = 54, 45    -- measured: window top y=50, first card top y=95

local function sc(n) local s = menu.get_setting(n); if s then return { s.r, s.g, s.b, s.a } end end
local function sf(n, d) local s = menu.get_setting(n); return s and s.f_val or d end
local function sb(n, d) local s = menu.get_setting(n); if s == nil then return d end return s.on end
local function si(n) local s = menu.get_setting(n); return s and s.value_index or 0 end

local function apply_skin()
    local acc = sc("Accent") or { 184, 14, 232, 255 }
    local sk = ui.skin
    -- Geometry measured off the reference screenshot (grid overlay, 10px steps):
    --   card pad 10, title band 48, chip h 28 / pitch 34, toggle disc r8, dropdown 44% of the card.
    sk.radius       = 16
    sk.pill_radius  = 999    -- the chips ARE pills: their end caps are full half-circles
    sk.btn_radius   = 999
    sk.btn_pad      = 12
    sk.btn_fit      = true
    sk.row_h        = 26
    sk.btn_h        = 28
    sk.gap          = 6
    sk.card_head    = 32   -- slim title bar
    sk.card_pad     = 10
    sk.card_bot     = 10
    sk.card_radius  = 4        -- barely rounded at the top
    sk.card_glow    = 0        -- no edge bloom
    sk.card_square_bottom = true   -- rounded across the top only
    sk.card_bottom_edge = false    -- no closing line; the card just fades out
    sk.window_shadow = 5       -- dark rim outside the window, reads as a drop shadow
    sk.card_top_edge = false
    sk.card_rule    = false    -- the reference has no rule between the title and the first row
    sk.rail_w       = SIDE_W
    sk.rail_cell    = 52       -- measured icon pitch
    sk.rail_indicator = false  -- selection is the icon's colour only; no bar, no box
    sk.rail_div_w   = 2
    sk.rail_glow_top = 0.30    -- rail stays near-black for its first third, as in the reference
    sk.header_h     = HDR_H
    sk.scrollbar_w  = 5
    sk.toggle_style = "circle"
    sk.toggle_r     = 8
    sk.combo_frac   = 0.44
    sk.combo_radius = 6
    sk.stepper_btn  = 30
    sk.track_h      = 5
    sk.knob_r       = 7
    sk.font.icon    = font.label
    sk.font.card    = font.breadcrumb
    local c = sk.col
    -- Sampled off the reference screenshot rather than eyeballed:
    --   window #020203 (essentially black), card #120122, chip/dropdown #470078, accent #B80EE8.
    c.bg          = { 5, 3, 7, 252 }          -- top, near-black (measured #050307)
    c.bg_bot      = { 154, 9, 217, 252 }      -- bottom EDGE brightness (#9A09D9)
    c.bg_center_dim = { 0, 0, 0, 126 }        -- knocks the middle back to ~#420560
    c.rail_glow   = nil                       -- the base gradient now carries the edge brightness
    c.panel       = { 5, 3, 7, 255 }
    -- Cards are a translucent dark tint whose ALPHA fades down the card, not a fill. Measured against
    -- the window gradient behind them: ~0.20 alpha near the top, ~0.00 by the bottom -- so a card is
    -- barely there at the foot of the window and only slightly darkens the top. That fade is what
    -- makes the reference look lit rather than a stack of dark boxes.
    c.card        = { 6, 1, 12, 62 }
    c.card_bot_col    = { 6, 1, 12, 100 }     -- options area keeps a little tint
    c.card_hover  = { 14, 4, 26, 78 }
    c.card_hover_bot  = { 14, 4, 26, 114 }
    -- Dark edge, not a violet one: with the bloom gone a bright border reads as a hard pink
    -- line. Same treatment as the window rim -- the card is defined by its dark title slab
    -- and body tint, with the edge only separating it from the background.
    c.card_bdr    = { 4, 2, 9, 165 }     -- MEASURED peak #7616C6 -- not the accent; the
                                              -- reference edge is violet, only ~2x the interior
    c.card_title_bg = { 2, 2, 3, 205 }        -- near-black title slab (measured #020202)
    c.acc         = acc
    c.pill        = { 71, 0, 120, 255 }
    c.pill_hover  = { 100, 6, 165, 255 }
    c.combo       = { 71, 0, 120, 255 }
    c.combo_hover = { 100, 6, 165, 255 }
    c.combo_bdr   = nil
    c.toggle_off  = { 40, 2, 70, 255 }
    c.knob        = { 250, 246, 252, 255 }
    c.track       = { 52, 4, 90, 255 }
    c.field       = { 30, 2, 54, 255 }
    c.field_bdr   = { 106, 31, 168, 200 }
    c.txt         = { 250, 246, 252, 255 }
    c.txt_dim     = { 240, 234, 248, 255 }
    c.txt_off     = { 150, 120, 186, 255 }
    c.div         = { 106, 31, 168, 130 }
    c.rail_div    = { 255, 255, 255, 105 }    -- translucent white; the gradient shows through
    c.rail        = { 0, 0, 0, 0 }            -- transparent: the rail shows the window gradient
    c.window_bdr  = { 3, 2, 6, 240 }          -- dark rim; the glow sits outside it (measured #030510)
    c.rail_sel    = acc
    c.scrollbar   = { 255, 246, 255, 235 }
    return sk
end

-- Edge glow: concentric fading outlines around the window.
local function draw_glow(x, y, w, h, sk)
    if not sb("Glow Enabled", true) then return end
    local gc = sc("Glow Color") or sk.col.acc
    local size, op = sf("Glow Size", 46), sf("Glow Opacity", 0.85)
    -- One ring per pixel of spread with a quartic falloff. Coarser stepping leaves visible banding
    -- rather than a bloom, which is the single most obvious tell against the reference.
    local steps = math.max(8, math.floor(size))
    for i = steps, 1, -1 do
        local t = i / steps
        local sp = size * t
        local f = (1 - t)
        local a = math.floor(255 * op * f * f * f)
        if a > 0 then
            draw.rect_outline(x - sp, y - sp, x + w + sp, y + h + sp,
                              gc[1], gc[2], gc[3], a, sk.radius + sp, 1)
        end
    end
end

local function draw_bg_image(x, y, w, h, full)
    if not sb("BG Enabled", true) or #bg_handles == 0 then return end
    local handle = bg_handles[si("BG Image") + 1] or bg_handles[1]
    if not handle then return end
    local op = sf("BG Opacity", 0.3)
    if full then draw.image(handle, x, y, x + w, y + h, op)
    else draw.image(handle, x + SIDE_W, y + HDR_H, x + w, y + h, op) end
end

-- Header: wordmark centred over the content area, search + star on the right.
local function header_right(x, y, w, h, sk)
    local cy = y + h * 0.5
    local star_x, srch_x = x + w - 28, x + w - 58
    local c1 = ui.hovered(srch_x - 8, cy - 11, srch_x + 16, cy + 11) and sk.col.txt or sk.col.txt_dim
    draw.circle_outline(srch_x + 4, cy - 2, 5.5, c1[1], c1[2], c1[3], 255, 1.6)
    draw.line(srch_x + 8, cy + 2, srch_x + 12, cy + 6, c1[1], c1[2], c1[3], 255, 1.6)

    local c2 = ui.hovered(star_x - 8, cy - 11, star_x + 16, cy + 11) and sk.col.acc or sk.col.txt_dim
    local pts = {}
    for i = 0, 9 do
        local a = -math.pi * 0.5 + i * math.pi / 5
        local rr = (i % 2 == 0) and 8 or 3.6
        pts[#pts + 1] = { star_x + 4 + math.cos(a) * rr, cy + math.sin(a) * rr }
    end
    for i = 1, #pts do
        local a, b = pts[i], pts[(i % #pts) + 1]
        draw.line(a[1], a[2], b[1], b[2], c2[1], c2[2], c2[3], 255, 1.5)
    end
end

function draw_menu()
    if not menu.is_visible() then return end
    ui.begin_frame()
    ui.auto_accent = false
    local sk = apply_skin()

    local x, y = ui.window("cherax", WIN_W, WIN_H, sk, HDR_H)
    draw_glow(x, y, WIN_W, WIN_H, sk)
    draw_bg_image(x, y, WIN_W, WIN_H, sb("BG Full", false))

    local tree = ui.row{
        -- Small gap so the content clears the rail divider. With gap 0 the first card is drawn
        -- straight over it and the line vanishes below the header.
        gap = 4,
        weights = { SIDE_W, 1 },
        ui.icon_rail{ h = WIN_H, icons = ICONS, cell = sk.rail_cell, top = HDR_H },
        ui.column{
            gap = 0,                 -- the first card sits directly under the header, as in the reference
            ui.header{ h = HDR_H, wordmark = "NENYOO", font = font.tagline, right = header_right },
            ui.columns{
                n = 2,
                vgap = 0,          -- cards stack flush; their title bands do the separating
                fill_column = true,
                panel = true,      -- one continuous tinted surface behind the whole grid-- a short column stretches its last card rather than showing bare background
                id = ui.id("cherax", menu.page_id()),
                -- header + gap + columns must total WIN_H exactly. Subtracting the gap TWICE left a
                -- strip of bare window at the foot -- untinted, so it read as a brighter band with a
                -- hard edge where the cards stopped.
                h = WIN_H - HDR_H,
                -- ONE scroll for the whole grid, with a single bar at the window's right edge.
                -- Measured: the reference has exactly one scrollbar column (x 807-810 of an 821-wide
                -- window) and nothing between the columns -- both columns clip at the same line, so
                -- they move together rather than scrolling independently.
                independent_scroll = false,
                -- The reference stacks actions full-width, one per row -- never two up.
                table.unpack(ui.cards_for_page{ pair_buttons = false }),
            },
        },
    }

    ui.draw(tree, x, y, WIN_W, sk)
    ui.end_frame()
end

function handle_input()
    -- Arrows move the focus ring, Enter activates through the same path a click takes, Escape/Back
    -- go up a page. Without this the menu is mouse-only.
    ui.keyboard_nav()
end
